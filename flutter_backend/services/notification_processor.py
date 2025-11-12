"""
Notification Processor Service

Automatically extracts todos and calendar events from notifications using Groq LLM.
"""

import logging
from typing import Dict, Any, List, Tuple
from datetime import datetime

from ml.llm_adapter import get_llm_adapter
from app.core.nosql import store

logger = logging.getLogger(__name__)


class NotificationProcessor:
    """Processes notifications to extract todos and events"""
    
    def __init__(self):
        self.llm_adapter = get_llm_adapter()
    
    def process_notification(
        self,
        text: str,
        user_id: int = 1,
        source: str = "notification",
        source_id: str = None
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        Process notification text and extract todos and events.
        
        Args:
            text: Notification text to process
            user_id: User ID
            source: Source of notification (whatsapp, email, etc.)
            source_id: ID of the source feed item
            
        Returns:
            Tuple of (todos, events) as lists of dictionaries
        """
        todos = []
        events = []
        
        try:
            # Extract tasks using LLM
            task_result = self.llm_adapter.extract_tasks(text)
            logger.info(f"Extracted {len(task_result.get('tasks', []))} tasks from notification")
            
            # Convert to todo format and save
            for task in task_result.get("tasks", []):
                todo = {
                    "title": task.get("text", "")[:100],
                    "verb": task.get("verb", ""),
                    "due_date": task.get("due_date"),
                    "description": text[:200],
                    "priority": self._determine_priority(task.get("verb", ""), text),
                    "completed": False,
                    "source": source,
                    "source_id": source_id,
                    "user_id": user_id,
                    "created_at": datetime.now().timestamp(),
                    "deleted": False,
                }
                
                # Save to database
                try:
                    todo_id = store.insert("tasks", todo)
                    todo["id"] = todo_id
                    todos.append(todo)
                    logger.info(f"Created todo: {todo['title']}")
                except Exception as e:
                    logger.error(f"Failed to save todo: {e}")
            
            # Extract events using LLM
            event_result = self.llm_adapter.extract_events(text)
            logger.info(f"Extracted {len(event_result.get('events', []))} events from notification")
            
            # Convert to event format and save
            for evt in event_result.get("events", []):
                event = {
                    "title": evt.get("title", "")[:100],
                    "start_time": evt.get("start_time"),
                    "duration_minutes": evt.get("duration_minutes", 60),
                    "location": evt.get("location"),
                    "description": evt.get("description", text[:200]),
                    "source": source,
                    "source_id": source_id,
                    "user_id": user_id,
                    "is_ai_detected": True,
                    "created_at": datetime.now().timestamp(),
                    "deleted": False,
                }
                
                # Save to database
                try:
                    event_id = store.insert("events", event)
                    event["id"] = event_id
                    events.append(event)
                    logger.info(f"Created event: {event['title']}")
                except Exception as e:
                    logger.error(f"Failed to save event: {e}")
            
        except Exception as e:
            logger.error(f"Error processing notification: {e}")
        
        return (todos, events)
    
    def _determine_priority(self, verb: str, text: str) -> int:
        """Determine priority based on verb and text content"""
        # High priority verbs
        high_priority_verbs = ["submit", "pay", "register", "apply"]
        # Urgent keywords
        urgent_keywords = ["urgent", "asap", "immediately", "deadline", "today", "tomorrow"]
        
        priority = 1  # default
        
        if verb.lower() in high_priority_verbs:
            priority = 3
        
        text_lower = text.lower()
        for keyword in urgent_keywords:
            if keyword in text_lower:
                priority = max(priority, 2)
                break
        
        return priority


# Global instance
notification_processor = NotificationProcessor()


def get_notification_processor() -> NotificationProcessor:
    """Get the global notification processor instance"""
    return notification_processor
