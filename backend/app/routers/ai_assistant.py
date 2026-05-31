"""FastAPI router untuk AI assistant command endpoint."""

from fastapi import APIRouter, Depends, HTTPException, status
from typing import Optional
import logging

from app.auth import verify_supabase_token

from app.ai_assistant.manager import AIAssistantManager
from app.ai_assistant import schemas, history
from app.ai_assistant.conversation_memory import conversation_memory, MemoryType
from app.ai_assistant.template_manager import template_manager
from app.ai_assistant.tools import get_all_tool_names
from app.ai_assistant.key_rotator import get_key_rotator
from app.ai_assistant.monitoring import get_metrics_collector
from app.ai_assistant.circuit_breaker import get_all_circuit_breakers
from app.ai_assistant.cache_manager import get_ai_cache
from app.ai_assistant.request_validator import get_request_validator

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ai", tags=["ai-assistant"])


@router.post("/command", response_model=schemas.AICommandResponse)
async def process_ai_command(
    payload: schemas.AICommandRequest,
    manager: AIAssistantManager = Depends(),
    current_user: dict = Depends(verify_supabase_token),
):
    """Process command yang datang dari web dashboard."""

    if not payload.command.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Command cannot be empty")

    # Log the incoming command for debugging
    logger.info(f"🤖 AI Assistant received command: {payload.command}")

    # Extract session ID from context or generate new one
    session_id = payload.context.get("session_id", f"session_{current_user.get('uid', 'anonymous')}")
    
    # Add user message to conversation memory
    conversation_memory.add_user_message(
        user_id=current_user.get("uid", "anonymous"),
        session_id=session_id,
        content=payload.command,
        metadata=payload.context
    )

    response = await manager.handle_command(
        payload.command,
        context=payload.context,
        current_user=current_user,
    )

    # Add AI response to conversation memory
    if response.success and response.message:
        conversation_memory.add_ai_response(
            user_id=current_user.get("uid", "anonymous"),
            session_id=session_id,
            content=response.message,
            metadata=response.data or {},
            intent=response.data.get("intent") if response.data else None
        )

    # Log the response for debugging
    logger.info(f"🤖 AI Assistant response success: {response.success}, message length: {len(response.message)}")

    if not response.success:
        # 200 OK tapi kita embed success flag → frontend boleh handle gracefully
        # Option: kalau nak 4xx, boleh tukar bila behaviour dah stabil.
        return response

    return response


@router.get("/history")
async def get_ai_history(limit: int = 10):
    """Get AI command history (public endpoint for dashboard)."""
    return {
        "history": history.get_recent_history(limit)
    }


# New endpoints for conversation memory management
@router.get("/conversations")
async def get_user_conversations(
    current_user: dict = Depends(verify_supabase_token),
    session_limit: int = 10,
    message_limit: int = 20
):
    """Get user's conversation history."""
    user_id = current_user.get("uid", "anonymous")
    history = conversation_memory.get_user_conversation_history(
        user_id, session_limit, message_limit
    )
    
    return {
        "user_id": user_id,
        "conversations": {
            session_id: [
                {
                    "id": msg.id,
                    "content": msg.content,
                    "type": msg.message_type.value,
                    "timestamp": msg.timestamp.isoformat(),
                    "metadata": msg.metadata
                } for msg in messages
            ]
            for session_id, messages in history.items()
        }
    }


@router.get("/conversation/{session_id}")
async def get_conversation_session(
    session_id: str,
    limit: int = 50,
    current_user: dict = Depends(verify_supabase_token)
):
    """Get specific conversation session history."""
    # Verify user has access to this session (basic check)
    user_sessions = conversation_memory.get_user_sessions(current_user.get("uid", "anonymous"))
    if session_id not in user_sessions and current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this conversation session"
        )
    
    messages = conversation_memory.get_conversation_history(session_id, limit)
    
    return {
        "session_id": session_id,
        "messages": [
            {
                "id": msg.id,
                "content": msg.content,
                "type": msg.message_type.value,
                "timestamp": msg.timestamp.isoformat(),
                "metadata": msg.metadata
            } for msg in messages
        ],
        "summary": conversation_memory.get_session_summary(session_id)
    }


@router.delete("/conversation/{session_id}")
async def clear_conversation_session(
    session_id: str,
    current_user: dict = Depends(verify_supabase_token)
):
    """Clear specific conversation session."""
    # Verify user has access to this session
    user_sessions = conversation_memory.get_user_sessions(current_user.get("uid", "anonymous"))
    if session_id not in user_sessions and current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied to this conversation session"
        )
    
    success = conversation_memory.clear_session(session_id)
    
    if success:
        return {"message": f"Session {session_id} cleared successfully", "success": True}
    else:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Session {session_id} not found"
        )


@router.delete("/conversations")
async def clear_user_conversations(
    current_user: dict = Depends(verify_supabase_token)
):
    """Clear all conversation sessions for user."""
    user_id = current_user.get("uid", "anonymous")
    success = conversation_memory.clear_user_sessions(user_id)
    
    if success:
        return {"message": f"All sessions for user {user_id} cleared successfully", "success": True}
    else:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No sessions found for user {user_id}"
        )


