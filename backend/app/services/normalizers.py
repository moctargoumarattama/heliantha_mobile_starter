from __future__ import annotations

from html import unescape
from typing import Any


def unwrap_collection(payload: Any, key: str) -> list[dict[str, Any]]:
    if not isinstance(payload, dict):
        return []
    value = payload.get(key, [])
    if isinstance(value, list):
        return [x for x in value if isinstance(x, dict)]
    if isinstance(value, dict):
        return [value]
    return []


def unwrap_single(payload: Any, key: str) -> dict[str, Any]:
    rows = unwrap_collection(payload, key)
    return rows[0] if rows else {}


def localized(value: Any, language_id: int = 1) -> str:
    '''
    PrestaShop peut renvoyer :
    - "Nom"
    - [{"id": "1", "value": "Nom"}]
    - {"language": [{"id": "1", "value": "Nom"}]}
    '''
    if value is None:
        return ""
    if isinstance(value, str):
        return unescape(value)
    if isinstance(value, list):
        for item in value:
            if not isinstance(item, dict):
                continue
            try:
                if int(item.get("id", -1)) == int(language_id):
                    return unescape(str(item.get("value", "")))
            except Exception:
                pass
        if value and isinstance(value[0], dict):
            return unescape(str(value[0].get("value", "")))
    if isinstance(value, dict):
        if "language" in value:
            return localized(value["language"], language_id)
        if "value" in value:
            return unescape(str(value.get("value", "")))
    return unescape(str(value))


def to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except Exception:
        return default


def to_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "oui"}
