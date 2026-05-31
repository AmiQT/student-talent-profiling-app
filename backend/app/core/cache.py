"""
Unified Cache Manager

In-memory caching system with LRU eviction, TTL support, and statistics.
Used by AI module, ML analytics, and other services.
"""

import time
import hashlib
import json
import logging
from typing import Any, Optional, Dict, Union
from datetime import timedelta
from collections import OrderedDict

logger = logging.getLogger(__name__)


class CacheEntry:
    """Single cache entry with metadata."""
    
    def __init__(self, value: Any, ttl_seconds: float):
        """
        Initialize cache entry.
        
        Args:
            value: Cached value
            ttl_seconds: Time-to-live in seconds (0 = never expire)
        """
        self.value = value
        self.created_at = time.time()
        self.ttl_seconds = ttl_seconds
        self.hits = 0
    
    def is_expired(self) -> bool:
        """Check if cache entry expired."""
        if self.ttl_seconds == 0:
            return False  # Never expires
        return (time.time() - self.created_at) > self.ttl_seconds
    
    def get_age(self) -> float:
        """Get age of cache entry in seconds."""
        return time.time() - self.created_at
    
    def __repr__(self) -> str:
        age = self.get_age()
        return f"<CacheEntry age={age:.0f}s ttl={self.ttl_seconds:.0f}s hits={self.hits}>"


