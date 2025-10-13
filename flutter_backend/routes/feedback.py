"""
Feedback endpoints for user interaction and personalization
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from sqlalchemy.orm import Session
from datetime import datetime

from storage.db import get_db
from storage.models import User, FeedItem, Feedback, UserProfile
from services.ranking import get_ranking_service

router = APIRouter()

class FeedbackRequest(BaseModel):
    feed_item_id: int
    feedback_type: str  # like, dislike, complete, snooze
    feedback_value: Optional[float] = None
    context: Optional[Dict[str, Any]] = None

class FeedbackResponse(BaseModel):
    success: bool
    message: str
    updated_ranking: Optional[bool] = None

class UserProfileResponse(BaseModel):
    user_id: int
    important_keywords: List[str]
    important_contacts: List[str]
    preferred_sources: List[str]
    local_only_mode: bool
    allow_llm_processing: bool
    ranking_weights: Dict[str, float]
    feedback_count: int

class UpdateProfileRequest(BaseModel):
    important_keywords: Optional[List[str]] = None
    important_contacts: Optional[List[str]] = None
    preferred_sources: Optional[List[str]] = None
    local_only_mode: Optional[bool] = None
    allow_llm_processing: Optional[bool] = None
    ranking_weights: Optional[Dict[str, float]] = None

@router.post("/feedback", response_model=FeedbackResponse)
async def submit_feedback(
    request: FeedbackRequest,
    db: Session = Depends(get_db)
    # TODO: Add user authentication when implemented
    # current_user: User = Depends(get_current_user)
):
    """
    Submit user feedback on a feed item for personalization
    
    Example request:
    {
        "feed_item_id": 123,
        "feedback_type": "like",
        "feedback_value": 1.0,
        "context": {"source": "mobile_app"}
    }
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Validate feedback type
        valid_feedback_types = ["like", "dislike", "complete", "snooze", "dismiss"]
        if request.feedback_type not in valid_feedback_types:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid feedback_type. Must be one of: {valid_feedback_types}"
            )
        
        # Validate feedback value
        if request.feedback_value is not None:
            if not (0.0 <= request.feedback_value <= 1.0):
                raise HTTPException(
                    status_code=400,
                    detail="feedback_value must be between 0.0 and 1.0"
                )
        
        # Get feed item
        feed_item = db.query(FeedItem).filter(
            FeedItem.id == request.feed_item_id,
            FeedItem.user_id == user_id
        ).first()
        
        if not feed_item:
            raise HTTPException(status_code=404, detail="Feed item not found")
        
        # Create feedback record
        feedback = Feedback(
            user_id=user_id,
            feed_item_id=request.feed_item_id,
            feedback_type=request.feedback_type,
            feedback_value=request.feedback_value,
            context=request.context or {}
        )
        
        db.add(feedback)
        db.commit()
        
        # Update user profile for learning
        ranking_service = get_ranking_service()
        ranking_service.update_user_profile_from_feedback(
            user_id=user_id,
            feed_item=feed_item,
            feedback_type=request.feedback_type,
            feedback_value=request.feedback_value or 0.5,
            db=db
        )
        
        logger.info(f"User {user_id} submitted {request.feedback_type} feedback for item {request.feed_item_id}")
        
        return FeedbackResponse(
            success=True,
            message=f"Feedback recorded successfully",
            updated_ranking=True
        )
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to submit feedback: {str(e)}")

