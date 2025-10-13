from fastapi import APIRouter
from typing import List
from models import FeedItem
from utils.mock_data import mock_feed
from services.news_service import get_live_news

router = APIRouter()

@router.get("/feed", response_model=List[FeedItem])
async def get_feed():
    """
    This endpoint returns a combined list of mock items and live news.
    """
    # 1. Fetch live news articles
    live_news_items = await get_live_news()

    # 2. Combine mock data with live news
    # (Remove the old mock news item to avoid duplicates)
    non_news_mock_data = [item for item in mock_feed if item.source != "News"]
    combined_feed = non_news_mock_data + live_news_items

    # 3. Sort by date for a chronological feed (newest first)
    combined_feed.sort(key=lambda x: x.date, reverse=True)

    return combined_feed