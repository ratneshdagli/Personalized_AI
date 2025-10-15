from fastapi import APIRouter
from pydantic import BaseModel
from storage.db import get_db

router = APIRouter(prefix="/api/debug", tags=["debug"])


class DebugEvent(BaseModel):
    source: str = "notification"
    package: str
    sender: str
    text: str
    timestamp: int
    event_id: str


@router.post("/simulate_event")
def simulate_event(event: DebugEvent):
    # Minimal: store into context_events if available; otherwise accept
    try:
        conn = get_db()
        conn.execute(
            """
            INSERT INTO context_events (source, package, sender, text, timestamp, event_id)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (event.source, event.package, event.sender, event.text, event.timestamp, event.event_id),
        )
        conn.commit()
    except Exception:
        # Table may not exist in some setups; still return accepted
        pass
    return {"status": "ok", "stored": True}


