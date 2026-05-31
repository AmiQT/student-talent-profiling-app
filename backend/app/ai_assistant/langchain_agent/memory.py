"""Conversation Memory for LangChain Agent.

Provides persistent conversation memory that integrates with
the existing conversation_memory system.
"""

from typing import List, Dict, Any, Optional
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage, SystemMessage
from langchain_core.chat_history import BaseChatMessageHistory
import logging

logger = logging.getLogger(__name__)


class InMemoryHistory(BaseChatMessageHistory):
    """Simple in-memory chat history for a session."""
    
    def __init__(self, session_id: str, max_messages: int = 50):
        self.session_id = session_id
        self.max_messages = max_messages
        self._messages: List[BaseMessage] = []
    
    @property
    def messages(self) -> List[BaseMessage]:
        """Return messages, limited to max_messages."""
        return self._messages[-self.max_messages:]
    
    def add_message(self, message: BaseMessage) -> None:
        """Add a message to history."""
        self._messages.append(message)
        
        # Trim if exceeds max
        if len(self._messages) > self.max_messages * 2:
            self._messages = self._messages[-self.max_messages:]
    
    def add_user_message(self, message: str) -> None:
        """Add a user message."""
        self.add_message(HumanMessage(content=message))
    
    def add_ai_message(self, message: str) -> None:
        """Add an AI message."""
        self.add_message(AIMessage(content=message))
    
    def clear(self) -> None:
        """Clear all messages."""
        self._messages = []


class ConversationMemoryManager:
    """Manages conversation memory across sessions."""
    
    def __init__(self, max_sessions: int = 1000, max_messages_per_session: int = 50):
        self.max_sessions = max_sessions
        self.max_messages_per_session = max_messages_per_session
        self._sessions: Dict[str, InMemoryHistory] = {}
    
    def get_session_history(self, session_id: str) -> InMemoryHistory:
        """Get or create session history."""
        if session_id not in self._sessions:
            # Clean up old sessions if needed
            if len(self._sessions) >= self.max_sessions:
                # Remove oldest sessions (simple FIFO)
                oldest_keys = list(self._sessions.keys())[:len(self._sessions) // 4]
                for key in oldest_keys:
                    del self._sessions[key]
                logger.info(f"Cleaned up {len(oldest_keys)} old sessions")
            
            self._sessions[session_id] = InMemoryHistory(
                session_id=session_id,
                max_messages=self.max_messages_per_session
            )
        
        return self._sessions[session_id]
    
    def clear_session(self, session_id: str) -> None:
        """Clear a specific session."""
        if session_id in self._sessions:
            self._sessions[session_id].clear()
    
    def delete_session(self, session_id: str) -> None:
        """Delete a session entirely."""
        if session_id in self._sessions:
            del self._sessions[session_id]
    
    def get_session_summary(self, session_id: str) -> Dict[str, Any]:
        """Get summary of a session."""
        if session_id not in self._sessions:
            return {"exists": False, "message_count": 0}
        
        history = self._sessions[session_id]
        return {
            "exists": True,
            "message_count": len(history.messages),
            "session_id": session_id
        }


# Global memory manager instance
memory_manager = ConversationMemoryManager()


def get_session_history(session_id: str) -> InMemoryHistory:
    """Get session history - used by RunnableWithMessageHistory."""
    return memory_manager.get_session_history(session_id)
