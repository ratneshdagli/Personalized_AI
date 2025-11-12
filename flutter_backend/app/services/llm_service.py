import json
from typing import Any, Dict, List
import requests
import numpy as np
from pathlib import Path

from ..core.config import settings
from ..core.nosql import store


def analyze_notification(data: Dict[str, Any]) -> Dict[str, Any]:
    """Send notification JSON to Groq API and return a structured response.

    If the API key is missing or the request fails, return a graceful
    fallback classification with low priority and is_relevant=False.
    """

    if not settings.groq_api_key:
        result = {
            "is_relevant": False,
            "priority": 0.1,
            "category": data.get("category") or "Unknown",
            "summary": (data.get("title") or "")[:120] or "No summary",
        }
        _maybe_embed_document(data, result)
        return result

    # Prepare a simple prompt for structured output
    prompt = (
        "Classify this mobile notification. "
        "Return JSON with keys: is_relevant (bool), priority (0-1), "
        "category (string), summary (string). Notification: "
        + json.dumps(data)
    )

    try:
        # Example Groq chat completions endpoint (model name may vary).
        # Adjust if your environment uses a different client.
        headers = {
            "Authorization": f"Bearer {settings.groq_api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": "mixtral-8x7b-32768",
            "messages": [
                {"role": "system", "content": "You are a helpful assistant that outputs strict JSON."},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.2,
        }
        resp = requests.post(
            "https://api.groq.com/openai/v1/chat/completions", headers=headers, json=payload, timeout=20
        )
        resp.raise_for_status()
        data_json = resp.json()
        content = data_json["choices"][0]["message"]["content"].strip()

        # Attempt to parse JSON from the model response
        result = json.loads(content)
        # Ensure required keys exist with fallbacks
        result = {
            "is_relevant": bool(result.get("is_relevant", False)),
            "priority": float(result.get("priority", 0.1)),
            "category": str(result.get("category", data.get("category") or "Unknown")),
            "summary": str(result.get("summary", (data.get("title") or "")[:120] or "No summary")),
        }
        _maybe_embed_document(data, result)
        return result
    except Exception:
        result = {
            "is_relevant": False,
            "priority": 0.1,
            "category": data.get("category") or "Unknown",
            "summary": (data.get("title") or "")[:120] or "No summary",
        }
        _maybe_embed_document(data, result)
        return result


def _maybe_embed_document(origin: Dict[str, Any], analysis: Dict[str, Any], model_name: str = "mini-emb") -> None:
    """Generate and persist an embedding for a document, idempotently.

    - Uses Hive-first id if present in origin (id or client_id); else derives a deterministic key from text.
    - Saves raw vector under vectors/<document_id>.npy
    - Then upserts metadata into vector_meta: {document_id, embedding_file, created_at, source, model_name}
    - Logs an event into validation.log (shared log file) for visibility
    """
    try:
        text = (origin.get("message") or origin.get("text") or origin.get("title") or "").strip()
        if not text:
            return
        # Derive document id: prefer Hive id/client_id
        doc_id = str(origin.get("id") or origin.get("client_id") or _stable_key(text))

        # Simple embedding stand-in (hash to fixed-size vector) for local/dev
        vec = _hash_embedding(text)

        # Write vector file first (atomic-ish): write temp then rename
        # Tests expect vectors under flutter_backend/vectors
        vectors_dir = Path(__file__).resolve().parents[2] / "vectors"
        vectors_dir.mkdir(exist_ok=True)
        target = vectors_dir / f"{doc_id}.npy"
        tmp = vectors_dir / f".{doc_id}.tmp.npy"
        np.save(tmp, vec)
        tmp.replace(target)

        # Upsert metadata
        meta = {
            "document_id": doc_id,
            "embedding_file": str(target.name),
            "created_at": __import__("time").time(),
            "source": origin.get("package") or origin.get("app_name") or "unknown",
            "model_name": model_name,
        }
        store.upsert("vector_meta", meta, key="document_id")

        # Log embedding event
        _log_embedding_event(doc_id, model_name)
    except Exception:
        # Do not block ingestion on embedding errors
        return


def _hash_embedding(text: str, dim: int = 256) -> np.ndarray:
    rng = np.random.default_rng(abs(hash(text)) % (2**32))
    return rng.normal(0, 1, size=(dim,)).astype(np.float32)


def _stable_key(text: str) -> str:
    import hashlib
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _log_embedding_event(document_id: str, model_name: str) -> None:
    from . import llm_service as _ls  # self-module ok
    from ..core.validation_logging import LOG_FILE
    entry = {
        "timestamp": __import__("datetime").datetime.utcnow().isoformat() + "Z",
        "event": "embedding",
        "document_id": document_id,
        "model": model_name,
    }
    try:
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass


