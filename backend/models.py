from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional, Union

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

