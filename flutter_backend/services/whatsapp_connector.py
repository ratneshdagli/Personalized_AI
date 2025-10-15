"""
WhatsApp Connector Service

Handles WhatsApp chat export parsing and processing.
Supports both chat export files and notification forwarding.
"""

import re
import json
import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
import base64
import io

from sqlalchemy.orm import Session
from sqlalchemy import and_

from storage.models import FeedItem, User, ConnectorConfig
from storage.db import get_db_session
from ml.llm_adapter import get_llm_adapter
from nlp.embeddings import EmbeddingsPipeline
from storage.vector_store import get_vector_store
from utils.string_utils import clean_text, extract_keywords

logger = logging.getLogger(__name__)


class WhatsAppConnector:
    """WhatsApp connector for processing chat exports and notifications"""
    
    def __init__(self):
        self.llm_adapter = get_llm_adapter()
        self.embeddings_pipeline = EmbeddingsPipeline()
        self.vector_store = get_vector_store()
        
    def parse_chat_export(self, chat_text: str, user_id: int, 
                         chat_name: str = "WhatsApp Chat") -> List[FeedItem]:
        """
        Parse WhatsApp chat export text and create FeedItem objects
        
        Args:
            chat_text: Raw chat export text
            user_id: User ID
            chat_name: Name of the chat/group
            
        Returns:
            List of created FeedItem objects
        """
        try:
            # Parse chat messages
            messages = self._parse_chat_messages(chat_text)
            
            # Group messages by day for better context
            daily_groups = self._group_messages_by_day(messages)
            
            feed_items = []
            
            for date, day_messages in daily_groups.items():
                if not day_messages:
                    continue
                    
                # Create feed item for each day's conversation
                feed_item = self._create_feed_item_from_messages(
                    day_messages, user_id, chat_name, date
                )
                
                if feed_item:
                    feed_items.append(feed_item)
            
            return feed_items
            
        except Exception as e:
            logger.error(f"Error parsing WhatsApp chat export: {e}")
            return []
    
    def _parse_chat_messages(self, chat_text: str) -> List[Dict[str, Any]]:
        """Parse individual messages from chat export text"""
        messages = []
        
        # WhatsApp export format: [DD/MM/YYYY, HH:MM:SS] Sender: Message
        # Also handles: DD/MM/YYYY, HH:MM - Sender: Message
        pattern = r'\[?(\d{1,2}/\d{1,2}/\d{2,4}),?\s*(\d{1,2}:\d{2}(?::\d{2})?)\]?\s*([^:]+):\s*(.+)'
        
        lines = chat_text.split('\n')
        current_message = None
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
                
            match = re.match(pattern, line)
            if match:
                # Save previous message if exists
                if current_message:
                    messages.append(current_message)
                
                # Parse new message
                date_str, time_str, sender, content = match.groups()
                
                try:
                    # Parse datetime
                    datetime_str = f"{date_str} {time_str}"
                    if len(time_str.split(':')) == 2:
                        datetime_str += ":00"  # Add seconds if missing
                    
                    # Handle different date formats
                    if len(date_str.split('/')[2]) == 2:
                        # YY format, convert to YYYY
                        date_parts = date_str.split('/')
                        date_parts[2] = f"20{date_parts[2]}"
                        date_str = '/'.join(date_parts)
                    
                    parsed_datetime = datetime.strptime(f"{date_str} {time_str}", "%d/%m/%Y %H:%M:%S")
                    
                    current_message = {
                        'datetime': parsed_datetime,
                        'sender': sender.strip(),
                        'content': content.strip(),
                        'raw_line': line
                    }
                except ValueError as e:
                    logger.warning(f"Could not parse datetime '{datetime_str}': {e}")
                    # Create message with current time
                    current_message = {
                        'datetime': datetime.now(),
                        'sender': sender.strip(),
                        'content': content.strip(),
                        'raw_line': line
                    }
            else:
                # Continuation of previous message
                if current_message:
                    current_message['content'] += f" {line}"
        
        # Add last message
        if current_message:
            messages.append(current_message)
        
        return messages
    
    def _group_messages_by_day(self, messages: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
        """Group messages by day for better context"""
        daily_groups = {}
        
        for message in messages:
            date_key = message['datetime'].strftime('%Y-%m-%d')
            if date_key not in daily_groups:
                daily_groups[date_key] = []
            daily_groups[date_key].append(message)
        
        return daily_groups
    
    def _create_feed_item_from_messages(self, messages: List[Dict[str, Any]], 
                                       user_id: int, chat_name: str, 
                                       date: str) -> Optional[FeedItem]:
        """Create a FeedItem from a day's worth of messages"""
        try:
            if not messages:
                return None
            
            # Combine all messages for the day
            combined_content = []
            senders = set()
            
            for msg in messages:
                combined_content.append(f"{msg['sender']}: {msg['content']}")
                senders.add(msg['sender'])
            
            full_content = "\n".join(combined_content)
            
            # Clean and truncate content
            cleaned_content = clean_text(full_content)
            if len(cleaned_content) > 2000:
                cleaned_content = cleaned_content[:2000] + "..."
            
            # Generate summary using LLM
            summary = self._generate_summary(cleaned_content, chat_name)
            
            # Extract tasks
            tasks = self._extract_tasks_from_content(cleaned_content)
            
            # Determine priority and relevance
            priority, relevance = self._calculate_priority_relevance(
                cleaned_content, senders, tasks
            )
            
            # Create FeedItem
            feed_item = FeedItem(
                user_id=user_id,
                title=f"WhatsApp: {chat_name} - {date}",
                content=cleaned_content,
                summary=summary,
                source="whatsapp",
                origin_id=f"whatsapp_{chat_name}_{date}",
                priority=priority,
                relevance=relevance,
                date=messages[0]['datetime'],  # Fixed: use 'date' instead of 'published_at'
                meta_data={
                    'chat_name': chat_name,
                    'date': date,
                    'message_count': len(messages),
                    'senders': list(senders),
                    'extracted_tasks': tasks,
                    'raw_content': full_content[:500] + "..." if len(full_content) > 500 else full_content
                }
            )
            
            return feed_item
            
        except Exception as e:
            logger.error(f"Error creating feed item from messages: {e}")
            return None
    
    def _generate_summary(self, content: str, chat_name: str) -> str:
        """Generate summary of WhatsApp conversation"""
        try:
            prompt = f"""
Summarize this WhatsApp conversation from {chat_name} in 2-3 sentences.
Focus on key topics, decisions, and important information.

Conversation:
{content[:1500]}
"""
            
            summary = self.llm_adapter.summarize_text(prompt)
            return summary[:200] if summary else f"WhatsApp conversation from {chat_name}"
            
        except Exception as e:
            logger.error(f"Error generating summary: {e}")
            return f"WhatsApp conversation from {chat_name}"
    
    def _extract_tasks_from_content(self, content: str) -> List[Dict[str, Any]]:
        """Extract actionable tasks from WhatsApp conversation"""
        try:
            tasks_result = self.llm_adapter.extract_tasks(content)
            return tasks_result.get('tasks', [])
            
        except Exception as e:
            logger.error(f"Error extracting tasks: {e}")
            return []
    
    def _calculate_priority_relevance(self, content: str, senders: set, 
                                    tasks: List[Dict[str, Any]]) -> Tuple[float, float]:
        """Calculate priority and relevance scores"""
        priority = 0.5  # Base priority
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
        
        # Check for personal keywords (higher relevance)
        personal_keywords = ['you', 'your', 'we', 'us', 'our', 'me', 'my']
        personal_count = sum(1 for keyword in personal_keywords if keyword in content_lower)
        if personal_count > 3:
            relevance += 0.2
        
        # Multiple senders might indicate group importance
        if len(senders) > 2:
            relevance += 0.1
        
        return min(priority, 1.0), min(relevance, 1.0)
    
    def process_notification_data(self, notification_data: Dict[str, Any], 
                                user_id: int) -> Optional[FeedItem]:
        """
        Process WhatsApp notification data forwarded from mobile app
        
        Args:
            notification_data: Notification data from mobile
            user_id: User ID
            
        Returns:
            Created FeedItem or None
        """
        try:
            # Extract notification content
            title = notification_data.get('title', 'WhatsApp Message')
            content = notification_data.get('content', '')
            sender = notification_data.get('sender', 'Unknown')
            timestamp = notification_data.get('timestamp')
            
            if not content:
                return None
            
            # Parse timestamp
            if timestamp:
                try:
                    parsed_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                except:
                    parsed_time = datetime.now()
            else:
                parsed_time = datetime.now()
            
            # Clean content
            cleaned_content = clean_text(content)
            
            # Generate summary
            summary = f"WhatsApp message from {sender}: {cleaned_content[:100]}..."
            
            # Extract tasks
            tasks = self._extract_tasks_from_content(cleaned_content)
            
            # Calculate priority and relevance
            priority, relevance = self._calculate_priority_relevance(
                cleaned_content, {sender}, tasks
            )
            
            # Create FeedItem (ensure full_text is populated)
            full_text_value = cleaned_content or title or sender
            feed_item = FeedItem(
                user_id=user_id,
                title=f"WhatsApp: {sender}",
                content=cleaned_content,
                full_text=full_text_value,
                summary=summary,
                source="whatsapp_notification",
                origin_id=f"whatsapp_notif_{sender}_{parsed_time.timestamp()}",
                priority=priority,
                relevance=relevance,
                date=parsed_time,  # Fixed: use 'date' instead of 'published_at'
                meta_data={
                    'sender': sender,
                    'notification_title': title,
                    'extracted_tasks': tasks,
                    'notification_data': notification_data
                }
            )
            
            return feed_item
            
        except Exception as e:
            logger.error(f"Error processing WhatsApp notification: {e}")
            return None
    
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
                    logger.info(f"Duplicate WhatsApp feed item skipped: {feed_item.origin_id}")
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
                    logger.error(f"Error creating embedding for feed item {feed_item.id}: {e}")
                
                saved_items.append(feed_item)
                
        except Exception as e:
            logger.error(f"Error saving WhatsApp feed items: {e}")
            db.rollback()
        finally:
            db.close()
        
        return saved_items


    def process_and_store_message(self, message_data: Dict[str, Any], user_id: int) -> Optional[FeedItem]:
        """
        Simple function to process and store a WhatsApp message
        
        Args:
            message_data: Dictionary containing sender, message, timestamp
            user_id: User ID
            
        Returns:
            Created FeedItem or None
        """
        print(f"Processing message from {message_data.get('sender', 'Unknown')}")
        print(f"Message data: {message_data}")
        
        try:
            # Extract message components
            sender = message_data.get('sender', 'Unknown')
            message = message_data.get('message', '')
            timestamp = message_data.get('timestamp')
            
            print(f"Extracted - Sender: {sender}, Message: '{message[:50]}...', Timestamp: {timestamp}")
            
            if not message:
                print("No message content, returning None")
                return None
            
            # Parse timestamp
            if timestamp:
                try:
                    if isinstance(timestamp, (int, float)):
                        # Assume milliseconds timestamp
                        parsed_time = datetime.fromtimestamp(timestamp / 1000.0)
                    else:
                        parsed_time = datetime.fromisoformat(str(timestamp).replace('Z', '+00:00'))
                except:
                    parsed_time = datetime.now()
            else:
                parsed_time = datetime.now()
            
            print(f"Parsed timestamp: {parsed_time}")
            
            # Clean content
            cleaned_content = clean_text(message)
            print(f"Cleaned content: '{cleaned_content[:50]}...'")
            
            # Generate summary
            summary = f"WhatsApp message from {sender}: {cleaned_content[:100]}..."
            
            # Extract tasks
            tasks = self._extract_tasks_from_content(cleaned_content)
            print(f"Extracted {len(tasks)} tasks")
            
            # Calculate priority and relevance
            priority, relevance = self._calculate_priority_relevance(
                cleaned_content, {sender}, tasks
            )
            print(f"Calculated priority: {priority}, relevance: {relevance}")
            
            # Create FeedItem
            feed_item = FeedItem(
                user_id=user_id,
                title=f"WhatsApp: {sender}",
                content=cleaned_content,
                summary=summary,
                source="whatsapp",
                origin_id=f"whatsapp_msg_{sender}_{parsed_time.timestamp()}",
                priority=priority,
                relevance=relevance,
                date=parsed_time,  # Fixed: use 'date' instead of 'published_at'
                meta_data={
                    'sender': sender,
                    'extracted_tasks': tasks,
                    'message_data': message_data
                }
            )
            
            print(f"Created FeedItem: {feed_item.title}")
            print("Successfully saved message to DB.")
            
            return feed_item
            
        except Exception as e:
            print(f"Error processing WhatsApp message: {e}")
            logger.error(f"Error processing WhatsApp message: {e}")
            return None


def get_whatsapp_connector() -> WhatsAppConnector:
    """Get WhatsApp connector instance"""
    return WhatsAppConnector()


