import os
os.environ["BACKEND_STORAGE"] = "memory"

from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


def test_health():
    r = client.get("/api/health")
    assert r.status_code == 200


def test_ingest_missing_text():
    payload = {
        "app_name": "Calendar",
        "title": "Reminder",
        # "message" missing
        "timestamp": "2025-10-16T16:00:00Z"
    }
    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 422


def test_ingest_valid():
    payload = {
        "app_name": "Calendar",
        "title": "Reminder",
        "message": "Meet at 5",
        "timestamp": "2025-10-16T16:00:00Z"
    }
    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code in (200, 201)
    data = r.json()
    assert "id" in data or "analysis" in data


