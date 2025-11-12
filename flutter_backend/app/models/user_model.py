from typing import Dict
from pydantic import BaseModel, Field, field_validator


class UserProfileModel(BaseModel):
    name: str
    email: str
    preferences: Dict = Field(default_factory=dict)
    persona: Dict = Field(default_factory=dict)

    @field_validator("email")
    @classmethod
    def _validate_email(cls, v: str) -> str:
        if not isinstance(v, str):
            raise ValueError("email must be a string")
        if v.count("@") != 1:
            raise ValueError("email must contain exactly one '@'")
        local, domain = v.split("@", 1)
        if not local or not domain:
            raise ValueError("email must have non-empty local and domain parts")
        # Optional: require at least one dot in domain
        if "." not in domain:
            raise ValueError("email domain must contain a '.'")
        return v


