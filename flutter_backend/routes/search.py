"""
Search endpoints for semantic search over feed items
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session

from storage.db import get_db
from storage.models import User, FeedItem
from storage.vector_store import get_vector_store
from nlp.embeddings import get_embeddings_pipeline

router = APIRouter()

class SearchRequest(BaseModel):
    query: str
    top_k: Optional[int] = 10
    threshold: Optional[float] = 0.0
    source_filter: Optional[str] = None  # Filter by source type

class SearchResult(BaseModel):
    id: int
    title: str
    summary: Optional[str]
    source: str
    date: str
    priority: str
    relevance_score: float
    similarity_score: float
    entities: List[str]
    has_tasks: bool

class SearchResponse(BaseModel):
    query: str
    results: List[SearchResult]
    total_found: int
    search_time_ms: float

@router.post("/search", response_model=SearchResponse)
async def semantic_search(
    request: SearchRequest,
    db: Session = Depends(get_db),
    # TODO: Add user authentication when implemented
    # current_user: User = Depends(get_current_user)
):
    """
    Perform semantic search over user's feed items
    
    Example request:
    {
        "query": "assignment due next week",
        "top_k": 5,
        "threshold": 0.3
    }
    """
    import time
    start_time = time.time()
    
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1  # This should come from authentication
        
        # Validate request
        if not request.query or not request.query.strip():
            raise HTTPException(status_code=400, detail="Query cannot be empty")
        
        if request.top_k and (request.top_k < 1 or request.top_k > 100):
            raise HTTPException(status_code=400, detail="top_k must be between 1 and 100")
        
        if request.threshold and (request.threshold < 0.0 or request.threshold > 1.0):
            raise HTTPException(status_code=400, detail="threshold must be between 0.0 and 1.0")
        
        # Get vector store
        vector_store = get_vector_store()
        
        # Perform semantic search
        search_results = vector_store.search(
            query=request.query,
            user_id=user_id,
            top_k=request.top_k or 10,
            threshold=request.threshold or 0.0
        )
        
        # Filter by source if specified
        if request.source_filter:
            search_results = [
                result for result in search_results
                if result["feed_item"].source.value == request.source_filter
            ]
        
        # Convert to response format
        results = []
        for result in search_results:
            feed_item = result["feed_item"]
            results.append(SearchResult(
                id=feed_item.id,
                title=feed_item.title,
                summary=feed_item.summary,
                source=feed_item.source.value,
                date=feed_item.date.isoformat(),
                priority=feed_item.priority.value,
                relevance_score=feed_item.relevance_score,
                similarity_score=result["similarity_score"],
                entities=feed_item.entities or [],
                has_tasks=feed_item.has_tasks
            ))
        
        search_time_ms = (time.time() - start_time) * 1000
        
        return SearchResponse(
            query=request.query,
            results=results,
            total_found=len(results),
            search_time_ms=search_time_ms
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/search/suggestions")
async def get_search_suggestions(
    query: str = Query(..., min_length=1),
    limit: int = Query(5, ge=1, le=20),
    db: Session = Depends(get_db)
):
    """
    Get search suggestions based on existing feed items
    """
    try:
        # For now, use a default user (TODO: implement proper authentication)
        user_id = 1
        
        # Get recent feed items for suggestions
        recent_items = db.query(FeedItem).filter(
            FeedItem.user_id == user_id,
            FeedItem.title.ilike(f"%{query}%")
        ).order_by(FeedItem.date.desc()).limit(limit).all()
        
        suggestions = []
        for item in recent_items:
            suggestions.append({
                "text": item.title,
                "source": item.source.value,
                "date": item.date.isoformat()
            })
        
        return {"suggestions": suggestions}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get suggestions: {str(e)}")

@router.get("/search/stats")
async def get_search_stats(db: Session = Depends(get_db)):
    """
    Get search and vector store statistics
    """
    try:
        vector_store = get_vector_store()
        embeddings_pipeline = get_embeddings_pipeline()
        
        # Get database stats
        total_feed_items = db.query(FeedItem).count()
        items_with_embeddings = db.query(FeedItem).filter(
            FeedItem.embedding.isnot(None)
        ).count()
        
        # Get vector store stats
        vector_stats = vector_store.get_stats()
        
        return {
            "database": {
                "total_feed_items": total_feed_items,
                "items_with_embeddings": items_with_embeddings,
                "embedding_coverage": items_with_embeddings / max(total_feed_items, 1)
            },
            "vector_store": vector_stats,
            "embeddings": {
                "dimension": embeddings_pipeline.get_embedding_dimension(),
                "model_available": embeddings_pipeline.model is not None
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get stats: {str(e)}")

@router.post("/search/rebuild-index")
async def rebuild_search_index(
    db: Session = Depends(get_db)
    # TODO: Add admin authentication
    # current_user: User = Depends(get_current_admin_user)
):
    """
    Rebuild the vector search index
    Admin endpoint - requires authentication
    """
    try:
        vector_store = get_vector_store()
        
        # Rebuild index
        vector_store.rebuild_index()
        
        return {"message": "Vector index rebuilt successfully"}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to rebuild index: {str(e)}")


