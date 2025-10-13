from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from services.context_processor import process_context_event

router = APIRouter(prefix="/api", tags=["context_ingest"])


class ContextEvent(BaseModel):
    user_id: str = Field(...)
    package: str = Field(...)
    title: Optional[str] = None
    text: Optional[str] = None
    timestamp: Optional[str] = None
    source: str = Field(..., pattern=r"^(notification|accessibility)$")
    meta: Dict[str, Any] = Field(default_factory=dict)
    user_opt_in_raw: Optional[bool] = False
    local_only: Optional[bool] = None  # client can override; otherwise use server policy


@router.post("/ingest/context_event")
async def ingest_context_event(event: ContextEvent):
    try:
        result = await process_context_event(event)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


