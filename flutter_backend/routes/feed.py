from fastapi import APIRouter
from typing import List
from datetime import datetime
from models import FeedItem
from utils.mock_data import mock_feed
from services.news_service import get_live_news
from app.core.nosql import store

router = APIRouter()

@router.get("/feed", response_model=List[FeedItem])
async def get_feed():
    """
    This endpoint returns a combined list of database items, mock items, and live news.
    """
    print("=" * 50)
    print("Feed endpoint: Starting to fetch feed data")
    print("=" * 50)
    
    # 1. Fetch items from NoSQL store
    db_feed_items = []
    try:
        # Use the correct store object for TinyDB
        all_items = store.all('feed_items')
        
        # Sort by date (newest first)
        # Handle potential string or datetime objects for date
        def get_date(item):
            date_val = item.get('date')
            if isinstance(date_val, str):
                return datetime.fromisoformat(date_val)
            return date_val

        all_items.sort(key=lambda x: get_date(x) if x.get('date') else datetime.min, reverse=True)
        
        # Apply limit
        latest_items = all_items[:50]
        print(f"Found {len(latest_items)} items in NoSQL store")

        # Convert to API model
        for item_data in latest_items:
            feed_item = FeedItem(
                id=str(item_data.get('id')),
                title=item_data.get('title', ''),
                summary=item_data.get('summary', ''),
                content=item_data.get('text', item_data.get('summary', '')),
                full_text=item_data.get('text', item_data.get('summary', '')),
                date=get_date(item_data),
                source=str(item_data.get('source', 'unknown')),
                priority=int(item_data.get('priority', 1)),
                relevance=float(item_data.get('relevance_score', 0.0)),
                metaData=item_data.get('meta_data', {})
            )
            db_feed_items.append(feed_item)

        print(f"Converted {len(db_feed_items)} NoSQL items to API format")

    except Exception as e:
        print(f"Error fetching from NoSQL store: {e}")
        db_feed_items = []

    # 2. Fetch live news articles
    try:
        live_news_items = await get_live_news()
        print(f"Fetched {len(live_news_items)} live news items")
    except Exception as e:
        print(f"Error fetching live news: {e}")
        live_news_items = []

    # 3. Combine database items with mock data and live news
    # (Remove the old mock news item to avoid duplicates)
    non_news_mock_data = [item for item in mock_feed if item.source != "News"]
    combined_feed = db_feed_items + non_news_mock_data + live_news_items

    # 4. Sort by date for a chronological feed (newest first)
    combined_feed.sort(key=lambda x: x.date, reverse=True)

    print(f"Total combined feed items: {len(combined_feed)}")
    print("=" * 50)

    return combined_feed