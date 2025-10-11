# Personalized AI - Backend (FastAPI)

Minimal FastAPI backend used for serving a mock feed.

Run locally:

```bash
python -m pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Endpoints:
- GET /healthz -> health check
- GET /feed/ -> returns mock feed items
