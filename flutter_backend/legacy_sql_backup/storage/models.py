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
    important_keywords = Column(JSON, default=list)
    important_contacts = Column(JSON, default=list)
    preferred_sources = Column(JSON, default=list)
    feedback_history = Column(JSON, default=list)
    
    # Privacy settings
    local_only_mode = Column(Boolean, default=False)
    allow_llm_processing = Column(Boolean, default=True)
    
    # Ranking weights
    ranking_weights = Column(JSON, default=dict)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    user = relationship("User", back_populates="profile")

class FeedItem(Base):
    __tablename__ = "feed_items"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    source = Column(Enum(SourceType), nullable=False)
    origin_id = Column(String(255), nullable=False)
    title = Column(String(500), nullable=False)
    summary = Column(Text)
    text = Column(Text)
    date = Column(DateTime(timezone=True), nullable=False)
    priority = Column(Enum(PriorityLevel), default=PriorityLevel.MEDIUM)
    relevance_score = Column(Float, default=0.5)
    entities = Column(JSON, default=list)
    meta_data = Column("metadata", JSON, default=dict)
    has_tasks = Column(Boolean, default=False)
    extracted_tasks = Column(JSON, default=list)
    embedding = Column(JSON)
    is_encrypted = Column(Boolean, default=False)
    processed_locally = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user = relationship("User", back_populates="feed_items")
    tasks = relationship("Task", back_populates="feed_item")

class Task(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    feed_item_id = Column(Integer, ForeignKey("feed_items.id"), nullable=True)
    verb = Column(String(100), nullable=False)
    text = Column(Text, nullable=False)
    due_date = Column(DateTime(timezone=True), nullable=True)
    is_completed = Column(Boolean, default=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    calendar_event_id = Column(String(255), nullable=True)
    is_synced_to_calendar = Column(Boolean, default=False)
    priority = Column(Enum(PriorityLevel), default=PriorityLevel.MEDIUM)
    task_meta = Column("metadata", JSON, default=dict)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user = relationship("User", back_populates="tasks")
    feed_item = relationship("FeedItem", back_populates="tasks")

class ConnectorConfig(Base):
    __tablename__ = "connector_configs"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    connector_type = Column(Enum(SourceType), nullable=False)
    is_enabled = Column(Boolean, default=True)
    access_token = Column(Text, nullable=True)
    refresh_token = Column(Text, nullable=True)
    token_expires_at = Column(DateTime(timezone=True), nullable=True)
    config_data = Column(JSON, default=dict)
    last_sync_at = Column(DateTime(timezone=True), nullable=True)
    sync_frequency_minutes = Column(Integer, default=60)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    user = relationship("User", back_populates="connector_configs")

class Feedback(Base):
    __tablename__ = "feedback"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    feed_item_id = Column(Integer, ForeignKey("feed_items.id"), nullable=False)
    feedback_type = Column(String(50), nullable=False)
    feedback_value = Column(Float, nullable=True)
    context = Column(JSON, default=dict)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User")
    feed_item = relationship("FeedItem")

class SearchHistory(Base):
    __tablename__ = "search_history"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    query = Column(Text, nullable=False)
    results_count = Column(Integer, default=0)
    clicked_results = Column(JSON, default=list)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    user = relationship("User")


