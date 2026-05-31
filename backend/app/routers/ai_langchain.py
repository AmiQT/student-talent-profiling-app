"""LangChain Agentic AI Router.

FastAPI router for the LangChain-based agentic AI assistant.
This provides a cleaner, more stable implementation compared to
the custom Gemini client approach.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import logging
import os

from app.database import get_db
from app.auth import verify_supabase_token
from app.ai_assistant.langchain_agent import create_agent, StudentTalentAgent

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai/v2", tags=["AI Assistant v2 (LangChain)"])


# Request/Response models
class AgentCommandRequest(BaseModel):
    """Request model for agent commands."""
    command: str = Field(..., min_length=1, max_length=50000, description="User command/message with optional RAG context")
    context: Optional[Dict[str, Any]] = Field(default_factory=dict, description="Additional context")
    session_id: Optional[str] = Field(None, description="Session ID for conversation memory")


class AgentCommandResponse(BaseModel):
    """Response model for agent commands."""
    success: bool
    message: str
    session_id: Optional[str] = None
    tool_calls: List[Dict[str, Any]] = Field(default_factory=list)
    source: str = "langchain_agent"
    data: Optional[Dict[str, Any]] = None


class AgentHealthResponse(BaseModel):
    """Response model for health check."""
    status: str
    agent_type: str
    model: str
    tools_available: List[str]
    langchain_version: str


# Cached agent instance (per-request due to DB session dependency)
_agent_cache: Dict[str, StudentTalentAgent] = {}


def get_agent(db: Session = Depends(get_db)) -> StudentTalentAgent:
    """Get or create agent instance."""
    # Note: In production, you might want to use a more sophisticated
    # caching mechanism. For now, we create a new agent per request
    # to ensure fresh DB session.
    return create_agent(db=db)


@router.post("/command", response_model=AgentCommandResponse)
async def process_command(
    request: AgentCommandRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Process a command using the LangChain agentic AI.
    
    This endpoint uses LangGraph for orchestration and provides
    a more stable, production-ready implementation.
    
    Features:
    - Multi-turn conversation memory
    - Automatic tool selection and execution
    - Natural language understanding in Bahasa Melayu
    """
    try:
        # Get or generate session ID
        session_id = request.session_id or f"session_{current_user.get('uid', 'anonymous')}"
        
        logger.info(f"🤖 LangChain Agent received: '{request.command[:50]}...' from {current_user.get('email', 'unknown')}")
        
        # Create agent with database session
        agent = create_agent(db=db)
        
        # Process command
        result = await agent.invoke(
            message=request.command,
            session_id=session_id,
            config={"user": current_user, **request.context}
        )
        
        logger.info(f"✅ LangChain Agent response: success={result['success']}")
        
        return AgentCommandResponse(
            success=result["success"],
            message=result["message"],
            session_id=result.get("session_id", session_id),
            tool_calls=result.get("tool_calls", []),
            source=result.get("source", "langchain_agent"),
            data={
                "model": "gemini-2.5-flash",
                "agent_type": "langgraph"
            }
        )
        
    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Agent configuration error: {str(e)}"
        )
    except Exception as e:
        error_str = str(e)
        logger.error(f"Agent error: {e}", exc_info=True)
        
        # Check if it's a rate limit error - return friendly message
        is_rate_limit = any(keyword in error_str.upper() for keyword in [
            "429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE_LIMIT", "RATE LIMIT"
        ])
        
        if is_rate_limit:
            return AgentCommandResponse(
                success=False,
                message=(
                    "Hai! 👋 Terima kasih kerana bertanya. "
                    "Buat masa sekarang, saya sedang memproses banyak permintaan. "
                    "Sementara menunggu, anda boleh:\n\n"
                    "📚 Layari bahagian 'Aktiviti' untuk melihat event terkini\n"
                    "🎯 Semak profil anda di tab 'Profil'\n"
                    "💬 Berbual dengan rakan di 'Chat'\n\n"
                    "Cuba tanya saya semula dalam beberapa minit ya! 😊"
                ),
                session_id=request.session_id,
                tool_calls=[],
                source="langchain_agent",
                data={"error": "rate_limit", "retry_after": 60}
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Agent processing error: {error_str}"
        )


