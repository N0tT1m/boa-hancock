import ast
import logging
import sqlite3
import os
import uuid
import aiosqlite
import fastapi.responses
from fastapi import FastAPI, HTTPException, UploadFile, File, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from models import ChatMessage, ChatResponse, SearchResponse, MovieMetadata, StreamingResponse, FileItem, SmbConfig, ImageSearchResult, SourceCodeAnalysisRequest, SourceCodeAnalysisResponse, SearchResult, Expense, Income, Metadata, DocumentAnalysisResult, CalendarEvent, CalendarEventRequest, FinancialData, LoginCredentials
from config import setup_logging, setup_ollama, setup_calendar_api
from calendar_service import handle_calendar_request, is_calendar_request
from chat_service import process_chat_request, get_conversation_history, store_message
from search_service import perform_web_search, perform_image_search, is_search_request
from document_analysis_service import analyze_pdf, analyze_word, analyze_spreadsheet
from expense_service import is_expense_request, handle_expense_request
from expense_service import ExpenseTracker
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException
from state import global_state
from capital_one import login_navigate_and_download_capital_one
import json, base64
from pydantic import BaseModel
from datetime import datetime, time
from calendar_service import add_calendar_event
import asyncio
from pathlib import Path
import tempfile
import uvicorn
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
import logging
import socket
import sys
import traceback
from smb_config import SMB_CONFIG
from movie import stream_movie, list_directory, get_smb_connection, get_movie_metadata

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
conn2 = sqlite3.connect('financial_data.db')
c2 = conn2.cursor()
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

# Increase the system's socket buffer size
# This might require administrative privileges
def increase_socket_buffer_size():
    try:
        socket.SOMAXCONN = 1024  # Increase maximum connections
        socket.setdefaulttimeout(60)  # Set a default timeout
    except Exception as e:
        logger.warning(f"Failed to increase socket buffer size: {e}")


class DatabaseManager:
    def __init__(self, db_path: str = 'chat_history.db'):
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        """Initialize the database with required tables."""
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS conversations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                conversation_id TEXT,
                role TEXT,
                content TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()

    async def get_conversation_history(self, conversation_id: str) -> List[Dict[str, Any]]:
        """Retrieve conversation history from the database."""
        try:
            async with aiosqlite.connect(self.db_path) as db:
                async with db.execute("""
                    SELECT role, content 
                    FROM conversations 
                    WHERE conversation_id = ?
                    ORDER BY timestamp
                """, (conversation_id,)) as cursor:
                    rows = await cursor.fetchall()

                    return [
                        {
                            "isUser": row[0] == "user",
                            "text": row[1]
                        }
                        for row in rows
                    ]
        except Exception as e:
            logger.error(f"Error retrieving conversation history: {e}")
            return []

    async def store_message(self, conversation_id: str, role: str, content: str) -> None:
        """Store a message in the database."""
        try:
            async with aiosqlite.connect(self.db_path) as db:
                await db.execute("""
                    INSERT INTO conversations (conversation_id, role, content)
                    VALUES (?, ?, ?)
                """, (conversation_id, role, content))
                await db.commit()
        except Exception as e:
            logger.error(f"Error storing message: {e}")


