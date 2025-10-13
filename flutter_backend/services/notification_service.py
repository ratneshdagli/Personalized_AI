"""
Notification Service

Handles local notifications for tasks and important updates.
"""

import logging
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
import json

from sqlalchemy.orm import Session
from sqlalchemy import and_

from storage.models import Task, User, FeedItem
from storage.db import get_db_session

logger = logging.getLogger(__name__)


class NotificationService:
    """Service for managing local notifications"""
    
    def __init__(self):
        pass
    
    def schedule_task_notification(self, task: Task, user_id: int) -> bool:
        """
        Schedule a notification for a task
        
        Args:
            task: Task to notify about
            user_id: User ID
            
        Returns:
            Success status
        """
        try:
            if not task.dueDate:
                logger.warning(f"Task {task.id} has no due date, cannot schedule notification")
                return False
            
            # Calculate notification times
            notification_times = self._calculate_notification_times(task.dueDate, task.priority)
            
            # Store notification data
            notification_data = {
                "task_id": task.id,
                "user_id": user_id,
                "title": f"Task Due: {task.title}",
                "body": task.description or "Task is due soon",
                "scheduled_times": notification_times,
                "priority": task.priority,
                "created_at": datetime.now().isoformat()
            }
            
            # TODO: Integrate with Flutter's flutter_local_notifications
            # For now, just log the notification
            logger.info(f"Scheduled notification for task {task.id}: {notification_data}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error scheduling notification for task {task.id}: {e}")
            return False
    
    def schedule_priority_notification(self, feed_item: FeedItem, user_id: int) -> bool:
        """
        Schedule a notification for a high-priority feed item
        
        Args:
            feed_item: Feed item to notify about
            user_id: User ID
            
        Returns:
            Success status
        """
        try:
            if feed_item.priority < 0.8:  # Only notify for high priority items
                return False
            
            notification_data = {
                "feed_item_id": feed_item.id,
                "user_id": user_id,
                "title": f"High Priority: {feed_item.title}",
                "body": feed_item.summary or feed_item.content[:100] + "...",
                "priority": "high",
                "source": feed_item.source,
                "created_at": datetime.now().isoformat()
            }
            
            # TODO: Integrate with Flutter's flutter_local_notifications
            logger.info(f"Scheduled priority notification for feed item {feed_item.id}: {notification_data}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error scheduling priority notification for feed item {feed_item.id}: {e}")
            return False
    
    def cancel_task_notification(self, task_id: int, user_id: int) -> bool:
        """
        Cancel scheduled notifications for a task
        
        Args:
            task_id: Task ID
            user_id: User ID
            
        Returns:
            Success status
        """
        try:
            # TODO: Cancel notifications in Flutter's flutter_local_notifications
            logger.info(f"Cancelled notifications for task {task_id}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error cancelling notifications for task {task_id}: {e}")
            return False
    
    def get_upcoming_notifications(self, user_id: int, hours_ahead: int = 24) -> List[Dict[str, Any]]:
        """
        Get upcoming notifications for a user
        
        Args:
            user_id: User ID
            hours_ahead: Hours to look ahead
            
        Returns:
            List of upcoming notifications
        """
        try:
            db = get_db_session()
            
            # Get tasks due in the next N hours
            now = datetime.now()
            time_limit = now + timedelta(hours=hours_ahead)
            
            upcoming_tasks = db.query(Task).filter(
                Task.user_id == user_id,
                Task.isCompleted == False,
                Task.dueDate.isnot(None),
                Task.dueDate >= now,
                Task.dueDate <= time_limit
            ).all()
            
            notifications = []
            for task in upcoming_tasks:
                notifications.append({
                    "type": "task",
                    "task_id": task.id,
                    "title": task.title,
                    "due_date": task.dueDate.isoformat(),
                    "priority": task.priority,
                    "description": task.description
                })
            
            # Get high-priority feed items from the last 24 hours
            last_24h = now - timedelta(hours=24)
            high_priority_items = db.query(FeedItem).filter(
                FeedItem.user_id == user_id,
                FeedItem.priority >= 0.8,
                FeedItem.created_at >= last_24h
            ).all()
            
            for item in high_priority_items:
                notifications.append({
                    "type": "feed_item",
                    "feed_item_id": item.id,
                    "title": item.title,
                    "priority": item.priority,
                    "source": item.source,
                    "summary": item.summary
                })
            
            db.close()
            
            # Sort by priority and time
            notifications.sort(key=lambda x: (x.get("priority", 0), x.get("due_date", "")), reverse=True)
            
            return notifications
            
        except Exception as e:
            logger.error(f"Error getting upcoming notifications for user {user_id}: {e}")
            return []
    
    def _calculate_notification_times(self, due_date: datetime, priority: str) -> List[datetime]:
        """
        Calculate notification times based on due date and priority
        
        Args:
            due_date: Task due date
            priority: Task priority
            
        Returns:
            List of notification times
        """
        notification_times = []
        
        if priority == "high":
            # High priority: 24h, 2h, 30min, 10min before
            notification_times.extend([
                due_date - timedelta(hours=24),
                due_date - timedelta(hours=2),
                due_date - timedelta(minutes=30),
                due_date - timedelta(minutes=10)
            ])
        elif priority == "medium":
            # Medium priority: 2h, 30min before
            notification_times.extend([
                due_date - timedelta(hours=2),
                due_date - timedelta(minutes=30)
            ])
        else:
            # Low priority: 30min before
            notification_times.append(due_date - timedelta(minutes=30))
        
        # Filter out past times
        now = datetime.now()
        notification_times = [t for t in notification_times if t > now]
        
        return notification_times
    
    def send_immediate_notification(self, user_id: int, title: str, body: str, 
                                  priority: str = "normal") -> bool:
        """
        Send an immediate notification
        
        Args:
            user_id: User ID
            title: Notification title
            body: Notification body
            priority: Notification priority
            
        Returns:
            Success status
        """
        try:
            notification_data = {
                "user_id": user_id,
                "title": title,
                "body": body,
                "priority": priority,
                "immediate": True,
                "created_at": datetime.now().isoformat()
            }
            
            # TODO: Send immediate notification via Flutter
            logger.info(f"Sent immediate notification to user {user_id}: {notification_data}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error sending immediate notification to user {user_id}: {e}")
            return False
    
    def get_notification_settings(self, user_id: int) -> Dict[str, Any]:
        """
        Get user's notification settings
        
        Args:
            user_id: User ID
            
        Returns:
            Notification settings
        """
        try:
            db = get_db_session()
            
            # Get user preferences (this would be stored in user profile or settings)
            # For now, return default settings
            settings = {
                "task_notifications": True,
                "priority_notifications": True,
                "daily_summary": True,
                "quiet_hours_start": "22:00",
                "quiet_hours_end": "08:00",
                "notification_sound": True,
                "vibration": True
            }
            
            db.close()
            return settings
            
        except Exception as e:
            logger.error(f"Error getting notification settings for user {user_id}: {e}")
            return {}
    
    def update_notification_settings(self, user_id: int, settings: Dict[str, Any]) -> bool:
        """
        Update user's notification settings
        
        Args:
            user_id: User ID
            settings: New notification settings
            
        Returns:
            Success status
        """
        try:
            # TODO: Store settings in user profile or dedicated settings table
            logger.info(f"Updated notification settings for user {user_id}: {settings}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error updating notification settings for user {user_id}: {e}")
            return False


def get_notification_service() -> NotificationService:
    """Get notification service instance"""
    return NotificationService()


