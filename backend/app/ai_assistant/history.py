"""Temporary in-memory history store untuk AI commands."""

from __future__ import annotations

from collections import deque
from datetime import datetime
from typing import Deque, Dict


MAX_HISTORY = 100
_HISTORY: Deque[Dict] = deque(maxlen=MAX_HISTORY)


def add_history_entry(entry: Dict) -> None:
    entry.setdefault("timestamp", datetime.utcnow().isoformat() + "Z")
    _HISTORY.appendleft(entry)


def get_recent_history(limit: int = 10) -> list[Dict]:
    return list(_HISTORY)[:limit]

