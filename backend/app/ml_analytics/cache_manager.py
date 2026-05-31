"""
ML Cache Manager - DEPRECATED

This module is deprecated. Please use app.core.cache instead.
This file is kept for backwards compatibility only.
"""

# Re-export from unified cache
from app.core.cache import (
    CacheManager,
    CacheEntry,
    get_ml_cache,
    clear_all_caches,
)

__all__ = [
    "CacheManager",
    "CacheEntry",
    "get_ml_cache",
    "clear_all_caches",
]
