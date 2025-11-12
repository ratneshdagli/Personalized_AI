import os
import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Callable

try:
    from tinydb import TinyDB, Query  # type: ignore
    from tinydb.storages import JSONStorage, MemoryStorage  # type: ignore
    from tinydb.middlewares import CachingMiddleware  # type: ignore
    _HAS_TINYDB = True
except Exception:
    TinyDB = None  # type: ignore
    Query = None  # type: ignore
    CachingMiddleware = None  # type: ignore
    JSONStorage = None  # type: ignore
    _HAS_TINYDB = False


ROOT_DIR = Path(__file__).resolve().parent.parent.parent
DATA_DIR = ROOT_DIR / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
DB_FILE = DATA_DIR / "db.json"


class _CollectionProxy:
    """Lightweight proxy that provides a .search(callable) API.

    This keeps tests compatible whether TinyDB is installed or we use the
    built-in fallback store.
    """

    def __init__(self, store_ref: "NoSQLStore", name: str):
        self._store = store_ref
        self._name = name

    def search(self, predicate: Callable[[Dict[str, Any]], bool]) -> List[Dict[str, Any]]:
        # Always work off of an in-memory list for simplicity
        if _HAS_TINYDB and hasattr(self._store, "_db") and hasattr(self._store, name := self._name):
            try:
                table = getattr(self._store, f"_{self._name}_table", None)
                if table is None:
                    table = self._store._db.table(self._name)
                return [d for d in table.all() if predicate(d)]
            except Exception:
                # Fallback to store API
                data = self._store.all(self._name)
                return [d for d in data if predicate(d)]
        else:
            data = self._store.all(self._name)
            return [d for d in data if predicate(d)]


class NoSQLStore:
    """TinyDB-backed document store with simple collection helpers.

    Collections: users, feed_items, tasks, connectors, vector_meta, events
    Supports in-memory mode if BACKEND_STORAGE=memory.
    """

    def __init__(self) -> None:
        storage_mode = os.getenv("BACKEND_STORAGE", "file").lower()
        use_tinydb = _HAS_TINYDB and storage_mode != "memory"

        if use_tinydb:
            # File-backed TinyDB with caching middleware
            self._db = TinyDB(str(DB_FILE), storage=CachingMiddleware(JSONStorage))
            # Keep raw TinyDB tables internally for store APIs
            self._users_table = self._db.table("users")
            self._feed_items_table = self._db.table("feed_items")
            self._tasks_table = self._db.table("tasks")
            self._connectors_table = self._db.table("connectors")
            self._vector_meta_table = self._db.table("vector_meta")
            self._events_table = self._db.table("events")
        else:
            # Minimal fallback JSON store (no external deps)
            self._mem: Dict[str, List[Dict[str, Any]]] = {
                "users": [],
                "feed_items": [],
                "tasks": [],
                "connectors": [],
                "vector_meta": [],
                "events": [],
            }
            self._storage_mode = storage_mode
            if storage_mode != "memory" and DB_FILE.exists():
                try:
                    data = json.loads(DB_FILE.read_text(encoding="utf-8") or "{}")
                    for k in self._mem.keys():
                        self._mem[k] = list(data.get(k, []))
                except Exception:
                    pass

        # Public collection proxies for tests (provide .search(callable))
        self.users = _CollectionProxy(self, "users")
        self.feed_items = _CollectionProxy(self, "feed_items")
        self.tasks = _CollectionProxy(self, "tasks")
        self.connectors = _CollectionProxy(self, "connectors")
        self.vector_meta = _CollectionProxy(self, "vector_meta")
        self.events = _CollectionProxy(self, "events")

        (DATA_DIR / "vectors").mkdir(exist_ok=True)

    def _next_id(self, table_name: str) -> int:
        if _HAS_TINYDB and hasattr(self, "_db"):
            table = getattr(self, f"_{table_name}_table")
            ids = [doc.get("id", 0) for doc in table.all()]
        else:
            ids = [doc.get("id", 0) for doc in self._mem.get(table_name, [])]
        return (max(ids) + 1) if ids else 1

    def insert(self, table_name: str, doc: Dict[str, Any]) -> int:
        if _HAS_TINYDB and hasattr(self, "_db"):
            table = getattr(self, f"_{table_name}_table")
            if "id" not in doc:
                doc["id"] = self._next_id(table_name)
            table.insert(doc)
            # Flush to ensure durability
            if hasattr(self._db.storage, 'flush'):
                self._db.storage.flush()
            return int(doc["id"])  # type: ignore
        else:
            if "id" not in doc:
                doc["id"] = self._next_id(table_name)
            self._mem[table_name].append(doc)
            self._flush()
            return int(doc["id"])  # type: ignore

    def upsert(self, table_name: str, doc: Dict[str, Any], key: str) -> int:
        if _HAS_TINYDB and hasattr(self, "_db"):
            table = getattr(self, f"_{table_name}_table")
            q = Query()
            existing = table.get(q[key] == doc.get(key))
            if existing:
                doc["id"] = existing.get("id")
                table.update(doc, doc_ids=[existing.doc_id])
                if hasattr(self._db.storage, 'flush'):
                    self._db.storage.flush()
                return int(doc["id"])  # type: ignore
            return self.insert(table_name, doc)
        else:
            items = self._mem[table_name]
            for i, d in enumerate(items):
                if d.get(key) == doc.get(key):
                    doc["id"] = d.get("id")
                    items[i] = doc
                    self._flush()
                    return int(doc["id"])  # type: ignore
            return self.insert(table_name, doc)

    def find_since(self, table_name: str, ts_field: str, since: Optional[float]) -> List[Dict[str, Any]]:
        if _HAS_TINYDB and hasattr(self, "_db"):
            table = getattr(self, f"_{table_name}_table")
            if since is None:
                return table.all()
            q = Query()
            return table.search(q[ts_field] >= since)
        else:
            data = list(self._mem.get(table_name, []))
            if since is None:
                return data
            return [d for d in data if d.get(ts_field) is not None and d.get(ts_field) >= since]

    def all(self, table_name: str) -> List[Dict[str, Any]]:
        if _HAS_TINYDB and hasattr(self, "_db"):
            table = getattr(self, f"_{table_name}_table")
            return table.all()
        else:
            return list(self._mem.get(table_name, []))

    def get_vector_meta(self, document_id: str) -> Optional[Dict[str, Any]]:
        if _HAS_TINYDB and hasattr(self, "_db"):
            q = Query()
            table = getattr(self, "_vector_meta_table")
            return table.get(q["document_id"] == document_id)
        else:
            for d in self._mem.get("vector_meta", []):
                if d.get("document_id") == document_id:
                    return d
            return None

    def _flush(self) -> None:
        if getattr(self, "_storage_mode", "memory") == "memory":
            return
        try:
            tmp = DB_FILE.with_suffix(".tmp")
            tmp.write_text(json.dumps(self._mem), encoding="utf-8")
            tmp.replace(DB_FILE)
        except Exception:
            pass


store = NoSQLStore()