@router.get("/templates")
async def get_templates(
    category: Optional[str] = None,
    tag: Optional[str] = None,
    search: Optional[str] = None
):
    """Get available templates."""
    templates = []
    
    if search:
        # Search templates
        found_templates = template_manager.search_templates(search)
        templates = [
            {
                "template_id": t.template_id,
                "name": t.name,
                "content": t.content,
                "category": t.category.value,
                "tags": t.tags,
                "variables": t.variables,
                "priority": t.priority,
                "is_active": t.is_active
            } for t in found_templates
        ]
    elif tag:
        # Get templates by tag
        found_templates = template_manager.get_templates_by_tag(tag)
        templates = [
            {
                "template_id": t.template_id,
                "name": t.name,
                "content": t.content,
                "category": t.category.value,
                "tags": t.tags,
                "variables": t.variables,
                "priority": t.priority,
                "is_active": t.is_active
            } for t in found_templates
        ]
    elif category:
        # Get templates by category
        from app.ai_assistant.template_manager import TemplateCategory
        try:
            cat_enum = TemplateCategory(category)
            found_templates = template_manager.get_templates_by_category(cat_enum)
            templates = [
                {
                    "template_id": t.template_id,
                    "name": t.name,
                    "content": t.content,
                    "category": t.category.value,
                    "tags": t.tags,
                    "variables": t.variables,
                    "priority": t.priority,
                    "is_active": t.is_active
                } for t in found_templates
            ]
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid category: {category}"
            )
    else:
        # Get all templates
        all_templates = template_manager._templates.values()
        templates = [
            {
                "template_id": t.template_id,
                "name": t.name,
                "content": t.content,
                "category": t.category.value,
                "tags": t.tags,
                "variables": t.variables,
                "priority": t.priority,
                "is_active": t.is_active
            } for t in all_templates
        ]
    
    return {"templates": templates}


@router.get("/memory/stats")
async def get_memory_stats():
    """Get conversation memory statistics."""
    return {
        "conversation_stats": conversation_memory.get_session_summary("global") if "global" in conversation_memory._memory else {},
        "template_stats": template_manager.get_statistics(),
        "active_sessions": len(conversation_memory._memory),
        "total_users_with_sessions": len(conversation_memory._user_sessions)
    }


@router.get("/keys/stats")
async def get_key_rotation_stats(
    current_user: dict = Depends(verify_supabase_token)
):
    """Get API key rotation statistics (admin only)."""
    # Check if user is admin
    if current_user.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Only admins can view key rotation stats"
        )
    
    rotator = get_key_rotator()
    if not rotator:
        return {
            "enabled": False,
            "message": "Key rotation not configured (using single API key)"
        }
    
    stats = rotator.get_stats()
    return {
        "enabled": True,
        "stats": stats
    }


@router.get("/agentic/status")
async def get_agentic_status():
    """Get agentic AI system status and capabilities."""
    from app.ai_assistant.tools import AVAILABLE_TOOLS
    from app.ai_assistant.config import get_ai_settings
    
    settings = get_ai_settings()
    
    return {
        "system": "Agentic AI Upgrade Complete",
        "version": "2.0.0",
        "status": "operational",
        "features": {
            "tool_calling": True,
            "structured_context": True,
            "conversation_memory": True,
            "database_access": True,
            "natural_language": True
        },
        "tools": {
            "available": get_all_tool_names(),
            "count": len(AVAILABLE_TOOLS)
        },
        "config": {
            "openrouter_enabled": settings.enable_openrouter,
            "ai_enabled": settings.ai_enabled,
            "model": "qwen/qwen3-30b-a3b:free"
        },
        "phases_completed": [
            "Phase 1: Keyword system removed",
            "Phase 2: Tool calling implemented",
            "Phase 3: Structured context added",
            "Phase 4: Database access enabled",
            "Phase 5: Testing & refinement done"
        ]
    }
@router.get("/health")
async def get_ai_health():
    """Get AI system health status and metrics."""
    metrics_collector = get_metrics_collector()
    cache = get_ai_cache()
    validator = get_request_validator()
    
    health_data = metrics_collector.get_system_health()
    cache_stats = cache.get_stats()
    validator_stats = validator.get_stats()
    circuit_breakers = get_all_circuit_breakers()
    
    # Get key rotator stats if available
    key_rotator = get_key_rotator()
    key_stats = key_rotator.get_stats() if key_rotator else {"total_keys": 1, "active_keys": 1, "cooldown_keys": 0}
    
    return {
        "status": health_data["status"],
        "uptime": {
            "seconds": health_data["uptime_seconds"],
            "hours": health_data["uptime_hours"]
        },
        "performance": {
            "recent_5min": health_data["recent_5min"],
            "overall": health_data["overall"]
        },
        "cache": {
            "size": cache_stats["size"],
            "max_size": cache_stats["max_size"],
            "hit_rate": cache_stats["hit_rate"],
            "total_requests": cache_stats["total_requests"]
        },
        "validation": {
            "total_validations": validator_stats["total_validations"],
            "success_rate": validator_stats["success_rate"],
            "errors": validator_stats["errors"]
        },
        "circuit_breakers": circuit_breakers,
        "api_keys": {
            "total": key_stats["total_keys"],
            "active": key_stats["active_keys"],
            "cooldown": key_stats["cooldown_keys"]
        }
    }


@router.get("/metrics")
async def get_ai_metrics(current_user: dict = Depends(verify_supabase_token)):
    """Get detailed AI metrics (requires authentication)."""
    metrics_collector = get_metrics_collector()
    
    return metrics_collector.get_full_report()


@router.get("/metrics/tools")
async def get_tool_metrics():
    """Get tool usage statistics."""
    metrics_collector = get_metrics_collector()
    
    return {
        "tool_usage": metrics_collector.get_tool_usage_stats(),
        "available_tools": get_all_tool_names()
    }


@router.post("/cache/clear")
async def clear_cache(current_user: dict = Depends(verify_supabase_token)):
    """Clear AI response cache (admin only)."""
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    
    cache = get_ai_cache()
    cache.clear()
    
    return {"message": "Cache cleared successfully", "status": "success"}


@router.get("/cache/stats")
async def get_cache_stats():
    """Get cache statistics."""
    cache = get_ai_cache()
    return cache.get_stats()


