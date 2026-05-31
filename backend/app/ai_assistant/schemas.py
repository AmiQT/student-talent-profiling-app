"""Pydantic schemas untuk AI assistant module."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional, List, Union

from pydantic import BaseModel, Field


class AISource(str, Enum):
    PSEUDO = "pseudo"
    GEMINI = "gemini"
    MANUAL = "manual"
    ENHANCED_SUPABASE = "enhanced_supabase"


class AICommandRequest(BaseModel):
    """Payload dari frontend untuk jalankan arahan AI."""

    command: str = Field(..., description="Natural language command dari admin")
    context: dict[str, Any] | None = Field(default=None, description="Extra context seperti selected entity")
    mode: str = Field(default="standard", description="Mode for the AI command (e.g., standard, enhanced, direct_query)")


class AICommandStep(BaseModel):
    """Satu langkah reasoning/action dalam response AI."""

    label: str
    detail: str | None = None


class AIQueryResult(BaseModel):
    """Structure for query results from enhanced capabilities."""
    
    success: bool
    data: Union[List[dict], dict, str, None] = None
    query_type: str
    rows_affected: int = 0
    error: Optional[str] = None
    details: Optional[str] = None
    filters_applied: Optional[dict] = None


class AICommandResponse(BaseModel):
    """Response standard untuk arahan AI."""

    success: bool
    message: str
    source: AISource
    data: Optional[dict[str, Any]] = None
    steps: list[AICommandStep] = Field(default_factory=list)
    fallback_used: bool = Field(default=False)
    query_result: Optional[AIQueryResult] = None  # For enhanced query results


class AIActionLogCreate(BaseModel):
    """Log model untuk simpan tindakan AI."""

    user_id: str
    command: str
    response_message: str
    source: AISource
    success: bool
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: dict[str, Any] | None = None

