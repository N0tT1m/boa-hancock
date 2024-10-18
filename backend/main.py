import logging
from fastapi import FastAPI, HTTPException, Request
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
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Setup Ollama and Google Calendar API
ollama_client = setup_ollama()
setup_calendar_api()

conversation = []
calendar_event_info = {}
event_creation_stage = None


@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(chat_message: ChatMessage, request: Request):
    client_host = request.client.host
    logger.info(f"Received request from: {client_host}")
    logger.info(f"Request headers: {request.headers}")

    global conversation, calendar_event_info, event_creation_stage
    user_input = chat_message.message
    logger.info(f"Received chat message: {user_input}")

    if is_calendar_request(user_input) or event_creation_stage is not None:
        return handle_calendar_request(user_input, calendar_event_info, event_creation_stage)

    return await process_chat_request(user_input, conversation, ollama_client)


if __name__ == "__main__":
    import uvicorn

    logger.info("Starting Uvicorn server")
    uvicorn.run(app, host="192.168.1.90", port=8000, log_level="debug")