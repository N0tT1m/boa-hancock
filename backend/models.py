from pydantic import BaseModel

class ChatMessage(BaseModel):
    message: str

class ChatResponse(BaseModel):
    message: str
    metadata: dict