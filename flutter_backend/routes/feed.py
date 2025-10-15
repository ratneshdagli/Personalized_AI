from fastapi import APIRouter
from typing import List
from models import FeedItem
from utils.mock_data import mock_feed
from services.news_service import get_live_news
from storage.db import get_db_session
from storage.models import FeedItem as DBFeedItem
from sqlalchemy.orm import Session

router = APIRouter()

@router.get("/feed", response_model=List[FeedItem])
async def get_feed():
    """
    This endpoint returns a combined list of database items, mock items, and live news.
    """
    print("=" * 50)
    print("Feed endpoint: Starting to fetch feed data")
    print("=" * 50)
    
    # 1. Fetch items from database
    db = get_db_session()
    try:
        db_items = db.query(DBFeedItem).order_by(DBFeedItem.date.desc()).limit(50).all()
        print(f"Found {len(db_items)} items in database")
        
        # Convert database items to API models
        db_feed_items = []
        for item in db_items:
            # Convert priority enum to int
            priority_value = item.priority.value if hasattr(item.priority, 'value') else int(item.priority)
            
            feed_item = FeedItem(
                id=str(item.id),
                title=item.title,
                summary=item.summary or "",
                content=item.text or item.summary or "",
                date=item.date,
                source=item.source.value if hasattr(item.source, 'value') else str(item.source),
                priority=priority_value,
                relevance=item.relevance_score or 0.0,
                metaData=item.meta_data or {}
            )
            db_feed_items.append(feed_item)
            
        print(f"Converted {len(db_feed_items)} database items to API format")
        
        # Log WhatsApp items specifically
        whatsapp_items = [item for item in db_feed_items if 'whatsapp' in item.source.lower()]
        print(f"Found {len(whatsapp_items)} WhatsApp items in database")
        for item in whatsapp_items:
            print(f"Database WhatsApp item: {item.title} - {item.source}")
            
    except Exception as e:
        print(f"Error fetching from database: {e}")
        db_feed_items = []
    finally:
        db.close()

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