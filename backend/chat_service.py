import logging
from typing import List, Dict
import asyncio
from models import ChatResponse
from calendar_service import is_calendar_request, handle_calendar_request
from search_service import is_search_request, handle_search_request
from state import global_state
import json
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

logger = logging.getLogger(__name__)

def process_response(response):
    logger.debug("Processing Ollama response")
    content = response['message']['content']
    content = content.strip().strip('"')
    content = content.replace('\\n', '\n')
    return content


async def process_chat_request(user_input: str, conversation_history: list, ollama_client, client_id: str):
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
        logger.debug(f"Sending conversation to Ollama for client {client_id}: {formatted_conversation}")

        # Generate response using Ollama
        response = ollama_client.chat(model="llama3.1", messages=formatted_conversation)

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
            "message": "I'm sorry, but I encountered an error while processing your request. Could you please try again?",
            "metadata": {
                "error": str(e),
                "client_id": client_id
            }
        }

# You'll need to implement these functions
def get_conversation_history(conversation_id: str) -> list:
    # Retrieve conversation history from your database or storage
    pass

def store_message(conversation_id: str, role: str, content: str):
    # Store the message in your database or storage
    pass