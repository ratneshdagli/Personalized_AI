from pydantic import BaseModel, Field
from typing import Optional


class MessageModel(BaseModel):
    conversation_id: Optional[str] = None
    role: str = Field(..., description="system|user|assistant")
    content: str = Field(..., min_length=1)
    timestamp: Optional[str] = None


