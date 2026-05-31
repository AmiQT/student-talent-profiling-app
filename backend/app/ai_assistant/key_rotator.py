"""API Key rotation system untuk elakkan rate limits"""

import time
import logging
from typing import List, Dict, Optional
from collections import deque

logger = logging.getLogger(__name__)


class APIKeyRotator:
    """Rotates between multiple API keys untuk elakkan rate limits"""
    
    def __init__(self, api_keys: List[str], cooldown_seconds: int = 60):
        """
        Initialize key rotator
        
        Args:
            api_keys: List of API keys to rotate
            cooldown_seconds: Time to wait before reusing a rate-limited key
        """
        if not api_keys:
            raise ValueError("At least one API key required")
        
        self.api_keys = api_keys
        self.cooldown_seconds = cooldown_seconds
        
        # Track key usage and failures
        self.key_failures: Dict[str, float] = {}  # key -> timestamp of last failure
        self.key_usage_count: Dict[str, int] = {key: 0 for key in api_keys}
        self.current_key_index = 0
        
        logger.info(f"🔑 API Key Rotator initialized with {len(api_keys)} keys")
    
    def get_next_key(self) -> Optional[str]:
        """
        Get next available API key (skip yang dalam cooldown)
        
        Returns:
            API key string, or None if all keys are in cooldown
        """
        current_time = time.time()
        attempts = 0
        max_attempts = len(self.api_keys)
        
        while attempts < max_attempts:
            # Get current key
            key = self.api_keys[self.current_key_index]
            
            # Check if key is in cooldown
            if key in self.key_failures:
                time_since_failure = current_time - self.key_failures[key]
                if time_since_failure < self.cooldown_seconds:
                    # Key masih dalam cooldown, try next key
                    logger.debug(f"⏳ Key {self._mask_key(key)} dalam cooldown ({self.cooldown_seconds - time_since_failure:.1f}s remaining)")
                    self.current_key_index = (self.current_key_index + 1) % len(self.api_keys)
                    attempts += 1
                    continue
                else:
                    # Cooldown selesai, clear failure
                    del self.key_failures[key]
            
            # Key available!
            self.key_usage_count[key] += 1
            logger.info(f"✅ Using API key {self._mask_key(key)} (used {self.key_usage_count[key]} times)")
            
            # Move to next key for next request
            self.current_key_index = (self.current_key_index + 1) % len(self.api_keys)
            
            return key
        
        # Semua keys dalam cooldown
        logger.error(f"❌ All {len(self.api_keys)} API keys are in cooldown!")
        return None
    
    def mark_key_failed(self, api_key: str):
        """Mark key as failed (rate limited) - masuk cooldown"""
        self.key_failures[api_key] = time.time()
        logger.warning(f"⚠️  API key {self._mask_key(api_key)} marked as failed - cooldown {self.cooldown_seconds}s")
    
    def get_stats(self) -> Dict:
        """Get rotation statistics"""
        current_time = time.time()
        
        active_keys = []
        cooldown_keys = []
        
        for key in self.api_keys:
            if key in self.key_failures:
                time_since_failure = current_time - self.key_failures[key]
                if time_since_failure < self.cooldown_seconds:
                    cooldown_keys.append({
                        "key": self._mask_key(key),
                        "cooldown_remaining": self.cooldown_seconds - time_since_failure,
                        "usage_count": self.key_usage_count[key]
                    })
                    continue
            
            active_keys.append({
                "key": self._mask_key(key),
                "usage_count": self.key_usage_count[key]
            })
        
        return {
            "total_keys": len(self.api_keys),
            "active_keys": len(active_keys),
            "cooldown_keys": len(cooldown_keys),
            "keys": {
                "active": active_keys,
                "cooldown": cooldown_keys
            }
        }
    
    @staticmethod
    def _mask_key(key: str) -> str:
        """Mask API key for logging (show first/last 4 chars)"""
        if len(key) <= 8:
            return "***"
        return f"{key[:4]}...{key[-4:]}"


# Global instance (will be initialized in manager.py)
key_rotator: Optional[APIKeyRotator] = None


def initialize_key_rotator(api_keys: List[str], cooldown_seconds: int = 60):
    """Initialize global key rotator"""
    global key_rotator
    key_rotator = APIKeyRotator(api_keys, cooldown_seconds)
    logger.info(f"🔄 Global key rotator initialized with {len(api_keys)} keys")


def get_key_rotator() -> Optional[APIKeyRotator]:
    """Get global key rotator instance"""
    return key_rotator
