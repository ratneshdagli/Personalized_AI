"""
Background Jobs API Routes

Provides endpoints for managing background jobs and monitoring job status.
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import logging

from services.background_jobs import (
    get_job_queue, create_job, JobType, JobStatus, BackgroundJob
)

logger = logging.getLogger(__name__)

router = APIRouter()


class JobRequest(BaseModel):
    """Request model for creating jobs"""
    job_type: str
    user_id: int
    payload: Dict[str, Any] = {}
    priority: int = 0


class JobResponse(BaseModel):
    """Response model for job information"""
    job_id: str
    job_type: str
    user_id: int
    status: str
    priority: int
    created_at: str
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error_message: Optional[str] = None
    result: Optional[Dict[str, Any]] = None


class JobListResponse(BaseModel):
    """Response model for job list"""
    jobs: List[JobResponse]
    total: int


@router.post("/jobs/create")
async def create_background_job(request: JobRequest):
    """
    Create a new background job
    """
    try:
        # Validate job type
        try:
            job_type = JobType(request.job_type)
        except ValueError:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid job type: {request.job_type}"
            )
        
        # Create job
        job = create_job(
            job_type=job_type,
            user_id=request.user_id,
            payload=request.payload,
            priority=request.priority
        )
        
        # Enqueue job
        job_queue = get_job_queue()
        success = job_queue.enqueue_job(job)
        
        if not success:
            raise HTTPException(
                status_code=500,
                detail="Failed to enqueue job"
            )
        
        return {
            "message": "Job created successfully",
            "job_id": job.job_id,
            "job_type": job.job_type.value,
            "status": job.status.value
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating job: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating job: {str(e)}")


@router.get("/jobs/{job_id}")
async def get_job_status(job_id: str):
    """
    Get status of a specific job
    """
    try:
        job_queue = get_job_queue()
        job = job_queue.get_job_status(job_id)
        
        if not job:
            raise HTTPException(status_code=404, detail="Job not found")
        
        return _job_to_response(job)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting job status: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting job status: {str(e)}")


@router.get("/jobs/user/{user_id}")
async def get_user_jobs(user_id: int, limit: int = 50):
    """
    Get jobs for a specific user
    """
    try:
        job_queue = get_job_queue()
        jobs = job_queue.get_user_jobs(user_id, limit)
        
        job_responses = [_job_to_response(job) for job in jobs]
        
        return JobListResponse(
            jobs=job_responses,
            total=len(job_responses)
        )
        
    except Exception as e:
        logger.error(f"Error getting user jobs: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting user jobs: {str(e)}")


@router.delete("/jobs/{job_id}")
async def cancel_job(job_id: str):
    """
    Cancel a job
    """
    try:
        job_queue = get_job_queue()
        success = job_queue.cancel_job(job_id)
        
        if not success:
            raise HTTPException(status_code=404, detail="Job not found or cannot be cancelled")
        
        return {
            "message": "Job cancelled successfully",
            "job_id": job_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error cancelling job: {e}")
        raise HTTPException(status_code=500, detail=f"Error cancelling job: {str(e)}")


@router.post("/jobs/sync/gmail")
async def trigger_gmail_sync(
    background_tasks: BackgroundTasks,
    user_id: int,
    max_results: int = 10,
    since_hours: int = 72
):
    """
    Trigger Gmail sync job
    """
    try:
        job = create_job(
            job_type=JobType.GMAIL_SYNC,
            user_id=user_id,
            payload={
                'max_results': max_results,
                'since_hours': since_hours
            },
            priority=1
        )
        
        job_queue = get_job_queue()
        success = job_queue.enqueue_job(job)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to enqueue Gmail sync job")
        
        return {
            "message": "Gmail sync job started",
            "job_id": job.job_id,
            "user_id": user_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error triggering Gmail sync: {e}")
        raise HTTPException(status_code=500, detail=f"Error triggering Gmail sync: {str(e)}")


@router.post("/jobs/sync/news")
async def trigger_news_sync(
    background_tasks: BackgroundTasks,
    user_id: int,
    sources: List[str] = ["rss", "newsapi"],
    query: str = ""
):
    """
    Trigger news sync job
    """
    try:
        job = create_job(
            job_type=JobType.NEWS_SYNC,
            user_id=user_id,
            payload={
                'sources': sources,
                'query': query
            },
            priority=1
        )
        
        job_queue = get_job_queue()
        success = job_queue.enqueue_job(job)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to enqueue news sync job")
        
        return {
            "message": "News sync job started",
            "job_id": job.job_id,
            "user_id": user_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error triggering news sync: {e}")
        raise HTTPException(status_code=500, detail=f"Error triggering news sync: {str(e)}")


@router.post("/jobs/sync/reddit")
async def trigger_reddit_sync(
    background_tasks: BackgroundTasks,
    user_id: int,
    subreddits: List[str] = ["programming", "MachineLearning"],
    max_posts_per_subreddit: int = 5
):
    """
    Trigger Reddit sync job
    """
    try:
        job = create_job(
            job_type=JobType.REDDIT_SYNC,
            user_id=user_id,
            payload={
                'subreddits': subreddits,
                'max_posts_per_subreddit': max_posts_per_subreddit
            },
            priority=1
        )
        
        job_queue = get_job_queue()
        success = job_queue.enqueue_job(job)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to enqueue Reddit sync job")
        
        return {
            "message": "Reddit sync job started",
            "job_id": job.job_id,
            "user_id": user_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error triggering Reddit sync: {e}")
        raise HTTPException(status_code=500, detail=f"Error triggering Reddit sync: {str(e)}")


@router.post("/jobs/cleanup")
async def trigger_cleanup_job(
    background_tasks: BackgroundTasks,
    days_to_keep: int = 30
):
    """
    Trigger cleanup job for old data
    """
    try:
        job = create_job(
            job_type=JobType.CLEANUP_OLD_DATA,
            user_id=0,  # System job
            payload={
                'days_to_keep': days_to_keep
            },
            priority=2
        )
        
        job_queue = get_job_queue()
        success = job_queue.enqueue_job(job)
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to enqueue cleanup job")
        
        return {
            "message": "Cleanup job started",
            "job_id": job.job_id,
            "days_to_keep": days_to_keep
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error triggering cleanup job: {e}")
        raise HTTPException(status_code=500, detail=f"Error triggering cleanup job: {str(e)}")


@router.get("/jobs/stats")
async def get_job_stats():
    """
    Get job queue statistics
    """
    try:
        job_queue = get_job_queue()
        
        # Count jobs by status
        status_counts = {}
        for job in job_queue._jobs.values():
            status = job.status.value
            status_counts[status] = status_counts.get(status, 0) + 1
        
        # Count running jobs
        running_count = len(job_queue._running_jobs)
        
        return {
            "total_jobs": len(job_queue._jobs),
            "running_jobs": running_count,
            "status_counts": status_counts,
            "worker_running": job_queue._background_worker.is_running if hasattr(job_queue, '_background_worker') else False
        }
        
    except Exception as e:
        logger.error(f"Error getting job stats: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting job stats: {str(e)}")


def _job_to_response(job: BackgroundJob) -> JobResponse:
    """Convert BackgroundJob to JobResponse"""
    return JobResponse(
        job_id=job.job_id,
        job_type=job.job_type.value,
        user_id=job.user_id,
        status=job.status.value,
        priority=job.priority,
        created_at=job.created_at.isoformat(),
        started_at=job.started_at.isoformat() if job.started_at else None,
        completed_at=job.completed_at.isoformat() if job.completed_at else None,
        error_message=job.error_message,
        result=job.result
    )


