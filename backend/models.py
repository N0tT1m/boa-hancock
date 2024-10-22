from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional, Union, AsyncGenerator, Callable

from datetime import datetime

from starlette.background import BackgroundTask

from smb_config import SMB_CONFIG


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
    conversation_id: str
    client_id: str

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
class FinancialData(BaseModel):
    expenses: List[Expense]
    incomes: List[Income]

class CalendarEvent(BaseModel):
    name: str
    date: str
    time: str
    description: str
    duration: str = "1 hour"  # Default to 1 hour if not provided

class CalendarEventRequest(BaseModel):
    message: str
    conversation_id: Optional[str] = None

class SourceCodeAnalysisRequest(BaseModel):
    code: str
    filename: str

class SourceCodeAnalysisResponse(BaseModel):
    filename: str
    language: str
    summary: str
    complexity: str
    suggestions: List[str]
    code: str

class LoginCredentials(BaseModel):
    username: str
    password: str

# Previous classes remain the same
class ShareConfig(BaseModel):
    name: str
    path: str
    display_name: str

class SmbConfig(BaseModel):
    username: str
    password: str
    server_name: str
    server_ip: str
    shares: List[ShareConfig]
    client_name: str
    domain: str

    @classmethod
    def from_config(cls):
        return cls(
            username=SMB_CONFIG["username"],
            password=SMB_CONFIG["password"],
            server_name=SMB_CONFIG["server_name"],
            server_ip=SMB_CONFIG["server_ip"],
            shares=[ShareConfig(**share) for share in SMB_CONFIG["shares"]],
            client_name=SMB_CONFIG["client_name"],
            domain=SMB_CONFIG["domain"]
        )

    @classmethod
    def get_instance(cls):
        """Get a singleton instance of SmbConfig"""
        if not hasattr(cls, '_instance'):
            cls._instance = cls.from_config()
        return cls._instance

class FileItem(BaseModel):
    name: str
    path: str
    is_directory: bool
    size: int
    modified_time: str
    share_name: str
    display_name: str

class MovieMetadata(BaseModel):
    title: str
    path: str
    size: int
    modified_time: str
    duration: Optional[float] = None
    thumbnail: Optional[str] = None
    share_name: str
    display_name: str


class StreamingResponse():
    def __init__(
            self,
            content: Union[AsyncGenerator[bytes, None], Callable[[], AsyncGenerator[bytes, None]]],
            status_code: int = 200,
            headers: Optional[Dict[str, str]] = None,
            media_type: Optional[str] = None,
            background: Optional[BackgroundTask] = None,
    ) -> None:
        """
        Initialize StreamingResponse with video streaming support.

        Args:
            content: An async generator that yields bytes
            status_code: HTTP status code
            headers: HTTP headers
            media_type: Content type of the response
            background: Background task to run after the response
        """
        self.headers = headers or {}
        # Ensure headers for video streaming
        if media_type == "video/mp4":
            self.headers.update({
                "Accept-Ranges": "bytes",
                "Cache-Control": "no-cache",
                "Content-Type": "video/mp4",
            })

        super().__init__(
            content=content,
            status_code=status_code,
            headers=self.headers,
            media_type=media_type,
            background=background
        )