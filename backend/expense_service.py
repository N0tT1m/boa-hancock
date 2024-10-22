from datetime import datetime
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import logging
from state import global_state
from models import ChatResponse
from utils import parse_date_time
from datetime import timedelta
import random

logger = logging.getLogger(__name__)
creds = None

class Expense(BaseModel):
    amount: float
    category: str
    description: str
    date: str = datetime.now().strftime("%Y-%m-%d")


class Income(BaseModel):
    amount: float
    source: str
    date: str = datetime.now().strftime("%Y-%m-%d")

def generate_expense_response(amount, category, description, date):
    responses = [
        f"""Great news! I've added the following expense to your records:

**Amount**: ${amount:.2f}
**Category**: {category}
**Description**: {description}
**Date**: {date}

{placeholder_text}""",

        f"""Excellent! I've recorded the new expense:

💰 Amount: ${amount:.2f}
📁 Category: {category}
📝 Description: {description}
📅 Date: {date}

{placeholder_text}""",

        f"""Your new expense has been added! Here are the details:

- Amount: ${amount:.2f}
- Category: {category}
- Description: {description}
- Date: {date}

{placeholder_text}""",

        f"""Expense recorded! I've added the following to your records:

Expense: ${amount:.2f}
Category: {category}
Details: {description}
Date: {date}

{placeholder_text}""",

        f"""Success! I've added this expense to your account:

Amount: ${amount:.2f}
Category: {category}
Description: {description}
Date: {date}

{placeholder_text}""",

        f"""All done! Here's the new expense I've recorded:

Amount: ${amount:.2f}
Category: {category}
Description: {description}
Date: {date}

{placeholder_text}"""
    ]

    return random.choice(responses)

# Placeholder text (you can replace this with whatever you'd like)
placeholder_text = "*insert random text here i will fill it in*"

# Example usage
amount = 125.99
category = "Utilities"
description = "Electric bill for October"
date = "October 18, 2024"

expense = {
    'amount': amount,
    'category': category,
    'description': description,
    'date': date,
}

class ExpenseTracker:
    def __init__(self, db_conn):
        self.db_conn = db_conn

    def add_expense(self, amount, category, description, date=None):
        if date is None:
            date = datetime.now().strftime("%Y-%m-%d")
        expense = Expense(amount=amount, category=category, description=description, date=date)
        self._sync_with_db("expenses", expense)

    def add_income(self, amount, source, date=None):
        if date is None:
            date = datetime.now().strftime("%Y-%m-%d")
        income = Income(amount=amount, source=source, date=date)
        self._sync_with_db("income", income)

    def _sync_with_db(self, table_name, data):
        try:
            if table_name == "expenses":
                self.db_conn.execute("INSERT INTO expenses (amount, category, description, date) VALUES (?, ?, ?, ?)",
                                     (data.amount, data.category, data.description, data.date))
            elif table_name == "income":
                self.db_conn.execute("INSERT INTO income (amount, source, date) VALUES (?, ?, ?)",
                                     (data.amount, data.source, data.date))
            self.db_conn.commit()
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error syncing with database: {str(e)}")

    def get_expenses(self):
        self.db_conn.execute("SELECT * FROM expenses")
        return self.db_conn.fetchall()

    def get_income(self):
        self.db_conn.execute("SELECT * FROM income")
        return self.db_conn.fetchall()

def is_expense_request(message):
    return any(phrase in message.lower() for phrase in ['add expense'])

def add_expense(summary, amount, category, description, date):
    logger.info(f"Attempting to add expense: {summary}")

    event = {
        'amount': amount,
        'category': category,
        'description': description,
        'date': date,
    }


def handle_expense_request(user_input):
    if global_state.event_creation_stage is None:
        global_state.event_creation_stage = 'amount'
        global_state.expense_info = {}
        return ChatResponse(
            message="Sure, I can help you add a expense. What's the expense amount?",
            metadata={}
        )

    if global_state.event_creation_stage == 'amount':
        global_state.expense_info['amount'] = user_input
        global_state.event_creation_stage = 'category'
        return ChatResponse(
            message="Great! Now, what's the category? Please provide enter it now.",
            metadata={}
        )

    if global_state.event_creation_stage == 'category':
        global_state.expense_info['category'] = user_input
        global_state.event_creation_stage = 'description'
        return ChatResponse(
            message="Great! Now, give a description of the expense. Please provide enter it now.",
            metadata={}
        )

    if global_state.event_creation_stage == 'description':
        global_state.expense_info['description'] = user_input
        global_state.event_creation_stage = 'date_time'
        return ChatResponse(
            message="Great! Now, when was the expense from? Please provide the date and time.",
            metadata={}
        )

    if global_state.event_creation_stage == 'date_time':
        date_time, time_zone = parse_date_time(user_input)
        if date_time is None:
            return ChatResponse(
                message="I couldn't understand that date and time. Can you please provide it in a format like '10/24/24 10:00am EST' or '10 am est on October 24, 2024'?",
                metadata={}
            )
        global_state.expense_info['date_time'] = date_time
        global_state.expense_info['time_zone'] = time_zone
        global_state.event_creation_stage = 'duration'
        return ChatResponse(
            message="Got it. How long will the event last? (e.g., '1 hour', '30 minutes')",
            metadata={}
        )

    if global_state.event_creation_stage == 'duration':
        try:
            duration = parse_duration(user_input)
            start_time = global_state.event_creation_stage['date_time']
            end_time = start_time + duration
            result = add_expense    (
                global_state.expense_info['amount'],
                global_state.expense_info['category'],
                global_state.expense_info['description'],
                global_state.expense_info['date_time'],
            )
            logger.info("Calendar event added successfully")

            # Format the response
            event_title = global_state.calendar_event_info['summary']
            date_time = start_time.strftime("%B %d, %Y, %I:%M %p %Z")
            duration_str = f"{duration.total_seconds() // 3600} hours" if duration.total_seconds() >= 3600 else f"{duration.total_seconds() // 60} minutes"

            response_message = generate_expense_response(event_title, date_time, duration_str)

            global_state.expense_info = {}  # Clear the info after successful addition
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