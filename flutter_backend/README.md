# Personalized AI Companion Backend (FastAPI)

Run locally:

```bash
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

Environment (.env optional):

```
GROQ_API_KEY=your_api_key_here
BACKEND_PORT=8000
```

Key endpoints:
- GET `/api/health` → {"status":"ok"}
- POST `/api/ingest/context_event` → accepts notification JSON, calls LLM, stores
- GET/POST `/api/user/profile` → manage persona data