@router.post("/command/sync", response_model=AgentCommandResponse)
def process_command_sync(
    request: AgentCommandRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Synchronous version of process_command.
    
    Use this if you're having issues with async execution.
    """
    try:
        session_id = request.session_id or f"session_{current_user.get('uid', 'anonymous')}"
        
        logger.info(f"🤖 LangChain Agent (sync) received: '{request.command[:50]}...'")
        
        agent = create_agent(db=db)
        
        result = agent.invoke_sync(
            message=request.command,
            session_id=session_id,
            config={"user": current_user, **request.context}
        )
        
        return AgentCommandResponse(
            success=result["success"],
            message=result["message"],
            session_id=result.get("session_id", session_id),
            tool_calls=result.get("tool_calls", []),
            source=result.get("source", "langchain_agent"),
            data={
                "model": "gemini-2.5-flash",
                "agent_type": "langgraph",
                "sync_mode": True
            }
        )
        
    except Exception as e:
        error_str = str(e)
        logger.error(f"Agent sync error: {e}", exc_info=True)
        
        # Check if it's a rate limit error - return friendly message
        is_rate_limit = any(keyword in error_str.upper() for keyword in [
            "429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE_LIMIT", "RATE LIMIT"
        ])
        
        if is_rate_limit:
            return AgentCommandResponse(
                success=False,
                message=(
                    "Hai! 👋 Terima kasih kerana bertanya. "
                    "Buat masa sekarang, saya sedang memproses banyak permintaan. "
                    "Sementara menunggu, anda boleh:\n\n"
                    "📚 Layari bahagian 'Aktiviti' untuk melihat event terkini\n"
                    "🎯 Semak profil anda di tab 'Profil'\n"
                    "💬 Berbual dengan rakan di 'Chat'\n\n"
                    "Cuba tanya saya semula dalam beberapa minit ya! 😊"
                ),
                session_id=request.session_id,
                tool_calls=[],
                source="langchain_agent",
                data={"error": "rate_limit", "retry_after": 60, "sync_mode": True}
            )
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Agent processing error: {error_str}"
        )


@router.get("/health", response_model=AgentHealthResponse)
def health_check(db: Session = Depends(get_db)):
    """
    Check LangChain agent health and configuration.
    """
    try:
        import langchain
        from app.ai_assistant.langchain_agent.tools import get_student_tools
        
        # Check API key
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            return AgentHealthResponse(
                status="degraded",
                agent_type="langgraph",
                model="gemini-2.5-flash",
                tools_available=[],
                langchain_version=langchain.__version__
            )
        
        # Get available tools
        tools = get_student_tools(db)
        tool_names = [t.name for t in tools]
        
        return AgentHealthResponse(
            status="healthy",
            agent_type="langgraph",
            model="gemini-2.5-flash",
            tools_available=tool_names,
            langchain_version=langchain.__version__
        )
        
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return AgentHealthResponse(
            status="error",
            agent_type="langgraph",
            model="unknown",
            tools_available=[],
            langchain_version="unknown"
        )


@router.delete("/session/{session_id}")
def clear_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Clear conversation history for a session.
    """
    try:
        from app.ai_assistant.langchain_agent.memory import memory_manager
        
        # Verify user owns this session (basic check)
        user_session_prefix = f"session_{current_user.get('uid', '')}"
        if not session_id.startswith(user_session_prefix) and current_user.get("role") != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot clear sessions belonging to other users"
            )
        
        memory_manager.clear_session(session_id)
        
        return {
            "success": True,
            "message": f"Session '{session_id}' cleared successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Clear session error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/sessions")
def list_sessions(
    current_user: dict = Depends(verify_supabase_token)
):
    """
    List user's active sessions.
    """
    try:
        from app.ai_assistant.langchain_agent.memory import memory_manager
        
        user_id = current_user.get("uid", "anonymous")
        user_prefix = f"session_{user_id}"
        
        # Get sessions matching user prefix
        sessions = []
        for session_id in list(memory_manager._sessions.keys()):
            if session_id.startswith(user_prefix) or current_user.get("role") == "admin":
                summary = memory_manager.get_session_summary(session_id)
                sessions.append(summary)
        
        return {
            "success": True,
            "sessions": sessions
        }
        
    except Exception as e:
        logger.error(f"List sessions error: {e}")
        return {
            "success": False,
            "sessions": [],
            "error": str(e)
        }
