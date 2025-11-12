from typing import Any, Dict

from ..core.nosql import store


def store_enhanced_notification(notification: Dict[str, Any], analysis: Dict[str, Any]) -> int:
    record = {
        "app_name": notification.get("app_name"),
        "title": notification.get("title"),
        "message": notification.get("message"),
        "timestamp": notification.get("timestamp"),
        "priority": analysis.get("priority"),
        "category": analysis.get("category"),
        "is_relevant": analysis.get("is_relevant"),
        "summary": analysis.get("summary"),
        "updated_at": __import__("time").time(),
    }
    # Persist under feed_items for downstream sync and querying
    new_id = store.insert("feed_items", record)
    return new_id


