"""
Events API Routes

Provides endpoints for managing AI-extracted calendar events from notifications.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime
import logging

from app.core.nosql import store

logger = logging.getLogger(__name__)

router = APIRouter()


class CalendarEvent(BaseModel):
    """Calendar event model"""
    id: Optional[int] = None
    title: str
    start_time: Optional[str] = None  # ISO format datetime
    duration_minutes: int = 60
    location: Optional[str] = None
    description: Optional[str] = None
    source: str = "ai_extracted"  # ai_extracted, manual, whatsapp, google_calendar, etc.
    source_id: Optional[str] = None  # ID of the feed item it came from
    user_id: int = 1
    is_ai_detected: bool = True
    created_at: Optional[float] = None
    deleted: bool = False


@router.get("/events")
async def get_events(
    user_id: int = 1,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None
):
    """Get all events for a user, optionally filtered by date range"""
    try:
        events = store.events.search(lambda e: e.get("user_id") == user_id and not e.get("deleted"))
        
        # Filter by date range if specified
        if start_date:
            events = [e for e in events if e.get("start_time") and e.get("start_time") >= start_date]
        if end_date:
            events = [e for e in events if e.get("start_time") and e.get("start_time") <= end_date]
        
        # Sort by start_time
        events.sort(key=lambda e: e.get("start_time") or "9999-12-31")
        
        return {"events": events, "total": len(events)}
        
    except Exception as e:
        logger.error(f"Error getting events: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting events: {str(e)}")


@router.post("/events")
async def create_event(event: CalendarEvent):
    """Create a new event"""
    try:
        event_dict = event.dict()
        event_dict["created_at"] = datetime.now().timestamp()
        event_dict["deleted"] = False
        
        event_id = store.insert("events", event_dict)
        event_dict["id"] = event_id
        
        return {"message": "Event created", "event": event_dict}
        
    except Exception as e:
        logger.error(f"Error creating event: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating event: {str(e)}")


@router.put("/events/{event_id}")
async def update_event(event_id: int, event: CalendarEvent):
    """Update an event"""
    try:
        events = store.events.search(lambda e: e.get("id") == event_id)
        if not events:
            raise HTTPException(status_code=404, detail="Event not found")
        
        event_dict = event.dict()
        event_dict["id"] = event_id
        
        store.upsert("events", event_dict, key="id")
        
        return {"message": "Event updated", "event": event_dict}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating event: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating event: {str(e)}")


@router.delete("/events/{event_id}")
async def delete_event(event_id: int):
    """Soft delete an event"""
    try:
        events = store.events.search(lambda e: e.get("id") == event_id)
        if not events:
            raise HTTPException(status_code=404, detail="Event not found")
        
        event = dict(events[0])
        event["deleted"] = True
        store.upsert("events", event, key="id")
        
        return {"message": "Event deleted"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting event: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting event: {str(e)}")
