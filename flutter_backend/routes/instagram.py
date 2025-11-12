"""
Instagram API Routes

Provides endpoints for Instagram OAuth flow and content fetching.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, Query
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.instagram_connector import get_instagram_connector
from storage.db import get_db_session
from storage.models import FeedItem, User, ConnectorConfig
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter()


class InstagramAuthRequest(BaseModel):
    """Request model for Instagram OAuth"""
    code: str
    state: str  # user_id


class InstagramStatus(BaseModel):
    """Instagram connector status"""
    enabled: bool
    last_sync: Optional[str] = None
    total_posts: int = 0
    last_24h_posts: int = 0
    username: Optional[str] = None


@router.get("/instagram/auth/url")
async def get_instagram_auth_url(user_id: int):
    """Get Instagram OAuth URL"""
    try:
        connector = get_instagram_connector()
        
        # Get redirect URI from environment
        import os
        redirect_uri = os.getenv("INSTAGRAM_REDIRECT_URI", "http://localhost:8000/api/auth/instagram/callback")
        
        auth_url = connector.get_auth_url(user_id, redirect_uri)
        
        return {
            "auth_url": auth_url,
            "user_id": user_id
        }
        
    except Exception as e:
        logger.error(f"Error getting Instagram auth URL: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting auth URL: {str(e)}")


@router.post("/instagram/auth/callback")
async def handle_instagram_callback(request: InstagramAuthRequest):
    """Handle Instagram OAuth callback"""
    try:
        connector = get_instagram_connector()
        
        # Get redirect URI from environment
        import os
        redirect_uri = os.getenv("INSTAGRAM_REDIRECT_URI", "http://localhost:8000/api/auth/instagram/callback")
        
        # Exchange code for token
        token_data = connector.exchange_code_for_token(request.code, redirect_uri)
        
        # Get user profile
        user_profile = connector.get_user_profile(token_data["access_token"])
        
        # Store token and config
        db = get_db_session()
        try:
            user_id = int(request.state)
            
            # Create or update connector config
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == "instagram"
            ).first()
            
            if not config:
                config = ConnectorConfig(
                    user_id=user_id,
                    connector_type="instagram",
                    enabled=True,
                    config_data={
                        "access_token": token_data["access_token"],
                        "user_id": token_data["user_id"],
                        "username": user_profile.get("username"),
                        "account_type": user_profile.get("account_type")
                    }
                )
                db.add(config)
            else:
                config.enabled = True
                config.config_data = {
                    "access_token": token_data["access_token"],
                    "user_id": token_data["user_id"],
                    "username": user_profile.get("username"),
                    "account_type": user_profile.get("account_type")
                }
            
            db.commit()
            
            return {
                "message": "Instagram authentication successful",
                "user_id": user_id,
                "username": user_profile.get("username")
            }
            
        finally:
            db.close()
        
    except Exception as e:
        logger.error(f"Error handling Instagram callback: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing callback: {str(e)}")


@router.get("/instagram/status")
async def get_instagram_status(user_id: int):
    """Get Instagram connector status"""
    try:
        db = get_db_session()
        
        # Check if Instagram is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "instagram"
        ).first()
        
        enabled = config is not None and config.enabled
        
        # Get post statistics
        from datetime import datetime, timedelta
        
        total_posts = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "instagram"
        ).count()
        
        last_24h = datetime.now() - timedelta(hours=24)
        last_24h_posts = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "instagram",
            FeedItem.created_at >= last_24h
        ).count()
        
        # Get last sync time
        last_sync = None
        if config and config.last_sync:
            last_sync = config.last_sync.isoformat()
        
        # Get username
        username = None
        if config and config.config_data:
            username = config.config_data.get("username")
        
        db.close()
        
        return InstagramStatus(
            enabled=enabled,
            last_sync=last_sync,
            total_posts=total_posts,
            last_24h_posts=last_24h_posts,
            username=username
        )
        
    except Exception as e:
        logger.error(f"Error getting Instagram status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")


@router.post("/instagram/fetch")
async def fetch_instagram_posts(
    background_tasks: BackgroundTasks,
    user_id: int,
    limit: int = Query(25, ge=1, le=100)
):
    """Fetch Instagram posts"""
    try:
        db = get_db_session()
        
        # Check if Instagram is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "instagram",
            ConnectorConfig.enabled == True
        ).first()
        
        if not config:
            raise HTTPException(status_code=400, detail="Instagram connector not enabled")
        
        access_token = config.config_data.get("access_token")
        instagram_user_id = config.config_data.get("user_id")
        
        if not access_token or not instagram_user_id:
            raise HTTPException(status_code=400, detail="Instagram not properly configured")
        
        # Process in background
        background_tasks.add_task(
            _fetch_instagram_posts_background,
            user_id,
            access_token,
            instagram_user_id,
            limit
        )
        
        db.close()
        
        return {
            "message": "Instagram posts fetch started",
            "user_id": user_id,
            "limit": limit
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching Instagram posts: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching posts: {str(e)}")


async def _fetch_instagram_posts_background(user_id: int, access_token: str, 
                                          instagram_user_id: str, limit: int):
    """Background task to fetch Instagram posts"""
    try:
        connector = get_instagram_connector()
        
        # Fetch user media
        posts = connector.fetch_user_media(access_token, instagram_user_id, limit)
        
        # Process posts into feed items
        feed_items = []
        for post in posts:
            feed_item = connector.process_media_post(post, user_id)
            if feed_item:
                feed_items.append(feed_item)
        
        if feed_items:
            # Save with embeddings
            saved_items = connector.save_feed_items_with_embeddings(feed_items)
            
            logger.info(f"Fetched Instagram posts: {len(saved_items)} items created for user {user_id}")
        else:
            logger.warning(f"No feed items created from Instagram posts for user {user_id}")
            
    except Exception as e:
        logger.error(f"Background Instagram fetch failed: {e}")


@router.post("/instagram/enable")
async def enable_instagram(user_id: int):
    """Enable Instagram connector for user"""
    try:
        db = get_db_session()
        
        # Create or update connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "instagram"
        ).first()
        
        if not config:
            config = ConnectorConfig(
                user_id=user_id,
                connector_type="instagram",
                enabled=True,
                config_data={"enabled": True}
            )
            db.add(config)
        else:
            config.enabled = True
            config.config_data = config.config_data or {}
            config.config_data["enabled"] = True
        
        db.commit()
        db.close()
        
        return {"message": "Instagram connector enabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error enabling Instagram: {e}")
        raise HTTPException(status_code=500, detail=f"Error enabling Instagram: {str(e)}")


@router.post("/instagram/disable")
async def disable_instagram(user_id: int):
    """Disable Instagram connector for user"""
    try:
        db = get_db_session()
        
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "instagram"
        ).first()
        
        if config:
            config.enabled = False
            config.config_data = config.config_data or {}
            config.config_data["enabled"] = False
            db.commit()
        
        db.close()
        
        return {"message": "Instagram connector disabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error disabling Instagram: {e}")
        raise HTTPException(status_code=500, detail=f"Error disabling Instagram: {str(e)}")


@router.get("/instagram/posts")
async def get_instagram_posts(
    user_id: int,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0)
):
    """Get Instagram posts for user"""
    try:
        db = get_db_session()
        
        posts = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "instagram"
        ).order_by(FeedItem.published_at.desc()).offset(offset).limit(limit).all()
        
        db.close()
        
        return {
            "posts": [
                {
                    "id": post.id,
                    "title": post.title,
                    "summary": post.summary,
                    "priority": post.priority,
                    "relevance": post.relevance,
                    "published_at": post.published_at.isoformat(),
                    "meta_data": post.meta_data
                }
                for post in posts
            ],
            "total": len(posts)
        }
        
    except Exception as e:
        logger.error(f"Error getting Instagram posts: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting posts: {str(e)}")


