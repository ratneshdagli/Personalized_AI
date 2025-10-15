from typing import Any, Dict
from storage.models import FeedItem, SourceType
from ml import llm_adapter
from storage.db import get_db_session
from storage.vector_store import add_embedding
from services.ranking import rerank_feed


async def process_context_event(event) -> Dict[str, Any]:
    # Decide local-only
    user_local_only = False
    if event.local_only is not None:
        user_local_only = bool(event.local_only)

    # Always normalize minimal metadata
    meta = {
        "package": event.package,
        "source": event.source,
        "timestamp": event.timestamp,
    }

    raw_text = (event.text or "").strip()
    if event.title:
        raw_text = (event.title + " " + raw_text).strip()

    summary = None
    tasks = []
    embedding = None

    if not user_local_only:
        # Server-side processing allowed; be fault-tolerant if LLM services are unavailable
        if raw_text:
            try:
                summary = await llm_adapter.summarize(raw_text)
            except Exception as e:
                print(f"context_processor: summarize error: {e}")
                summary = None
            try:
                tasks = await llm_adapter.extract_tasks(raw_text)
            except Exception as e:
                print(f"context_processor: extract_tasks error: {e}")
                tasks = []
            try:
                embedding = await llm_adapter.embed(raw_text)
            except Exception as e:
                print(f"context_processor: embed error: {e}")
                embedding = None
    else:
        # Local-only; do not keep raw text server-side
        raw_text = ""

    from datetime import datetime
    # Ensure we retain full original content for validation/UX
    # Robust defaults: don't crash on missing fields
    src = SourceType.NEWS if (getattr(event, "source", "notification") == "notification") else SourceType.INSTAGRAM
    safe_user_id = int(event.user_id) if str(event.user_id).isdigit() else 1
    safe_origin = f"ctx:{getattr(event, 'package', 'unknown')}:{getattr(event, 'timestamp', '0')}"
    safe_title = getattr(event, 'title', None) or (summary or getattr(event, 'sender', None) or "Context Event")

    feed_item = FeedItem(
        user_id=safe_user_id,
        source=src,
        origin_id=safe_origin,
        title=safe_title,
        summary=summary or "",
        text=raw_text or None,
        date=datetime.utcnow(),
        meta_data=meta,
        processed_locally=bool(getattr(event, 'local_only', False)),
    )

    db = get_db_session()
    try:
        db.add(feed_item)
        db.commit()
        db.refresh(feed_item)
        item_id = feed_item.id
    finally:
        db.close()

    if embedding is not None:
        add_embedding(item_id, embedding)

    # Trigger re-ranking
    try:
        rerank_feed(int(event.user_id) if str(event.user_id).isdigit() else 1)
    except Exception:
        pass

    return {"feed_item_id": item_id, "status": "queued"}


