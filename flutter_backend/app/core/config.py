import os
from dotenv import load_dotenv
from typing import Optional


class Settings:
    """Application configuration loaded from environment with sane defaults."""

    def __init__(self) -> None:
        # Load once on initialization; .env is optional
        load_dotenv(override=False)

        self.groq_api_key: Optional[str] = os.getenv("GROQ_API_KEY")
        self.backend_port: int = int(os.getenv("BACKEND_PORT", "8000"))

        # CORS origins for local/dev clients
        self.allowed_origins = [
            "http://localhost",
            "http://localhost:80",
            "http://localhost:8080",
            "http://localhost:3000",
            "http://127.0.0.1",
            "http://127.0.0.1:80",
            "http://127.0.0.1:8080",
            "http://10.0.2.2:8000",
        ]


settings = Settings()


