"""Simple rate limiter untuk Gemini API calls"""

import time
from collections import deque
from typing import Dict
import logging

logger = logging.getLogger(__name__)

class SimpleRateLimiter:
    """Simple in-memory rate limiter untuk API calls"""
    
    def __init__(self, max_requests: int = 10, time_window: int = 60, min_interval: float = 0.0):
        """Initialize rate limiter."""
        self.max_requests = max_requests
        self.time_window = time_window
        self.min_interval = float(min_interval)
        self.requests: Dict[str, deque] = {}  # user_id -> timestamps
        
    def can_make_request(self, user_id: str) -> bool:
        """
        Check if user can make a request
        
        Args:
            user_id: Unique identifier for user
            
        Returns:
            True if request is allowed, False otherwise
        """
        current_time = time.time()
        
        # Initialize user's request queue if not exists
        if user_id not in self.requests:
            self.requests[user_id] = deque()
        
        user_requests = self.requests[user_id]
        
        # Remove old requests outside time window
        while user_requests and current_time - user_requests[0] > self.time_window:
            user_requests.popleft()
        
        # Enforce minimum interval between requests to elakkan panggilan berturut-turut
        if self.min_interval > 0 and user_requests:
            elapsed = current_time - user_requests[-1]
            if elapsed < self.min_interval:
                wait_remaining = self.min_interval - elapsed
                logger.warning(
                    f"⚠️  Rate limit cooldown untuk {user_id}: tunggu {wait_remaining:.1f}s (min interval {self.min_interval:.1f}s)"
                )
                return False

        # Check if under limit
        if len(user_requests) < self.max_requests:
            user_requests.append(current_time)
            logger.info(f"✅ Rate limit OK untuk {user_id}: {len(user_requests)}/{self.max_requests} dalam {self.time_window}s")
            return True
        else:
            logger.warning(f"⚠️  Rate limit exceeded untuk {user_id}: {len(user_requests)}/{self.max_requests} dalam {self.time_window}s")
            return False
    
    def get_wait_time(self, user_id: str) -> float:
        """
        Get how long user needs to wait before next request
        
        Args:
            user_id: Unique identifier for user
            
        Returns:
            Wait time in seconds, 0 if can make request immediately
        """
        if user_id not in self.requests or not self.requests[user_id]:
            return 0.0
        
        current_time = time.time()
        user_requests = self.requests[user_id]
        
        # Remove old requests
        while user_requests and current_time - user_requests[0] > self.time_window:
            user_requests.popleft()
        
        wait_time = 0.0

        # If under limit, check minimum interval requirement
        if len(user_requests) < self.max_requests:
            if self.min_interval > 0 and user_requests:
                elapsed = current_time - user_requests[-1]
                interval_wait = self.min_interval - elapsed
                if interval_wait > wait_time:
                    wait_time = interval_wait
            return max(0.0, wait_time)

        # Calculate wait time until oldest request expires
        oldest_request = user_requests[0]
        window_wait = self.time_window - (current_time - oldest_request)
        wait_time = max(wait_time, window_wait)

        # Also respect minimum interval if applicable
        if self.min_interval > 0 and user_requests:
            elapsed = current_time - user_requests[-1]
            interval_wait = self.min_interval - elapsed
            if interval_wait > wait_time:
                wait_time = interval_wait

        return max(0.0, wait_time)
    
    def reset_user(self, user_id: str):
        """Reset rate limit for specific user"""
        if user_id in self.requests:
            del self.requests[user_id]
            logger.info(f"🔄 Rate limit reset for {user_id}")

# Global rate limiter instance
# Gemini Free tier: 15 RPM, but we set to 10 to be safe and enforce 3s gap antara calls
gemini_rate_limiter = SimpleRateLimiter(max_requests=10, time_window=60, min_interval=3)