class ChatProcessor:
    def __init__(self, ollama_client, db_manager: DatabaseManager):
        self.ollama_client = ollama_client
        self.db_manager = db_manager
        self.system_prompt = {"role": "system", "content": "You are a helpful AI assistant."}

    def format_conversation_history(self, history: List[Dict[str, Any]]) -> List[Dict[str, str]]:
        """Format the conversation history into Ollama's expected format."""
        formatted = [self.system_prompt]

        for message in history:
            formatted.append({
                "role": "user" if message.get("isUser", False) else "assistant",
                "content": message.get("text", "")
            })

        return formatted

    async def process_chat_request(
            self,
            user_input: str,
            conversation_history: List[Dict[str, Any]],
            client_id: str
    ) -> Dict[str, Any]:
        """Process a chat request and return a response."""
        try:
            formatted_conversation = self.format_conversation_history(conversation_history)
            formatted_conversation.append({
                "role": "user",
                "content": user_input
            })

            logger.debug(f"Sending conversation to Ollama for client {client_id}: {formatted_conversation}")

            response = self.ollama_client.chat(
                model="llama3.1",
                messages=formatted_conversation
            )

            assistant_message = response['message']['content']

            logger.debug(f"Received response from Ollama for client {client_id}: {assistant_message}")

            return {
                "type": "chat",
                "message": assistant_message,
                "metadata": {
                    "tokens_evaluated": response.get('eval_count', 0),
                    "duration": response.get('eval_duration', 0),
                    "client_id": client_id
                }
            }

        except Exception as e:
            logger.error(f"Error in chat processing for client {client_id}: {str(e)}", exc_info=True)
            return {
                "type": "error",
                "message": "I'm sorry, but I encountered an error while processing your request. Please try again.",
                "metadata": {
                    "error": str(e),
                    "client_id": client_id
                }
            }

class ConversationManager:
    """Handle conversation storage and retrieval."""

    def __init__(self, database_connection):
        self.db = database_connection

    async def get_conversation_history(conversation_id: str) -> List[Dict[str, Any]]:
        """
        Retrieve conversation history from the database.
        Returns a list of message dictionaries.
        """
        try:
            cursor = c.execute("""
                SELECT role, content 
                FROM conversations 
                WHERE conversation_id = ?
                ORDER BY timestamp
            """, (conversation_id,))

            messages = []
            for row in cursor.fetchall():
                role, content = row
                messages.append({
                    "isUser": role == "user",
                    "text": content
                })

            return messages
        except Exception as e:
            logger.error(f"Error retrieving conversation history: {e}")
            return []

    async def store_message(conversation_id: str, role: str, content: str) -> None:
        """Store a message in the database."""
        try:
            c.execute("""
                INSERT INTO conversations (conversation_id, role, content)
                VALUES (?, ?, ?)
            """, (conversation_id, role, content))
            conn.commit()
        except Exception as e:
            logger.error(f"Error storing message: {e}")

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        logger.info(f"New client connected: {client_id}")

    def disconnect(self, client_id: str):
        self.active_connections.pop(client_id, None)
        logger.info(f"Client disconnected: {client_id}")

    async def send_message(self, message: str, client_id: str):
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_text(message)

# Initialize database and chat processor
db_manager = DatabaseManager()
manager = ConnectionManager()
chat_processor = ChatProcessor(ollama_client, db_manager)
conversation_manager = ConversationManager(c)



async def process_chat_request(user_input: str, conversation_history: List[Dict[str, str]], ollama_client, client_id: str):
    # Format the conversation history
    formatted_conversation = [
        {"role": "system", "content": "You are a helpful AI assistant."}
    ]

    # Add conversation history if it exists
    if conversation_history:
        for message in conversation_history:
            formatted_conversation.append({
                "role": "user" if message.get("isUser", False) else "assistant",
                "content": message.get("text", "")
            })

    # Add the new user input
    formatted_conversation.append({"role": "user", "content": user_input})

    try:
        logger.debug(f"Sending conversation to Ollama: {formatted_conversation}")

        # Generate response using Ollama (synchronous call)
        response = ollama_client.chat(model="llama3.1", messages=formatted_conversation)

        assistant_message = response['message']['content']

        logger.debug(f"Received response from Ollama: {assistant_message}")

        result = {
            "type": "chat",
            "message": assistant_message,
            "metadata": {
                "tokens_evaluated": response.get('eval_count', 0),
                "duration": response.get('eval_duration', 0)
            }
        }

        # Send the response to the client via WebSocket
        await manager.send_message(json.dumps(result), client_id)

        return result
    except Exception as e:
        logger.error(f"Error in chat processing: {str(e)}", exc_info=True)
        error_message = {
            "type": "error",
            "message": "I'm sorry, but I encountered an error while processing your request. Could you please try again?",
            "metadata": {
                "error": str(e)
            }
        }
        await manager.send_message(json.dumps(error_message), client_id)
        return error_message

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_text()
            # ... (your existing WebSocket logic)
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {str(e)}")
    finally:
        manager.disconnect(client_id)

