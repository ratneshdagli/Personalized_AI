"""
Telegram API Routes

Provides endpoints for Telegram bot integration and message fetching.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, Query
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.telegram_connector import get_telegram_connector
from storage.db import get_db_session
from storage.models import FeedItem, User, ConnectorConfig
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter()


class TelegramBotConfig(BaseModel):
    """Request model for Telegram bot configuration"""
    bot_token: str
    user_id: int


class TelegramStatus(BaseModel):
    """Telegram connector status"""
    enabled: bool
    last_sync: Optional[str] = None
    total_messages: int = 0
    last_24h_messages: int = 0
    bot_username: Optional[str] = None


@router.get("/telegram/bot/info")
async def get_telegram_bot_info():
    """Get Telegram bot information"""
    try:
        connector = get_telegram_connector()
        bot_info = connector.get_me()
        
        return {
            "bot_info": bot_info,
            "status": "active"
        }
        
    except Exception as e:
        logger.error(f"Error getting Telegram bot info: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting bot info: {str(e)}")


@router.post("/telegram/configure")
async def configure_telegram_bot(request: TelegramBotConfig):
    """Configure Telegram bot for user"""
    try:
        connector = get_telegram_connector()
        
        # Verify bot token by getting bot info
        try:
            bot_info = connector.get_me()
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid bot token: {str(e)}")
        
        # Store bot configuration
        db = get_db_session()
        try:
            # Create or update connector config
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == request.user_id,
                ConnectorConfig.connector_type == "telegram"
            ).first()
            
            if not config:
                config = ConnectorConfig(
                    user_id=request.user_id,
                    connector_type="telegram",
                    enabled=True,
                    config_data={
                        "bot_token": request.bot_token,
                        "bot_username": bot_info.get("username"),
                        "bot_id": bot_info.get("id")
                    }
                )
                db.add(config)
            else:
                config.enabled = True
                config.config_data = {
                    "bot_token": request.bot_token,
                    "bot_username": bot_info.get("username"),
                    "bot_id": bot_info.get("id")
                }
            
            db.commit()
            
            return {
                "message": "Telegram bot configured successfully",
                "user_id": request.user_id,
                "bot_username": bot_info.get("username")
            }
            
        finally:
            db.close()
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error configuring Telegram bot: {e}")
        raise HTTPException(status_code=500, detail=f"Error configuring bot: {str(e)}")


@router.get("/telegram/status")
async def get_telegram_status(user_id: int):
    """Get Telegram connector status"""
    try:
        db = get_db_session()
        
        # Check if Telegram is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "telegram"
        ).first()
        
        enabled = config is not None and config.enabled
        
        # Get message statistics
        from datetime import datetime, timedelta
        
        total_messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "telegram"
        ).count()
        
        last_24h = datetime.now() - timedelta(hours=24)
        last_24h_messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "telegram",
            FeedItem.created_at >= last_24h
        ).count()
        
        # Get last sync time
        last_sync = None
        if config and config.last_sync:
            last_sync = config.last_sync.isoformat()
        
        # Get bot username
        bot_username = None
        if config and config.config_data:
            bot_username = config.config_data.get("bot_username")
        
        db.close()
        
        return TelegramStatus(
            enabled=enabled,
            last_sync=last_sync,
            total_messages=total_messages,
            last_24h_messages=last_24h_messages,
            bot_username=bot_username
        )
        
    except Exception as e:
        logger.error(f"Error getting Telegram status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")


@router.post("/telegram/fetch")
async def fetch_telegram_messages(
    background_tasks: BackgroundTasks,
    user_id: int,
    limit: int = Query(100, ge=1, le=1000)
):
    """Fetch Telegram messages"""
    try:
        db = get_db_session()
        
        # Check if Telegram is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "telegram",
            ConnectorConfig.enabled == True
        ).first()
        
        if not config:
            raise HTTPException(status_code=400, detail="Telegram connector not enabled")
        
        bot_token = config.config_data.get("bot_token")
        
        if not bot_token:
            raise HTTPException(status_code=400, detail="Telegram bot not properly configured")
        
        # Process in background
        background_tasks.add_task(
            _fetch_telegram_messages_background,
            user_id,
            bot_token,
            limit
        )
        
        db.close()
        
        return {
            "message": "Telegram messages fetch started",
            "user_id": user_id,
            "limit": limit
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching Telegram messages: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching messages: {str(e)}")


async def _fetch_telegram_messages_background(user_id: int, bot_token: str, limit: int):
    """Background task to fetch Telegram messages"""
    try:
        # Set bot token in environment for this request
        import os
        original_token = os.getenv("TELEGRAM_BOT_TOKEN")
        os.environ["TELEGRAM_BOT_TOKEN"] = bot_token
        
        try:
            connector = get_telegram_connector()
            
            # Get updates (messages)
            updates = connector.get_updates(limit=limit)
            
            # Process messages into feed items
            feed_items = []
            for update in updates:
                message = update.get("message")
                if message:
                    feed_item = connector.process_message(message, user_id)
                    if feed_item:
                        feed_items.append(feed_item)
            
            if feed_items:
                # Save with embeddings
                saved_items = connector.save_feed_items_with_embeddings(feed_items)
                
                logger.info(f"Fetched Telegram messages: {len(saved_items)} items created for user {user_id}")
            else:
                logger.warning(f"No feed items created from Telegram messages for user {user_id}")
                
        finally:
            # Restore original token
            if original_token:
                os.environ["TELEGRAM_BOT_TOKEN"] = original_token
            else:
                os.environ.pop("TELEGRAM_BOT_TOKEN", None)
            
    except Exception as e:
        logger.error(f"Background Telegram fetch failed: {e}")


@router.post("/telegram/enable")
async def enable_telegram(user_id: int):
    """Enable Telegram connector for user"""
    try:
        db = get_db_session()
        
        # Create or update connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "telegram"
        ).first()
        
        if not config:
            config = ConnectorConfig(
                user_id=user_id,
                connector_type="telegram",
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
        
        return {"message": "Telegram connector enabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error enabling Telegram: {e}")
        raise HTTPException(status_code=500, detail=f"Error enabling Telegram: {str(e)}")


@router.post("/telegram/disable")
async def disable_telegram(user_id: int):
    """Disable Telegram connector for user"""
    try:
        db = get_db_session()
        
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "telegram"
        ).first()
        
        if config:
            config.enabled = False
            config.config_data = config.config_data or {}
            config.config_data["enabled"] = False
            db.commit()
        
        db.close()
        
        return {"message": "Telegram connector disabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error disabling Telegram: {e}")
        raise HTTPException(status_code=500, detail=f"Error disabling Telegram: {str(e)}")


@router.get("/telegram/messages")
async def get_telegram_messages(
    user_id: int,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0)
):
    """Get Telegram messages for user"""
    try:
        db = get_db_session()
        
        messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == "telegram"
        ).order_by(FeedItem.published_at.desc()).offset(offset).limit(limit).all()
        
        db.close()
        
        return {
            "messages": [
                {
                    "id": msg.id,
                    "title": msg.title,
                    "summary": msg.summary,
                    "priority": msg.priority,
                    "relevance": msg.relevance,
                    "published_at": msg.published_at.isoformat(),
                    "meta_data": msg.meta_data
                }
                for msg in messages
            ],
            "total": len(messages)
        }
        
    except Exception as e:
        logger.error(f"Error getting Telegram messages: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting messages: {str(e)}")


@router.post("/telegram/send")
async def send_telegram_message(
    chat_id: str,
    text: str
):
    """Send a message to a Telegram chat"""
    try:
        connector = get_telegram_connector()
        
        success = connector.send_message(chat_id, text)
        
        if success:
            return {
                "message": "Message sent successfully",
                "chat_id": chat_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to send message")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending Telegram message: {e}")
        raise HTTPException(status_code=500, detail=f"Error sending message: {str(e)}")


