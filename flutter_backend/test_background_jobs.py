"""
Test Background Jobs

Tests for background job queue and worker functionality.
"""

import unittest
import asyncio
import os
import sys
from unittest.mock import Mock, patch
from datetime import datetime, timedelta

# Add the parent directory to the path so we can import our modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.background_jobs import (
    JobQueue, BackgroundJob, JobType, JobStatus, BackgroundWorker,
    create_job, get_job_queue
)


class TestBackgroundJobs(unittest.TestCase):
    """Test cases for background jobs"""
    
    def setUp(self):
        """Set up test environment"""
        self.job_queue = JobQueue()
    
    def test_create_job(self):
        """Test job creation"""
        job = create_job(
            job_type=JobType.GMAIL_SYNC,
            user_id=1,
            payload={'max_results': 10},
            priority=1
        )
        
        self.assertEqual(job.job_type, JobType.GMAIL_SYNC)
        self.assertEqual(job.user_id, 1)
        self.assertEqual(job.payload['max_results'], 10)
        self.assertEqual(job.priority, 1)
        self.assertEqual(job.status, JobStatus.PENDING)
        self.assertIsNotNone(job.job_id)
        self.assertIsNotNone(job.created_at)
    
    def test_enqueue_job(self):
        """Test job enqueuing"""
        job = create_job(JobType.GMAIL_SYNC, 1, {})
        
        success = self.job_queue.enqueue_job(job)
        self.assertTrue(success)
        
        # Check job is in queue
        retrieved_job = self.job_queue.get_job_status(job.job_id)
        self.assertIsNotNone(retrieved_job)
        self.assertEqual(retrieved_job.job_id, job.job_id)
    
    def test_get_next_job(self):
        """Test getting next job"""
        # Create jobs with different priorities
        job1 = create_job(JobType.GMAIL_SYNC, 1, {}, priority=1)
        job2 = create_job(JobType.NEWS_SYNC, 1, {}, priority=2)
        job3 = create_job(JobType.REDDIT_SYNC, 1, {}, priority=0)
        
        self.job_queue.enqueue_job(job1)
        self.job_queue.enqueue_job(job2)
        self.job_queue.enqueue_job(job3)
        
        # Should get highest priority job first
        next_job = self.job_queue.get_next_job()
        self.assertEqual(next_job.job_id, job2.job_id)
        
        # Start the job
        self.job_queue.start_job(job2)
        
        # Should get next highest priority job
        next_job = self.job_queue.get_next_job()
        self.assertEqual(next_job.job_id, job1.job_id)
    
    def test_job_lifecycle(self):
        """Test complete job lifecycle"""
        job = create_job(JobType.GMAIL_SYNC, 1, {})
        
        # Enqueue
        self.job_queue.enqueue_job(job)
        self.assertEqual(job.status, JobStatus.PENDING)
        
        # Start
        self.job_queue.start_job(job)
        self.assertEqual(job.status, JobStatus.RUNNING)
        self.assertIsNotNone(job.started_at)
        
        # Complete
        result = {'emails_fetched': 5}
        self.job_queue.complete_job(job, result)
        self.assertEqual(job.status, JobStatus.COMPLETED)
        self.assertIsNotNone(job.completed_at)
        self.assertEqual(job.result, result)
    
    def test_job_failure(self):
        """Test job failure handling"""
        job = create_job(JobType.GMAIL_SYNC, 1, {})
        
        self.job_queue.enqueue_job(job)
        self.job_queue.start_job(job)
        
        error_message = "Connection failed"
        self.job_queue.fail_job(job, error_message)
        
        self.assertEqual(job.status, JobStatus.FAILED)
        self.assertEqual(job.error_message, error_message)
        self.assertIsNotNone(job.completed_at)
    
    def test_job_cancellation(self):
        """Test job cancellation"""
        job = create_job(JobType.GMAIL_SYNC, 1, {})
        
        self.job_queue.enqueue_job(job)
        
        # Cancel pending job
        success = self.job_queue.cancel_job(job.job_id)
        self.assertTrue(success)
        self.assertEqual(job.status, JobStatus.CANCELLED)
        
        # Try to cancel non-existent job
        success = self.job_queue.cancel_job("non-existent")
        self.assertFalse(success)
    
    def test_get_user_jobs(self):
        """Test getting jobs for a specific user"""
        # Create jobs for different users
        job1 = create_job(JobType.GMAIL_SYNC, 1, {})
        job2 = create_job(JobType.NEWS_SYNC, 1, {})
        job3 = create_job(JobType.REDDIT_SYNC, 2, {})
        
        self.job_queue.enqueue_job(job1)
        self.job_queue.enqueue_job(job2)
        self.job_queue.enqueue_job(job3)
        
        # Get jobs for user 1
        user_jobs = self.job_queue.get_user_jobs(1)
        self.assertEqual(len(user_jobs), 2)
        
        # Get jobs for user 2
        user_jobs = self.job_queue.get_user_jobs(2)
        self.assertEqual(len(user_jobs), 1)
        
        # Get jobs for non-existent user
        user_jobs = self.job_queue.get_user_jobs(999)
        self.assertEqual(len(user_jobs), 0)
    
    def test_cleanup_old_jobs(self):
        """Test cleanup of old jobs"""
        # Create completed job
        job = create_job(JobType.GMAIL_SYNC, 1, {})
        job.status = JobStatus.COMPLETED
        job.completed_at = datetime.now() - timedelta(days=10)
        
        self.job_queue.enqueue_job(job)
        
        # Cleanup jobs older than 7 days
        cleaned_count = self.job_queue.cleanup_old_jobs(days=7)
        self.assertEqual(cleaned_count, 1)
        
        # Job should be removed
        retrieved_job = self.job_queue.get_job_status(job.job_id)
        self.assertIsNone(retrieved_job)
    
    @patch('services.background_jobs.get_gmail_connector')
    def test_gmail_sync_handler(self, mock_connector):
        """Test Gmail sync job handler"""
        # Mock connector
        mock_connector_instance = Mock()
        mock_connector.return_value = mock_connector_instance
        
        # Mock email fetching
        mock_emails = [
            {'id': '1', 'subject': 'Test Email', 'body': 'Test content'},
            {'id': '2', 'subject': 'Another Email', 'body': 'More content'}
        ]
        mock_connector_instance.fetch_emails.return_value = mock_emails
        
        # Mock feed item processing
        mock_feed_item = Mock()
        mock_feed_item.id = 1
        mock_connector_instance.process_email.return_value = mock_feed_item
        mock_connector_instance.save_feed_items_with_embeddings.return_value = [mock_feed_item]
        
        # Create and process job
        job = create_job(
            JobType.GMAIL_SYNC, 
            1, 
            {'max_results': 10, 'since_hours': 72}
        )
        
        # Mock database query
        with patch('services.background_jobs.get_db_session') as mock_db:
            mock_session = Mock()
            mock_db.return_value = mock_session
            
            mock_config = Mock()
            mock_config.enabled = True
            mock_session.query.return_value.filter.return_value.first.return_value = mock_config
            
            # Run handler
            async def run_test():
                result = await self.job_queue._handle_gmail_sync(job)
                return result
            
            result = asyncio.run(run_test())
            
            self.assertEqual(result['emails_fetched'], 2)
            self.assertEqual(result['feed_items_created'], 2)
            self.assertEqual(result['status'], 'success')


def run_background_job_tests():
    """Run all background job tests"""
    print("[TEST] Running Background Job Tests...")
    
    # Create test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(TestBackgroundJobs)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print results
    if result.wasSuccessful():
        print("[SUCCESS] All background job tests passed!")
        return True
    else:
        print(f"[FAILED] {len(result.failures)} test(s) failed, {len(result.errors)} error(s)")
        for failure in result.failures:
            print(f"FAIL: {failure[0]}")
            print(f"  {failure[1]}")
        for error in result.errors:
            print(f"ERROR: {error[0]}")
            print(f"  {error[1]}")
        return False


if __name__ == "__main__":
    run_background_job_tests()

