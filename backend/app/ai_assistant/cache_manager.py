"""
AI Response Cache - DEPRECATED

This module is deprecated. Please use app.core.cache instead.
This file is kept for backwards compatibility only.
"""

# Re-export from unified cache
from app.core.cache import (
    CacheManager as AIResponseCache,
    CacheEntry,
    get_ai_cache,
    clear_all_caches as clear_ai_cache,
)

__all__ = [
    "AIResponseCache",
    "CacheEntry",
    "get_ai_cache",
    "clear_ai_cache",
]
