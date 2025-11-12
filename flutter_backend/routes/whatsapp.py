"""
WhatsApp API Routes

Provides endpoints for WhatsApp chat export processing and notification handling.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, UploadFile, File
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.whatsapp_connector import get_whatsapp_connector
from app.core.nosql import store

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
            'user_id': int(message_data.get('user_id')) if str(message_data.get('user_id')).isdigit() else 1 # Safely convert to int
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
            
            # Extract todos and events from the message
            try:
                from services.notification_processor import get_notification_processor
                processor = get_notification_processor()
                
                message_text = message_data.get('message', '')
                feed_item_id = str(saved_items[0].id) if saved_items else None
                
                todos, events = processor.process_notification(
                    text=message_text,
                    user_id=notification_data['user_id'],
                    source="whatsapp",
                    source_id=feed_item_id
                )
                
                print(f"Auto-extracted {len(todos)} todos and {len(events)} events from WhatsApp message")
                logger.info(f"Auto-extracted {len(todos)} todos and {len(events)} events from WhatsApp message")
            except Exception as e:
                print(f"Error auto-extracting todos/events: {e}")
                logger.error(f"Error auto-extracting todos/events: {e}")
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
        # Check if WhatsApp is enabled in NoSQL connectors
        configs = store.connectors.search(lambda c: c.get("user_id") == user_id and c.get("connector_type") == "whatsapp")
        cfg = configs[0] if configs else None
        enabled = bool(cfg and (cfg.get("enabled") or cfg.get("is_enabled")))

        # Stats over feed_items in NoSQL store
        from datetime import datetime, timedelta
        now_ts = datetime.now().timestamp()
        msgs = store.feed_items.search(lambda d: d.get("user_id") == user_id and d.get("source") in ("whatsapp", "whatsapp_notification") and not d.get("deleted"))
        total_messages = len(msgs)
        cutoff = now_ts - 24 * 3600
        last_24h_messages = len([m for m in msgs if (m.get("created_at") or 0) >= cutoff])

        last_sync = cfg.get("last_sync") if cfg else None
        
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
        # Upsert connector record in NoSQL store
        record = {
            "user_id": user_id,
            "connector_type": "whatsapp",
            "enabled": True,
            "is_enabled": True,
            "config_data": {"enabled": True},
            "updated_at": __import__("time").time(),
        }
        # Note: upserting by user_id (shared with other connectors) is acceptable for current scope
        store.upsert("connectors", record, key="user_id")
        
        return {"message": "WhatsApp connector enabled", "user_id": user_id}
        
    except Exception as e:
        logger.error(f"Error enabling WhatsApp: {e}")
        raise HTTPException(status_code=500, detail=f"Error enabling WhatsApp: {str(e)}")


@router.post("/whatsapp/disable")
async def disable_whatsapp(user_id: int):
    """Disable WhatsApp connector for user"""
    try:
        configs = store.connectors.search(lambda c: c.get("user_id") == user_id and c.get("connector_type") == "whatsapp")
        cfg = configs[0] if configs else {"user_id": user_id, "connector_type": "whatsapp"}
        cfg["enabled"] = False
        cfg["is_enabled"] = False
        data = cfg.get("config_data") or {}
        data["enabled"] = False
        cfg["config_data"] = data
        cfg["updated_at"] = __import__("time").time()
        store.upsert("connectors", cfg, key="user_id")
        
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
        docs = store.feed_items.search(lambda d: d.get("user_id") == user_id and d.get("source") in ("whatsapp", "whatsapp_notification") and not d.get("deleted"))
        # Sort by created_at desc, fallback to 0
        docs.sort(key=lambda d: d.get("created_at") or 0, reverse=True)
        messages = docs[offset: offset + limit]
        
        return {
            "messages": [
                {
                    "id": m.get("id"),
                    "title": m.get("title"),
                    "summary": m.get("summary"),
                    "priority": m.get("priority"),
                    "relevance": m.get("relevance") or m.get("relevance_score"),
                    "published_at": m.get("date"),
                    "meta_data": m.get("metadata") or m.get("meta_data"),
                }
                for m in messages
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
        docs = store.feed_items.search(lambda d: d.get("id") == message_id and d.get("user_id") == user_id and d.get("source") in ("whatsapp", "whatsapp_notification"))
        if not docs:
            raise HTTPException(status_code=404, detail="Message not found")
        # Soft delete by marking a flag
        doc = dict(docs[0])
        doc["deleted"] = True
        store.upsert("feed_items", doc, key="id")
        
        return {"message": "WhatsApp message deleted", "message_id": message_id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting WhatsApp message: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting message: {str(e)}")


