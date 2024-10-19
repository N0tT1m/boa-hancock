import logging
from dotenv import load_dotenv
from ollama import Client, pull
from google_auth_oauthlib.flow import InstalledAppFlow

def setup_logging():
    logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)
    logger.info("Starting application")
    return logger

def setup_ollama():
    logger = logging.getLogger(__name__)
    load_dotenv()
    logger.info("Pulling model...")
    try:
        pull('llama3.1:70b')
        logger.info("Model pull completed successfully")
    except Exception as e:
        logger.error(f"Error pulling model: {str(e)}")
        raise
    ollama_client = Client(host='http://192.168.1.78:11434')
    logger.info("Ollama client initialized")
    return ollama_client

def setup_calendar_api():
    logger = logging.getLogger(__name__)
    SCOPES = ['https://www.googleapis.com/auth/calendar.events',
              'https://www.googleapis.com/auth/calendar.settings.readonly']
    try:
        flow = InstalledAppFlow.from_client_secrets_file(
            './ai-assistant.json',
            scopes=SCOPES
        )
        flow.redirect_uri = 'http://localhost:8000/oauth2callback'
        logger.info("Google Calendar API flow initialized")
    except Exception as e:
        logger.error(f"Error initializing Google Calendar API flow: {str(e)}")
        raise