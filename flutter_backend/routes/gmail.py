"""
Gmail connector API endpoints
Handles OAuth2 authentication and email ingestion
"""

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from storage.db import get_db
from storage.models import User, FeedItem, ConnectorConfig, SourceType
from services.gmail_connector import get_gmail_connector

router = APIRouter()

class AuthUrlResponse(BaseModel):
    auth_url: str
    state: str

class OAuthCallbackRequest(BaseModel):
    code: str
    state: str

class FetchEmailsRequest(BaseModel):
    max_results: Optional[int] = 50
    since_hours: Optional[int] = 24

class GmailStatusResponse(BaseModel):
    connected: bool
    email: Optional[str] = None
    last_sync: Optional[str] = None
    total_emails: int = 0

@router.get("/auth/gmail/url", response_model=AuthUrlResponse)
async def get_gmail_auth_url(
    user_id: int = Query(..., description="User ID for OAuth state"),
    db: Session = Depends(get_db)
    # TODO: Add user authentication when implemented
    # current_user: User = Depends(get_current_user)
):
    """
    Get Gmail OAuth2 authorization URL
    
    Example response:
    {
        "auth_url": "https://accounts.google.com/o/oauth2/auth?...",
        "state": "123"
    }
    """
    try:
        gmail_connector = get_gmail_connector()
        
        auth_url = gmail_connector.get_auth_url(user_id)
        if not auth_url:
            raise HTTPException(
                status_code=500,
                detail="Failed to generate Gmail authorization URL. Check Gmail OAuth configuration."
            )
        
        return AuthUrlResponse(
            auth_url=auth_url,
            state=str(user_id)
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get auth URL: {str(e)}")

@router.post("/auth/gmail/callback")
async def handle_gmail_oauth_callback(
    request: OAuthCallbackRequest,
    db: Session = Depends(get_db)
):
    """
    Handle Gmail OAuth2 callback
    
    Example request:
    {
        "code": "4/0AX4XfWh...",
        "state": "123"
    }
    """
    try:
        gmail_connector = get_gmail_connector()
        
        success = gmail_connector.handle_oauth_callback(request.code, request.state)
        if not success:
            raise HTTPException(
                status_code=400,
                detail="Failed to complete Gmail OAuth flow"
            )
        
        return {
            "success": True,
            "message": "Gmail authentication completed successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OAuth callback failed: {str(e)}")

@router.get("/gmail/status", response_model=GmailStatusResponse)
async def get_gmail_status(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get Gmail connection status for user
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Check if Gmail is connected
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.GMAIL,
            ConnectorConfig.is_enabled == True
        ).first()
        
        if not config or not config.access_token:
            return GmailStatusResponse(connected=False)
        
        # Get email and last sync info
        email = config.config_data.get("email") if config.config_data else None
        last_sync = config.last_sync_at.isoformat() if config.last_sync_at else None
        
        # Count total emails
        total_emails = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.GMAIL
        ).count()
        
        return GmailStatusResponse(
            connected=True,
            email=email,
            last_sync=last_sync,
            total_emails=total_emails
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get Gmail status: {str(e)}")

@router.post("/gmail/fetch")
async def fetch_gmail_emails(
    request: FetchEmailsRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Fetch emails from Gmail and process them into feed items
    Runs in background for better performance
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Check if Gmail is connected
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.GMAIL,
            ConnectorConfig.is_enabled == True
        ).first()
        
        if not config or not config.access_token:
            raise HTTPException(
                status_code=400,
                detail="Gmail not connected. Please authenticate first."
            )
        
        # Calculate since date
        since_date = None
        if request.since_hours:
            since_date = datetime.now() - timedelta(hours=request.since_hours)
        
        # Add background task
        background_tasks.add_task(
            _fetch_and_process_emails,
            user_id=user_id,
            max_results=request.max_results or 50,
            since_date=since_date
        )
        
        return {
            "success": True,
            "message": "Gmail fetch started in background",
            "max_results": request.max_results or 50,
            "since_hours": request.since_hours
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to start Gmail fetch: {str(e)}")

@router.get("/gmail/emails")
async def get_gmail_emails(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get processed Gmail emails from feed
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get Gmail feed items
        feed_items = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.source == SourceType.GMAIL
        ).order_by(FeedItem.date.desc()).offset(offset).limit(limit).all()
        
        # Format response
        emails = []
        for item in feed_items:
            emails.append({
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
                "sender": item.metadata.get("sender") if item.metadata else None,
                "sender_email": item.metadata.get("sender_email") if item.metadata else None
            })
        
        return {
            "emails": emails,
            "total_count": len(emails),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get Gmail emails: {str(e)}")

@router.delete("/gmail/disconnect")
async def disconnect_gmail(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Disconnect Gmail and remove stored credentials
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Find Gmail config
        config = db.query(ConnectorConfig).filter(
            ConnectorConfig.user_id == user_id,
            ConnectorConfig.connector_type == SourceType.GMAIL
        ).first()
        
        if config:
            # Clear credentials
            config.access_token = None
            config.refresh_token = None
            config.token_expires_at = None
            config.is_enabled = False
            config.config_data = {}
            
            db.commit()
            
            return {
                "success": True,
                "message": "Gmail disconnected successfully"
            }
        else:
            return {
                "success": True,
                "message": "Gmail was not connected"
            }
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to disconnect Gmail: {str(e)}")

async def _fetch_and_process_emails(user_id: int, max_results: int, since_date: Optional[datetime]):
    """
    Background task to fetch and process Gmail emails
    """
    try:
        gmail_connector = get_gmail_connector()
        
        # Fetch emails from Gmail
        emails = gmail_connector.fetch_emails(
            user_id=user_id,
            max_results=max_results,
            since_date=since_date
        )
        
        if not emails:
            logger.info(f"No new Gmail emails found for user {user_id}")
            return
        
        # Process emails into feed items
        feed_items = gmail_connector.process_emails_to_feed_items(user_id, emails)
        
        # Save to database
        db = get_db_session()
        try:
            # Check for existing items to avoid duplicates
            existing_origin_ids = set()
            for item in feed_items:
                existing = db.query(FeedItem).filter(
                    FeedItem.user_id == user_id,
                    FeedItem.origin_id == item.origin_id,
                    FeedItem.source == SourceType.GMAIL
                ).first()
                
                if not existing:
                    db.add(item)
                    existing_origin_ids.add(item.origin_id)
            
            # Update last sync time
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user_id,
                ConnectorConfig.connector_type == SourceType.GMAIL
            ).first()
            
            if config:
                config.last_sync_at = datetime.now()
            
            db.commit()
            
            logger.info(f"Processed {len(existing_origin_ids)} new Gmail emails for user {user_id}")
            
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Background Gmail processing failed for user {user_id}: {e}")

# Import logger
import logging
logger = logging.getLogger(__name__)


