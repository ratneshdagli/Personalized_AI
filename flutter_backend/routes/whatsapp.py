"""
WhatsApp API Routes

Provides endpoints for WhatsApp chat export processing and notification handling.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, UploadFile, File
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.whatsapp_connector import get_whatsapp_connector
from storage.db import get_db_session
from storage.models import FeedItem, User, ConnectorConfig
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter()


class ChatExportRequest(BaseModel):
    """Request model for chat export processing"""
    chat_name: str = "WhatsApp Chat"
    user_id: int


class NotificationData(BaseModel):
    """Model for WhatsApp notification data"""
    title: str
    content: str
    sender: Optional[str] = None
    timestamp: Optional[str] = None
    user_id: int


class WhatsAppMessageData(BaseModel):
    """Model for WhatsApp message data from mobile app"""
    sender: str
    message: str
    timestamp: int
    user_id: str


class WhatsAppStatus(BaseModel):
    """WhatsApp connector status"""
    enabled: bool
    last_sync: Optional[str] = None
    total_messages: int = 0
    last_24h_messages: int = 0


@router.post("/whatsapp/export")
async def process_chat_export(
    background_tasks: BackgroundTasks,
    request: ChatExportRequest,
    file: UploadFile = File(...)
):
    """
    Process WhatsApp chat export file
    
    Expected file format: WhatsApp chat export text file
    """
    try:
        # Read file content
        content = await file.read()
        chat_text = content.decode('utf-8')
        
        if not chat_text.strip():
            raise HTTPException(status_code=400, detail="Empty chat export file")
        
        # Process in background
        background_tasks.add_task(
            _process_chat_export_background,
            chat_text,
            request.user_id,
            request.chat_name
        )
        
        return {
            "message": "Chat export processing started",
            "user_id": request.user_id,
            "chat_name": request.chat_name,
            "file_size": len(chat_text)
        }
        
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="Invalid file encoding. Please use UTF-8.")
    except Exception as e:
        logger.error(f"Error processing chat export: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing chat export: {str(e)}")


async def _process_chat_export_background(chat_text: str, user_id: int, chat_name: str):
    """Background task to process chat export"""
    try:
        connector = get_whatsapp_connector()
        
        # Parse chat export
        feed_items = connector.parse_chat_export(chat_text, user_id, chat_name)
        
        if feed_items:
            # Save with embeddings
            saved_items = connector.save_feed_items_with_embeddings(feed_items)
            
            logger.info(f"Processed WhatsApp chat export: {len(saved_items)} items created for user {user_id}")
        else:
            logger.warning(f"No feed items created from WhatsApp chat export for user {user_id}")
            
    except Exception as e:
        logger.error(f"Background chat export processing failed: {e}")


@router.post("/whatsapp/add")
async def add_whatsapp_message(
    background_tasks: BackgroundTasks,
    message_data: WhatsAppMessageData
):
    """
    Add WhatsApp message data from mobile app (notification or accessibility capture)
    """
    print("=" * 50)
    print("Received POST request on /whatsapp/add")
    print(f"Raw request data: {message_data.dict()}")
    print("=" * 50)
    
    try:
        # Process in background
        background_tasks.add_task(
            _process_whatsapp_message_background,
            message_data.dict()
        )
        
        print(f"Background task queued for user_id: {message_data.user_id}")
        
        return {
            "message": "WhatsApp message processing started",
            "user_id": message_data.user_id
        }
        
    except Exception as e:
        print(f"ERROR in /whatsapp/add endpoint: {e}")
        logger.error(f"Error processing WhatsApp message: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing WhatsApp message: {str(e)}")


@router.post("/whatsapp/notification")
async def process_notification(
    background_tasks: BackgroundTasks,
    notification: NotificationData
):
    """
    Process WhatsApp notification data forwarded from mobile app
    """
    try:
        # Process in background
        background_tasks.add_task(
            _process_notification_background,
            notification.dict()
        )
        
        return {
            "message": "Notification processing started",
            "user_id": notification.user_id
        }
        
    except Exception as e:
        logger.error(f"Error processing notification: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing notification: {str(e)}")


async def _process_whatsapp_message_background(message_data: Dict[str, Any]):
    """Background task to process WhatsApp message from mobile app"""
    print("=" * 50)
    print("Processing WhatsApp message in background")
    print(f"Message data: {message_data}")
    print("=" * 50)
    
    try:
        connector = get_whatsapp_connector()
        
        # Convert timestamp from milliseconds to datetime
        from datetime import datetime
        timestamp_ms = message_data.get('timestamp', 0)
        timestamp_dt = datetime.fromtimestamp(timestamp_ms / 1000.0)
        
        print(f"Converted timestamp: {timestamp_ms}ms -> {timestamp_dt}")
        
        # Create notification-like data structure
        notification_data = {
            'title': f"WhatsApp: {message_data.get('sender', 'Unknown')}",
            'content': message_data.get('message', ''),
            'sender': message_data.get('sender', 'Unknown'),
            'timestamp': timestamp_dt.isoformat(),
            'user_id': int(message_data.get('user_id', '1'))  # Convert string to int
        }
        
        print(f"Created notification data: {notification_data}")
        
        # Process as notification data
        feed_item = connector.process_notification_data(
            notification_data, 
            notification_data['user_id']
        )
        
        if feed_item:
            print(f"Feed item created successfully: {feed_item.title}")
            # Save with embeddings
            saved_items = connector.save_feed_items_with_embeddings([feed_item])
            
            print(f"Processed WhatsApp message: {len(saved_items)} items created for user {notification_data['user_id']}")
            logger.info(f"Processed WhatsApp message: {len(saved_items)} items created for user {notification_data['user_id']}")
        else:
            print(f"No feed item created from WhatsApp message for user {notification_data['user_id']}")
            logger.warning(f"No feed item created from WhatsApp message for user {notification_data['user_id']}")
            
    except Exception as e:
        print(f"ERROR in background WhatsApp processing: {e}")
        logger.error(f"Background WhatsApp message processing failed: {e}")


async def _process_notification_background(notification_data: Dict[str, Any]):
    """Background task to process notification"""
    try:
        connector = get_whatsapp_connector()
        
        # Process notification
        feed_item = connector.process_notification_data(
            notification_data, 
            notification_data['user_id']
        )
        
        if feed_item:
            # Save with embeddings
            saved_items = connector.save_feed_items_with_embeddings([feed_item])
            
            logger.info(f"Processed WhatsApp notification: {len(saved_items)} items created for user {notification_data['user_id']}")
        else:
            logger.warning(f"No feed item created from WhatsApp notification for user {notification_data['user_id']}")
            
    except Exception as e:
        logger.error(f"Background notification processing failed: {e}")


@router.get("/whatsapp/status")
async def get_whatsapp_status(user_id: int):
    """Get WhatsApp connector status and statistics"""
    try:
        db = get_db_session()
        
        # Check if WhatsApp is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "whatsapp"
        ).first()
        
        enabled = config is not None and config.enabled
        
        # Get message statistics
        from datetime import datetime, timedelta
        
        total_messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source.in_(["whatsapp", "whatsapp_notification"])
        ).count()
        
        last_24h = datetime.now() - timedelta(hours=24)
        last_24h_messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source.in_(["whatsapp", "whatsapp_notification"]),
            FeedItem.created_at >= last_24h
        ).count()
        
        # Get last sync time
        last_sync = None
        if config and config.last_sync:
            last_sync = config.last_sync.isoformat()
        
        db.close()
        
        return WhatsAppStatus(
            enabled=enabled,
            last_sync=last_sync,
            total_messages=total_messages,
            last_24h_messages=last_24h_messages
        )
        
    except Exception as e:
        logger.error(f"Error getting WhatsApp status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")


@router.post("/whatsapp/enable")
async def enable_whatsapp(user_id: int):
    """Enable WhatsApp connector for user"""
    try:
        db = get_db_session()
        
        # Create or update connector config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "whatsapp"
        ).first()
        
        if not config:
            config = ConnectorConfig(
                user_id=user_id,
                connector_type="whatsapp",
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
        
        return {"message": "WhatsApp connector enabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error enabling WhatsApp: {e}")
        raise HTTPException(status_code=500, detail=f"Error enabling WhatsApp: {str(e)}")


@router.post("/whatsapp/disable")
async def disable_whatsapp(user_id: int):
    """Disable WhatsApp connector for user"""
    try:
        db = get_db_session()
        
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "whatsapp"
        ).first()
        
        if config:
            config.enabled = False
            config.config_data = config.config_data or {}
            config.config_data["enabled"] = False
            db.commit()
        
        db.close()
        
        return {"message": "WhatsApp connector disabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error disabling WhatsApp: {e}")
        raise HTTPException(status_code=500, detail=f"Error disabling WhatsApp: {str(e)}")


@router.get("/whatsapp/messages")
async def get_whatsapp_messages(
    user_id: int,
    limit: int = 50,
    offset: int = 0
):
    """Get WhatsApp messages for user"""
    try:
        db = get_db_session()
        
        messages = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source.in_(["whatsapp", "whatsapp_notification"])
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
        logger.error(f"Error getting WhatsApp messages: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting messages: {str(e)}")


@router.delete("/whatsapp/messages/{message_id}")
async def delete_whatsapp_message(message_id: int, user_id: int):
    """Delete a specific WhatsApp message"""
    try:
        db = get_db_session()
        
        message = db.query(FeedItem).filter(
            FeedItem.id == message_id,
            FeedItem.user_id == user_id,
            FeedItem.source.in_(["whatsapp", "whatsapp_notification"])
        ).first()
        
        if not message:
            raise HTTPException(status_code=404, detail="Message not found")
        
        db.delete(message)
        db.commit()
        db.close()
        
        return {"message": "WhatsApp message deleted", "message_id": message_id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting WhatsApp message: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting message: {str(e)}")


