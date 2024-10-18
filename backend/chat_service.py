import logging
from models import ChatResponse

logger = logging.getLogger(__name__)

def process_response(response):
    logger.debug("Processing Ollama response")
    content = response['message']['content']
    content = content.strip().strip('"')
    content = content.replace('\\n', '\n')
    return content

async def process_chat_request(user_input, conversation, ollama_client):
    conversation.append({'role': 'user', 'content': user_input})

    try:
        logger.debug("Sending chat request to Ollama")
        response = ollama_client.chat(model='llama3.2', messages=conversation)
        ai_response = process_response(response)
        logger.info("Received response from Ollama")

        conversation.append({'role': 'assistant', 'content': ai_response})

        return ChatResponse(
            message=ai_response,
            metadata={
                'duration': response['total_duration'] / 1e9,
                'tokens_evaluated': response['eval_count']
            }
        )
    except Exception as e:
        logger.error(f"Error in chat processing: {str(e)}")
        raise Exception(str(e))