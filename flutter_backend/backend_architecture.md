# Backend Architecture (NoSQL & Hive-first)

## Overview
- Mobile app stores canonical user data locally in Hive (on-device, offline-first).
- Backend is a lightweight NoSQL mirror and sync peer using TinyDB (file-backed JSON) for local dev and simple hosting.
- Embedding/vector metadata stored in a `vector_meta` collection; vector index files live under `vectors/`.

## Storage
- NoSQL implementation: TinyDB with CachingMiddleware (file: `personalized_ai_nosql.json`).
- Collections: `users`, `feed_items`, `tasks`, `connectors`, `vector_meta`.
- In-memory mode for tests: set `BACKEND_STORAGE=memory`.

## Sync API
- POST `/api/sync/upload` → accept arrays of documents (e.g., `tasks`, `feed_items`, `users`). Upsert by `client_id` if present, else by `id`. Returns status per item.
- GET `/api/sync/download?since=<epoch_seconds>` → returns documents changed since timestamp.
- POST `/api/profile` → upsert user profile (compatible with `users` collection).

### Document shapes (minimal)
- feed_items:
```json
{
  "id": 1,
  "app_name": "Calendar",
  "title": "Reminder",
  "message": "Meet at 5",
  "timestamp": "2025-10-16T16:00:00Z",
  "priority": 0.7,
  "category": "Event",
  "summary": "...",
  "updated_at": 1730000000
}
```
- tasks:
```json
{
  "id": 1,
  "client_id": "task-local-123",
  "verb": "do",
  "text": "Submit report",
  "due_date": "2025-10-20T09:00:00Z",
  "is_completed": false,
  "updated_at": 1730000000
}
```
- users (profile):
```json
{
  "id": 1,
  "name": "Alex",
  "email": "alex@example.com",
  "preferences": {},
  "persona": {},
  "updated_at": 1730000000
}
```

## LLM & Embeddings
- LLM analysis (Groq) remains; analyzed notifications are saved into `feed_items` with `updated_at`.
- Embedding metadata for documents saved in `vector_meta` and any vector index in `vectors/`.

## Validation Logging
- Request validation errors are logged to `logs/validation.log` with timestamp, path, headers (non-sensitive), raw body, and errors.

## Run
```bash
python -m pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## Tests
- Smoke script: `python tests/smoke.py` (ensure server is running).
- Pytest (in-memory):
```bash
set BACKEND_STORAGE=memory
pytest -q
```

## Mapping Hive boxes → backend collections
- Hive `feed_items` → NoSQL `feed_items`
- Hive `tasks` → NoSQL `tasks`
- Hive `settings` / user profile → NoSQL `users`
