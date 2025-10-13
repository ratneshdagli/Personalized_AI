"""
SQLAlchemy models for the Personalized AI Feed system
"""

from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, Float, ForeignKey, JSON, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import enum
from .db import Base

class SourceType(enum.Enum):
    """Enum for different content sources"""
    GMAIL = "gmail"
    REDDIT = "reddit"
    NEWS = "news"
    WHATSAPP = "whatsapp"
    INSTAGRAM = "instagram"
    TELEGRAM = "telegram"
    CALENDAR = "calendar"

class PriorityLevel(enum.Enum):
    """Enum for priority levels"""
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    URGENT = 4

class User(Base):
    """User model for authentication and personalization"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    profile = relationship("UserProfile", back_populates="user", uselist=False)
    feed_items = relationship("FeedItem", back_populates="user")
    tasks = relationship("Task", back_populates="user")
    connector_configs = relationship("ConnectorConfig", back_populates="user")

class UserProfile(Base):
    """User personalization profile"""
    __tablename__ = "user_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Personalization data
    important_keywords = Column(JSON, default=list)  # List of important keywords
    important_contacts = Column(JSON, default=list)  # List of important email addresses/contacts
    preferred_sources = Column(JSON, default=list)   # List of preferred source types
    feedback_history = Column(JSON, default=list)    # List of feedback items
    
    # Privacy settings
    local_only_mode = Column(Boolean, default=False)  # Process on-device only
    allow_llm_processing = Column(Boolean, default=True)  # Allow sending to Groq/HF
    
    # Ranking weights (user-specific overrides)
    ranking_weights = Column(JSON, default=dict)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="profile")

# FeedItem model: metadata renamed to meta_data
class FeedItem(Base):
    __tablename__ = "feed_items"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Content metadata
    source = Column(Enum(SourceType), nullable=False)
    origin_id = Column(String(255), nullable=False)
    title = Column(String(500), nullable=False)
    summary = Column(Text)
    text = Column(Text)
    
    # Processing metadata
    date = Column(DateTime(timezone=True), nullable=False)
    priority = Column(Enum(PriorityLevel), default=PriorityLevel.MEDIUM)
    relevance_score = Column(Float, default=0.5)
    
    # Extracted entities and metadata
    entities = Column(JSON, default=list)
    meta_data = Column("metadata", JSON, default=dict)  # ✅ safe rename
    
    # Task extraction
    has_tasks = Column(Boolean, default=False)
    extracted_tasks = Column(JSON, default=list)
    
    # Vector embedding
    embedding = Column(JSON)
    
    # Privacy and processing flags
    is_encrypted = Column(Boolean, default=False)
    processed_locally = Column(Boolean, default=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="feed_items")
    tasks = relationship("Task", back_populates="feed_item")


# Task model: metadata renamed to task_meta
class Task(Base):
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    feed_item_id = Column(Integer, ForeignKey("feed_items.id"), nullable=True)
    
    # Task details
    verb = Column(String(100), nullable=False)
    text = Column(Text, nullable=False)
    due_date = Column(DateTime(timezone=True), nullable=True)
    
    # Task status
    is_completed = Column(Boolean, default=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    
    # Calendar sync
    calendar_event_id = Column(String(255), nullable=True)
    is_synced_to_calendar = Column(Boolean, default=False)
    
    # Priority and metadata
    priority = Column(Enum(PriorityLevel), default=PriorityLevel.MEDIUM)
    task_meta = Column("metadata", JSON, default=dict)  # ✅ safe rename
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="tasks")
    feed_item = relationship("FeedItem", back_populates="tasks")


class ConnectorConfig(Base):
    """Configuration for external connectors (Gmail, Reddit, etc.)"""
    __tablename__ = "connector_configs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Connector details
    connector_type = Column(Enum(SourceType), nullable=False)
    is_enabled = Column(Boolean, default=True)
    
    # OAuth tokens (encrypted)
    access_token = Column(Text, nullable=True)  # Encrypted
    refresh_token = Column(Text, nullable=True)  # Encrypted
    token_expires_at = Column(DateTime(timezone=True), nullable=True)
    
    # Connector-specific configuration
    config_data = Column(JSON, default=dict)  # Subreddits, RSS feeds, etc.
    
    # Sync metadata
    last_sync_at = Column(DateTime(timezone=True), nullable=True)
    sync_frequency_minutes = Column(Integer, default=60)  # How often to sync
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", back_populates="connector_configs")

class Feedback(Base):
    """User feedback on feed items for personalization"""
    __tablename__ = "feedback"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    feed_item_id = Column(Integer, ForeignKey("feed_items.id"), nullable=False)
    
    # Feedback details
    feedback_type = Column(String(50), nullable=False)  # like, dislike, complete, snooze
    feedback_value = Column(Float, nullable=True)  # Numerical value if applicable
    
    # Context
    context = Column(JSON, default=dict)  # Additional context about the feedback
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User")
    feed_item = relationship("FeedItem")

class SearchHistory(Base):
    """Search history for analytics and improvement"""
    __tablename__ = "search_history"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Search details
    query = Column(Text, nullable=False)
    results_count = Column(Integer, default=0)
    clicked_results = Column(JSON, default=list)  # List of clicked result IDs
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User")


