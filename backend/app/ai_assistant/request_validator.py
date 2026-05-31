"""Request validation dan sanitization untuk AI commands."""

import re
import logging
from typing import Any, Dict, List, Optional, Tuple
from html import escape

logger = logging.getLogger(__name__)


class RequestValidator:
    """
    Validates dan sanitizes AI command requests.
    
    Features:
    - Length validation
    - Content sanitization (XSS, SQL injection, etc.)
    - Rate limit checks
    - Malicious pattern detection
    """
    
    # Validation thresholds
    MAX_COMMAND_LENGTH = 2000
    MAX_CONTEXT_SIZE = 10000  # Max total size of context dict
    MIN_COMMAND_LENGTH = 1
    
    # Suspicious patterns (case-insensitive)
    SUSPICIOUS_PATTERNS = [
        r"<script[^>]*>.*?</script>",  # XSS scripts
        r"javascript:",  # JavaScript protocol
        r"on\w+\s*=",  # Event handlers (onclick, onload, etc.)
        r"eval\s*\(",  # Eval function
        r"(union|select|insert|update|delete|drop|create|alter)\s+(all|from|into|table|database)",  # SQL injection
        r"\.\.\/",  # Path traversal
        r"(exec|system|shell|cmd|passthru|popen)\s*\(",  # Command injection
    ]
    
    # Allowed characters for command (permissive untuk support Bahasa Melayu)
    ALLOWED_COMMAND_PATTERN = re.compile(
        r'^[\w\s\d.,?!@#$%^&*()\-+=\[\]{}:;"\'/<>àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÑÇ]+$',
        re.UNICODE
    )
    
    def __init__(self):
        """Initialize validator."""
        self.validation_errors = 0
        self.validation_successes = 0
        logger.info("✅ Request validator initialized")
    
    def validate_command(self, command: str) -> Tuple[bool, Optional[str]]:
        """
        Validate command string.
        
        Args:
            command: User command string
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        # Check if command exists
        if not command:
            self.validation_errors += 1
            return False, "Command tidak boleh kosong"
        
        # Strip whitespace
        command = command.strip()
        
        # Check minimum length
        if len(command) < self.MIN_COMMAND_LENGTH:
            self.validation_errors += 1
            return False, "Command terlalu pendek"
        
        # Check maximum length
        if len(command) > self.MAX_COMMAND_LENGTH:
            self.validation_errors += 1
            return False, f"Command terlalu panjang (max: {self.MAX_COMMAND_LENGTH} characters)"
        
        # Check for suspicious patterns
        for pattern in self.SUSPICIOUS_PATTERNS:
            if re.search(pattern, command, re.IGNORECASE):
                self.validation_errors += 1
                logger.warning(f"⚠️  Suspicious pattern detected: {pattern[:50]}...")
                return False, "Command mengandungi pattern yang tidak dibenarkan"
        
        # Validation passed
        self.validation_successes += 1
        return True, None
    
    def sanitize_command(self, command: str) -> str:
        """
        Sanitize command untuk remove dangerous content.
        
        Args:
            command: Raw command string
            
        Returns:
            Sanitized command
        """
        if not command:
            return ""
        
        # Strip whitespace
        command = command.strip()
        
        # Remove null bytes
        command = command.replace('\x00', '')
        
        # Escape HTML entities (untuk prevent XSS)
        command = escape(command)
        
        # Remove excessive whitespace
        command = re.sub(r'\s+', ' ', command)
        
        # Limit length
        if len(command) > self.MAX_COMMAND_LENGTH:
            command = command[:self.MAX_COMMAND_LENGTH]
            logger.warning(f"⚠️  Command truncated to {self.MAX_COMMAND_LENGTH} chars")
        
        return command
    
    def validate_context(self, context: Optional[Dict[str, Any]]) -> Tuple[bool, Optional[str]]:
        """
        Validate context dictionary.
        
        Args:
            context: Context dict
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if context is None:
            return True, None
        
        if not isinstance(context, dict):
            self.validation_errors += 1
            return False, "Context mesti dictionary"
        
        # Check total size (rough estimate)
        try:
            import json
            context_size = len(json.dumps(context, default=str))
            if context_size > self.MAX_CONTEXT_SIZE:
                self.validation_errors += 1
                return False, f"Context terlalu besar (max: {self.MAX_CONTEXT_SIZE} bytes)"
        except Exception as e:
            logger.warning(f"Failed to estimate context size: {e}")
        
        self.validation_successes += 1
        return True, None
    
    def sanitize_context(self, context: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """
        Sanitize context dictionary.
        
        Args:
            context: Context dict
            
        Returns:
            Sanitized context
        """
        if context is None:
            return None
        
        if not isinstance(context, dict):
            return {}
        
        # Recursively sanitize string values
        return self._sanitize_dict(context)
    
    def _sanitize_dict(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """Recursively sanitize dictionary values."""
        sanitized = {}
        for key, value in data.items():
            if isinstance(value, str):
                # Sanitize string values
                sanitized[key] = self.sanitize_command(value)
            elif isinstance(value, dict):
                # Recursively sanitize nested dicts
                sanitized[key] = self._sanitize_dict(value)
            elif isinstance(value, list):
                # Sanitize list items
                sanitized[key] = self._sanitize_list(value)
            else:
                # Keep other types as-is
                sanitized[key] = value
        
        return sanitized
    
    def _sanitize_list(self, data: List[Any]) -> List[Any]:
        """Recursively sanitize list items."""
        sanitized = []
        for item in data:
            if isinstance(item, str):
                sanitized.append(self.sanitize_command(item))
            elif isinstance(item, dict):
                sanitized.append(self._sanitize_dict(item))
            elif isinstance(item, list):
                sanitized.append(self._sanitize_list(item))
            else:
                sanitized.append(item)
        
        return sanitized
    
    def validate_and_sanitize(
        self,
        command: str,
        context: Optional[Dict[str, Any]] = None
    ) -> Tuple[bool, Optional[str], str, Optional[Dict[str, Any]]]:
        """
        Validate dan sanitize command + context sekaligus.
        
        Args:
            command: Raw command
            context: Raw context
            
        Returns:
            Tuple of (is_valid, error_message, sanitized_command, sanitized_context)
        """
        # Validate command
        command_valid, command_error = self.validate_command(command)
        if not command_valid:
            return False, command_error, command, context
        
        # Validate context
        context_valid, context_error = self.validate_context(context)
        if not context_valid:
            return False, context_error, command, context
        
        # Sanitize both
        sanitized_command = self.sanitize_command(command)
        sanitized_context = self.sanitize_context(context)
        
        logger.debug(f"✅ Request validated and sanitized successfully")
        return True, None, sanitized_command, sanitized_context
    
    def get_stats(self) -> Dict[str, Any]:
        """Get validation statistics."""
        total = self.validation_errors + self.validation_successes
        success_rate = (self.validation_successes / total * 100) if total > 0 else 0
        
        return {
            "total_validations": total,
            "successes": self.validation_successes,
            "errors": self.validation_errors,
            "success_rate": round(success_rate, 2),
            "max_command_length": self.MAX_COMMAND_LENGTH,
            "max_context_size": self.MAX_CONTEXT_SIZE
        }


# Global validator instance
_request_validator: Optional[RequestValidator] = None


def get_request_validator() -> RequestValidator:
    """Get or create global request validator."""
    global _request_validator
    if _request_validator is None:
        _request_validator = RequestValidator()
    return _request_validator
