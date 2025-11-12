"""Lightweight in-memory DB session shim for legacy tests.

Provides a small subset of SQLAlchemy Session behavior so tests that call
get_db_session().add(...)/query(...).filter(...).first() do not crash.

This is NOT a real database. It stores objects in memory per Python process.
"""

from typing import Any, Dict, List, Optional, Type


class _QueryShim:
    def __init__(self, data: List[Any], store_ref: "_DummyDBSession", model: Type[Any]):
        self._data = data
        self._store_ref = store_ref
        self._model = model

    def filter(self, *args, **kwargs):
        # Filtering is a no-op in this shim; tests generally just call .first()
        return self

    def first(self):
        return self._data[0] if self._data else None

    def all(self):
        return list(self._data)

    def count(self):
        return len(self._data)

    def delete(self):
        # Remove all items of this model in the store (since filter is a no-op)
        self._store_ref._store[self._model] = []
        return 0


class _DummyDBSession:
    def __init__(self):
        # Simple registry: model class -> list of instances
        self._store: Dict[Type[Any], List[Any]] = {}

    def add(self, obj: Any) -> None:
        cls = obj.__class__
        self._store.setdefault(cls, []).append(obj)

    def delete(self, obj: Any) -> None:
        cls = obj.__class__
        if cls in self._store and obj in self._store[cls]:
            self._store[cls].remove(obj)

    def query(self, model: Type[Any]) -> _QueryShim:
        return _QueryShim(self._store.get(model, []), self, model)

    def commit(self) -> None:
        # No-op for in-memory store
        return None

    def rollback(self) -> None:
        # No-op for in-memory store
        return None

    def refresh(self, obj: Any) -> None:
        # No-op for in-memory store
        return None

    def close(self) -> None:
        return None


_GLOBAL_SESSION: Optional[_DummyDBSession] = None


def init_db():
    global _GLOBAL_SESSION
    if _GLOBAL_SESSION is None:
        _GLOBAL_SESSION = _DummyDBSession()
    return _GLOBAL_SESSION


def get_db_session():
    """Return the global in-memory session shim."""
    global _GLOBAL_SESSION
    if _GLOBAL_SESSION is None:
        _GLOBAL_SESSION = _DummyDBSession()
    return _GLOBAL_SESSION


def check_db_health():
    return {"status": "ok", "message": "In-memory DB shim active"}


def get_db():
    # Compatibility with FastAPI dependency pattern
    return get_db_session()