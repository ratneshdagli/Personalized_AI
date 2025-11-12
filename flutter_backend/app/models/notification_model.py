from pydantic import BaseModel, Field
from typing import Optional


class NotificationModel(BaseModel):
    app_name: str = Field(..., min_length=1)
    title: Optional[str] = None
    message: str = Field(..., min_length=1)
    timestamp: str = Field(..., description="ISO8601 timestamp string")
    priority: Optional[float] = Field(None, ge=0.0, le=1.0)
    category: Optional[str] = None
    id: Optional[str] = Field(None, description="Optional document ID for embedding")


