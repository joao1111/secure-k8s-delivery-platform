"""Shared checks for expiry annotations on exceptions and suppressions."""

from __future__ import annotations

import datetime as dt
from typing import Mapping

REQUIRED = (
    "security.platform/reason",
    "security.platform/owner",
    "security.platform/ticket",
    "security.platform/expires",
)


def annotation_errors(annotations: Mapping[str, object] | None, today: dt.date) -> list[str]:
    annotations = annotations or {}
    errors: list[str] = []
    for key in REQUIRED:
        value = annotations.get(key, "")
        if not str(value).strip():
            errors.append(f"missing {key}")
    raw = str(annotations.get("security.platform/expires", "")).strip()
    if raw:
        try:
            expires = dt.date.fromisoformat(raw)
        except ValueError:
            errors.append("security.platform/expires must be YYYY-MM-DD")
        else:
            if expires < today:
                errors.append(f"expired on {expires.isoformat()}")
    return errors
