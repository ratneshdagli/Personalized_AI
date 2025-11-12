"""
Reddit connector API endpoints
Handles Reddit API integration and subreddit management
"""

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from storage.db import get_db
from storage.models import User, FeedItem, ConnectorConfig, SourceType
from services.reddit_connector import get_reddit_connector

router = APIRouter()

class FetchRedditRequest(BaseModel):
    subreddits: Optional[List[str]] = None
    max_posts_per_subreddit: Optional[int] = 10
    time_filter: Optional[str] = "day"

class RedditStatusResponse(BaseModel):
    connected: bool
    configured_subreddits: List[str]
    total_posts: int
    last_sync: Optional[str] = None

@router.get("/reddit/status", response_model=RedditStatusResponse)
async def get_reddit_status(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get Reddit connector status and configuration
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        reddit_connector = get_reddit_connector()
        
        # Check if Reddit API is connected
        connected = reddit_connector.reddit is not None
        
        # Get configured subreddits
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.REDDIT
        ).first()
        
        if config and config.config_data:
            configured_subreddits = config.config_data.get("subreddits", [])
        else:
            configured_subreddits = reddit_connector.default_subreddits
        
        # Count total Reddit posts
        total_posts = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.REDDIT
        ).count()
        
        # Get last sync time
        last_sync = config.last_sync_at.isoformat() if config and config.last_sync_at else None
        
        return RedditStatusResponse(
            connected=connected,
            configured_subreddits=configured_subreddits,
            total_posts=total_posts,
            last_sync=last_sync
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get Reddit status: {str(e)}")

@router.post("/reddit/fetch")
async def fetch_reddit_posts(
    request: FetchRedditRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Fetch posts from Reddit subreddits
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        reddit_connector = get_reddit_connector()
        
        if not reddit_connector.reddit:
            raise HTTPException(
                status_code=400,
                detail="Reddit API not configured. Please set REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET."
            )
        
        # Determine subreddits to fetch from
        subreddits = request.subreddits or reddit_connector.default_subreddits
        
        # Add background task
        background_tasks.add_task(
            _fetch_and_process_reddit_posts,
            user_id=user_id,
            subreddits=subreddits,
            max_posts_per_subreddit=request.max_posts_per_subreddit or 10,
            time_filter=request.time_filter or "day"
        )
        
        return {
            "success": True,
            "message": "Reddit fetch started in background",
            "subreddits": subreddits,
            "max_posts_per_subreddit": request.max_posts_per_subreddit or 10,
            "time_filter": request.time_filter or "day"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start Reddit fetch: {str(e)}")

@router.get("/reddit/posts")
async def get_reddit_posts(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    subreddit: Optional[str] = Query(None),
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get processed Reddit posts from feed
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Build query
        query = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.REDDIT
        )
        
        # Filter by subreddit if specified
        if subreddit:
            query = query.filter(FeedItem.metadata.contains({"subreddit": subreddit}))
        
        # Get posts
        posts = query.order_by(FeedItem.date.desc()).offset(offset).limit(limit).all()
        
        # Format response
        reddit_posts = []
        for item in posts:
            reddit_posts.append({
                "id": item.id,
                "origin_id": item.origin_id,
                "title": item.title,
                "summary": item.summary,
                "date": item.date.isoformat(),
                "priority": item.priority.value,
                "relevance_score": item.relevance_score,
                "has_tasks": item.has_tasks,
                "extracted_tasks": item.extracted_tasks,
                "entities": item.entities,
                "author": item.metadata.get("author") if item.metadata else None,
                "subreddit": item.metadata.get("subreddit") if item.metadata else None,
                "score": item.metadata.get("score") if item.metadata else None,
                "num_comments": item.metadata.get("num_comments") if item.metadata else None,
                "flair": item.metadata.get("flair") if item.metadata else None,
                "post_type": item.metadata.get("post_type") if item.metadata else None,
                "url": item.metadata.get("url") if item.metadata else None,
                "permalink": item.metadata.get("permalink") if item.metadata else None
            })
        
        return {
            "posts": reddit_posts,
            "total_count": len(reddit_posts),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get Reddit posts: {str(e)}")

@router.get("/reddit/subreddits")
async def get_available_subreddits():
    """
    Get list of available subreddits
    """
    try:
        reddit_connector = get_reddit_connector()
        
        return {
            "default_subreddits": reddit_connector.default_subreddits,
            "categories": {
                "technology": [
                    "technology", "programming", "MachineLearning", "artificial",
                    "webdev", "compsci", "datascience", "startups"
                ],
                "programming": [
                    "programming", "webdev", "compsci", "MachineLearning",
                    "artificial", "datascience", "learnprogramming"
                ],
                "general": [
                    "technology", "programming", "startups", "entrepreneur"
                ]
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get subreddits: {str(e)}")

@router.post("/reddit/subreddits")
async def update_subreddits(
    subreddits: List[str],
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Update user's configured subreddits
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Validate subreddits (basic validation)
        if len(subreddits) > 20:
            raise HTTPException(
                status_code=400,
                detail="Too many subreddits. Maximum 20 allowed."
            )
        
        # Get or create Reddit connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.REDDIT
        ).first()
        
        if not config:
            config = ConnectorConfig(
                user_id=user_id,
                connector_type=SourceType.REDDIT,
                is_enabled=True,
                config_data={"subreddits": []}
            )
            db.add(config)
        
        # Update subreddits
        config.config_data["subreddits"] = subreddits
        db.commit()
        
        return {
            "success": True,
            "message": f"Updated {len(subreddits)} subreddits",
            "subreddits": subreddits
        }
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update subreddits: {str(e)}")

@router.get("/reddit/popular")
async def get_popular_posts(
    subreddit: str = Query("technology"),
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get popular posts from a specific subreddit (real-time)
    """
    try:
        reddit_connector = get_reddit_connector()
        
        if not reddit_connector.reddit:
            raise HTTPException(
                status_code=400,
                detail="Reddit API not configured"
            )
        
        # Fetch posts directly from Reddit
        posts = reddit_connector.fetch_subreddit_posts([subreddit], limit)
        
        # Format response
        popular_posts = []
        for post in posts:
            popular_posts.append({
                "id": post["id"],
                "title": post["title"],
                "url": post["url"],
                "content": post["content"][:500] if post["content"] else None,
                "author": post["author"],
                "score": post["score"],
                "num_comments": post["num_comments"],
                "date": post["date"].isoformat(),
                "subreddit": post["subreddit"],
                "flair": post["flair"],
                "post_type": post["post_type"],
                "permalink": post["permalink"]
            })
        
        return {
            "subreddit": subreddit,
            "posts": popular_posts,
            "count": len(popular_posts)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get popular posts: {str(e)}")

async def _fetch_and_process_reddit_posts(user_id: int, subreddits: List[str], 
                                        max_posts_per_subreddit: int, time_filter: str):
    """
    Background task to fetch and process Reddit posts
    """
    try:
        reddit_connector = get_reddit_connector()
        
        if not reddit_connector.reddit:
            logger.error("Reddit API not available for background processing")
            return
        
        # Fetch posts from Reddit
        posts = reddit_connector.fetch_subreddit_posts(subreddits, max_posts_per_subreddit)
        
        if not posts:
            logger.info(f"No Reddit posts found for user {user_id}")
            return
        
        # Process posts into feed items
        feed_items = reddit_connector.process_posts_to_feed_items(user_id, posts)
        
        # Save to database
        db = get_db_session()
        try:
            # Check for existing items to avoid duplicates
            existing_origin_ids = set()
            for item in feed_items:
                existing = db.query(FeedItem).filter(
                    FeedItem.user_id == user_id,
                    FeedItem.origin_id == item.origin_id,
                    FeedItem.source == SourceType.REDDIT
                ).first()
                
                if not existing:
                    db.add(item)
                    existing_origin_ids.add(item.origin_id)
            
            # Update last sync time
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == SourceType.REDDIT
            ).first()
            
            if config:
                config.last_sync_at = datetime.now()
            else:
                config = ConnectorConfig(
                    user_id=user_id,
                    connector_type=SourceType.REDDIT,
                    is_enabled=True,
                    last_sync_at=datetime.now()
                )
                db.add(config)
            
            db.commit()
            
            logger.info(f"Processed {len(existing_origin_ids)} new Reddit posts for user {user_id}")
            
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Background Reddit processing failed for user {user_id}: {e}")

# Import logger
import logging
logger = logging.getLogger(__name__)


