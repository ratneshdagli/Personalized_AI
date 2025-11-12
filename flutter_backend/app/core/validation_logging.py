import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

from fastapi import Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


LOG_DIR = Path(__file__).resolve().parent.parent.parent / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "validation.log"


async def validation_exception_handler(request: Request, exc: RequestValidationError):
    try:
        body = await request.body()
        entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "method": request.method,
            "path": request.url.path,
            "client": getattr(request.client, "host", None),
            "headers": {k: v for k, v in request.headers.items() if k.lower() not in {"authorization"}},
            "raw_body": body.decode("utf-8", errors="ignore"),
            "errors": exc.errors(),
        }
        with LOG_FILE.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass
    return JSONResponse(status_code=422, content={"detail": exc.errors()})


