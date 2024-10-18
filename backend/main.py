# main.py

import logging
import sqlite3
import uuid
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from models import ChatMessage, ChatResponse
from config import setup_logging, setup_ollama, setup_calendar_api
from calendar_service import handle_calendar_request, is_calendar_request
from chat_service import process_chat_request

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

if __name__ == "__main__":
    import uvicorn

    logger.info("Starting Uvicorn server")
    uvicorn.run(app, host="192.168.1.90", port=8000)