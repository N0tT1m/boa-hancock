import logging
import sqlite3
import uuid
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from models import ChatMessage, ChatResponse, SearchResponse, ImageSearchResult, SearchResult, Expense, Income, Metadata, DocumentAnalysisResult
from config import setup_logging, setup_ollama, setup_calendar_api
from calendar_service import handle_calendar_request, is_calendar_request
from chat_service import process_chat_request
from search_service import perform_web_search, perform_image_search, is_search_request
from document_analysis_service import analyze_pdf, analyze_word, analyze_spreadsheet
from expense_service import ExpenseTracker
from typing import List, Dict, Any
import traceback

expenses: List[Dict[str, Any]] = []
income: List[Dict[str, Any]] = []

# Setup logging
logger = setup_logging()

# Initialize FastAPI app
app = FastAPI()

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Setup Ollama and Google Calendar API
ollama_client = setup_ollama()
setup_calendar_api()

# Setup SQLite database
conn = sqlite3.connect('chat_history.db')
c = conn.cursor()
c.execute('''CREATE TABLE IF NOT EXISTS conversations
             (id INTEGER PRIMARY KEY AUTOINCREMENT,
              conversation_id TEXT,
              role TEXT,
              content TEXT,
              timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)''')
conn.commit()

# SQLite setup
conn2 = sqlite3.connect('expense_tracker.db')
c2 = conn.cursor()
c2.execute('''CREATE TABLE IF NOT EXISTS expenses
             (id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL,
              category TEXT,
              description TEXT,
              date DATE)''')
c2.execute('''CREATE TABLE IF NOT EXISTS income
             (id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL,
              source TEXT,
              date DATE)''')
conn2.commit()

def get_last_conversation(limit=5):
    c.execute("""
        SELECT role, content 
        FROM conversations 
        WHERE conversation_id = (
            SELECT conversation_id 
            FROM conversations 
            ORDER BY timestamp DESC 
            LIMIT 1
        )
        ORDER BY timestamp DESC
        LIMIT ?
    """, (limit,))
    return c.fetchall()[::-1]  # Reverse the order to get oldest to newest

@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(chat_message: ChatMessage):
    user_input = chat_message.message
    conversation_id = chat_message.conversation_id
    logger.info(f"Received chat message: {user_input} for conversation: {conversation_id}")

    if not conversation_id:
        # This is a new conversation, get context from the last conversation
        last_conversation = get_last_conversation()
        conversation_id = str(uuid.uuid4())
        logger.info(f"Starting new conversation with ID: {conversation_id}")

        # Add a system message to provide context from the last conversation
        if last_conversation:
            system_message = "Here's a summary of our last conversation: "
            system_message += " ".join([f"{role}: {content}" for role, content in last_conversation])
            c.execute("INSERT INTO conversations (conversation_id, role, content) VALUES (?, ?, ?)",
                      (conversation_id, 'system', system_message))

    # Store user message in database
    c.execute("INSERT INTO conversations (conversation_id, role, content) VALUES (?, ?, ?)",
              (conversation_id, 'user', user_input))
    conn.commit()

    # Retrieve conversation history
    c.execute("SELECT role, content FROM conversations WHERE conversation_id = ? ORDER BY timestamp",
              (conversation_id,))
    conversation_history = c.fetchall()

    if is_calendar_request(user_input):
        response = handle_calendar_request(user_input)
    else:
        response = await process_chat_request(user_input, conversation_history, ollama_client)

    # Store assistant response in database
    c.execute("INSERT INTO conversations (conversation_id, role, content) VALUES (?, ?, ?)",
              (conversation_id, 'assistant', response.message))
    conn.commit()

    return ChatResponse(
        message=response.message,
        metadata={
            "conversation_id": conversation_id,
            "duration": response.metadata.get("duration"),
            "tokens_evaluated": response.metadata.get("tokens_evaluated")
        }
    )

@app.get("/api/search", response_model=SearchResponse)
async def search_endpoint(q: str, type: str = "web"):
    logger.info(f"Received search request: {q}, type: {type}")

    try:
        if type.lower() == "image":
            image_results = perform_image_search(q)
            return SearchResponse(images=image_results)
        else:
            search_results = perform_web_search(q)
            return SearchResponse(results=search_results)
    except Exception as e:
        logger.error(f"Error performing search: {str(e)}")
        raise HTTPException(status_code=500, detail=f"An error occurred while performing the search: {str(e)}")


@app.post("/api/analyze-document", response_model=DocumentAnalysisResult)
async def analyze_document(file: UploadFile = File(...)):
    content = ""
    metadata = {}
    excel_data = None

    try:
        file_content = await file.read()
        file_extension = file.filename.split('.')[-1].lower()

        if file_extension == 'pdf':
            content, metadata = analyze_pdf(file_content)
        elif file_extension in ['doc', 'docx']:
            content, metadata = analyze_word(file_content)
        elif file_extension in ['xls', 'xlsx', 'csv']:
            content, metadata, excel_data = analyze_spreadsheet(file_content, file_extension)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file type")

        result = DocumentAnalysisResult(
            filename=file.filename,
            content=content,
            metadata=Metadata(**metadata),
            excel_data=excel_data
        )
        logger.debug(f"Analysis result: {result.dict()}")
        return result
    except Exception as e:
        logger.error(f"Error analyzing document: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error analyzing document: {str(e)}")

@app.post("/api/expense", response_model=dict)
async def add_expense(expense: Expense):
    try:
        c.execute("INSERT INTO expenses (amount, category, description, date) VALUES (?, ?, ?, ?)",
                  (expense.amount, expense.category, expense.description, expense.date))
        conn.commit()
        return {"message": "Expense added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding expense: {str(e)}")

@app.post("/api/income", response_model=dict)
async def add_income(income: Income):
    try:
        c.execute("INSERT INTO income (amount, source, date) VALUES (?, ?, ?)",
                  (income.amount, income.source, income.date))
        conn.commit()
        return {"message": "Income added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding income: {str(e)}")

@app.get("/api/expenses", response_model=list)
async def get_expenses():
    try:
        c.execute("SELECT * FROM expenses")
        expenses = c.fetchall()
        return [{"id": e[0], "amount": e[1], "category": e[2],
                 "description": e[3], "date": e[4]} for e in expenses]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving expenses: {str(e)}")

@app.get("/api/income", response_model=list)
async def get_income():
    try:
        c.execute("SELECT * FROM income")
        income_entries = c.fetchall()
        return [{"id": i[0], "amount": i[1], "source": i[2], "date": i[3]} for i in income_entries]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving income: {str(e)}")

if __name__ == "__main__":
    import uvicorn

    logger.info("Starting Uvicorn server")
    uvicorn.run(app, host="192.168.1.90", port=8000)