from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.feed import router as feed_router
from routes.tasks import router as tasks_router
from routes.search import router as search_router
from routes.feedback import router as feedback_router
from routes.gmail import router as gmail_router
from routes.news import router as news_router
from routes.reddit import router as reddit_router
try:
    from routes.whatsapp import router as whatsapp_router
except Exception:
    whatsapp_router = None
from routes.jobs import router as jobs_router
from routes.instagram import router as instagram_router
from routes.telegram import router as telegram_router
from routes.calendar import router as calendar_router
from storage.db import init_db
from dotenv import load_dotenv
import os

# ✅ Load environment variables from .env
load_dotenv()

app = FastAPI(title="Personal AI Feed Backend")

# ✅ Verify env variables loaded correctly
if not os.getenv("GROQ_API_KEY"):
    print("⚠️ Warning: GROQ_API_KEY not found in environment. LLM features may not work.")
else:
    print("✅ GROQ_API_KEY loaded successfully!")

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    init_db()
    
    # Start background worker
    from services.background_jobs import start_background_worker
    await start_background_worker()

# Include the routers
app.include_router(feed_router, prefix="/api")
app.include_router(tasks_router, prefix="/api")
app.include_router(search_router, prefix="/api")
app.include_router(feedback_router, prefix="/api")
app.include_router(gmail_router, prefix="/api")
app.include_router(news_router, prefix="/api")
app.include_router(reddit_router, prefix="/api")
if whatsapp_router is not None:
    app.include_router(whatsapp_router, prefix="/api")
else:
    print("⚠️ WhatsApp routes are deprecated and disabled in favor of Notification+Accessibility pipeline.")
from routes.context_ingest import router as context_router
app.include_router(context_router)
app.include_router(jobs_router, prefix="/api")
app.include_router(instagram_router, prefix="/api")
app.include_router(telegram_router, prefix="/api")
app.include_router(calendar_router, prefix="/api")

# CORS (dev-friendly defaults; restrict in production)
allowed_origins = [
    "http://localhost",
    "http://localhost:80",
    "http://localhost:8080",
    "http://localhost:3000",
    "http://127.0.0.1",
    "http://127.0.0.1:80",
    "http://127.0.0.1:8080",
    "http://10.0.2.2:8000",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins + ["*"],  # allow all during development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Root endpoint
@app.get("/")
def root():
    return {"message": "Welcome to Personal AI Feed Backend!"}

# Health endpoint for container health checks
@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
