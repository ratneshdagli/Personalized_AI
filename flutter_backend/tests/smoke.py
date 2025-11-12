import requests

BASE = "http://localhost:8000"

def main():
    print("GET /api/health", requests.get(f"{BASE}/api/health").json())
    ing = {
        "app_name": "Calendar",
        "title": "Reminder",
        "message": "Meet at 5",
        "timestamp": "2025-10-16T16:00:00Z"
    }
    print("POST /api/ingest/context_event", requests.post(f"{BASE}/api/ingest/context_event", json=ing).json())
    up = {"tasks":[{"client_id":"t1","text":"demo","verb":"do","updated_at":1730000000}]}
    print("POST /api/sync/upload", requests.post(f"{BASE}/api/sync/upload", json=up).json())
    print("GET /api/sync/download", requests.get(f"{BASE}/api/sync/download?since=0").json())

if __name__ == "__main__":
    main()


