"""SQL/ORM models archived. See `legacy_sql_backup/`.
This lightweight shim keeps attribute access working in legacy paths without
requiring a live SQLAlchemy setup. It is NOT a full ORM mapping.
"""

import enum


class SourceType(enum.Enum):
    GMAIL = "gmail"
    REDDIT = "reddit"
    NEWS = "news"
    WHATSAPP = "whatsapp"
    INSTAGRAM = "instagram"
    TELEGRAM = "telegram"
    CALENDAR = "calendar"

class PriorityLevel:
    pass

class User:
    id: int | None = None
    email: str
    name: str
    is_active: bool = True
    is_admin: bool = False

    def __init__(self, email: str, name: str):
        self.email = email
        self.name = name

class UserProfile:
    pass

# FeedItem shim: include properties referenced by routes
class FeedItem:
    id: int | None = None
    user_id: int | None = None
    source: SourceType | str | None = None
    origin_id: str | None = None
    title: str | None = None
    summary: str | None = None
    text: str | None = None
    content: str | None = None
    date: object | None = None
    relevance_score: float | None = None
    relevance: float | None = None
    has_tasks: bool | None = None
    extracted_tasks: list | None = None
    entities: list | None = None
    # Legacy mismatch: routes may access `metadata`
    metadata: dict | None = None
    meta_data: dict | None = None

    def __init__(self, **kwargs):
        for k, v in kwargs.items():
            setattr(self, k, v)


# Task model: metadata renamed to task_meta
class Task:
    pass


class ConnectorConfig:
    id: int | None = None
    user_id: int | None = None
    connector_type: SourceType | None = None
    is_enabled: bool = True
    access_token: str | None = None
    refresh_token: str | None = None
    token_expires_at: object | None = None
    config_data: dict | None = None
    last_sync_at: object | None = None

class Feedback:
    pass

class SearchHistory:
    pass


