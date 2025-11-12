from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import settings
from .core.database import init_db
from .routes.sync_routes import router as sync_router
from .routes.health_routes import router as health_router
from .routes.ingest_routes import router as ingest_router
from .routes.user_routes import router as user_router
from .core.validation_logging import validation_exception_handler
from fastapi.exceptions import RequestValidationError


app = FastAPI(title="Personalized AI Companion Backend")
app.add_exception_handler(RequestValidationError, validation_exception_handler)


@app.on_event("startup")
async def on_startup() -> None:
    init_db()


app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins + ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(health_router, prefix="/api")
app.include_router(ingest_router, prefix="/api")
app.include_router(user_router, prefix="/api")
app.include_router(sync_router, prefix="/api")


@app.get("/")
def root():
    return {"message": "Welcome to Personalized AI Companion Backend"}


