"""Circuit breaker pattern untuk prevent cascading failures."""

import time
import logging
from enum import Enum
from typing import Optional, Callable, Any
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class CircuitState(Enum):
    """States of circuit breaker"""
    CLOSED = "closed"  # Normal operation, requests allowed
    OPEN = "open"  # Too many failures, block all requests
    HALF_OPEN = "half_open"  # Testing if service recovered


class CircuitBreaker:
    """
    Circuit breaker pattern implementation untuk protect AI services.
    
    States:
    - CLOSED: Normal operation (requests go through)
    - OPEN: Service failing (block requests, return fallback)
    - HALF_OPEN: Testing recovery (allow 1 request to test)
    
    Flow:
    CLOSED --[failures >= threshold]--> OPEN
    OPEN --[timeout elapsed]--> HALF_OPEN
    HALF_OPEN --[success]--> CLOSED
    HALF_OPEN --[failure]--> OPEN
    """
    
    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: int = 60,
        expected_exception: type = Exception,
        name: str = "default"
    ):
        """
        Initialize circuit breaker.
        
        Args:
            failure_threshold: Berapa kali failures sebelum circuit open
            recovery_timeout: Berapa lama (seconds) tunggu sebelum try recovery
            expected_exception: Type of exception yang di-track
            name: Name untuk logging
        """
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        self.name = name
        
        # State tracking
        self.failure_count = 0
        self.last_failure_time: Optional[float] = None
        self.state = CircuitState.CLOSED
        
        logger.info(
            f"🔌 Circuit breaker '{name}' initialized: "
            f"threshold={failure_threshold}, timeout={recovery_timeout}s"
        )
    
    def call(self, func: Callable, *args, **kwargs) -> Any:
        """
        Execute function with circuit breaker protection.
        
        Args:
            func: Function to call
            *args: Positional arguments
            **kwargs: Keyword arguments
            
        Returns:
            Function result or raises CircuitBreakerError
        """
        # Check current state
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self._move_to_half_open()
            else:
                logger.warning(
                    f"⚠️  Circuit '{self.name}' is OPEN - blocking request "
                    f"(failures: {self.failure_count}/{self.failure_threshold})"
                )
                raise CircuitBreakerOpenError(
                    f"Circuit breaker '{self.name}' is OPEN. "
                    f"Service unavailable. Try again in {self._get_remaining_timeout():.0f}s."
                )
        
        try:
            # Attempt the call
            result = func(*args, **kwargs)
            self._on_success()
            return result
            
        except self.expected_exception as e:
            self._on_failure()
            raise e
    
    async def call_async(self, func: Callable, *args, **kwargs) -> Any:
        """Async version of call method."""
        # Check current state
        if self.state == CircuitState.OPEN:
            if self._should_attempt_reset():
                self._move_to_half_open()
            else:
                logger.warning(
                    f"⚠️  Circuit '{self.name}' is OPEN - blocking async request "
                    f"(failures: {self.failure_count}/{self.failure_threshold})"
                )
                raise CircuitBreakerOpenError(
                    f"Circuit breaker '{self.name}' is OPEN. "
                    f"Service unavailable. Try again in {self._get_remaining_timeout():.0f}s."
                )
        
        try:
            # Attempt the async call
            result = await func(*args, **kwargs)
            self._on_success()
            return result
            
        except self.expected_exception as e:
            self._on_failure()
            raise e
    
    def _should_attempt_reset(self) -> bool:
        """Check if enough time passed to attempt recovery."""
        if self.last_failure_time is None:
            return False
        
        time_since_failure = time.time() - self.last_failure_time
        return time_since_failure >= self.recovery_timeout
    
    def _get_remaining_timeout(self) -> float:
        """Get remaining timeout duration."""
        if self.last_failure_time is None:
            return 0.0
        
        elapsed = time.time() - self.last_failure_time
        remaining = self.recovery_timeout - elapsed
        return max(0.0, remaining)
    
    def _on_success(self):
        """Handle successful call."""
        if self.state == CircuitState.HALF_OPEN:
            logger.info(f"✅ Circuit '{self.name}' recovered - moving to CLOSED")
            self.state = CircuitState.CLOSED
        
        # Reset failure count on success
        self.failure_count = 0
        self.last_failure_time = None
    
    def _on_failure(self):
        """Handle failed call."""
        self.failure_count += 1
        self.last_failure_time = time.time()
        
        logger.warning(
            f"⚠️  Circuit '{self.name}' failure {self.failure_count}/{self.failure_threshold}"
        )
        
        if self.failure_count >= self.failure_threshold:
            self._move_to_open()
    
    def _move_to_open(self):
        """Move circuit to OPEN state."""
        self.state = CircuitState.OPEN
        logger.error(
            f"❌ Circuit '{self.name}' is now OPEN - blocking all requests for {self.recovery_timeout}s"
        )
    
    def _move_to_half_open(self):
        """Move circuit to HALF_OPEN state for testing."""
        self.state = CircuitState.HALF_OPEN
        logger.info(f"🔄 Circuit '{self.name}' is now HALF_OPEN - testing recovery")
    
    def reset(self):
        """Manually reset circuit breaker."""
        logger.info(f"🔄 Circuit '{self.name}' manually reset")
        self.failure_count = 0
        self.last_failure_time = None
        self.state = CircuitState.CLOSED
    
    def get_state(self) -> dict:
        """Get current circuit breaker state."""
        return {
            "name": self.name,
            "state": self.state.value,
            "failure_count": self.failure_count,
            "failure_threshold": self.failure_threshold,
            "last_failure_time": datetime.fromtimestamp(self.last_failure_time).isoformat() if self.last_failure_time else None,
            "recovery_timeout": self.recovery_timeout,
            "time_until_retry": self._get_remaining_timeout() if self.state == CircuitState.OPEN else 0
        }


class CircuitBreakerOpenError(Exception):
    """Raised when circuit breaker is open."""
    pass


# Global circuit breakers
_circuit_breakers = {}


def get_circuit_breaker(
    name: str,
    failure_threshold: int = 5,
    recovery_timeout: int = 60,
    expected_exception: type = Exception
) -> CircuitBreaker:
    """
    Get or create a circuit breaker instance.
    
    Args:
        name: Unique name for circuit breaker
        failure_threshold: Number of failures before opening
        recovery_timeout: Seconds to wait before retry
        expected_exception: Exception type to track
        
    Returns:
        CircuitBreaker instance
    """
    if name not in _circuit_breakers:
        _circuit_breakers[name] = CircuitBreaker(
            failure_threshold=failure_threshold,
            recovery_timeout=recovery_timeout,
            expected_exception=expected_exception,
            name=name
        )
    
    return _circuit_breakers[name]


def get_all_circuit_breakers() -> dict:
    """Get state of all circuit breakers."""
    return {
        name: breaker.get_state()
        for name, breaker in _circuit_breakers.items()
    }
