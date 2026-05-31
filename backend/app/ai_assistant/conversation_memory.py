"""Conversation Memory System for Agentic AI Assistant."""

from __future__ import annotations
from typing import Dict, List, Any, Optional, Union
from dataclasses import dataclass, asdict
from datetime import datetime
import json
import logging
from enum import Enum

logger = logging.getLogger(__name__)

class MemoryType(Enum):
    """Type of memory entry."""
    USER_MESSAGE = "user_message"
    AI_RESPONSE = "ai_response"
    SYSTEM_CONTEXT = "system_context"
    CONVERSATION_SUMMARY = "conversation_summary"


@dataclass
class MemoryEntry:
    """Represents a single entry in conversation memory."""
    id: str
    user_id: str
    session_id: str
    content: str
    message_type: MemoryType
    timestamp: datetime
    metadata: Dict[str, Any] = None
    message_id: Optional[str] = None
    intent: Optional[str] = None
    entities: Optional[Dict[str, Any]] = None


class ConversationMemory:
    """In-memory conversation storage with SQLite persistence option."""
    
    def __init__(self, max_messages: int = 20, max_history_days: int = 7):
        self.max_messages = max_messages
        self.max_history_days = max_history_days
        self._memory: Dict[str, List[MemoryEntry]] = {}  # session_id -> messages
        self._user_sessions: Dict[str, List[str]] = {}  # user_id -> [session_ids]
        self._last_tool_calls: Dict[str, Dict[str, Any]] = {}  # session_id -> last tool call
        
    def add_message(self, user_id: str, session_id: str, content: str, 
                   message_type: MemoryType, metadata: Optional[Dict[str, Any]] = None,
                   message_id: Optional[str] = None, intent: Optional[str] = None,
                   entities: Optional[Dict[str, Any]] = None) -> MemoryEntry:
        """Add a message to the conversation memory."""
        entry = MemoryEntry(
            id=f"{session_id}_{datetime.now().timestamp()}",
            user_id=user_id,
            session_id=session_id,
            content=content,
            message_type=message_type,
            timestamp=datetime.now(),
            metadata=metadata or {},
            message_id=message_id,
            intent=intent,
            entities=entities or {}
        )
        
        # Initialize session if not exists
        if session_id not in self._memory:
            self._memory[session_id] = []
            if user_id not in self._user_sessions:
                self._user_sessions[user_id] = []
            self._user_sessions[user_id].append(session_id)
        
        # Add entry to session
        self._memory[session_id].append(entry)
        
        # Trim memory if needed
        self._trim_session_memory(session_id)
        
        logger.info(f"Added message to session {session_id} for user {user_id}")
        return entry
    
    def add_tool_call(self, user_id: str, session_id: str, tool_name: str, 
                     arguments: Dict[str, Any], result: Dict[str, Any], 
                     success: bool = True) -> None:
        """Add a tool call to the conversation memory and track as last tool call."""
        if session_id not in self._memory:
            self._memory[session_id] = []
        
        # Create tool call summary
        result_summary = self._summarize_tool_result(result)
        
        # Store as last tool call for "again" context
        self._last_tool_calls[session_id] = {
            "tool": tool_name,
            "arguments": arguments,
            "result": result,
            "result_summary": result_summary,
            "timestamp": datetime.now().isoformat(),
            "success": success
        }
        
        logger.info(f"Added tool call to session {session_id}: {tool_name}")
    
    def add_user_message(self, user_id: str, session_id: str, content: str,
                        metadata: Optional[Dict[str, Any]] = None,
                        message_id: Optional[str] = None) -> MemoryEntry:
        """Add a user message to memory."""
        return self.add_message(user_id, session_id, content, 
                               MemoryType.USER_MESSAGE, metadata, message_id)
    
    def add_ai_response(self, user_id: str, session_id: str, content: str,
                       metadata: Optional[Dict[str, Any]] = None,
                       message_id: Optional[str] = None, 
                       intent: Optional[str] = None,
                       entities: Optional[Dict[str, Any]] = None) -> MemoryEntry:
        """Add an AI response to memory."""
        return self.add_message(user_id, session_id, content, 
                               MemoryType.AI_RESPONSE, metadata, 
                               message_id, intent, entities)
    
    def get_conversation_history(self, session_id: str, limit: Optional[int] = None) -> List[MemoryEntry]:
        """Get conversation history for a session."""
        if session_id not in self._memory:
            return []
        
        messages = self._memory[session_id]
        if limit:
            return messages[-limit:]
        return messages
    
    def get_recent_conversation_context(self, session_id: str, limit: int = 5) -> str:
        """Get recent conversation as context string."""
        messages = self.get_conversation_history(session_id, limit)
        context_lines = []
        
        for msg in messages:
            sender = "User" if msg.message_type == MemoryType.USER_MESSAGE else "AI Assistant"
            timestamp = msg.timestamp.strftime("%H:%M:%S")
            context_lines.append(f"[{timestamp}] {sender}: {msg.content}")
        
        return "\n".join(context_lines)
    
    def get_user_sessions(self, user_id: str) -> List[str]:
        """Get all session IDs for a user."""
        return self._user_sessions.get(user_id, [])
    
    def get_user_conversation_history(self, user_id: str, session_limit: int = 3, message_limit: int = 10) -> Dict[str, List[MemoryEntry]]:
        """Get conversation history for all user sessions."""
        sessions = self.get_user_sessions(user_id)
        result = {}
        
        # Get the most recent sessions
        recent_sessions = sessions[-session_limit:] if sessions else []
        
        for session_id in recent_sessions:
            result[session_id] = self.get_conversation_history(session_id, message_limit)
        
        return result
    
    def clear_session(self, session_id: str) -> bool:
        """Clear memory for a specific session."""
        if session_id in self._memory:
            del self._memory[session_id]
            # Also remove from user sessions
            for user_id, session_list in self._user_sessions.items():
                if session_id in session_list:
                    session_list.remove(session_id)
            logger.info(f"Cleared memory for session {session_id}")
            return True
        return False
    
    def clear_user_sessions(self, user_id: str) -> bool:
        """Clear all memory for a specific user."""
        if user_id in self._user_sessions:
            sessions_to_delete = self._user_sessions[user_id].copy()
            for session_id in sessions_to_delete:
                self.clear_session(session_id)
            del self._user_sessions[user_id]
            logger.info(f"Cleared all sessions for user {user_id}")
            return True
        return False
    
    def _trim_session_memory(self, session_id: str):
        """Trim session memory to stay within limits."""
        if session_id not in self._memory:
            return
        
        messages = self._memory[session_id]
        if len(messages) > self.max_messages:
            # Keep the most recent messages
            self._memory[session_id] = messages[-self.max_messages:]
            logger.debug(f"Trimmed session {session_id} memory to {self.max_messages} messages")
    
    def get_session_summary(self, session_id: str) -> Dict[str, Any]:
        """Get summary information about a session."""
        if session_id not in self._memory:
            return {}
        
        messages = self._memory[session_id]
        user_messages = [m for m in messages if m.message_type == MemoryType.USER_MESSAGE]
        ai_responses = [m for m in messages if m.message_type == MemoryType.AI_RESPONSE]
        
        return {
            "session_id": session_id,
            "total_messages": len(messages),
            "user_messages": len(user_messages),
            "ai_responses": len(ai_responses),
            "start_time": messages[0].timestamp if messages else None,
            "last_message_time": messages[-1].timestamp if messages else None,
            "is_active": len(messages) > 0
        }
    
    def cleanup_old_sessions(self):
        """Remove sessions older than max_history_days."""
        import datetime
        cutoff_time = datetime.datetime.now() - datetime.timedelta(days=self.max_history_days)
        
        sessions_to_remove = []
        for session_id, messages in self._memory.items():
            if messages and messages[-1].timestamp < cutoff_time:
                sessions_to_remove.append(session_id)
        
        for session_id in sessions_to_remove:
            self.clear_session(session_id)
        
        logger.info(f"Cleaned up {len(sessions_to_remove)} old sessions")
    
    def get_structured_context(self, session_id: str, limit: int = 10) -> Dict[str, Any]:
        """Get structured conversation context for agentic AI.
        
        Returns a rich context object with:
        - Recent messages
        - Tool calls made
        - Entities mentioned
        - Session insights
        """
        if session_id not in self._memory:
            return {
                "messages": [],
                "tool_calls": [],
                "entities": {},
                "insights": {
                    "message_count": 0,
                    "has_history": False
                }
            }
        
        messages = self._memory[session_id][-limit:]
        
        # Extract tool calls from metadata
        tool_calls = []
        all_entities = {}
        
        for msg in messages:
            # Track tool usage
            if msg.metadata and "tools_used" in msg.metadata:
                for tool_use in msg.metadata["tools_used"]:
                    tool_calls.append({
                        "tool": tool_use["tool"],
                        "arguments": tool_use["arguments"],
                        "timestamp": msg.timestamp.isoformat(),
                        "result_summary": self._summarize_tool_result(tool_use.get("result", {}))
                    })
            
            # Aggregate entities
            if msg.entities:
                for entity_type, values in msg.entities.items():
                    if entity_type not in all_entities:
                        all_entities[entity_type] = []
                    if isinstance(values, list):
                        all_entities[entity_type].extend(values)
                    else:
                        all_entities[entity_type].append(values)
        
        # Generate insights
        insights = {
            "message_count": len(messages),
            "has_history": len(messages) > 0,
            "tool_calls_count": len(tool_calls),
            "unique_intents": list(set(msg.intent for msg in messages if msg.intent)),
            "session_duration_minutes": (messages[-1].timestamp - messages[0].timestamp).total_seconds() / 60 if messages else 0
        }
        
        return {
            "messages": [self._message_to_dict(msg) for msg in messages],
            "tool_calls": tool_calls,
            "entities": all_entities,
            "insights": insights,
            "last_tool_call": self._last_tool_calls.get(session_id)
        }
    
    def _summarize_tool_result(self, result: Dict[str, Any]) -> str:
        """Create a brief summary of tool result."""
        if not result:
            return "No result"
        
        if result.get("success"):
            if "count" in result:
                return f"Found {result['count']} items"
            elif "students" in result:
                return f"Found {len(result['students'])} students"
            elif "events" in result:
                return f"Found {len(result['events'])} events"
            else:
                return "Success"
        else:
            return f"Error: {result.get('error', 'Unknown')}"
    
    def _message_to_dict(self, msg: MemoryEntry) -> Dict[str, Any]:
        """Convert MemoryEntry to dict for serialization."""
        return {
            "content": msg.content,
            "type": msg.message_type.value,
            "timestamp": msg.timestamp.isoformat(),
            "intent": msg.intent,
            "has_tools": bool(msg.metadata and "tools_used" in msg.metadata)
        }


