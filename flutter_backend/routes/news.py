"""
News connector API endpoints
Handles RSS feeds and NewsAPI integration
"""

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from storage.db import get_db
from storage.models import User, FeedItem, ConnectorConfig, SourceType
from services.news_connector import get_news_connector

router = APIRouter()

class FetchNewsRequest(BaseModel):
    sources: Optional[List[str]] = None  # RSS feed URLs or "newsapi" or "gnews"
    max_results: Optional[int] = 20
    query: Optional[str] = "technology"

class NewsSourceRequest(BaseModel):
    name: str
    url: str
    category: str = "general"

class NewsStatusResponse(BaseModel):
    rss_feeds_configured: int
    newsapi_available: bool
    gnews_available: bool
    total_articles: int
    last_sync: Optional[str] = None

@router.get("/news/status", response_model=NewsStatusResponse)
async def get_news_status(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get news connector status and configuration
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        news_connector = get_news_connector()
        
        # Check API availability
        newsapi_available = bool(news_connector.newsapi_key)
        gnews_available = bool(news_connector.gnews_api_key)
        
        # Count configured RSS feeds
        rss_feeds_configured = len(news_connector.default_rss_feeds)
        
        # Count total news articles
        total_articles = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.NEWS
        ).count()
        
        # Get last sync time
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.NEWS
        ).first()
        
        last_sync = config.last_sync_at.isoformat() if config and config.last_sync_at else None
        
        return NewsStatusResponse(
            rss_feeds_configured=rss_feeds_configured,
            newsapi_available=newsapi_available,
            gnews_available=gnews_available,
            total_articles=total_articles,
            last_sync=last_sync
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get news status: {str(e)}")

@router.post("/news/fetch")
async def fetch_news_articles(
    request: FetchNewsRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Fetch news articles from configured sources
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        news_connector = get_news_connector()
        
        # Determine sources to fetch from
        sources = request.sources or ["rss", "newsapi", "gnews"]
        
        # Add background task
        background_tasks.add_task(
            _fetch_and_process_news,
            user_id=user_id,
            sources=sources,
            max_results=request.max_results or 20,
            query=request.query or "technology"
        )
        
        return {
            "success": True,
            "message": "News fetch started in background",
            "sources": sources,
            "max_results": request.max_results or 20,
            "query": request.query or "technology"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start news fetch: {str(e)}")

@router.get("/news/articles")
async def get_news_articles(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get processed news articles from feed
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Build query
        query = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.NEWS
        )
        
        # Filter by category if specified
        if category:
            query = query.filter(FeedItem.metadata.contains({"category": category}))
        
        # Get articles
        articles = query.order_by(FeedItem.date.desc()).offset(offset).limit(limit).all()
        
        # Format response
        news_articles = []
        for item in articles:
            news_articles.append({
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
                "source": item.metadata.get("source") if item.metadata else None,
                "source_name": item.metadata.get("source_name") if item.metadata else None,
                "link": item.metadata.get("link") if item.metadata else None,
                "tags": item.metadata.get("tags") if item.metadata else []
            })
        
        return {
            "articles": news_articles,
            "total_count": len(news_articles),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get news articles: {str(e)}")

@router.get("/news/sources")
async def get_news_sources():
    """
    Get available news sources and their configuration
    """
    try:
        news_connector = get_news_connector()
        
        return {
            "rss_feeds": news_connector.default_rss_feeds,
            "apis": {
                "newsapi": {
                    "available": bool(news_connector.newsapi_key),
                    "description": "NewsAPI.org - Global news articles"
                },
                "gnews": {
                    "available": bool(news_connector.gnews_api_key),
                    "description": "GNews API - News aggregation"
                }
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get news sources: {str(e)}")

@router.post("/news/sources/rss")
async def add_rss_source(
    request: NewsSourceRequest,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Add a new RSS feed source
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get or create news connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.NEWS
        ).first()
        
        if not config:
            config = ConnectorConfig(
                user_id=user_id,
                connector_type=SourceType.NEWS,
                is_enabled=True,
                config_data={"rss_feeds": []}
            )
            db.add(config)
        
        # Add RSS feed to config
        rss_feeds = config.config_data.get("rss_feeds", [])
        new_feed = {
            "name": request.name,
            "url": request.url,
            "category": request.category
        }
        
        # Check if feed already exists
        if not any(feed["url"] == request.url for feed in rss_feeds):
            rss_feeds.append(new_feed)
            config.config_data["rss_feeds"] = rss_feeds
            db.commit()
            
            return {
                "success": True,
                "message": f"RSS feed '{request.name}' added successfully"
            }
        else:
            return {
                "success": False,
                "message": "RSS feed already exists"
            }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to add RSS source: {str(e)}")

@router.delete("/news/sources/rss/{feed_url:path}")
async def remove_rss_source(
    feed_url: str,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Remove an RSS feed source
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get news connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.NEWS
        ).first()
        
        if config and config.config_data:
            rss_feeds = config.config_data.get("rss_feeds", [])
            original_count = len(rss_feeds)
            
            # Remove feed
            config.config_data["rss_feeds"] = [
                feed for feed in rss_feeds if feed["url"] != feed_url
            ]
            
            removed_count = original_count - len(config.config_data["rss_feeds"])
            db.commit()
            
            if removed_count > 0:
                return {
                    "success": True,
                    "message": f"Removed {removed_count} RSS feed(s)"
                }
            else:
                return {
                    "success": False,
                    "message": "RSS feed not found"
                }
        else:
            return {
                "success": False,
                "message": "No RSS feeds configured"
            }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to remove RSS source: {str(e)}")

async def _fetch_and_process_news(user_id: int, sources: List[str], max_results: int, query: str):
    """
    Background task to fetch and process news articles
    """
    try:
        news_connector = get_news_connector()
        articles = []
        
        # Fetch from RSS feeds
        if "rss" in sources:
            rss_feeds = [feed["url"] for feed in news_connector.default_rss_feeds]
            rss_articles = news_connector.fetch_rss_feeds(rss_feeds, max_results // 3)
            articles.extend(rss_articles)
        
        # Fetch from NewsAPI
        if "newsapi" in sources and news_connector.newsapi_key:
            newsapi_articles = news_connector.fetch_newsapi_articles(query, max_results // 3)
            articles.extend(newsapi_articles)
        
        # Fetch from GNews
        if "gnews" in sources and news_connector.gnews_api_key:
            gnews_articles = news_connector.fetch_gnews_articles(query, max_results // 3)
            articles.extend(gnews_articles)
        
        if not articles:
            logger.info(f"No news articles found for user {user_id}")
            return
        
        # Process articles into feed items
        feed_items = news_connector.process_articles_to_feed_items(user_id, articles)
        
        # Save to database
        db = get_db_session()
        try:
            # Check for existing items to avoid duplicates
            existing_origin_ids = set()
            for item in feed_items:
                existing = db.query(FeedItem).filter(
                    FeedItem.user_id == user_id,
                    FeedItem.origin_id == item.origin_id,
                    FeedItem.source == SourceType.NEWS
                ).first()
                
                if not existing:
                    db.add(item)
                    existing_origin_ids.add(item.origin_id)
            
            # Update last sync time
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == SourceType.NEWS
            ).first()
            
            if config:
                config.last_sync_at = datetime.now()
            else:
                config = ConnectorConfig(
                    user_id=user_id,
                    connector_type=SourceType.NEWS,
                    is_enabled=True,
                    last_sync_at=datetime.now()
                )
                db.add(config)
            
            db.commit()
            
            logger.info(f"Processed {len(existing_origin_ids)} new news articles for user {user_id}")
            
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Background news processing failed for user {user_id}: {e}")

# Import logger
import logging
logger = logging.getLogger(__name__)


