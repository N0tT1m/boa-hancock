import ast
import logging
import sqlite3
import uuid
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from models import ChatMessage, ChatResponse, SearchResponse, ImageSearchResult, SourceCodeAnalysisRequest, SourceCodeAnalysisResponse, SearchResult, Expense, Income, Metadata, DocumentAnalysisResult, CalendarEvent, CalendarEventRequest
from config import setup_logging, setup_ollama, setup_calendar_api
from calendar_service import handle_calendar_request, is_calendar_request
from chat_service import process_chat_request
from search_service import perform_web_search, perform_image_search, is_search_request
from document_analysis_service import analyze_pdf, analyze_word, analyze_spreadsheet
from expense_service import is_expense_request, handle_expense_request
from expense_service import ExpenseTracker
from typing import List, Dict, Any
from fastapi import FastAPI, HTTPException
from state import global_state
from pydantic import BaseModel
from datetime import datetime, time
from calendar_service import add_calendar_event
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
    elif is_expense_request(user_input):
        response = handle_expense_request(user_input)
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
            "tokens_evaluated": response.metadata.get("tokens_evaluated"),
            "event_creation_stage": global_state.event_creation_stage if is_calendar_request(user_input) else None
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


# Add this new function for source code analysis
def analyze_source_code(code: str, filename: str) -> SourceCodeAnalysisResponse:
    try:
        # Parse the code
        tree = ast.parse(code)

        # Analyze complexity
        complexity = ast.walk(tree)
        complexity_score = sum(1 for _ in complexity)

        if complexity_score < 50:
            complexity_rating = "Low"
        elif complexity_score < 100:
            complexity_rating = "Medium"
        else:
            complexity_rating = "High"

        # Generate summary
        summary = f"This code contains {len(tree.body)} top-level statements."

        # Generate suggestions
        suggestions = []
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef):
                if len(node.body) > 20:
                    suggestions.append(f"Consider breaking down the function '{node.name}' into smaller functions.")
            elif isinstance(node, ast.For) or isinstance(node, ast.While):
                suggestions.append("Make sure to handle potential infinite loops.")

        if not suggestions:
            suggestions.append("No specific suggestions. The code looks good!")

        # Determine language (in this case, we're assuming Python)
        language = "Python"

        return SourceCodeAnalysisResponse(
            filename=filename,
            language=language,
            summary=summary,
            complexity=complexity_rating,
            suggestions=suggestions,
            code=code
        )
    except SyntaxError as e:
        return SourceCodeAnalysisResponse(
            filename=filename,
            language="Unknown",
            summary="Unable to analyze: Syntax error in the code.",
            complexity="N/A",
            suggestions=["Fix the syntax error: " + str(e)],
            code=code
        )
    except Exception as e:
        logger.error(f"Error analyzing source code: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error analyzing source code: {str(e)}")

# Update the existing analyze_document endpoint to use the LLM for text files
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
        elif file_extension in ['txt', 'py', 'js', 'java', 'cpp', 'cs', 'go', 'rb', 'php', 'swift', 'kt']:
            # For text-based files, treat them as source code and use the LLM
            analysis_result = await analyze_source_code_with_llm(file_content.decode('utf-8'), file.filename, ollama_client)
            content = analysis_result.code
            metadata = {
                "language": analysis_result.language,
                "summary": analysis_result.summary,
                "complexity": analysis_result.complexity,
                "suggestions": analysis_result.suggestions
            }
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
        c2.execute("INSERT INTO expenses (amount, category, description, date) VALUES (?, ?, ?, ?)",
                  (expense.amount, expense.category, expense.description, expense.date))
        conn2.commit()
        return {"message": "Expense added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding expense: {str(e)}")

@app.post("/api/income", response_model=dict)
async def add_income(income: Income):
    try:
        c2.execute("INSERT INTO income (amount, source, date) VALUES (?, ?, ?)",
                  (income.amount, income.source, income.date))
        conn2.commit()
        return {"message": "Income added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding income: {str(e)}")

@app.get("/api/expenses", response_model=list)
async def get_expenses():
    try:
        c2.execute("SELECT * FROM expenses")
        expenses = c2.fetchall()
        return [{"id": e[0], "amount": e[1], "category": e[2],
                 "description": e[3], "date": e[4]} for e in expenses]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving expenses: {str(e)}")

@app.get("/api/income", response_model=list)
async def get_income():
    try:
        c2.execute("SELECT * FROM income")
        income_entries = c2.fetchall()
        return [{"id": i[0], "amount": i[1], "source": i[2], "date": i[3]} for i in income_entries]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving income: {str(e)}")

async def analyze_source_code_with_llm(code: str, filename: str, ollama_client) -> SourceCodeAnalysisResponse:
    try:
        # Prepare the prompt for the LLM
        prompt = f"""Analyze the following source code and provide:
1. The programming language
2. A brief summary of what the code does
3. An assessment of its complexity (Low, Medium, or High)
4. 2-3 suggestions for improvement or best practices
5. Any potential security concerns

Here's the code:

```
{code}
```

Please format your response as follows:
Language: [language name]
Summary: [brief summary]
Complexity: [Low/Medium/High]
Suggestions:
- [suggestion 1]
- [suggestion 2]
- [suggestion 3 (if applicable)]
Security Concerns: [list any security concerns or "None identified" if none]
"""

        # Create a mock conversation history with the prompt as the user's message
        conversation_history = [
            {'role': 'user', 'content': prompt}
        ]

        # Send the prompt to the LLM
        response = await process_chat_request(prompt, conversation_history, ollama_client)

        # Parse the LLM's response
        lines = response.message.split('\n')
        language = next((line.split(': ')[1] for line in lines if line.startswith('Language:')), 'Unknown')
        summary = next((line.split(': ')[1] for line in lines if line.startswith('Summary:')), 'No summary provided')
        complexity = next((line.split(': ')[1] for line in lines if line.startswith('Complexity:')), 'Unknown')
        suggestions = [line.strip('- ') for line in lines if line.startswith('-')]
        security_concerns = next((line.split(': ')[1] for line in lines if line.startswith('Security Concerns:')), 'None identified')

        return SourceCodeAnalysisResponse(
            filename=filename,
            language=language,
            summary=summary,
            complexity=complexity,
            suggestions=suggestions + ([security_concerns] if security_concerns != "None identified" else []),
            code=code
        )
    except Exception as e:
        logger.error(f"Error analyzing source code with LLM: {str(e)}")
        logger.error(traceback.format_exc())
        return SourceCodeAnalysisResponse(
            filename=filename,
            language="Unknown",
            summary="Error occurred during analysis",
            complexity="Unknown",
            suggestions=["An error occurred during the analysis. Please try again."],
            code=code
        )

@app.post("/api/analyze-document/source", response_model=SourceCodeAnalysisResponse)
async def analyze_source_code_endpoint(request: SourceCodeAnalysisRequest):
    try:
        result = await analyze_source_code_with_llm(request.code, request.filename, ollama_client)
        return result
    except Exception as e:
        logger.error(f"Error in analyze_source_code_endpoint: {str(e)}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Error analyzing source code: {str(e)}")


# Update the existing analyze_document endpoint to handle text files

# In your main FastAPI app file (main.py), update the endpoint:
@app.post("/api/calendar", response_model=ChatResponse)
async def add_calendar_event(event: CalendarEvent):
    return handle_calendar_request(event)

if __name__ == "__main__":
    import uvicorn

    logger.info("Starting Uvicorn server")
    uvicorn.run(app, host="192.168.1.87", port=8000)