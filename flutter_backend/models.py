from pydantic import BaseModel
from datetime import datetime

class FeedItem(BaseModel):
    id: str
    title: str
    summary: str
    date: datetime
    source: str   # Gmail, Reddit, News, WhatsApp
    priority: int # 1 = high, 2 = medium, 3 = low
