"""
Calendar & Notifications API Routes

Provides endpoints for calendar synchronization and notification management.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks, Depends, Query
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.calendar_service import get_calendar_service
from services.notification_service import get_notification_service
from storage.db import get_db_session
from storage.models import Task, User, ConnectorConfig
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

router = APIRouter()


class CalendarAuthRequest(BaseModel):
    """Request model for calendar OAuth"""
    code: str
    state: str  # user_id


class CalendarStatus(BaseModel):
    """Calendar connector status"""
    enabled: bool
    last_sync: Optional[str] = None
    total_events: int = 0
    upcoming_events: int = 0


class NotificationSettings(BaseModel):
    """Notification settings model"""
    task_notifications: bool = True
    priority_notifications: bool = True
    daily_summary: bool = True
    quiet_hours_start: str = "22:00"
    quiet_hours_end: str = "08:00"
    notification_sound: bool = True
    vibration: bool = True


@router.get("/calendar/auth/url")
async def get_calendar_auth_url(user_id: int):
    """Get Google Calendar OAuth URL"""
    try:
        calendar_service = get_calendar_service()
        
        # Get redirect URI from environment
        import os
        redirect_uri = os.getenv("GOOGLE_CALENDAR_REDIRECT_URI", "http://localhost:8000/api/auth/calendar/callback")
        
        auth_url = calendar_service.get_calendar_auth_url(user_id, redirect_uri)
        
        return {
            "auth_url": auth_url,
            "user_id": user_id
        }
        
    except Exception as e:
        logger.error(f"Error getting calendar auth URL: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting auth URL: {str(e)}")


@router.post("/calendar/auth/callback")
async def handle_calendar_callback(request: CalendarAuthRequest):
    """Handle Google Calendar OAuth callback"""
    try:
        calendar_service = get_calendar_service()
        
        # Get redirect URI from environment
        import os
        redirect_uri = os.getenv("GOOGLE_CALENDAR_REDIRECT_URI", "http://localhost:8000/api/auth/calendar/callback")
        
        # Exchange code for token
        token_data = calendar_service.exchange_code_for_token(request.code, redirect_uri)
        
        # Store token and config
        db = get_db_session()
        try:
            user_id = int(request.state)
            
            # Create or update connector config
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == "google_calendar"
            ).first()
            
            if not config:
                config = ConnectorConfig(
                    user_id=user_id,
                    connector_type="google_calendar",
                    enabled=True,
                    config_data={
                        "access_token": token_data["access_token"],
                        "refresh_token": token_data.get("refresh_token"),
                        "token_type": token_data.get("token_type", "Bearer"),
                        "expires_in": token_data.get("expires_in")
                    }
                )
                db.add(config)
            else:
                config.enabled = True
                config.config_data = {
                    "access_token": token_data["access_token"],
                    "refresh_token": token_data.get("refresh_token"),
                    "token_type": token_data.get("token_type", "Bearer"),
                    "expires_in": token_data.get("expires_in")
                }
            
            db.commit()
            
            return {
                "message": "Google Calendar authentication successful",
                "user_id": user_id
            }
            
        finally:
            db.close()
        
    except Exception as e:
        logger.error(f"Error handling calendar callback: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing callback: {str(e)}")


@router.get("/calendar/status")
async def get_calendar_status(user_id: int):
    """Get calendar connector status"""
    try:
        db = get_db_session()
        
        # Check if calendar is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "google_calendar"
        ).first()
        
        enabled = config is not None and config.enabled
        
        # Get event statistics
        from datetime import datetime, timedelta
        
        total_events = db.query(Task).filter(
            Task.user_id == user_id,
            Task.task_meta["calendar_synced"].astext == "true"
        ).count()
        
        upcoming_events = db.query(Task).filter(
            Task.user_id == user_id,
            Task.isCompleted == False,
            Task.dueDate.isnot(None),
            Task.dueDate >= datetime.now(),
            Task.task_meta["calendar_synced"].astext == "true"
        ).count()
        
        # Get last sync time
        last_sync = None
        if config and config.last_sync:
            last_sync = config.last_sync.isoformat()
        
        db.close()
        
        return CalendarStatus(
            enabled=enabled,
            last_sync=last_sync,
            total_events=total_events,
            upcoming_events=upcoming_events
        )
        
    except Exception as e:
        logger.error(f"Error getting calendar status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting status: {str(e)}")


@router.post("/calendar/sync/task/{task_id}")
async def sync_task_to_calendar(task_id: int, user_id: int):
    """Sync a specific task to Google Calendar"""
    try:
        db = get_db_session()
        
        # Get task
        task = db.query(Task).filter(
            Task.id == task_id,
            Task.user_id == user_id
        ).first()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # Sync to calendar
        calendar_service = get_calendar_service()
        event_id = calendar_service.sync_task_to_calendar(task, user_id)
        
        db.close()
        
        if event_id:
            return {
                "message": "Task synced to calendar successfully",
                "task_id": task_id,
                "event_id": event_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to sync task to calendar")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error syncing task to calendar: {e}")
        raise HTTPException(status_code=500, detail=f"Error syncing task: {str(e)}")


@router.delete("/calendar/unsync/task/{task_id}")
async def unsync_task_from_calendar(task_id: int, user_id: int):
    """Remove a task from Google Calendar"""
    try:
        db = get_db_session()
        
        # Get task
        task = db.query(Task).filter(
            Task.id == task_id,
            Task.user_id == user_id
        ).first()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # Unsync from calendar
        calendar_service = get_calendar_service()
        success = calendar_service.unsync_task_from_calendar(task, user_id)
        
        db.close()
        
        if success:
            return {
                "message": "Task removed from calendar successfully",
                "task_id": task_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to remove task from calendar")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error unsyncing task from calendar: {e}")
        raise HTTPException(status_code=500, detail=f"Error unsyncing task: {str(e)}")


@router.get("/calendar/events")
async def get_calendar_events(
    user_id: int,
    days_ahead: int = Query(30, ge=1, le=365)
):
    """Get upcoming calendar events"""
    try:
        db = get_db_session()
        
        # Check if calendar is enabled
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == "google_calendar",
            ConnectorConfig.enabled == True
        ).first()
        
        if not config:
            raise HTTPException(status_code=400, detail="Calendar not enabled")
        
        access_token = config.config_data.get("access_token")
        if not access_token:
            raise HTTPException(status_code=400, detail="Calendar not properly configured")
        
        # Get events from Google Calendar
        calendar_service = get_calendar_service()
        events = calendar_service.get_calendar_events(access_token, days_ahead)
        
        db.close()
        
        return {
            "events": events,
            "total": len(events)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting calendar events: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting events: {str(e)}")


# Notification endpoints

@router.get("/notifications/upcoming")
async def get_upcoming_notifications(
    user_id: int,
    hours_ahead: int = Query(24, ge=1, le=168)
):
    """Get upcoming notifications for a user"""
    try:
        notification_service = get_notification_service()
        notifications = notification_service.get_upcoming_notifications(user_id, hours_ahead)
        
        return {
            "notifications": notifications,
            "total": len(notifications)
        }
        
    except Exception as e:
        logger.error(f"Error getting upcoming notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting notifications: {str(e)}")


@router.post("/notifications/schedule/task/{task_id}")
async def schedule_task_notification(task_id: int, user_id: int):
    """Schedule notifications for a task"""
    try:
        db = get_db_session()
        
        # Get task
        task = db.query(Task).filter(
            Task.id == task_id,
            Task.user_id == user_id
        ).first()
        
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        
        # Schedule notification
        notification_service = get_notification_service()
        success = notification_service.schedule_task_notification(task, user_id)
        
        db.close()
        
        if success:
            return {
                "message": "Task notifications scheduled successfully",
                "task_id": task_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to schedule notifications")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error scheduling task notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Error scheduling notifications: {str(e)}")


@router.delete("/notifications/cancel/task/{task_id}")
async def cancel_task_notification(task_id: int, user_id: int):
    """Cancel notifications for a task"""
    try:
        notification_service = get_notification_service()
        success = notification_service.cancel_task_notification(task_id, user_id)
        
        if success:
            return {
                "message": "Task notifications cancelled successfully",
                "task_id": task_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to cancel notifications")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling task notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Error cancelling notifications: {str(e)}")


@router.post("/notifications/send")
async def send_immediate_notification(
    user_id: int,
    title: str,
    body: str,
    priority: str = "normal"
):
    """Send an immediate notification"""
    try:
        notification_service = get_notification_service()
        success = notification_service.send_immediate_notification(user_id, title, body, priority)
        
        if success:
            return {
                "message": "Notification sent successfully",
                "user_id": user_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to send notification")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error sending immediate notification: {e}")
        raise HTTPException(status_code=500, detail=f"Error sending notification: {str(e)}")


@router.get("/notifications/settings")
async def get_notification_settings(user_id: int):
    """Get user's notification settings"""
    try:
        notification_service = get_notification_service()
        settings = notification_service.get_notification_settings(user_id)
        
        return {
            "settings": settings,
            "user_id": user_id
        }
        
    except Exception as e:
        logger.error(f"Error getting notification settings: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting settings: {str(e)}")


@router.put("/notifications/settings")
async def update_notification_settings(
    user_id: int,
    settings: NotificationSettings
):
    """Update user's notification settings"""
    try:
        notification_service = get_notification_service()
        success = notification_service.update_notification_settings(user_id, settings.dict())
        
        if success:
            return {
                "message": "Notification settings updated successfully",
                "user_id": user_id
            }
        else:
            raise HTTPException(status_code=500, detail="Failed to update settings")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating notification settings: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating settings: {str(e)}")