@router.get("/feedback/history")
async def get_feedback_history(
    limit: int = 50,
    feedback_type: Optional[str] = None,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get user's feedback history
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Build query
        query = db.query(Feedback).filter(Feedback.user_id == user_id)
        
        if feedback_type:
            query = query.filter(Feedback.feedback_type == feedback_type)
        
        # Get recent feedback
        feedback_items = query.order_by(Feedback.created_at.desc()).limit(limit).all()
        
        # Format response
        history = []
        for feedback in feedback_items:
            history.append({
                "id": feedback.id,
                "feed_item_id": feedback.feed_item_id,
                "feedback_type": feedback.feedback_type,
                "feedback_value": feedback.feedback_value,
                "context": feedback.context,
                "created_at": feedback.created_at.isoformat()
            })
        
        return {
            "feedback_history": history,
            "total_count": len(history)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get feedback history: {str(e)}")

@router.get("/profile", response_model=UserProfileResponse)
async def get_user_profile(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Get user's personalization profile
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get or create user profile
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
        if not user_profile:
            user_profile = UserProfile(user_id=user_id)
            db.add(user_profile)
            db.commit()
        
        # Get feedback count
        feedback_count = db.query(Feedback).filter(Feedback.user_id == user_id).count()
        
        return UserProfileResponse(
            user_id=user_id,
            important_keywords=user_profile.important_keywords or [],
            important_contacts=user_profile.important_contacts or [],
            preferred_sources=user_profile.preferred_sources or [],
            local_only_mode=user_profile.local_only_mode,
            allow_llm_processing=user_profile.allow_llm_processing,
            ranking_weights=user_profile.ranking_weights or {},
            feedback_count=feedback_count
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get user profile: {str(e)}")

@router.put("/profile", response_model=FeedbackResponse)
async def update_user_profile(
    request: UpdateProfileRequest,
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Update user's personalization profile
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get or create user profile
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
        if not user_profile:
            user_profile = UserProfile(user_id=user_id)
            db.add(user_profile)
        
        # Update fields if provided
        if request.important_keywords is not None:
            user_profile.important_keywords = request.important_keywords[:50]  # Limit to 50
        
        if request.important_contacts is not None:
            user_profile.important_contacts = request.important_contacts[:20]  # Limit to 20
        
        if request.preferred_sources is not None:
            user_profile.preferred_sources = request.preferred_sources
        
        if request.local_only_mode is not None:
            user_profile.local_only_mode = request.local_only_mode
        
        if request.allow_llm_processing is not None:
            user_profile.allow_llm_processing = request.allow_llm_processing
        
        if request.ranking_weights is not None:
            # Validate ranking weights
            valid_weights = ["semantic_relevance", "sender_importance", "urgency", "recency", "user_feedback"]
            for key in request.ranking_weights:
                if key not in valid_weights:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Invalid ranking weight: {key}. Must be one of: {valid_weights}"
                    )
            user_profile.ranking_weights = request.ranking_weights
        
        db.commit()
        
        return FeedbackResponse(
            success=True,
            message="User profile updated successfully"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to update user profile: {str(e)}")

@router.delete("/profile/reset")
async def reset_user_profile(
    db: Session = Depends(get_db)
    # TODO: Add user authentication
    # current_user: User = Depends(get_current_user)
):
    """
    Reset user's personalization profile to defaults
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get user profile
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
        if user_profile:
            # Reset to defaults
            user_profile.important_keywords = []
            user_profile.important_contacts = []
            user_profile.preferred_sources = []
            user_profile.feedback_history = []
            user_profile.ranking_weights = {}
            
            db.commit()
        
        return FeedbackResponse(
            success=True,
            message="User profile reset to defaults"
        )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Failed to reset user profile: {str(e)}")

@router.get("/ranking/weights")
async def get_ranking_weights():
    """
    Get default ranking weights and their descriptions
    """
    return {
        "default_weights": {
            "semantic_relevance": {
                "weight": 0.4,
                "description": "How relevant the content is to your interests"
            },
            "sender_importance": {
                "weight": 0.25,
                "description": "Importance of the sender/contact"
            },
            "urgency": {
                "weight": 0.15,
                "description": "Time sensitivity and urgency of the content"
            },
            "recency": {
                "weight": 0.15,
                "description": "How recent the content is"
            },
            "user_feedback": {
                "weight": 0.05,
                "description": "Based on your historical feedback"
            }
        },
        "note": "Weights should sum to 1.0 for optimal ranking"
    }

# Import logger
import logging
logger = logging.getLogger(__name__)


