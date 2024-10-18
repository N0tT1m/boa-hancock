from datetime import datetime
import requests
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

class Expense(BaseModel):
    amount: float
    category: str
    description: str
    date: str = datetime.now().strftime("%Y-%m-%d")


class Income(BaseModel):
    amount: float
    source: str
    date: str = datetime.now().strftime("%Y-%m-%d")


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