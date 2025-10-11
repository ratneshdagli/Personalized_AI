from pydantic import BaseModel
from datetime import datetime

class FeedItem(BaseModel):
    id: str
    title: str
    summary: str
    full_text: str  # New field for the original content
    date: datetime
    source: str
    priority: int