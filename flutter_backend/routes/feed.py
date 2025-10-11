from fastapi import APIRouter
from typing import List
from models import FeedItem
from utils.mock_data import mock_feed
from ml.ranker import rank_feed_items
from ml.summarizer import summarize_text # <-- Import the summarizer

router = APIRouter()

@router.get("/feed", response_model=List[FeedItem])
async def get_feed():
    """
    This endpoint returns a mock list of personalized feed items,
    ranked and summarized by the NLP services.
    """
    # First, rank the items
    ranked_feed = rank_feed_items(mock_feed)

    # Now, summarize each item's content
    for item in ranked_feed:
        # Keep the original summary in the full_text field
        item.full_text = item.summary
        # Create a new, shorter summary
        item.summary = summarize_text(item.full_text)
        
    return ranked_feed