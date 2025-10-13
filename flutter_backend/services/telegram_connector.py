"""
Telegram Connector Service

Handles Telegram Bot API integration for fetching messages and channels.
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


class TelegramConnector:
    """Telegram connector for processing messages and channels"""
    
    def __init__(self):
        self.llm_adapter = get_llm_adapter()
        self.embeddings_pipeline = EmbeddingsPipeline()
        self.vector_store = get_vector_store()
        self.base_url = "https://api.telegram.org/bot"
    
    def get_bot_token(self) -> str:
        """Get Telegram bot token from environment"""
        import os
        
        token = os.getenv("TELEGRAM_BOT_TOKEN")
        if not token:
            raise ValueError("TELEGRAM_BOT_TOKEN not configured")
        
        return token
    
    def get_me(self) -> Dict[str, Any]:
        """Get bot information"""
        token = self.get_bot_token()
        url = f"{self.base_url}{token}/getMe"
        
        try:
            response = requests.get(url)
            response.raise_for_status()
            
            data = response.json()
            if data.get("ok"):
                return data["result"]
            else:
                raise Exception(f"Telegram API error: {data.get('description')}")
                
        except requests.RequestException as e:
            logger.error(f"Error getting Telegram bot info: {e}")
            raise
    
    def get_updates(self, offset: Optional[int] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Get updates (messages) from Telegram
        
        Args:
            offset: Identifier of the first update to be returned
            limit: Limits the number of updates to be retrieved
            
        Returns:
            List of updates
        """
        token = self.get_bot_token()
        url = f"{self.base_url}{token}/getUpdates"
        
        params = {
            "limit": limit,
            "timeout": 0  # Long polling
        }
        
        if offset:
            params["offset"] = offset
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            if data.get("ok"):
                return data["result"]
            else:
                raise Exception(f"Telegram API error: {data.get('description')}")
                
        except requests.RequestException as e:
            logger.error(f"Error getting Telegram updates: {e}")
            raise
    
    def get_chat_info(self, chat_id: str) -> Dict[str, Any]:
        """Get chat information"""
        token = self.get_bot_token()
        url = f"{self.base_url}{token}/getChat"
        
        params = {"chat_id": chat_id}
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            if data.get("ok"):
                return data["result"]
            else:
                raise Exception(f"Telegram API error: {data.get('description')}")
                
        except requests.RequestException as e:
            logger.error(f"Error getting Telegram chat info: {e}")
            raise
    
    def get_chat_members_count(self, chat_id: str) -> int:
        """Get number of members in a chat"""
        token = self.get_bot_token()
        url = f"{self.base_url}{token}/getChatMembersCount"
        
        params = {"chat_id": chat_id}
        
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            
            data = response.json()
            if data.get("ok"):
                return data["result"]
            else:
                logger.warning(f"Could not get member count for chat {chat_id}: {data.get('description')}")
                return 0
                
        except requests.RequestException as e:
            logger.error(f"Error getting Telegram chat member count: {e}")
            return 0
    
    def process_message(self, message: Dict[str, Any], user_id: int) -> Optional[FeedItem]:
        """
        Process Telegram message into FeedItem
        
        Args:
            message: Telegram message data
            user_id: User ID
            
        Returns:
            FeedItem or None
        """
        try:
            # Extract message data
            message_id = message.get("message_id")
            text = message.get("text", "")
            chat = message.get("chat", {})
            from_user = message.get("from", {})
            date = message.get("date")
            
            if not message_id or not text:
                return None
            
            # Parse timestamp
            try:
                published_at = datetime.fromtimestamp(date)
            except:
                published_at = datetime.now()
            
            # Get chat info
            chat_id = str(chat.get("id", ""))
            chat_title = chat.get("title", chat.get("first_name", "Unknown Chat"))
            chat_type = chat.get("type", "unknown")
            
            # Get sender info
            sender_name = from_user.get("first_name", "")
            sender_username = from_user.get("username", "")
            sender_id = from_user.get("id", "")
            
            # Clean text
            cleaned_text = clean_text(text)
            
            # Generate summary
            summary = self._generate_summary(cleaned_text, chat_title, sender_name)
            
            # Extract tasks
            tasks = self._extract_tasks_from_content(cleaned_text)
            
            # Calculate priority and relevance
            priority, relevance = self._calculate_priority_relevance(
                cleaned_text, chat_type, tasks
            )
            
            # Create FeedItem
            feed_item = FeedItem(
                user_id=user_id,
                title=f"Telegram: {chat_title}",
                content=cleaned_text,
                summary=summary,
                source="telegram",
                origin_id=f"telegram_{chat_id}_{message_id}",
                priority=priority,
                relevance=relevance,
                published_at=published_at,
                meta_data={
                    'message_id': message_id,
                    'chat_id': chat_id,
                    'chat_title': chat_title,
                    'chat_type': chat_type,
                    'sender_name': sender_name,
                    'sender_username': sender_username,
                    'sender_id': sender_id,
                    'extracted_tasks': tasks,
                    'raw_text': text
                }
            )
            
            return feed_item
            
        except Exception as e:
            logger.error(f"Error processing Telegram message: {e}")
            return None
    
    def _generate_summary(self, text: str, chat_title: str, sender_name: str) -> str:
        """Generate summary of Telegram message"""
        try:
            if not text:
                return f"Message from {sender_name} in {chat_title}"
            
            prompt = f"""
Summarize this Telegram message in 1-2 sentences.
Focus on the main message or topic.

Message: {text[:500]}
"""
            
            summary = self.llm_adapter.summarize_text(prompt)
            return summary[:150] if summary else f"Message from {sender_name} in {chat_title}"
            
        except Exception as e:
            logger.error(f"Error generating Telegram summary: {e}")
            return f"Message from {sender_name} in {chat_title}"
    
    def _extract_tasks_from_content(self, content: str) -> List[Dict[str, Any]]:
        """Extract actionable tasks from Telegram content"""
        try:
            if not content:
                return []
            
            tasks_result = self.llm_adapter.extract_tasks(content)
            return tasks_result.get('tasks', [])
            
        except Exception as e:
            logger.error(f"Error extracting tasks from Telegram content: {e}")
            return []
    
    def _calculate_priority_relevance(self, content: str, chat_type: str, 
                                    tasks: List[Dict[str, Any]]) -> Tuple[float, float]:
        """Calculate priority and relevance scores for Telegram content"""
        priority = 0.4  # Base priority
        relevance = 0.5  # Base relevance
        
        # Increase priority for task-related content
        if tasks:
            priority += 0.3
        
        # Check for urgent keywords
        urgent_keywords = ['urgent', 'asap', 'deadline', 'important', 'meeting', 'call']
        content_lower = content.lower()
        for keyword in urgent_keywords:
            if keyword in content_lower:
                priority += 0.1
                break
        
        # Adjust based on chat type
        if chat_type == "private":
            relevance += 0.2  # Private messages are more relevant
        elif chat_type == "group":
            relevance += 0.1  # Group messages are moderately relevant
        elif chat_type == "channel":
            priority += 0.1  # Channel messages might be announcements
        
        # Check for personal keywords
        personal_keywords = ['you', 'your', 'we', 'us', 'our', 'me', 'my']
        personal_count = sum(1 for keyword in personal_keywords if keyword in content_lower)
        if personal_count > 3:
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
                    logger.info(f"Duplicate Telegram feed item skipped: {feed_item.origin_id}")
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
                    logger.error(f"Error creating embedding for Telegram feed item {feed_item.id}: {e}")
                
                saved_items.append(feed_item)
                
        except Exception as e:
            logger.error(f"Error saving Telegram feed items: {e}")
            db.rollback()
        finally:
            db.close()
        
        return saved_items
    
    def send_message(self, chat_id: str, text: str) -> bool:
        """Send a message to a Telegram chat"""
        token = self.get_bot_token()
        url = f"{self.base_url}{token}/sendMessage"
        
        data = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML"
        }
        
        try:
            response = requests.post(url, json=data)
            response.raise_for_status()
            
            result = response.json()
            return result.get("ok", False)
            
        except requests.RequestException as e:
            logger.error(f"Error sending Telegram message: {e}")
            return False


def get_telegram_connector() -> TelegramConnector:
    """Get Telegram connector instance"""
    return TelegramConnector()


