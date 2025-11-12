"""
Instagram Connector Service

Handles Instagram OAuth authentication and content fetching.
Note: Instagram Basic Display API has limited functionality.
"""

import logging
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
import json

from sqlalchemy.orm import Session
from sqlalchemy import and_

from storage.models import FeedItem, User, ConnectorConfig
from storage.db import get_db_session
from ml.llm_adapter import get_llm_adapter
from nlp.embeddings import EmbeddingsPipeline
from storage.vector_store import get_vector_store
from utils.string_utils import clean_text, extract_keywords

logger = logging.getLogger(__name__)


class InstagramConnector:
    """Instagram connector for processing posts and stories"""
    
    def __init__(self):
        self.llm_adapter = get_llm_adapter()
        self.embeddings_pipeline = EmbeddingsPipeline()
        self.vector_store = get_vector_store()
        self.base_url = "https://graph.instagram.com"
    
    def get_auth_url(self, user_id: int, redirect_uri: str) -> str:
        """
        Generate Instagram OAuth URL
        
        Args:
            user_id: User ID
            redirect_uri: Redirect URI after authorization
            
        Returns:
            Instagram OAuth URL
        """
        import os
        
        client_id = os.getenv("INSTAGRAM_CLIENT_ID")
        if not client_id:
            raise ValueError("INSTAGRAM_CLIENT_ID not configured")
        
        # Instagram Basic Display API scopes
        scopes = [
            "user_profile",
            "user_media"
        ]
        
        params = {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scope": ",".join(scopes),
            "response_type": "code",
            "state": str(user_id)
        }
        
        query_string = "&".join([f"{k}={v}" for k, v in params.items()])
        return f"https://api.instagram.com/oauth/authorize?{query_string}"
    
    def exchange_code_for_token(self, code: str, redirect_uri: str) -> Dict[str, Any]:
        """
        Exchange authorization code for access token
        
        Args:
            code: Authorization code from Instagram
            redirect_uri: Redirect URI used in auth
            
        Returns:
            Token response with access_token and user_id
        """
        import os
        
        client_id = os.getenv("INSTAGRAM_CLIENT_ID")
        client_secret = os.getenv("INSTAGRAM_CLIENT_SECRET")
        
        if not client_id or not client_secret:
            raise ValueError("Instagram credentials not configured")
        
        url = "https://api.instagram.com/oauth/access_token"
        
        data = {
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
            "code": code
        }
        
        try:
            response = requests.post(url, data=data)
            response.raise_for_status()
            
            token_data = response.json()
            
            # Get long-lived token
            long_lived_token = self._get_long_lived_token(token_data["access_token"])
            token_data["access_token"] = long_lived_token
            
            return token_data
            
        except requests.RequestException as e:
            logger.error(f"Error exchanging Instagram code for token: {e}")
            raise
    
    def _get_long_lived_token(self, short_lived_token: str) -> str:
        """Convert short-lived token to long-lived token"""
        import os
        
        client_secret = os.getenv("INSTAGRAM_CLIENT_SECRET")
        
        url = f"{self.base_url}/access_token"
        params = {
            "grant_type": "ig_exchange_token",
            "client_secret": client_secret,
            "access_token": short_lived_token
        }
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data["access_token"]
            
        except requests.RequestException as e:
            logger.error(f"Error getting long-lived Instagram token: {e}")
            # Return short-lived token as fallback
            return short_lived_token
    
    def refresh_token(self, access_token: str) -> Dict[str, Any]:
        """Refresh Instagram access token"""
        url = f"{self.base_url}/refresh_access_token"
        params = {
            "grant_type": "ig_refresh_token",
            "access_token": access_token
        }
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            return response.json()
            
        except requests.RequestException as e:
            logger.error(f"Error refreshing Instagram token: {e}")
            raise
    
    def get_user_profile(self, access_token: str) -> Dict[str, Any]:
        """Get Instagram user profile"""
        url = f"{self.base_url}/me"
        params = {
            "fields": "id,username,account_type,media_count",
            "access_token": access_token
        }
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            return response.json()
            
        except requests.RequestException as e:
            logger.error(f"Error getting Instagram user profile: {e}")
            raise
    
    def fetch_user_media(self, access_token: str, user_id: str, 
                        limit: int = 25) -> List[Dict[str, Any]]:
        """
        Fetch user's media (posts)
        
        Args:
            access_token: Instagram access token
            user_id: Instagram user ID
            limit: Number of posts to fetch
            
        Returns:
            List of media posts
        """
        url = f"{self.base_url}/{user_id}/media"
        params = {
            "fields": "id,caption,media_type,media_url,thumbnail_url,permalink,timestamp",
            "limit": limit,
            "access_token": access_token
        }
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            return data.get("data", [])
            
        except requests.RequestException as e:
            logger.error(f"Error fetching Instagram media: {e}")
            raise
    
    def process_media_post(self, post: Dict[str, Any], user_id: int) -> Optional[FeedItem]:
        """
        Process Instagram media post into FeedItem
        
        Args:
            post: Instagram media post data
            user_id: User ID
            
        Returns:
            FeedItem or None
        """
        try:
            # Extract post data
            post_id = post.get("id")
            caption = post.get("caption", "")
            media_type = post.get("media_type", "IMAGE")
            media_url = post.get("media_url", "")
            permalink = post.get("permalink", "")
            timestamp = post.get("timestamp", "")
            
            if not post_id:
                return None
            
            # Parse timestamp
            try:
                published_at = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            except:
                published_at = datetime.now()
            
            # Clean caption
            cleaned_caption = clean_text(caption) if caption else ""
            
            # Generate summary
            summary = self._generate_summary(cleaned_caption, media_type)
            
            # Extract tasks
            tasks = self._extract_tasks_from_content(cleaned_caption)
            
            # Calculate priority and relevance
            priority, relevance = self._calculate_priority_relevance(
                cleaned_caption, tasks
            )
            
            # Create FeedItem
            feed_item = FeedItem(
                user_id=user_id,
                title=f"Instagram Post: {media_type.lower()}",
                content=cleaned_caption,
                summary=summary,
                source="instagram",
                origin_id=f"instagram_{post_id}",
                priority=priority,
                relevance=relevance,
                published_at=published_at,
                meta_data={
                    'post_id': post_id,
                    'media_type': media_type,
                    'media_url': media_url,
                    'permalink': permalink,
                    'extracted_tasks': tasks,
                    'raw_caption': caption
                }
            )
            
            return feed_item
            
        except Exception as e:
            logger.error(f"Error processing Instagram post: {e}")
            return None
    
    def _generate_summary(self, caption: str, media_type: str) -> str:
        """Generate summary of Instagram post"""
        try:
            if not caption:
                return f"Instagram {media_type.lower()} post"
            
            prompt = f"""
Summarize this Instagram post caption in 1-2 sentences.
Focus on the main message or topic.

Caption: {caption[:500]}
"""
            
            summary = self.llm_adapter.summarize_text(prompt)
            return summary[:150] if summary else f"Instagram {media_type.lower()} post"
            
        except Exception as e:
            logger.error(f"Error generating Instagram summary: {e}")
            return f"Instagram {media_type.lower()} post"
    
    def _extract_tasks_from_content(self, content: str) -> List[Dict[str, Any]]:
        """Extract actionable tasks from Instagram content"""
        try:
            if not content:
                return []
            
            tasks_result = self.llm_adapter.extract_tasks(content)
            return tasks_result.get('tasks', [])
            
        except Exception as e:
            logger.error(f"Error extracting tasks from Instagram content: {e}")
            return []
    
    def _calculate_priority_relevance(self, content: str, tasks: List[Dict[str, Any]]) -> Tuple[float, float]:
        """Calculate priority and relevance scores for Instagram content"""
        priority = 0.3  # Base priority (lower than other sources)
        relevance = 0.4  # Base relevance
        
        # Increase priority for task-related content
        if tasks:
            priority += 0.2
        
        # Check for engagement keywords
        engagement_keywords = ['check out', 'visit', 'link in bio', 'swipe up', 'dm me']
        content_lower = content.lower()
        for keyword in engagement_keywords:
            if keyword in content_lower:
                priority += 0.1
                relevance += 0.1
                break
        
        # Check for personal keywords
        personal_keywords = ['you', 'your', 'we', 'us', 'our']
        personal_count = sum(1 for keyword in personal_keywords if keyword in content_lower)
        if personal_count > 2:
            relevance += 0.1
        
        return min(priority, 1.0), min(relevance, 1.0)
    
    def save_feed_items_with_embeddings(self, feed_items: List[FeedItem]) -> List[FeedItem]:
        """Save feed items to database and create embeddings"""
        db = get_db_session()
        saved_items = []
        
        try:
            for feed_item in feed_items:
                # Check for duplicates
                existing = db.query(FeedItem).filter(
                    and_(
                        FeedItem.origin_id == feed_item.origin_id,
                        FeedItem.user_id == feed_item.user_id,
                        FeedItem.source == feed_item.source
                    )
                ).first()
                
                if existing:
                    logger.info(f"Duplicate Instagram feed item skipped: {feed_item.origin_id}")
                    continue
                
                # Save to database
                db.add(feed_item)
                db.commit()
                db.refresh(feed_item)
                
                # Create embedding
                try:
                    embedding = self.embeddings_pipeline.embed_text(feed_item.content)
                    if embedding:
                        self.vector_store.add_embedding(
                            feed_item.id, embedding, feed_item.user_id
                        )
                except Exception as e:
                    logger.error(f"Error creating embedding for Instagram feed item {feed_item.id}: {e}")
                
                saved_items.append(feed_item)
                
        except Exception as e:
            logger.error(f"Error saving Instagram feed items: {e}")
            db.rollback()
        finally:
            db.close()
        
        return saved_items


def get_instagram_connector() -> InstagramConnector:
    """Get Instagram connector instance"""
    return InstagramConnector()


