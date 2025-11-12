from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from routes.feed import router as feed_router
from routes.tasks import router as tasks_router
from routes.search import router as search_router
from routes.feedback import router as feedback_router
from routes.news import router as news_router
from routes.reddit import router as reddit_router
from routes.models import router as models_router
try:
    from routes.whatsapp import router as whatsapp_router
except Exception:
    whatsapp_router = None
from routes.jobs import router as jobs_router
from routes.instagram import router as instagram_router
from routes.telegram import router as telegram_router
from routes.calendar import router as calendar_router
from routes.debug import router as debug_router
from routes.todos import router as todos_router
from routes.events import router as events_router
from storage.db import init_db
from dotenv import load_dotenv
import os
import logging
import sys

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# ✅ Load environment variables from .env
load_dotenv()

app = FastAPI(
    title="Personal AI Feed Backend",
    description="Backend for the Personal AI application with model management",
    version="0.1.0",
    docs_url="/docs" if os.getenv("ENVIRONMENT", "development") != "production" else None,
    redoc_url="/redoc" if os.getenv("ENVIRONMENT", "development") != "production" else None
)

# Configure CORS with specific allowed origins
allowed_origins = [
    "http://localhost",
    "http://localhost:*",
    "http://127.0.0.1",
    "http://127.0.0.1:*",
    "http://192.168.*",
    "http://192.168.*:*",
    "https://*.vercel.app",
    "https://*.vercel.app:*",
    "https://*.netlify.app",
    "https://*.netlify.app:*",
    "http://192.168.29.143",
    "http://192.168.29.143:*",
    "http://192.168.29.143:8000",
    "http://192.168.29.143:8000/*"
]

# Allow all origins in development, but only specific ones in production
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if os.getenv("ENVIRONMENT") == "production" else ["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],  # Important for file downloads
)

# ✅ Verify env variables loaded correctly
if not os.getenv("GROQ_API_KEY"):
    print("Warning: GROQ_API_KEY not found in environment. LLM features may not work.")
else:
    print("GROQ_API_KEY loaded successfully!")

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
# The models_router has its own /models prefix, so we just mount it under /api/v1
app.include_router(models_router, prefix="/api/v1")
app.include_router(feedback_router, prefix="/api")
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
app.include_router(todos_router, prefix="/api")
app.include_router(events_router, prefix="/api")
app.include_router(debug_router)

# CORS configuration is handled at the top of the file

# Root endpoint
@app.get("/")
def root():
    return {"message": "Welcome to Personal AI Feed Backend!"}

# Health endpoint for container health checks
@app.get("/health")
def health():
    return {"status": "ok"}

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"message": "Internal server error"}
    )

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))  # Changed to 8000 as requested
    logger.info(f"Starting server on port {port}")
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
