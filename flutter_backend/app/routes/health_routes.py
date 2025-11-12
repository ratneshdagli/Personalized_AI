from fastapi import APIRouter


router = APIRouter(tags=["health"])


@router.get("/health")
def health_check():
    """Simple health probe for uptime checks."""
    return {"status": "ok"}