async def process_message(data: str, client_id: str):
    try:
        message = json.loads(data)
        message_type = message.get('type')

        if message_type == 'chat':
            logger.debug(f"Processing chat message for client {client_id}: {message['message']}")
            response = chat_processor.process_chat_request(
                message['message'],
                message.get('conversation_history', []),
                ollama_client
            )
            logger.debug(f"Sending response to client {client_id}: {response}")
            await manager.send_message(json.dumps(response), client_id)
        else:
            logger.warning(f"Unknown message type received from client {client_id}: {message_type}")
            await manager.send_message(json.dumps({"error": "Unknown message type"}), client_id)
    except Exception as e:
        logger.error(f"Error processing message for client {client_id}: {str(e)}", exc_info=True)
        await manager.send_message(json.dumps({"error": str(e)}), client_id)


@app.post("/api/chat")
async def chat_endpoint(chat_message: ChatMessage):
    user_input = chat_message.message
    conversation_id = chat_message.conversation_id
    client_id = chat_message.client_id

    logger.info(f"Received chat message: {user_input} for conversation: {conversation_id}, client: {client_id}")

    # Get conversation history using the database manager
    conversation_history = await db_manager.get_conversation_history(conversation_id)

    # Store user message
    await db_manager.store_message(conversation_id, 'user', user_input)

    if is_calendar_request(user_input):
        response = handle_calendar_request(user_input)
    else:
        response = await chat_processor.process_chat_request(
            user_input,
            conversation_history,
            client_id
        )

    # Store assistant response
    await db_manager.store_message(conversation_id, 'assistant', response['message'])

    return ChatResponse(
        message=response['message'],
        metadata={
            "conversation_id": conversation_id,
            "duration": response['metadata'].get("duration"),
            "tokens_evaluated": response['metadata'].get("tokens_evaluated"),
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

@app.post("/api/financial-analysis")
async def financial_analysis(data: FinancialData):
    try:
        # Calculate total expenses and income
        total_expenses = sum(expense.amount for expense in data.expenses)
        total_income = sum(income.amount for income in data.incomes)
        net_income = total_income - total_expenses

        # Prepare data for AI analysis
        expense_categories = {}
        for expense in data.expenses:
            if expense.category in expense_categories:
                expense_categories[expense.category] += expense.amount
            else:
                expense_categories[expense.category] = expense.amount

        # Prepare prompt for AI
        prompt = f"""Analyze the following financial data and provide insights:

Total Income: ${total_income:.2f}
Total Expenses: ${total_expenses:.2f}
Net Income: ${net_income:.2f}

Expense Breakdown:
{json.dumps(expense_categories, indent=2)}

Please provide:
1. An overall assessment of the financial situation.
2. Insights into spending patterns.
3. At least 3 specific recommendations for saving money.
4. Any potential areas of concern or opportunities for improvement.

Format your response in markdown for easy reading."""

        # Get AI analysis
        response = ollama_client.chat(model="llama3.1", messages=[
            {"role": "system", "content": "You are a helpful financial advisor."},
            {"role": "user", "content": prompt}
        ])

        ai_analysis = response['message']['content']

        # Prepare the response
        analysis_result = {
            "expenses": [expense.dict() for expense in data.expenses],
            "incomes": [income.dict() for income in data.incomes],
            "analysis": ai_analysis
        }

        return analysis_result

    except Exception as e:
        logger.error(f"Error in financial analysis: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error performing financial analysis: {str(e)}")

@app.post("/api/expense")
async def add_expense(expense: Expense):
    try:
        c2.execute("INSERT INTO expenses (amount, category, description, date) VALUES (?, ?, ?, ?)",
                  (expense.amount, expense.category, expense.description, expense.date))
        conn.commit()
        return {"message": "Expense added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding expense: {str(e)}")

@app.post("/api/income")
async def add_income(income: Income):
    try:
        c2.execute("INSERT INTO income (amount, source, date) VALUES (?, ?, ?)",
                  (income.amount, income.source, income.date))
        conn.commit()
        return {"message": "Income added successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding income: {str(e)}")

@app.get("/api/expenses")
async def get_expenses():
    try:
        c2.execute("SELECT * FROM expenses")
        expenses = c2.fetchall()
        return [{"id": e[0], "amount": e[1], "category": e[2],
                 "description": e[3], "date": e[4]} for e in expenses]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving expenses: {str(e)}")

@app.get("/api/income")
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
        response = await chat_processor.process_chat_request(prompt, conversation_history, ollama_client)

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

# In your FastAPI app file (main.py), update the endpoint:
@app.post("/api/login-capital-one")
async def capital_one_navigation(credentials: LoginCredentials):
    result = await login_navigate_and_download_capital_one(credentials.username, credentials.password)
    if result["success"]:
        return {
            "message": result["message"],
            "balance": result.get("balance"),
            "file_path": result.get("file_path")
        }
    else:
        raise HTTPException(status_code=401, detail=result["message"])


@app.get("/api/movies/list", response_model=List[FileItem])
async def list_movies(path: str = "/"):
    """List available movies and directories"""
    return await list_directory(path)  # list_directory now uses get_instance() internally


@app.get("/api/movies/stream/{share_name}/{path:path}")
async def stream_movie_endpoint(share_name: str, path: str):
    """Stream a movie file"""
    try:
        config = SmbConfig.get_instance()
        conn = get_smb_connection(config)

        # Find the matching share configuration
        share = next((s for s in config.shares if s.name == share_name), None)
        if not share:
            raise HTTPException(status_code=404, detail=f"Share {share_name} not found")

        # Normalize the path
        clean_path = path.replace('/', '\\')
        full_path = str(Path(share.path) / clean_path.lstrip('\\/'))

        # Get file info
        file_obj = conn.getAttributes(share_name, full_path)
        file_size = file_obj.file_size

        # Create a temp file and stream from it
        temp_file = tempfile.NamedTemporaryFile(delete=False)

        # Download file in chunks to temp file
        chunk_size = 8192
        offset = 0
        while offset < file_size:
            chunk = conn.retrieveFileFromOffset(
                share_name,
                full_path,
                temp_file,
                offset,
                chunk_size
            )
            if not chunk:
                break
            offset += chunk_size

        temp_file.close()
        conn.close()

        # Create async generator to stream from temp file
        async def file_stream():
            try:
                with open(temp_file.name, 'rb') as f:
                    while chunk := f.read(chunk_size):
                        yield chunk
            finally:
                os.unlink(temp_file.name)  # Clean up temp file

        return fastapi.responses.StreamingResponse(
            file_stream(),
            media_type='video/mp4',
            headers={
                'Content-Disposition': f'inline; filename="{Path(path).name}"',
                'Content-Length': str(file_size),
                'Accept-Ranges': 'bytes'
            }
        )

    except Exception as e:
        logger.error(f"Error streaming movie: {e}")
        if 'temp_file' in locals():
            try:
                os.unlink(temp_file.name)  # Clean up temp file on error
            except:
                pass
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/movies/metadata/{share_name}/{path:path}", response_model=MovieMetadata)
async def get_movie_metadata_endpoint(share_name: str, path: str):
    """Get metadata for a movie file"""
    return await get_movie_metadata(share_name, path)  # get_movie_metadata now uses get_instan

if __name__ == "__main__":
    increase_socket_buffer_size()

    config = uvicorn.Config(
        app,
        host="192.168.1.78",
        port=8000,
        loop="asyncio",
        limit_concurrency=100,  # Limit concurrent connections
        limit_max_requests=10000,  # Limit max requests per worker
        timeout_keep_alive=5,  # Reduce keep-alive timeout
    )
    server = uvicorn.Server(config)

    # Run the server with proper asyncio handling
    loop = asyncio.get_event_loop()
    loop.run_until_complete(server.serve())