# Global conversation memory instance
conversation_memory = ConversationMemory()


# Async wrapper for easier integration (if needed)
class AsyncConversationMemory:
    """Async wrapper for conversation memory system."""
    
    def __init__(self):
        self.sync_memory = conversation_memory
    
    async def add_message(self, user_id: str, session_id: str, content: str, 
                         message_type: MemoryType, metadata: Optional[Dict[str, Any]] = None,
                         message_id: Optional[str] = None, intent: Optional[str] = None,
                         entities: Optional[Dict[str, Any]] = None) -> MemoryEntry:
        """Async wrapper for adding message."""
        return self.sync_memory.add_message(user_id, session_id, content, 
                                          message_type, metadata, message_id, 
                                          intent, entities)
    
    async def get_conversation_history(self, session_id: str, limit: Optional[int] = None) -> List[MemoryEntry]:
        """Async wrapper for getting conversation history."""
        return self.sync_memory.get_conversation_history(session_id, limit)
    
    async def get_recent_conversation_context(self, session_id: str, limit: int = 5) -> str:
        """Async wrapper for getting recent conversation context."""
        return self.sync_memory.get_recent_conversation_context(session_id, limit)


if __name__ == "__main__":
    # Example usage
    mem = ConversationMemory()
    
    # Simulate a conversation
    session_id = "session_123"
    user_id = "user_456"
    
    # Add some messages
    mem.add_user_message(user_id, session_id, "Hi there!")
    mem.add_ai_response(user_id, session_id, "Hello! How can I help you today?")
    mem.add_user_message(user_id, session_id, "Can you show me top students?")
    mem.add_ai_response(user_id, session_id, "Sure! Here are the top students...", 
                       intent="student_query", entities={"limit": 5, "type": "top"})
    
    # Get conversation context
    context = mem.get_recent_conversation_context(session_id, limit=3)
    print("Recent conversation context:")
    print(context)
    
    # Get session summary
    summary = mem.get_session_summary(session_id)
    print(f"\nSession summary: {summary}")