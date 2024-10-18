from pydantic import BaseModel, Field
from typing import Dict, Any

class ChatResponse(BaseModel):
    message: str
    metadata: Dict[str, Any] = Field(default_factory=lambda: {
        "conversation_id": None,
        "duration": None,
        "tokens_evaluated": None
    })

    class Config:
        arbitrary_types_allowed = True

class ChatMessage(BaseModel):
    message: str
    conversation_id: str = None

    class Config:
        arbitrary_types_allowed = True