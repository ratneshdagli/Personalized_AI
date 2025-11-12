import json
from fastapi import APIRouter
from typing import Any, Dict

from ..core.database import get_user_profile, upsert_user_profile
from ..models.user_model import UserProfileModel


router = APIRouter(prefix="/user", tags=["user"])


@router.get("/profile")
def get_profile():
    row = get_user_profile()
    if not row:
        return {"profile": None}
    return {
        "profile": {
            "name": row["name"],
            "email": row["email"],
            "preferences": json.loads(row["preferences_json"]) if row["preferences_json"] else {},
            "persona": json.loads(row["persona_json"]) if row["persona_json"] else {},
        }
    }


@router.post("/profile")
def set_profile(profile: UserProfileModel):
    user_id = upsert_user_profile(
        name=profile.name,
        email=profile.email,
        preferences_json=json.dumps(profile.preferences or {}),
        persona_json=json.dumps(profile.persona or {}),
    )
    return {"id": user_id, "status": "ok"}


