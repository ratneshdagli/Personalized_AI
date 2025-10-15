from pydantic import BaseModel
from datetime import datetime
from typing import Any, Dict, Optional


class FeedItem(BaseModel):
    id: str
    title: str
    summary: str
    # Content shown in app cards
    content: str
    # Full original text; guaranteed to be present
    full_text: str
    date: datetime
    source: str
    priority: int
    # Additional fields used by the app
    relevance: float = 0.0
    metaData: Dict[str, Any] = {}