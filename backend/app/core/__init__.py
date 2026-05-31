"""
Core Module

Shared utilities and services used across the application.
"""

from .cache import (
    CacheManager,
    CacheEntry,
    get_ai_cache,
    get_ml_cache,
    get_cache,
    clear_all_caches,
    # Backwards compatibility
    AIResponseCache,
    MLCacheManager,
)

__all__ = [
    "CacheManager",
    "CacheEntry", 
    "get_ai_cache",
    "get_ml_cache",
    "get_cache",
    "clear_all_caches",
    "AIResponseCache",
    "MLCacheManager",
]
