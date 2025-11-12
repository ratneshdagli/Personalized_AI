from datetime import datetime
from models import FeedItem

mock_feed = [
    FeedItem(
        id="1",
        title="Assignment due tomorrow",
        summary="The Google form for the AI course has been released. Please submit it by tomorrow at 5 PM sharp. Late submissions will not be accepted under any circumstances.",
        content="The Google form for the AI course has been released. Please submit it by tomorrow at 5 PM sharp. Late submissions will not be accepted under any circumstances.",
        full_text="The Google form for the AI course has been released. Please submit it by tomorrow at 5 PM sharp. Late submissions will not be accepted under any circumstances. This is a mandatory assignment for all students enrolled in the course.",
        date=datetime.now(),
        source="Gmail",
        priority=1
    ),
    FeedItem(
        id="2",
        title="Reddit post: New placements",
        summary="A new thread on the placements subreddit lists the top 10 companies hiring this month in the AI and ML space. The list includes several Fortune 500 companies.",
        content="A new thread on the placements subreddit lists the top 10 companies hiring this month in the AI and ML space. The list includes several Fortune 500 companies.",
        full_text="A new thread on the placements subreddit lists the top 10 companies hiring this month in the AI and ML space. The list includes several Fortune 500 companies. Many of the roles are remote-friendly and offer competitive salaries. Check the post for links to apply.",
        date=datetime.now(),
        source="Reddit",
        priority=2
    ),
    FeedItem(
        id="3",
        title="Friend landed abroad!",
        summary="Just saw on Instagram that your close friend has moved to Germany for a summer internship at a major tech company. They posted a picture from their new apartment in Berlin.",
        content="Just saw on Instagram that your close friend has moved to Germany for a summer internship at a major tech company. They posted a picture from their new apartment in Berlin.",
        full_text="Just saw on Instagram that your close friend has moved to Germany for a summer internship at a major tech company. They posted a picture from their new apartment in Berlin. Looks like they are having a great time!",
        date=datetime.now(),
        source="Instagram",
        priority=1
    ),
    FeedItem(
        id="4",
        title="Tech News",
        summary="Shares of tech giant XYZ fell by 20% today after their quarterly earnings report. This might have a ripple effect on AI sector investments over the next few months.",
        content="Shares of tech giant XYZ fell by 20% today after their quarterly earnings report. This might have a ripple effect on AI sector investments over the next few months.",
        full_text="Shares of tech giant XYZ fell by 20% today after their quarterly earnings report. This might have a ripple effect on AI sector investments over the next few months. Analysts are divided on whether this is a temporary dip or a sign of a larger market correction.",
        date=datetime.now(),
        source="News",
        priority=3
    ),
]