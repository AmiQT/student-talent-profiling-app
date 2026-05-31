"""AI Assistant package initialization.

Agentic AI System for UTHM Dashboard.
Phase 1: Removed keyword-based actions, Gemini handles all NLU.
Phase 2+: Tool calling, structured context, agentic orchestration.
Phase 3: Circuit breaker, caching, monitoring, request validation.
"""

from .config import get_ai_settings
from .manager import AIAssistantManager
from . import schemas
from .tools import AVAILABLE_TOOLS, get_tool_by_name, get_all_tool_names
from .tool_executor import ToolExecutor
from .circuit_breaker import get_circuit_breaker, get_all_circuit_breakers
from .cache_manager import get_ai_cache, clear_ai_cache
from .monitoring import get_metrics_collector
from .request_validator import get_request_validator

__all__ = [
    "AIAssistantManager",
    "get_ai_settings",
    "schemas",
    "AVAILABLE_TOOLS",
    "get_tool_by_name",
    "get_all_tool_names",
    "ToolExecutor",
    "get_circuit_breaker",
    "get_all_circuit_breakers",
    "get_ai_cache",
    "clear_ai_cache",
    "get_metrics_collector",
    "get_request_validator",
]

