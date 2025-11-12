import os
os.environ["BACKEND_STORAGE"] = "memory"

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_sync_upload_download_cycle():
    up = {"tasks": [
        {"client_id": "t1", "verb": "do", "text": "demo1", "updated_at": 1000},
        {"client_id": "t2", "verb": "do", "text": "demo2", "updated_at": 2000},
    ]}
    r = client.post("/api/sync/upload", json=up)
    assert r.status_code == 201
    res = r.json()["result"]["tasks"]
    assert all(item["status"] == "ok" for item in res)

    r2 = client.get("/api/sync/download", params={"since": 1500})
    assert r2.status_code == 200
    data = r2.json()
    tasks = data.get("tasks", [])
    assert any(t["text"] == "demo2" for t in tasks)
    assert not any(t.get("text") == "demo1" for t in tasks)


