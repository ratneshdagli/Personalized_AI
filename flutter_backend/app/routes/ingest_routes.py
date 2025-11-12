from fastapi import APIRouter, HTTPException
from fastapi import status

from ..models.notification_model import NotificationModel
from ..services.llm_service import analyze_notification
from ..services.notification_service import store_enhanced_notification
from ..core.nosql import store


router = APIRouter(prefix="/ingest", tags=["ingest"])


@router.post("/context_event", status_code=201)
def ingest_context_event(payload: NotificationModel):
    """Receive a notification payload, analyze via LLM, store, and return the result."""
    try:
        analysis = analyze_notification(payload.model_dump())
        # persist to NoSQL feed_items for sync later
        doc = {
            "app_name": payload.app_name,
            "title": payload.title,
            "message": payload.message,
            "timestamp": payload.timestamp,
            "priority": analysis.get("priority", 0.1),
            "category": analysis.get("category"),
            "is_relevant": analysis.get("is_relevant", False),
            "summary": analysis.get("summary"),
            "updated_at": __import__("time").time(),
        }
        new_id = store.insert("feed_items", doc)
        record_id = store_enhanced_notification(payload.model_dump(), analysis)
        return {"id": new_id, "analysis": analysis}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc))


