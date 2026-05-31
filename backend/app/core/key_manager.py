"""
Gemini API Key Manager with Round-Robin Rotation.

This module provides thread-safe key rotation to distribute
API requests across multiple Gemini API keys, helping to avoid
rate limiting issues with the free tier.
"""

import os
import logging
import threading
from typing import List, Optional

logger = logging.getLogger(__name__)


class GeminiKeyManager:
    """
    Thread-safe Gemini API Key Manager with round-robin rotation.
    
    This manager cycles through multiple API keys to distribute
    requests and avoid hitting rate limits on any single key.
    """
    
    _instance: Optional["GeminiKeyManager"] = None
    _lock = threading.Lock()
    
    def __new__(cls) -> "GeminiKeyManager":
        """Singleton pattern to ensure only one instance exists."""
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        """Initialize the key manager with keys from environment."""
        if self._initialized:
            return
            
        self._keys: List[str] = []
        self._current_index: int = 0
        self._key_lock = threading.Lock()
        
        # Load keys from environment
        self._load_keys()
        self._initialized = True
        
        logger.info(f"🔑 GeminiKeyManager initialized with {len(self._keys)} key(s)")
    
    def _load_keys(self) -> None:
        """Load API keys from environment variables."""
        # Try GEMINI_API_KEYS first (comma-separated, preferred for multiple keys)
        keys_str = os.getenv("GEMINI_API_KEYS", "")
        if keys_str:
            self._keys = [k.strip() for k in keys_str.split(",") if k.strip()]
            logger.info(f"📋 Loaded {len(self._keys)} keys from GEMINI_API_KEYS")
        
        # Also check for singular GEMINI_API_KEY
        single_key = os.getenv("GEMINI_API_KEY", "")
        if single_key:
            if single_key not in self._keys:
                self._keys.insert(0, single_key)  # Add at beginning
                logger.info("📋 Added key from GEMINI_API_KEY")
        
        if not self._keys:
            logger.warning("⚠️ No Gemini API keys found in environment!")
    
    def get_next_key(self) -> Optional[str]:
        """
        Get the next API key using round-robin rotation.
        Thread-safe implementation.
        
        Returns:
            The next API key in rotation, or None if no keys available.
        """
        if not self._keys:
            logger.error("❌ No API keys available!")
            return None
        
        with self._key_lock:
            key = self._keys[self._current_index]
            self._current_index = (self._current_index + 1) % len(self._keys)
            
            # Log rotation (mask key for security)
            masked_key = f"{key[:10]}...{key[-4:]}" if len(key) > 14 else "***"
            logger.debug(f"🔄 Using key {self._current_index}/{len(self._keys)}: {masked_key}")
            
        return key
    
    def get_key(self) -> Optional[str]:
        """Alias for get_next_key() for backwards compatibility."""
        return self.get_next_key()
    
    @property
    def key_count(self) -> int:
        """Get the number of available API keys."""
        return len(self._keys)
    
    @property
    def has_keys(self) -> bool:
        """Check if any API keys are available."""
        return len(self._keys) > 0
    
    def reload_keys(self) -> None:
        """Reload keys from environment (useful if keys are updated at runtime)."""
        with self._key_lock:
            self._keys.clear()
            self._current_index = 0
            self._load_keys()
            logger.info(f"🔄 Reloaded {len(self._keys)} keys from environment")


# Global singleton instance
key_manager = GeminiKeyManager()


# Convenience functions
def get_gemini_key() -> Optional[str]:
    """Get the next Gemini API key using rotation."""
    return key_manager.get_next_key()


def get_key_count() -> int:
    """Get the number of available API keys."""
    return key_manager.key_count
