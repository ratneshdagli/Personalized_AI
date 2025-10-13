"""
Database configuration and session management
Supports both SQLite (development) and PostgreSQL (production)
"""

import os
from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
import logging

logger = logging.getLogger(__name__)

# Database URL configuration
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./personalized_ai_feed.db")

# Create engine with appropriate configuration
if DATABASE_URL.startswith("sqlite"):
    # SQLite configuration for development
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=os.getenv("DB_ECHO", "false").lower() == "true"
    )
else:
    # PostgreSQL configuration for production
    engine = create_engine(
        DATABASE_URL,
        echo=os.getenv("DB_ECHO", "false").lower() == "true",
        pool_pre_ping=True,
        pool_recycle=300
    )

# Create session factory
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create base class for models
Base = declarative_base()

# Metadata for migrations
metadata = MetaData()

def get_db() -> Session:
    """
    Dependency to get database session
    Use with FastAPI Depends()
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    """
    Initialize database tables
    Call this on startup
    """
    try:
        # Import all models to ensure they're registered
        from .models import User, FeedItem, Task, UserProfile, ConnectorConfig
        
        # Create all tables
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
        
        # Create default admin user if none exists
        db = SessionLocal()
        try:
            from .models import User
            admin_user = db.query(User).filter(User.email == "admin@example.com").first()
            if not admin_user:
                admin_user = User(
                    email="admin@example.com",
                    name="Admin User",
                    is_active=True,
                    is_admin=True
                )
                db.add(admin_user)
                db.commit()
                logger.info("Default admin user created")
        finally:
            db.close()
            
    except Exception as e:
        logger.error(f"Failed to initialize database: {e}")
        raise

def get_db_session() -> Session:
    """
    Get a database session for direct use
    Remember to close it when done
    """
    return SessionLocal()

# Database health check
from sqlalchemy import text

def check_db_health() -> bool:
    try:
        db = SessionLocal()
        db.execute(text("SELECT 1"))  # must wrap in text()
        db.close()
        return True
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return False



