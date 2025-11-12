from fastapi import APIRouter, HTTPException, Query
from typing import Any, Dict, List, Optional
from ..core.nosql import store


router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/upload", status_code=201)
def upload_documents(payload: Dict[str, List[Dict[str, Any]]]):
    """Accept Hive-like documents for feed_items, tasks, users (profile)."""
    results: Dict[str, List[Dict[str, Any]]] = {}
    for collection in ["feed_items", "tasks", "users"]:
        items = payload.get(collection, []) or []
        out: List[Dict[str, Any]] = []
        for doc in items:
            try:
                # Upsert by client-provided id if present, else insert new
                key = "client_id" if "client_id" in doc else "id"
                doc["updated_at"] = doc.get("updated_at") or __import__("time").time()
                new_id = store.upsert(collection, doc, key)
                out.append({"status": "ok", "id": new_id})
            except Exception as e:
                out.append({"status": "error", "error": str(e)})
        results[collection] = out
    return {"result": results}


@router.get("/download")
def download_documents(since: Optional[float] = Query(None)):
    return {
        "feed_items": store.find_since("feed_items", "updated_at", since),
        "tasks": store.find_since("tasks", "updated_at", since),
        "users": store.find_since("users", "updated_at", since),
    }


