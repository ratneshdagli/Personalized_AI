from datetime import datetime
from models import FeedItem

mock_feed = [
    FeedItem(
        id="1",
        title="Assignment due tomorrow",
        summary="Submit Google form for AI course by tomorrow 5 PM.",
        date=datetime.now(),
        source="Gmail",
        priority=1
    ),
    FeedItem(
        id="2",
        title="Reddit post: New placements",
        summary="Top 10 companies are hiring this month in your field.",
        date=datetime.now(),
        source="Reddit",
        priority=2
    ),
    FeedItem(
        id="3",
        title="Friend landed abroad!",
        summary="Your friend posted on Instagram: moved to Germany for internship.",
        date=datetime.now(),
        source="Instagram",
        priority=1
    ),
    FeedItem(
        id="4",
        title="Tech News",
        summary="Stock XYZ fell 20%, might impact AI sector investments.",
        date=datetime.now(),
        source="News",
        priority=3
    ),
]
