"""
Ranking and personalization service
Implements weighted scoring with user feedback learning
"""

import logging
import json
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from storage.models import FeedItem, User, UserProfile, Feedback, SourceType, PriorityLevel
from nlp.embeddings import get_embeddings_pipeline

logger = logging.getLogger(__name__)

class RankingService:
    """
    Ranking service with personalization and feedback learning
    Uses weighted scoring with user-specific adjustments
    """
    
    def __init__(self):
        self.embeddings_pipeline = get_embeddings_pipeline()
        
        # Default ranking weights (can be overridden per user)
        self.default_weights = {
            "semantic_relevance": 0.4,    # How relevant to user's interests
            "sender_importance": 0.25,    # Importance of sender/contact
            "urgency": 0.15,              # Time sensitivity
            "recency": 0.15,              # How recent the content is
            "user_feedback": 0.05         # Historical user feedback
        }
        
        # Urgency keywords and their weights
        self.urgency_keywords = {
            "urgent": 1.0,
            "asap": 0.9,
            "immediately": 0.9,
            "deadline": 0.8,
            "due": 0.7,
            "submit": 0.6,
            "complete": 0.5,
            "attend": 0.5,
            "meeting": 0.4
        }
    
    def rank_feed_items(self, feed_items: List[FeedItem], user_id: int, 
                       db: Session, limit: int = 50) -> List[Tuple[FeedItem, float, Dict[str, float]]]:
        """
        Rank feed items for a user
        Returns list of (feed_item, final_score, score_breakdown) tuples
        """
        try:
            # Get user profile for personalization
            user_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not user_profile:
                # Create default profile
                user_profile = UserProfile(user_id=user_id)
                db.add(user_profile)
                db.commit()
            
            # Get user-specific weights
            weights = user_profile.ranking_weights or self.default_weights.copy()
            
            # Get user's important keywords and contacts
            important_keywords = user_profile.important_keywords or []
            important_contacts = user_profile.important_contacts or []
            
            # Calculate scores for each item
            ranked_items = []
            for item in feed_items:
                score_breakdown = self._calculate_score_breakdown(
                    item, user_profile, important_keywords, important_contacts, db
                )
                
                # Calculate weighted final score
                final_score = sum(
                    score_breakdown[component] * weights[component]
                    for component in weights
                )
                
                ranked_items.append((item, final_score, score_breakdown))
            
            # Sort by final score (descending)
            ranked_items.sort(key=lambda x: x[1], reverse=True)
            
            logger.debug(f"Ranked {len(ranked_items)} items for user {user_id}")
            return ranked_items[:limit]
            
        except Exception as e:
            logger.error(f"Ranking failed for user {user_id}: {e}")
            # Return items with default scores
            return [(item, 0.5, {}) for item in feed_items[:limit]]
    
    def _calculate_score_breakdown(self, item: FeedItem, user_profile: UserProfile,
                                 important_keywords: List[str], important_contacts: List[str],
                                 db: Session) -> Dict[str, float]:
        """Calculate individual score components for a feed item"""
        breakdown = {}
        
        # 1. Semantic relevance (0.0 to 1.0)
        breakdown["semantic_relevance"] = self._calculate_semantic_relevance(
            item, important_keywords, user_profile
        )
        
        # 2. Sender importance (0.0 to 1.0)
        breakdown["sender_importance"] = self._calculate_sender_importance(
            item, important_contacts
        )
        
        # 3. Urgency (0.0 to 1.0)
        breakdown["urgency"] = self._calculate_urgency(item)
        
        # 4. Recency (0.0 to 1.0)
        breakdown["recency"] = self._calculate_recency(item)
        
        # 5. User feedback (0.0 to 1.0)
        breakdown["user_feedback"] = self._calculate_feedback_score(item, user_profile.user_id, db)
        
        return breakdown
    
    def _calculate_semantic_relevance(self, item: FeedItem, important_keywords: List[str],
                                    user_profile: UserProfile) -> float:
        """Calculate semantic relevance to user's interests"""
        if not important_keywords:
            return 0.5  # Neutral score if no keywords
        
        try:
            # Get user's interest embedding (average of keyword embeddings)
            keyword_embeddings = []
            for keyword in important_keywords:
                embedding = self.embeddings_pipeline.embed_text(keyword)
                if embedding:
                    keyword_embeddings.append(embedding)
            
            if not keyword_embeddings:
                return 0.5
            
            # Calculate average embedding for user interests
            import numpy as np
            user_interest_embedding = np.mean(keyword_embeddings, axis=0).tolist()
            
            # Get item embedding
            item_text = f"{item.title} {item.summary or ''}"
            item_embedding = self.embeddings_pipeline.embed_text(item_text)
            
            if not item_embedding:
                return 0.5
            
            # Calculate similarity
            similarity = self.embeddings_pipeline.similarity(
                user_interest_embedding, item_embedding
            )
            
            # Convert similarity (-1 to 1) to relevance score (0 to 1)
            return max(0.0, (similarity + 1) / 2)
            
        except Exception as e:
            logger.error(f"Semantic relevance calculation failed: {e}")
            return 0.5
    
    def _calculate_sender_importance(self, item: FeedItem, important_contacts: List[str]) -> float:
        """Calculate importance based on sender/contact"""
        if not important_contacts:
            return 0.5
        
        # Check if sender is in important contacts
        sender = item.metadata.get("sender", "").lower()
        sender_email = item.metadata.get("sender_email", "").lower()
        
        for contact in important_contacts:
            contact_lower = contact.lower()
            if (contact_lower in sender or contact_lower in sender_email or
                sender in contact_lower or sender_email in contact_lower):
                return 1.0  # High importance for important contacts
        
        return 0.3  # Lower importance for unknown contacts
    
    def _calculate_urgency(self, item: FeedItem) -> float:
        """Calculate urgency based on content and metadata"""
        urgency_score = 0.0
        
        # Check for urgency keywords in title and text
        text_to_check = f"{item.title} {item.summary or ''} {item.text or ''}".lower()
        
        for keyword, weight in self.urgency_keywords.items():
            if keyword in text_to_check:
                urgency_score = max(urgency_score, weight)
        
        # Check for due dates in extracted tasks
        if item.extracted_tasks:
            for task in item.extracted_tasks:
                if task.get("due_date"):
                    # Calculate urgency based on due date proximity
                    try:
                        due_date = datetime.fromisoformat(task["due_date"].replace("Z", "+00:00"))
                        days_until_due = (due_date - datetime.now()).days
                        
                        if days_until_due <= 1:
                            urgency_score = max(urgency_score, 0.9)
                        elif days_until_due <= 3:
                            urgency_score = max(urgency_score, 0.7)
                        elif days_until_due <= 7:
                            urgency_score = max(urgency_score, 0.5)
                    except:
                        pass
        
        # Boost urgency for high priority items
        if item.priority == PriorityLevel.URGENT:
            urgency_score = max(urgency_score, 0.9)
        elif item.priority == PriorityLevel.HIGH:
            urgency_score = max(urgency_score, 0.7)
        
        return min(1.0, urgency_score)
    
    def _calculate_recency(self, item: FeedItem) -> float:
        """Calculate recency score (newer items score higher)"""
        now = datetime.now(item.date.tzinfo) if item.date.tzinfo else datetime.now()
        age_hours = (now - item.date).total_seconds() / 3600
        
        # Exponential decay: score = e^(-age_hours/24)
        # Items from last 24 hours get high scores, older items decay
        import math
        recency_score = math.exp(-age_hours / 24)
        
        return min(1.0, recency_score)
    
    def _calculate_feedback_score(self, item: FeedItem, user_id: int, db: Session) -> float:
        """Calculate score based on historical user feedback"""
        try:
            # Get recent feedback for this user
            recent_feedback = db.query(Feedback).filter(
                Feedback.user_id == user_id,
                Feedback.created_at >= datetime.now() - timedelta(days=30)
            ).all()
            
            if not recent_feedback:
                return 0.5  # Neutral if no feedback history
            
            # Calculate average feedback score
            total_score = 0.0
            count = 0
            
            for feedback in recent_feedback:
                if feedback.feedback_type == "like":
                    total_score += 1.0
                    count += 1
                elif feedback.feedback_type == "dislike":
                    total_score += 0.0
                    count += 1
                elif feedback.feedback_type == "complete":
                    total_score += 0.8
                    count += 1
                elif feedback.feedback_type == "snooze":
                    total_score += 0.3
                    count += 1
            
            if count == 0:
                return 0.5
            
            return total_score / count
            
        except Exception as e:
            logger.error(f"Feedback score calculation failed: {e}")
            return 0.5
    
    def update_user_profile_from_feedback(self, user_id: int, feed_item: FeedItem,
                                        feedback_type: str, feedback_value: float,
                                        db: Session) -> bool:
        """Update user profile based on feedback for learning"""
        try:
            # Get or create user profile
            user_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not user_profile:
                user_profile = UserProfile(user_id=user_id)
                db.add(user_profile)
            
            # Update feedback history
            feedback_history = user_profile.feedback_history or []
            feedback_history.append({
                "feed_item_id": feed_item.id,
                "feedback_type": feedback_type,
                "feedback_value": feedback_value,
                "timestamp": datetime.now().isoformat(),
                "item_source": feed_item.source.value,
                "item_title": feed_item.title[:100]  # Truncate for storage
            })
            
            # Keep only last 100 feedback items
            user_profile.feedback_history = feedback_history[-100:]
            
            # Update important keywords based on positive feedback
            if feedback_type in ["like", "complete"] and feedback_value > 0.5:
                self._update_important_keywords(user_profile, feed_item)
            
            # Update important contacts based on positive feedback
            if feedback_type in ["like", "complete"] and feedback_value > 0.5:
                self._update_important_contacts(user_profile, feed_item)
            
            db.commit()
            logger.debug(f"Updated user profile for user {user_id} based on {feedback_type} feedback")
            return True
            
        except Exception as e:
            logger.error(f"Failed to update user profile from feedback: {e}")
            db.rollback()
            return False
    
    def _update_important_keywords(self, user_profile: UserProfile, feed_item: FeedItem):
        """Update important keywords based on positive feedback"""
        try:
            important_keywords = user_profile.important_keywords or []
            
            # Extract keywords from title and summary
            text = f"{feed_item.title} {feed_item.summary or ''}"
            
            # Simple keyword extraction (can be enhanced with NLP)
            words = text.lower().split()
            keywords = [word for word in words if len(word) > 3 and word.isalpha()]
            
            # Add new keywords (limit to 50 total)
            for keyword in keywords:
                if keyword not in important_keywords and len(important_keywords) < 50:
                    important_keywords.append(keyword)
            
            user_profile.important_keywords = important_keywords
            
        except Exception as e:
            logger.error(f"Failed to update important keywords: {e}")
    
    def _update_important_contacts(self, user_profile: UserProfile, feed_item: FeedItem):
        """Update important contacts based on positive feedback"""
        try:
            important_contacts = user_profile.important_contacts or []
            
            # Extract sender information
            sender = feed_item.metadata.get("sender")
            sender_email = feed_item.metadata.get("sender_email")
            
            if sender and sender not in important_contacts:
                important_contacts.append(sender)
            
            if sender_email and sender_email not in important_contacts:
                important_contacts.append(sender_email)
            
            # Limit to 20 contacts
            user_profile.important_contacts = important_contacts[:20]
            
        except Exception as e:
            logger.error(f"Failed to update important contacts: {e}")

# Global ranking service instance
ranking_service = RankingService()

def get_ranking_service() -> RankingService:
    """Get the global ranking service instance"""
    return ranking_service


