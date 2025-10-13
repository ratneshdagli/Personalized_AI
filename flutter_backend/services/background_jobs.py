"""
Background Job Service

Handles background processing of data ingestion, sync, and cleanup tasks.
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Callable
from enum import Enum
import json
import uuid

from sqlalchemy.orm import Session
from sqlalchemy import and_

from storage.db import get_db_session
from storage.models import User, ConnectorConfig, FeedItem
from services.gmail_connector import get_gmail_connector
from services.news_connector import get_news_connector
from services.reddit_connector import get_reddit_connector
from services.whatsapp_connector import get_whatsapp_connector

logger = logging.getLogger(__name__)


class JobStatus(Enum):
    """Job status enumeration"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class JobType(Enum):
    """Job type enumeration"""
    GMAIL_SYNC = "gmail_sync"
    NEWS_SYNC = "news_sync"
    REDDIT_SYNC = "reddit_sync"
    WHATSAPP_SYNC = "whatsapp_sync"
    CLEANUP_OLD_DATA = "cleanup_old_data"
    REBUILD_VECTOR_INDEX = "rebuild_vector_index"
    USER_PERSONALIZATION_UPDATE = "user_personalization_update"


class BackgroundJob:
    """Background job representation"""
    
    def __init__(self, job_id: str, job_type: JobType, user_id: int, 
                 payload: Dict[str, Any], priority: int = 0):
        self.job_id = job_id
        self.job_type = job_type
        self.user_id = user_id
        self.payload = payload
        self.priority = priority
        self.status = JobStatus.PENDING
        self.created_at = datetime.now()
        self.started_at: Optional[datetime] = None
        self.completed_at: Optional[datetime] = None
        self.error_message: Optional[str] = None
        self.result: Optional[Dict[str, Any]] = None