class CacheManager:
    """
    Unified LRU cache with TTL support.
    
    Features:
    - TTL (Time-to-live) support with seconds or timedelta
    - LRU (Least Recently Used) eviction policy
    - Hit/miss statistics
    - Memory limit protection
    - Key generation helpers
    
    Usage:
        cache = CacheManager(max_size=1000, default_ttl=300)
        cache.set("key", {"data": "value"}, ttl=600)
        result = cache.get("key")
        cache.delete("key")
        cache.clear()
    """
    
    def __init__(
        self, 
        max_size: int = 1000, 
        default_ttl: Union[int, float, timedelta] = 300,
        name: str = "default"
    ):
        """
        Initialize cache.
        
        Args:
            max_size: Maximum number of entries (LRU eviction when exceeded)
            default_ttl: Default time-to-live (seconds, float, or timedelta)
            name: Cache name for logging
        """
        self.max_size = max_size
        self.default_ttl = self._to_seconds(default_ttl)
        self.name = name
        self._cache: OrderedDict[str, CacheEntry] = OrderedDict()
        
        # Statistics
        self.hits = 0
        self.misses = 0
        self.evictions = 0
        
        logger.info(f"💾 Cache '{name}' initialized: max_size={max_size}, default_ttl={self.default_ttl}s")
    
    @staticmethod
    def _to_seconds(ttl: Union[int, float, timedelta, None]) -> float:
        """Convert TTL to seconds."""
        if ttl is None:
            return 300  # Default 5 minutes
        if isinstance(ttl, timedelta):
            return ttl.total_seconds()
        return float(ttl)
    
    def _generate_key(self, prefix: str, data: Dict[str, Any]) -> str:
        """
        Generate cache key from data using hash.
        
        Args:
            prefix: Key prefix (e.g., "tool_call", "ai_response", "ml_prediction")
            data: Data to hash
            
        Returns:
            Cache key string
        """
        # Sort data to ensure consistent hashing
        data_str = json.dumps(data, sort_keys=True, default=str)
        hash_obj = hashlib.sha256(data_str.encode())
        hash_hex = hash_obj.hexdigest()[:16]  # First 16 chars
        return f"{prefix}:{hash_hex}"
    
    def get(self, key: str) -> Optional[Any]:
        """
        Get value from cache.
        
        Args:
            key: Cache key
            
        Returns:
            Cached value or None if not found/expired
        """
        if key not in self._cache:
            self.misses += 1
            logger.debug(f"❌ Cache MISS [{self.name}]: {key}")
            return None
        
        entry = self._cache[key]
        
        # Check if expired
        if entry.is_expired():
            logger.debug(f"⏰ Cache EXPIRED [{self.name}]: {key} (age: {entry.get_age():.1f}s)")
            del self._cache[key]
            self.misses += 1
            return None
        
        # Move to end (most recently used)
        self._cache.move_to_end(key)
        entry.hits += 1
        self.hits += 1
        
        logger.debug(f"✅ Cache HIT [{self.name}]: {key} (age: {entry.get_age():.1f}s, hits: {entry.hits})")
        return entry.value
    
    def set(
        self, 
        key: str, 
        value: Any, 
        ttl: Union[int, float, timedelta, None] = None
    ) -> None:
        """
        Set value in cache.
        
        Args:
            key: Cache key
            value: Value to cache
            ttl: Time-to-live (seconds, float, or timedelta; None uses default)
        """
        # Convert TTL
        ttl_seconds = self._to_seconds(ttl) if ttl is not None else self.default_ttl
        
        # Check if need to evict (LRU)
        if key not in self._cache and len(self._cache) >= self.max_size:
            evicted_key, _ = self._cache.popitem(last=False)  # Remove oldest
            self.evictions += 1
            logger.debug(f"🗑️  Cache EVICT [{self.name}]: {evicted_key} (LRU)")
        
        # Store entry
        self._cache[key] = CacheEntry(value, ttl_seconds)
        self._cache.move_to_end(key)  # Mark as most recent
        
        logger.debug(f"💾 Cache SET [{self.name}]: {key} (ttl: {ttl_seconds}s)")
    
    def delete(self, key: str) -> bool:
        """
        Delete entry from cache.
        
        Args:
            key: Cache key
            
        Returns:
            True if deleted, False if not found
        """
        if key in self._cache:
            del self._cache[key]
            logger.debug(f"🗑️  Cache DELETE [{self.name}]: {key}")
            return True
        return False
    
    # Alias for compatibility with old ml_analytics cache
    def invalidate(self, key: str) -> None:
        """Remove specific entry from cache (alias for delete)."""
        self.delete(key)
    
    def clear(self) -> None:
        """Clear all cache entries."""
        count = len(self._cache)
        self._cache.clear()
        logger.info(f"🗑️  Cache CLEARED [{self.name}]: {count} entries removed")
    
    # Alias for compatibility with old ml_analytics cache
    def invalidate_all(self) -> None:
        """Clear entire cache (alias for clear)."""
        self.clear()
    
    def cleanup_expired(self) -> int:
        """
        Remove all expired entries.
        
        Returns:
            Number of entries removed
        """
        expired_keys = [
            key for key, entry in self._cache.items()
            if entry.is_expired()
        ]
        
        for key in expired_keys:
            del self._cache[key]
        
        if expired_keys:
            logger.info(f"🧹 Cache CLEANUP [{self.name}]: {len(expired_keys)} expired entries removed")
        
        return len(expired_keys)
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics."""
        total_requests = self.hits + self.misses
        hit_rate = (self.hits / total_requests * 100) if total_requests > 0 else 0
        
        return {
            "name": self.name,
            "size": len(self._cache),
            "max_size": self.max_size,
            "hits": self.hits,
            "misses": self.misses,
            "evictions": self.evictions,
            "hit_rate": round(hit_rate, 2),
            "hit_rate_str": f"{hit_rate:.1f}%",
            "total_requests": total_requests,
            "default_ttl": self.default_ttl
        }
    
    # Key generation helpers
    def get_cache_key_for_tool(self, tool_name: str, arguments: Dict[str, Any]) -> str:
        """Generate cache key for tool call."""
        return self._generate_key(f"tool:{tool_name}", arguments)
    
    def get_cache_key_for_response(self, command: str, context: Dict[str, Any]) -> str:
        """Generate cache key for AI response."""
        data = {"command": command, "context": context}
        return self._generate_key("response", data)
    
    def get_cache_key_for_prediction(self, model: str, input_data: Dict[str, Any]) -> str:
        """Generate cache key for ML prediction."""
        data = {"model": model, "input": input_data}
        return self._generate_key("prediction", data)
    
    def __len__(self) -> int:
        """Get current cache size."""
        return len(self._cache)
    
    def __repr__(self) -> str:
        stats = self.get_stats()
        return f"<CacheManager '{self.name}' size={stats['size']}/{stats['max_size']} hit_rate={stats['hit_rate_str']}>"


# ============================================================================
# Global Cache Instances
# ============================================================================

# AI Response Cache (shorter TTL for dynamic content)
_ai_cache: Optional[CacheManager] = None

# ML Prediction Cache (longer TTL for stable predictions)
_ml_cache: Optional[CacheManager] = None

# General Purpose Cache
_general_cache: Optional[CacheManager] = None


def get_ai_cache(max_size: int = 1000, default_ttl: int = 300) -> CacheManager:
    """
    Get or create AI response cache instance.
    
    Args:
        max_size: Maximum cache size
        default_ttl: Default TTL in seconds (5 minutes default)
        
    Returns:
        CacheManager instance
    """
    global _ai_cache
    if _ai_cache is None:
        _ai_cache = CacheManager(max_size=max_size, default_ttl=default_ttl, name="ai_response")
    return _ai_cache


def get_ml_cache(max_size: int = 1000, default_ttl: Union[int, timedelta] = None) -> CacheManager:
    """
    Get or create ML prediction cache instance.
    
    Args:
        max_size: Maximum cache size
        default_ttl: Default TTL (24 hours default for stable predictions)
        
    Returns:
        CacheManager instance
    """
    global _ml_cache
    if _ml_cache is None:
        ttl = default_ttl or timedelta(hours=24)
        _ml_cache = CacheManager(max_size=max_size, default_ttl=ttl, name="ml_prediction")
    return _ml_cache


def get_cache(name: str = "general", max_size: int = 500, default_ttl: int = 600) -> CacheManager:
    """
    Get or create a named cache instance.
    
    Args:
        name: Cache name
        max_size: Maximum cache size
        default_ttl: Default TTL in seconds
        
    Returns:
        CacheManager instance
    """
    global _general_cache
    if _general_cache is None:
        _general_cache = CacheManager(max_size=max_size, default_ttl=default_ttl, name=name)
    return _general_cache


def clear_all_caches() -> None:
    """Clear all global cache instances."""
    global _ai_cache, _ml_cache, _general_cache
    
    for cache in [_ai_cache, _ml_cache, _general_cache]:
        if cache:
            cache.clear()
    
    logger.info("🗑️  All caches cleared")


# ============================================================================
# Backwards Compatibility Aliases
# ============================================================================

# For ai_assistant module compatibility
AIResponseCache = CacheManager
clear_ai_cache = lambda: _ai_cache.clear() if _ai_cache else None

# For ml_analytics module compatibility  
MLCacheManager = CacheManager
