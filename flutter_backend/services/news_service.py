import httpx
from datetime import datetime
from typing import List
from uuid import uuid4
from models import FeedItem
from config import GNEWS_API_KEY, GNEWS_API_URL

async def get_live_news() -> List[FeedItem]:
    """
    Fetches live tech headlines from GNews.io and maps them to FeedItem objects.
    """
    if not GNEWS_API_KEY:
        return []

    params = {
        "apikey": GNEWS_API_KEY,
        "topic": "technology",  # Personalized topic
        "lang": "en",
        "max": 5,               # Get the top 5 articles
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(GNEWS_API_URL, params=params)
            response.raise_for_status()
            data = response.json()
            articles = data.get("articles", [])

            feed_items = []
            for article in articles:
                if article.get("title") and article.get("description"):
                    content_value = article.get("content") or article["description"]
                    full_text_value = content_value or article["title"]
                    feed_items.append(
                        FeedItem(
                            id=str(uuid4()),
                            title=article["title"],
                            summary=article["description"],
                            content=content_value,
                            full_text=full_text_value,
                            date=datetime.fromisoformat(article["publishedAt"].replace("Z", "+00:00")),
                            source="News",
                            priority=3  # Default priority, will be re-ranked later
                        )
                    )
            return feed_items
        except httpx.HTTPStatusError as e:
            print(f"Error fetching news from GNews: {e}")
            return []
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            return []