class JobQueue:
    """Simple in-memory job queue with persistence"""
    
    def __init__(self):
        self._jobs: Dict[str, BackgroundJob] = {}
        self._running_jobs: Dict[str, BackgroundJob] = {}
        self._job_handlers: Dict[JobType, Callable] = {}
        self._register_handlers()
    
    def _register_handlers(self):
        """Register job handlers"""
        self._job_handlers = {
            JobType.GMAIL_SYNC: self._handle_gmail_sync,
            JobType.NEWS_SYNC: self._handle_news_sync,
            JobType.REDDIT_SYNC: self._handle_reddit_sync,
            JobType.WHATSAPP_SYNC: self._handle_whatsapp_sync,
            JobType.CLEANUP_OLD_DATA: self._handle_cleanup_old_data,
            JobType.REBUILD_VECTOR_INDEX: self._handle_rebuild_vector_index,
            JobType.USER_PERSONALIZATION_UPDATE: self._handle_user_personalization_update,
        }
    
    def enqueue_job(self, job: BackgroundJob) -> bool:
        """Enqueue a job for processing"""
        try:
            self._jobs[job.job_id] = job
            logger.info(f"Job {job.job_id} enqueued: {job.job_type.value}")
            return True
        except Exception as e:
            logger.error(f"Error enqueuing job {job.job_id}: {e}")
            return False
    
    def get_next_job(self) -> Optional[BackgroundJob]:
        """Get the next job to process (highest priority first)"""
        pending_jobs = [
            job for job in self._jobs.values() 
            if job.status == JobStatus.PENDING
        ]
        
        if not pending_jobs:
            return None
        
        # Sort by priority (higher number = higher priority)
        pending_jobs.sort(key=lambda x: x.priority, reverse=True)
        return pending_jobs[0]
    
    def start_job(self, job: BackgroundJob) -> bool:
        """Mark job as running"""
        try:
            job.status = JobStatus.RUNNING
            job.started_at = datetime.now()
            self._running_jobs[job.job_id] = job
            logger.info(f"Job {job.job_id} started: {job.job_type.value}")
            return True
        except Exception as e:
            logger.error(f"Error starting job {job.job_id}: {e}")
            return False
    
    def complete_job(self, job: BackgroundJob, result: Optional[Dict[str, Any]] = None) -> bool:
        """Mark job as completed"""
        try:
            job.status = JobStatus.COMPLETED
            job.completed_at = datetime.now()
            job.result = result
            self._running_jobs.pop(job.job_id, None)
            logger.info(f"Job {job.job_id} completed: {job.job_type.value}")
            return True
        except Exception as e:
            logger.error(f"Error completing job {job.job_id}: {e}")
            return False
    
    def fail_job(self, job: BackgroundJob, error_message: str) -> bool:
        """Mark job as failed"""
        try:
            job.status = JobStatus.FAILED
            job.completed_at = datetime.now()
            job.error_message = error_message
            self._running_jobs.pop(job.job_id, None)
            logger.error(f"Job {job.job_id} failed: {job.job_type.value} - {error_message}")
            return True
        except Exception as e:
            logger.error(f"Error failing job {job.job_id}: {e}")
            return False
    
    def cancel_job(self, job_id: str) -> bool:
        """Cancel a job"""
        try:
            if job_id in self._jobs:
                job = self._jobs[job_id]
                if job.status == JobStatus.PENDING:
                    job.status = JobStatus.CANCELLED
                    job.completed_at = datetime.now()
                    logger.info(f"Job {job_id} cancelled")
                    return True
                elif job.status == JobStatus.RUNNING:
                    # Mark as cancelled but let it finish
                    job.status = JobStatus.CANCELLED
                    logger.info(f"Job {job_id} marked for cancellation")
                    return True
            return False
        except Exception as e:
            logger.error(f"Error cancelling job {job_id}: {e}")
            return False
    
    def get_job_status(self, job_id: str) -> Optional[BackgroundJob]:
        """Get job status"""
        return self._jobs.get(job_id)
    
    def get_user_jobs(self, user_id: int, limit: int = 50) -> List[BackgroundJob]:
        """Get jobs for a specific user"""
        user_jobs = [
            job for job in self._jobs.values() 
            if job.user_id == user_id
        ]
        user_jobs.sort(key=lambda x: x.created_at, reverse=True)
        return user_jobs[:limit]
    
    def cleanup_old_jobs(self, days: int = 7) -> int:
        """Clean up old completed/failed jobs"""
        cutoff_date = datetime.now() - timedelta(days=days)
        jobs_to_remove = []
        
        for job_id, job in self._jobs.items():
            if (job.status in [JobStatus.COMPLETED, JobStatus.FAILED, JobStatus.CANCELLED] 
                and job.completed_at and job.completed_at < cutoff_date):
                jobs_to_remove.append(job_id)
        
        for job_id in jobs_to_remove:
            del self._jobs[job_id]
        
        logger.info(f"Cleaned up {len(jobs_to_remove)} old jobs")
        return len(jobs_to_remove)
    
    # Job handlers
    async def _handle_gmail_sync(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle Gmail sync job"""
        try:
            connector = get_gmail_connector()
            max_results = job.payload.get('max_results', 10)
            since_hours = job.payload.get('since_hours', 72)
            
            # Check if user has Gmail enabled
            db = get_db_session()
            config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == job.user_id,
                ConnectorConfig.connector_type == "gmail",
                ConnectorConfig.is_enabled == True
            ).first()
            
            if not config:
                raise Exception("Gmail connector not enabled for user")
            
            # Fetch emails
            emails = await connector.fetch_emails(
                job.user_id, max_results=max_results, since_hours=since_hours
            )
            
            # Process emails into feed items
            feed_items = []
            for email in emails:
                feed_item = connector.process_email(email, job.user_id)
                if feed_item:
                    feed_items.append(feed_item)
            
            # Save feed items
            saved_items = connector.save_feed_items_with_embeddings(feed_items)
            
            db.close()
            
            return {
                'emails_fetched': len(emails),
                'feed_items_created': len(saved_items),
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"Gmail sync failed for user {job.user_id}: {e}")
            raise
    
    async def _handle_news_sync(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle news sync job"""
        try:
            connector = get_news_connector()
            sources = job.payload.get('sources', ['rss', 'newsapi'])
            query = job.payload.get('query', '')
            
            # Fetch news articles
            articles = await connector.fetch_news(
                sources=sources, query=query
            )
            
            # Process articles into feed items
            feed_items = []
            for article in articles:
                feed_item = connector.process_article(article, job.user_id)
                if feed_item:
                    feed_items.append(feed_item)
            
            # Save feed items
            saved_items = connector.save_feed_items_with_embeddings(feed_items)
            
            return {
                'articles_fetched': len(articles),
                'feed_items_created': len(saved_items),
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"News sync failed for user {job.user_id}: {e}")
            raise
    
    async def _handle_reddit_sync(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle Reddit sync job"""
        try:
            connector = get_reddit_connector()
            subreddits = job.payload.get('subreddits', ['programming', 'MachineLearning'])
            max_posts = job.payload.get('max_posts_per_subreddit', 5)
            
            # Fetch Reddit posts
            posts = await connector.fetch_posts(
                subreddits=subreddits, max_posts_per_subreddit=max_posts
            )
            
            # Process posts into feed items
            feed_items = []
            for post in posts:
                feed_item = connector.process_post(post, job.user_id)
                if feed_item:
                    feed_items.append(feed_item)
            
            # Save feed items
            saved_items = connector.save_feed_items_with_embeddings(feed_items)
            
            return {
                'posts_fetched': len(posts),
                'feed_items_created': len(saved_items),
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"Reddit sync failed for user {job.user_id}: {e}")
            raise
    
    async def _handle_whatsapp_sync(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle WhatsApp sync job"""
        try:
            connector = get_whatsapp_connector()
            
            # This would typically process notification data or chat exports
            # For now, return a placeholder result
            return {
                'messages_processed': 0,
                'feed_items_created': 0,
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"WhatsApp sync failed for user {job.user_id}: {e}")
            raise
    
    async def _handle_cleanup_old_data(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle cleanup of old data"""
        try:
            db = get_db_session()
            days_to_keep = job.payload.get('days_to_keep', 30)
            cutoff_date = datetime.now() - timedelta(days=days_to_keep)
            
            # Delete old feed items
            old_items = db.query(FeedItem).filter(
                FeedItem.created_at < cutoff_date
            ).all()
            
            deleted_count = 0
            for item in old_items:
                db.delete(item)
                deleted_count += 1
            
            db.commit()
            db.close()
            
            return {
                'items_deleted': deleted_count,
                'cutoff_date': cutoff_date.isoformat(),
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"Cleanup failed: {e}")
            raise
    
    async def _handle_rebuild_vector_index(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle vector index rebuild"""
        try:
            # TODO: Implement vector index rebuild
            return {
                'index_rebuilt': True,
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"Vector index rebuild failed: {e}")
            raise
    
    async def _handle_user_personalization_update(self, job: BackgroundJob) -> Dict[str, Any]:
        """Handle user personalization update"""
        try:
            # TODO: Implement personalization update
            return {
                'personalization_updated': True,
                'status': 'success'
            }
            
        except Exception as e:
            logger.error(f"Personalization update failed: {e}")
            raise


class BackgroundWorker:
    """Background worker that processes jobs"""
    
    def __init__(self, job_queue: JobQueue):
        self.job_queue = job_queue
        self.is_running = False
        self._worker_task: Optional[asyncio.Task] = None
    
    async def start(self):
        """Start the background worker"""
        if self.is_running:
            return
        
        self.is_running = True
        self._worker_task = asyncio.create_task(self._worker_loop())
        logger.info("Background worker started")
    
    async def stop(self):
        """Stop the background worker"""
        self.is_running = False
        if self._worker_task:
            self._worker_task.cancel()
            try:
                await self._worker_task
            except asyncio.CancelledError:
                pass
        logger.info("Background worker stopped")
    
    async def _worker_loop(self):
        """Main worker loop"""
        while self.is_running:
            try:
                # Get next job
                job = self.job_queue.get_next_job()
                
                if job is None:
                    # No jobs available, wait a bit
                    await asyncio.sleep(5)
                    continue
                
                # Start the job
                self.job_queue.start_job(job)
                
                # Process the job
                try:
                    handler = self.job_queue._job_handlers.get(job.job_type)
                    if handler:
                        result = await handler(job)
                        self.job_queue.complete_job(job, result)
                    else:
                        raise Exception(f"No handler for job type: {job.job_type}")
                        
                except Exception as e:
                    self.job_queue.fail_job(job, str(e))
                
            except Exception as e:
                logger.error(f"Worker loop error: {e}")
                await asyncio.sleep(5)


# Global instances
_job_queue = JobQueue()
_background_worker = BackgroundWorker(_job_queue)


def get_job_queue() -> JobQueue:
    """Get the global job queue instance"""
    return _job_queue


def get_background_worker() -> BackgroundWorker:
    """Get the global background worker instance"""
    return _background_worker


def create_job(job_type: JobType, user_id: int, payload: Dict[str, Any], 
               priority: int = 0) -> BackgroundJob:
    """Create a new background job"""
    job_id = str(uuid.uuid4())
    return BackgroundJob(job_id, job_type, user_id, payload, priority)


async def start_background_worker():
    """Start the background worker"""
    await _background_worker.start()


async def stop_background_worker():
    """Stop the background worker"""
    await _background_worker.stop()

