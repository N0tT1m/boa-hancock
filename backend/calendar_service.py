import logging
import logging
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from google.auth.transport.requests import Request
import datetime
from models import ChatResponse
from utils import parse_date_time
from state import global_state
from datetime import timedelta

logger = logging.getLogger(__name__)
creds = None

import random

def generate_calendar_response(event_title, date_time, duration):
    responses = [
        f"""Great news! Your calendar event has been successfully added:

**Event Title**: {event_title}
**Date and Time:** {date_time}
**Duration**: {duration}

{placeholder_text}""",

        f"""Excellent! I've scheduled the event for you. Here are the details:

📅 {event_title}
🕒 {date_time}
⏱️ Duration: {duration}

{placeholder_text}""",

        f"""Your new calendar event is all set! Here's a summary:

• Title: {event_title}
• Scheduled for: {date_time}
• Event length: {duration}

{placeholder_text}""",

        f"""Calendar updated! I've added the following event:

🎉 {event_title} 🎉
When: {date_time}
How long: {duration}

{placeholder_text}""",

        f"""Success! Your event has been added to your calendar:

Event: {event_title}
Time & Date: {date_time}
Duration: {duration}

{placeholder_text}""",

        f"""All done! Here's what I've added to your calendar:

"{event_title}"
Happening on: {date_time}
Lasting for: {duration}

{placeholder_text}"""
    ]

    return random.choice(responses)

# Placeholder text (you can replace this with whatever you'd like)
placeholder_text = "*insert random text here i will fill it in*"
def generate_calendar_response(event_title, date_time, duration):
    responses = [
        f"""Great news! Your calendar event has been successfully added:

**Event Title**: {event_title}
**Date and Time:** {date_time}
**Duration**: {duration}

{placeholder_text}""",

        f"""Excellent! I've scheduled the event for you. Here are the details:

📅 {event_title}
🕒 {date_time}
⏱️ Duration: {duration}

{placeholder_text}""",

        f"""Your new calendar event is all set! Here's a summary:

• Title: {event_title}
• Scheduled for: {date_time}
• Event length: {duration}

{placeholder_text}""",

        f"""Calendar updated! I've added the following event:

🎉 {event_title} 🎉
When: {date_time}
How long: {duration}

{placeholder_text}""",

        f"""Success! Your event has been added to your calendar:

Event: {event_title}
Time & Date: {date_time}
Duration: {duration}

{placeholder_text}""",

        f"""All done! Here's what I've added to your calendar:

"{event_title}"
Happening on: {date_time}
Lasting for: {duration}

{placeholder_text}"""
    ]

    return random.choice(responses)

# Placeholder text (you can replace this with whatever you'd like)
placeholder_text = "*insert random text here i will fill it in*"

# Example usage
event_title = "Flexing (4 hours - this is the time for the whole event)"
date_time = "October 18, 2024, 4:00 PM EST"
duration = "4 hours"

# Example usage
event_title = "Flexing (4 hours - this is the time for the whole event)"
date_time = "October 18, 2024, 4:00 PM EST"
duration = "4 hours"

print(generate_calendar_response(event_title, date_time, duration))

def is_calendar_request(message):
    return any(phrase in message.lower() for phrase in ['add calendar event', 'add a calendar reminder'])

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


def handle_calendar_request(user_input):
    if global_state.event_creation_stage is None:
        global_state.event_creation_stage = 'title'
        global_state.calendar_event_info = {}
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
        return ChatResponse(
            message="Got it. How long will the event last? (e.g., '1 hour', '30 minutes')",
            metadata={}
        )

    if global_state.event_creation_stage == 'duration':
        try:
            duration = parse_duration(user_input)
            start_time = global_state.calendar_event_info['date_time']
            end_time = start_time + duration
            result = add_calendar_event(
                global_state.calendar_event_info['summary'],
                start_time,
                end_time,
                global_state.calendar_event_info['time_zone']
            )
            logger.info("Calendar event added successfully")

            # Format the response
            event_title = global_state.calendar_event_info['summary']
            date_time = start_time.strftime("%B %d, %Y, %I:%M %p %Z")
            duration_str = f"{duration.total_seconds() // 3600} hours" if duration.total_seconds() >= 3600 else f"{duration.total_seconds() // 60} minutes"

            response_message = generate_calendar_response(event_title, date_time, duration_str)

            global_state.calendar_event_info = {}  # Clear the info after successful addition
            global_state.event_creation_stage = None  # Reset the stage

            return ChatResponse(
                message=response_message,
                metadata={}
            )
        except Exception as e:
            logger.error(f"Failed to add calendar event: {str(e)}")
            global_state.calendar_event_info = {}  # Clear the info if there's an error
            global_state.event_creation_stage = None  # Reset the stage
            return ChatResponse(
                message=f"I'm sorry, but I couldn't add the calendar event. {str(e)}",
                metadata={}
            )

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

def parse_duration(duration_str):
    duration_str = duration_str.lower()
    if 'hour' in duration_str:
        hours = int(duration_str.split()[0])
        return timedelta(hours=hours)
    elif 'minute' in duration_str:
        minutes = int(duration_str.split()[0])
        return timedelta(minutes=minutes)
    else:
        raise ValueError("Couldn't understand the duration. Please specify in hours or minutes.")