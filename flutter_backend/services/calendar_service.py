"""
Calendar Service

Handles Google Calendar integration for task synchronization and notifications.
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import json

from sqlalchemy.orm import Session
from sqlalchemy import and_

from storage.models import Task, User, ConnectorConfig
from storage.db import get_db_session
from ml.llm_adapter import get_llm_adapter
from utils.string_utils import clean_text

logger = logging.getLogger(__name__)


class CalendarService:
    """Calendar service for task synchronization"""
    
    def __init__(self):
        self.llm_adapter = get_llm_adapter()
    
    def get_calendar_auth_url(self, user_id: int, redirect_uri: str) -> str:
        """
        Generate Google Calendar OAuth URL
        
        Args:
            user_id: User ID
            redirect_uri: Redirect URI after authorization
            
        Returns:
            Google Calendar OAuth URL
        """
        import os
        
        client_id = os.getenv("GOOGLE_CALENDAR_CLIENT_ID")
        if not client_id:
            raise ValueError("GOOGLE_CALENDAR_CLIENT_ID not configured")
        
        # Google Calendar API scopes
        scopes = [
            "https://www.googleapis.com/auth/calendar",
            "https://www.googleapis.com/auth/calendar.events"
        ]
        
        params = {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scope": " ".join(scopes),
            "response_type": "code",
            "access_type": "offline",
            "prompt": "consent",
            "state": str(user_id)
        }
        
        query_string = "&".join([f"{k}={v}" for k, v in params.items()])
        return f"https://accounts.google.com/o/oauth2/v2/auth?{query_string}"
    
    def exchange_code_for_token(self, code: str, redirect_uri: str) -> Dict[str, Any]:
        """
        Exchange authorization code for access token
        
        Args:
            code: Authorization code from Google
            redirect_uri: Redirect URI used in auth
            
        Returns:
            Token response with access_token and refresh_token
        """
        import os
        import requests
        
        client_id = os.getenv("GOOGLE_CALENDAR_CLIENT_ID")
        client_secret = os.getenv("GOOGLE_CALENDAR_CLIENT_SECRET")
        
        if not client_id or not client_secret:
            raise ValueError("Google Calendar credentials not configured")
        
        url = "https://oauth2.googleapis.com/token"
        
        data = {
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            
            return response.json()
            
        except requests.RequestException as e:
            logger.error(f"Error exchanging Google Calendar code for token: {e}")
            raise
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, Any]:
        """Refresh Google Calendar access token"""
        import os
        import requests
        
        client_id = os.getenv("GOOGLE_CALENDAR_CLIENT_ID")
        client_secret = os.getenv("GOOGLE_CALENDAR_CLIENT_SECRET")
        
        url = "https://oauth2.googleapis.com/token"
        
        data = {
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token"
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            
            return response.json()
            
        except requests.RequestException as e:
            logger.error(f"Error refreshing Google Calendar token: {e}")
            raise
    
    def create_calendar_event(self, task: Task, access_token: str) -> Optional[str]:
        """
        Create a calendar event from a task
        
        Args:
            task: Task object
            access_token: Google Calendar access token
            
        Returns:
            Event ID or None
        """
        import requests
        
        # Prepare event data
        event_data = {
            "summary": task.title,
            "description": task.description or "",
            "start": {
                "dateTime": task.dueDate.isoformat() if task.dueDate else datetime.now().isoformat(),
                "timeZone": "UTC"
            },
            "end": {
                "dateTime": (task.dueDate + timedelta(hours=1)).isoformat() if task.dueDate else (datetime.now() + timedelta(hours=1)).isoformat(),
                "timeZone": "UTC"
            },
            "reminders": {
                "useDefault": False,
                "overrides": [
                    {"method": "popup", "minutes": 30},
                    {"method": "popup", "minutes": 10}
                ]
            }
        }
        
        # Add priority-based color
        if task.priority == "high":
            event_data["colorId"] = "11"  # Red
        elif task.priority == "medium":
            event_data["colorId"] = "5"   # Yellow
        else:
            event_data["colorId"] = "10"  # Green
        
        url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(url, headers=headers, json=event_data)
            response.raise_for_status()
            
            result = response.json()
            return result.get("id")
            
        except requests.RequestException as e:
            logger.error(f"Error creating calendar event: {e}")
            return None
    
    def update_calendar_event(self, event_id: str, task: Task, access_token: str) -> bool:
        """
        Update an existing calendar event
        
        Args:
            event_id: Calendar event ID
            task: Updated task object
            access_token: Google Calendar access token
            
        Returns:
            Success status
        """
        import requests
        
        # Prepare event data
        event_data = {
            "summary": task.title,
            "description": task.description or "",
            "start": {
                "dateTime": task.dueDate.isoformat() if task.dueDate else datetime.now().isoformat(),
                "timeZone": "UTC"
            },
            "end": {
                "dateTime": (task.dueDate + timedelta(hours=1)).isoformat() if task.dueDate else (datetime.now() + timedelta(hours=1)).isoformat(),
                "timeZone": "UTC"
            }
        }
        
        # Add priority-based color
        if task.priority == "high":
            event_data["colorId"] = "11"  # Red
        elif task.priority == "medium":
            event_data["colorId"] = "5"   # Yellow
        else:
            event_data["colorId"] = "10"  # Green
        
        url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{event_id}"
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.put(url, headers=headers, json=event_data)
            response.raise_for_status()
            
            return True
            
        except requests.RequestException as e:
            logger.error(f"Error updating calendar event: {e}")
            return False
    
    def delete_calendar_event(self, event_id: str, access_token: str) -> bool:
        """
        Delete a calendar event
        
        Args:
            event_id: Calendar event ID
            access_token: Google Calendar access token
            
        Returns:
            Success status
        """
        import requests
        
        url = f"https://www.googleapis.com/calendar/v3/calendars/primary/events/{event_id}"
        headers = {
            "Authorization": f"Bearer {access_token}"
        }
        
        try:
            response = requests.delete(url, headers=headers)
            response.raise_for_status()
            
            return True
            
        except requests.RequestException as e:
            logger.error(f"Error deleting calendar event: {e}")
            return False
    
    def get_calendar_events(self, access_token: str, days_ahead: int = 30) -> List[Dict[str, Any]]:
        """
        Get calendar events for the next N days
        
        Args:
            access_token: Google Calendar access token
            days_ahead: Number of days to look ahead
            
        Returns:
            List of calendar events
        """
        import requests
        
        now = datetime.now()
        time_max = now + timedelta(days=days_ahead)
        
        url = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        params = {
            "timeMin": now.isoformat() + "Z",
            "timeMax": time_max.isoformat() + "Z",
            "singleEvents": True,
            "orderBy": "startTime"
        }
        headers = {
            "Authorization": f"Bearer {access_token}"
        }
        
        try:
            response = requests.get(url, headers=headers, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("items", [])
            
        except requests.RequestException as e:
            logger.error(f"Error getting calendar events: {e}")
            return []
    
    def sync_task_to_calendar(self, task: Task, user_id: int) -> Optional[str]:
        """
        Sync a task to Google Calendar
        
        Args:
            task: Task to sync
            user_id: User ID
            
        Returns:
            Calendar event ID or None
        """
        try:
            db = get_db_session()
            
            # Get user's calendar config
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == "google_calendar",
                ConnectorConfig.enabled == True
            ).first()
            
            if not config:
                logger.warning(f"Google Calendar not configured for user {user_id}")
                return None
            
            access_token = config.config_data.get("access_token")
            refresh_token = config.config_data.get("refresh_token")
            
            if not access_token:
                logger.warning(f"No access token for user {user_id}")
                return None
            
            # Try to create event
            event_id = self.create_calendar_event(task, access_token)
            
            if event_id:
                # Store event ID in task metadata
                task.task_meta = task.task_meta or {}
                task.task_meta["calendar_event_id"] = event_id
                task.task_meta["calendar_synced"] = True
                task.task_meta["calendar_sync_date"] = datetime.now().isoformat()
                
                db.commit()
                logger.info(f"Task {task.id} synced to calendar as event {event_id}")
            else:
                # Try to refresh token and retry
                if refresh_token:
                    try:
                        token_data = self.refresh_access_token(refresh_token)
                        new_access_token = token_data.get("access_token")
                        
                        if new_access_token:
                            # Update stored token
                            config.config_data["access_token"] = new_access_token
                            db.commit()
                            
                            # Retry creating event
                            event_id = self.create_calendar_event(task, new_access_token)
                            
                            if event_id:
                                task.task_meta = task.task_meta or {}
                                task.task_meta["calendar_event_id"] = event_id
                                task.task_meta["calendar_synced"] = True
                                task.task_meta["calendar_sync_date"] = datetime.now().isoformat()
                                db.commit()
                                logger.info(f"Task {task.id} synced to calendar as event {event_id} (after token refresh)")
                    except Exception as e:
                        logger.error(f"Error refreshing token for user {user_id}: {e}")
            
            db.close()
            return event_id
            
        except Exception as e:
            logger.error(f"Error syncing task {task.id} to calendar: {e}")
            return None
    
    def unsync_task_from_calendar(self, task: Task, user_id: int) -> bool:
        """
        Remove a task from Google Calendar
        
        Args:
            task: Task to unsync
            user_id: User ID
            
        Returns:
            Success status
        """
        try:
            db = get_db_session()
            
            # Get user's calendar config
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == "google_calendar",
                ConnectorConfig.enabled == True
            ).first()
            
            if not config:
                logger.warning(f"Google Calendar not configured for user {user_id}")
                return False
            
            access_token = config.config_data.get("access_token")
            event_id = task.task_meta.get("calendar_event_id") if task.task_meta else None
            
            if not access_token or not event_id:
                logger.warning(f"No access token or event ID for task {task.id}")
                return False
            
            # Delete event from calendar
            success = self.delete_calendar_event(event_id, access_token)
            
            if success:
                # Update task metadata
                task.task_meta = task.task_meta or {}
                task.task_meta["calendar_synced"] = False
                task.task_meta["calendar_event_id"] = None
                task.task_meta["calendar_unsync_date"] = datetime.now().isoformat()
                
                db.commit()
                logger.info(f"Task {task.id} removed from calendar")
            else:
                logger.error(f"Failed to delete calendar event for task {task.id}")
            
            db.close()
            return success
            
        except Exception as e:
            logger.error(f"Error unsyncing task {task.id} from calendar: {e}")
            return False


def get_calendar_service() -> CalendarService:
    """Get calendar service instance"""
    return CalendarService()


