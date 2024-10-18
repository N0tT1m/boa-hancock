import logging
from models import ChatResponse
from calendar_service import is_calendar_request, handle_calendar_request
from search_service import is_search_request, handle_search_request
from state import global_state

logger = logging.getLogger(__name__)

def process_response(response):
    logger.debug("Processing Ollama response")
    content = response['message']['content']
    content = content.strip().strip('"')
    content = content.replace('\\n', '\n')
    return content

async def process_chat_request(user_input, conversation_history, ollama_client):
    if global_state.event_creation_stage is not None or is_calendar_request(user_input):
        return handle_calendar_request(user_input)
    elif is_search_request(user_input):
        return handle_search_request(user_input)
    else:
        # Existing chat processing logic
        formatted_conversation = []
        for role, content in conversation_history:
            formatted_conversation.append({"role": role, "content": content})

        if formatted_conversation[-1]['role'] != 'user' or formatted_conversation[-1]['content'] != user_input:
            formatted_conversation.append({"role": "user", "content": user_input})

        try:
            logger.debug("Sending chat request to Ollama")
            response = ollama_client.chat(model='llama3.2', messages=formatted_conversation)
            ai_response = process_response(response)
            logger.info("Received response from Ollama")

            return ChatResponse(
                message=ai_response,
                metadata={
                    'duration': response['total_duration'] / 1e9,
                    'tokens_evaluated': response['eval_count']
                }
            )
        except Exception as e:
            logger.error(f"Error in chat processing: {str(e)}")
            raise Exception(f"Error in chat processing: {str(e)}")