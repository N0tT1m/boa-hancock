from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional, Union
from datetime import datetime

class ChatResponse(BaseModel):
    message: str
    metadata: Dict[str, Any] = Field(default_factory=lambda: {
        "conversation_id": None,
        "duration": None,
        "tokens_evaluated": None
    })

    class Config:
        arbitrary_types_allowed = True

class Metadata(BaseModel):
    num_rows: int
    num_columns: int
    column_names: List[str]

class DocumentAnalysisResult(BaseModel):
    filename: str
    content: str
    metadata: Metadata
    excel_data: Optional[List[List[Any]]] = None

class ChatMessage(BaseModel):
    message: str
    conversation_id: str = None

    class Config:
        arbitrary_types_allowed = True

class SearchResult(BaseModel):
    title: str
    link: str
    snippet: str

class ImageSearchResult(BaseModel):
    title: str
    link: str
    thumbnailLink: str
    displayLink: str
    mime: str
    fileFormat: Optional[str] = None
    contextLink: Optional[str] = None

class SearchResponse(BaseModel):
    results: Optional[List[SearchResult]] = None
    images: Optional[List[ImageSearchResult]] = None

class Expense(BaseModel):
    amount: float
    category: str
    description: str
    date: str = datetime.now().strftime("%Y-%m-%d")

class Income(BaseModel):
    amount: float
    source: str
    date: str = datetime.now().strftime("%Y-%m-%d")

class CalendarEvent(BaseModel):
    name: str
    date: str
    time: str
    description: str
    duration: str = "1 hour"  # Default to 1 hour if not provided

class CalendarEventRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None