import asyncio
from fastapi.testclient import TestClient
from main import app


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
        "user_id": "test",
        "package": "com.hotstar",
        "title": "Cricket Highlights",
        "text": "India vs Australia",
        "timestamp": "2025-10-13T10:00:00Z",
        "source": "notification",
        "meta": {},
    }

    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 200
    body = r.json()
    assert body.get("feed_item_id") is not None
    assert body.get("status") == "queued"


def test_ingest_local_only(monkeypatch):
    # Ensure LLM not called
    called = {"summarize": False}

    async def fake_summarize(text):
        called["summarize"] = True
        return "should_not_call"

    import ml.llm_adapter as llm
    monkeypatch.setattr(llm, "summarize", fake_summarize)

    payload = {
        "user_id": "test",
        "package": "com.whatsapp",
        "title": "Msg",
        "text": "Hello",
        "timestamp": "2025-10-13T10:00:00Z",
        "source": "accessibility",
        "meta": {},
        "local_only": True,
    }

    r = client.post("/api/ingest/context_event", json=payload)
    assert r.status_code == 200
    body = r.json()
    assert body.get("feed_item_id") is not None
    assert body.get("status") == "queued"
    assert called["summarize"] is False


