import logging
import requests
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
import datetime

from models import SearchResponse, SearchResult, ChatResponse, ChatMessage, ImageSearchResult
from typing import List, Dict, Any

import os
from dotenv import load_dotenv

from models import ChatResponse
from utils import parse_date_time
from state import global_state

logger = logging.getLogger(__name__)
creds = None

load_dotenv()

# Google Custom Search API credentials
GOOGLE_SEARCH_API_KEY = os.getenv('GOOGLE_SEARCH_API_KEY')
SEARCH_ENGINE_ID = os.getenv('SEARCH_ENGINE_ID')

def perform_web_search(query: str, num_results: int = 5) -> List[SearchResult]:
    logger.info(f"Performing web search for query: {query}")

    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_SEARCH_API_KEY,
        "cx": SEARCH_ENGINE_ID,
        "q": query,
        "num": min(num_results, 10)
    }

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        search_data = response.json()

        logger.debug(f"Search API response: {search_data}")

        if 'items' in search_data:
            return [
                SearchResult(
                    title=item.get('title', 'No title'),
                    link=item.get('link', 'No link'),
                    snippet=item.get('snippet', 'No snippet available')
                ) for item in search_data['items']
            ]
        else:
            logger.warning("No search results found")
            return []
    except requests.RequestException as e:
        logger.error(f"Error performing web search: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error in perform_web_search: {str(e)}", exc_info=True)
        raise

def perform_image_search(query: str, num_results: int = 5) -> List[ImageSearchResult]:
    logger.info(f"Performing image search for query: {query}")

    url = "https://www.googleapis.com/customsearch/v1"
    params = {
        "key": GOOGLE_SEARCH_API_KEY,
        "cx": SEARCH_ENGINE_ID,
        "q": query,
        "num": min(num_results, 10),
        "searchType": "image"
    }

    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        search_data = response.json()

        logger.debug(f"Image Search API response: {search_data}")

        if 'items' in search_data:
            return [
                ImageSearchResult(
                    title=item.get('title', 'No title'),
                    link=item.get('link', 'No link'),
                    thumbnailLink=item.get('image', {}).get('thumbnailLink', 'No thumbnail'),
                    displayLink=item.get('displayLink', 'No display link'),
                    mime=item.get('mime', 'Unknown'),
                    fileFormat=item.get('fileFormat'),
                    contextLink=item.get('image', {}).get('contextLink')
                ) for item in search_data['items']
            ]
        else:
            logger.warning("No image search results found")
            return []
    except requests.RequestException as e:
        logger.error(f"Error performing image search: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error in perform_image_search: {str(e)}", exc_info=True)
        raise

def is_search_request(message):
    return any(phrase in message.lower() for phrase in ['search for', 'find information about', 'look up'])


def handle_search_request(user_input):
    query = user_input.split(' ', 2)[-1]  # Extract the search query
    search_results = perform_web_search(query)

    if search_results:
        response = "Here are the top search results:\n\n"
        for i, result in enumerate(search_results, 1):
            response += f"{i}. {result['title']}\n   {result['link']}\n   {result['snippet']}\n\n"
    else:
        response = "I'm sorry, but I couldn't find any relevant search results for your query."

    return ChatResponse(message=response, metadata={})

