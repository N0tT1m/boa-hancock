import logging
import logging
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
import datetime
from models import ChatResponse
from utils import parse_date_time
from state import global_state

logger = logging.getLogger(__name__)
creds = None

def get_calendar_service():
    global creds
    logger.debug("Attempting to get calendar service")
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            logger.info("Refreshing expired credentials")
            try:
                creds.refresh(Request())
            except Exception as e:
                logger.error(f"Error refreshing credentials: {str(e)}")
                raise
        else:
            logger.info("Running local server for new credentials")
            try:
                from google_auth_oauthlib.flow import InstalledAppFlow
                flow = InstalledAppFlow.from_client_secrets_file(
                    './ai-assistant.json',
                    ['https://www.googleapis.com/auth/calendar.events',
                     'https://www.googleapis.com/auth/calendar.settings.readonly']
                )
                creds = flow.run_local_server(port=8080)
            except Exception as e:
                logger.error(f"Error obtaining new credentials: {str(e)}")
                raise

    logger.debug("Calendar service obtained successfully")
    return build('calendar', 'v3', credentials=creds)

def add_calendar_event(summary, start_time, end_time, time_zone):
    logger.info(f"Attempting to add calendar event: {summary}")
    service = get_calendar_service()

    event = {
        'summary': summary,
        'start': {
            'dateTime': start_time.isoformat(),
            'timeZone': time_zone,
        },
        'end': {
            'dateTime': end_time.isoformat(),
            'timeZone': time_zone,
        },
    }
    try:
        event = service.events().insert(calendarId='primary', body=event).execute()
        logger.info(f"Event created successfully: {event.get('htmlLink')}")
        return f"Event created: {event.get('htmlLink')}"
    except Exception as e:
        logger.error(f"Error creating calendar event: {str(e)}")
        raise

def is_calendar_request(message):
    return any(phrase in message.lower() for phrase in ['add calendar event', 'add a calendar reminder'])

def handle_calendar_request(user_input):
    if global_state.event_creation_stage is None:
        global_state.event_creation_stage = 'title'
        return ChatResponse(
            message="Sure, I can help you add a calendar event. What's the title of the event?",
            metadata={}
        )

    if global_state.event_creation_stage == 'title':
        global_state.calendar_event_info['summary'] = user_input
        global_state.event_creation_stage = 'date_time'
        return ChatResponse(
            message="Great! Now, when is this event? Please provide the date and time.",
            metadata={}
        )

    if global_state.event_creation_stage == 'date_time':
        date_time, time_zone = parse_date_time(user_input)
        if date_time is None:
            return ChatResponse(
                message="I couldn't understand that date and time. Can you please provide it in a format like '10/24/24 10:00am EST' or '10 am est on October 24, 2024'?",
                metadata={}
            )
        global_state.calendar_event_info['date_time'] = date_time
        global_state.calendar_event_info['time_zone'] = time_zone

        try:
            start_time = global_state.calendar_event_info['date_time']
            end_time = start_time + datetime.timedelta(hours=1)  # Assume 1-hour event
            result = add_calendar_event(global_state.calendar_event_info['summary'], start_time, end_time,
                                        global_state.calendar_event_info['time_zone'])
            logger.info("Calendar event added successfully")
            global_state.calendar_event_info = {}  # Clear the info after successful addition
            global_state.event_creation_stage = None  # Reset the stage
            return ChatResponse(
                message=f"Calendar event added successfully. {result}",
                metadata={}
            )
        except Exception as e:
            logger.error(f"Failed to add calendar event: {str(e)}")
            global_state.calendar_event_info = {}  # Clear the info if there's an error
            global_state.event_creation_stage = None  # Reset the stage
            raise Exception(f"Failed to add calendar event: {str(e)}")


