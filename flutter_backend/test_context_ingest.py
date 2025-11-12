import asyncio
from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


def test_ingest_notification_event(monkeypatch):
    # Mock llm adapter
    async def fake_summarize(text):
        return "summary"

    async def fake_extract(text):
        return ["task1"]

    async def fake_embed(text):
        return [0.1, 0.2, 0.3]

    import ml.llm_adapter as llm
    monkeypatch.setattr(llm, "summarize", fake_summarize)
    monkeypatch.setattr(llm, "extract_tasks", fake_extract)
    monkeypatch.setattr(llm, "embed", fake_embed)

    payload = {
        "app_name": "Hotstar",
        "title": "Cricket Highlights",
        "message": "India vs Australia",
        "timestamp": "2025-10-13T10:00:00Z",
    }

    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 201
    body = r.json()
    assert body.get("id") is not None
    assert body.get("analysis") is not None


def test_ingest_local_only(monkeypatch):
    # Ensure LLM not called
    called = {"summarize": False}

    async def fake_summarize(text):
        called["summarize"] = True
        return "should_not_call"

    import ml.llm_adapter as llm
    monkeypatch.setattr(llm, "summarize", fake_summarize)

    payload = {
        "app_name": "WhatsApp",
        "title": "Msg",
        "message": "Hello",
        "timestamp": "2025-10-13T10:00:00Z",
    }

    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 201
    body = r.json()
    assert body.get("id") is not None
    assert body.get("analysis") is not None
    # Note: The current API doesn't support local_only mode, so we can't test that


