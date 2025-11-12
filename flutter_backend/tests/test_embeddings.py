import os
os.environ["BACKEND_STORAGE"] = "memory"

from fastapi.testclient import TestClient
from app.main import app
from pathlib import Path
from app.core.nosql import store


client = TestClient(app)


def test_embedding_created_on_ingest(tmp_path):
    payload = {
        "id": "evt-123",
        "app_name": "Calendar",
        "title": "Reminder",
        "message": "Meet at 5",
        "timestamp": "2025-10-16T16:00:00Z"
    }
    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 201
    # Check vector file
    vectors_dir = Path(__file__).resolve().parents[2] / "vectors"
    vec_file = vectors_dir / "evt-123.npy"
    assert vec_file.exists()
    # Check metadata
    metas = store.vector_meta.search(lambda d: d.get("document_id") == "evt-123")
    assert metas


def test_embedding_upsert(tmp_path):
    payload = {
        "id": "evt-dup",
        "app_name": "Calendar",
        "title": "Reminder",
        "message": "foo",
        "timestamp": "2025-10-16T16:00:00Z"
    }
    r1 = client.post("/api/ingest/context_event", json=payload)
    assert r1.status_code == 201
    r2 = client.post("/api/ingest/context_event", json={**payload, "message": "foo updated"})
    assert r2.status_code == 201
    vectors_dir = Path(__file__).resolve().parents[2] / "vectors"
    vec_file = vectors_dir / "evt-dup.npy"
    assert vec_file.exists()
    metas = store.vector_meta.search(lambda d: d.get("document_id") == "evt-dup")
    assert metas


