"""LangChain Agentic AI Agent for Student Talent Analytics.

This module provides a production-ready agentic AI implementation
using LangChain and LangGraph with pluggable LLM providers (Gemini/Ollama).
"""

from typing import Dict, Any, List, Optional, Literal
from langchain_core.messages import (
    BaseMessage, 
    HumanMessage, 
    AIMessage, 
    SystemMessage,
    ToolMessage
)
from langchain_core.runnables import RunnableConfig
from langgraph.graph import StateGraph, START, END, MessagesState
from langgraph.checkpoint.memory import MemorySaver
from langgraph.prebuilt import ToolNode
from sqlalchemy.orm import Session
import logging
import os

from .prompts import CONCISE_SYSTEM_PROMPT
from .tools import get_student_tools, get_all_tools
from .memory import get_session_history, memory_manager
from app.ai_assistant.llm_factory import create_llm
from app.core.key_manager import key_manager, get_gemini_key

logger = logging.getLogger(__name__)


class StudentTalentAgent:
    """Agentic AI for Student Talent Analytics using LangGraph."""
    
    def __init__(
        self, 
        db: Session,
        provider: Optional[str] = None,
        model_name: Optional[str] = None,
        temperature: Optional[float] = None,
        include_nlp_tools: bool = True
    ):
        """
        Initialize Student Talent Agent.
        
        Args:
            db: Database session
            provider: LLM provider ("gemini" or "ollama", default from AI_PROVIDER env)
            model_name: Model name (default from AI_MODEL_NAME env)
            temperature: Temperature 0-1 (default from AI_TEMPERATURE env or 0.7)
            include_nlp_tools: Include NLP tools (default True)
        """
        self.db = db
        self.provider = provider
        self.model_name = model_name
        self.temperature = temperature
        
        # Initialize LLM using factory
        self.llm = create_llm(
            provider=provider,
            model_name=model_name,
            temperature=temperature
        )
        
        # Get tools (with or without NLP)
        if include_nlp_tools:
            self.tools = get_all_tools(db)
        else:
            self.tools = get_student_tools(db)
        
        # Bind tools to LLM
        self.llm_with_tools = self.llm.bind_tools(self.tools)
        
        # Create the agent graph
        self.graph = self._build_graph()
        
        logger.info(f"✅ StudentTalentAgent initialized with {len(self.tools)} tools")
    
    def _build_graph(self) -> StateGraph:
        """Build the LangGraph agent workflow."""
        
        # Define the agent node
        def call_model(state: MessagesState) -> Dict[str, List[BaseMessage]]:
            """Call the LLM with tools bound."""
            messages = state["messages"]
            
            # Prepend system message if not already there
            if not messages or not isinstance(messages[0], SystemMessage):
                messages = [SystemMessage(content=CONCISE_SYSTEM_PROMPT)] + messages
            
            response = self.llm_with_tools.invoke(messages)
            return {"messages": [response]}
        
        # Define routing logic
        def should_continue(state: MessagesState) -> Literal["tools", END]:
            """Decide whether to continue to tools or end."""
            messages = state["messages"]
            last_message = messages[-1]
            
            # If the last message has tool calls, route to tools
            if hasattr(last_message, 'tool_calls') and last_message.tool_calls:
                return "tools"
            
            # Otherwise, end
            return END
        
        # Build the graph
        builder = StateGraph(MessagesState)
        
        # Add nodes
        builder.add_node("agent", call_model)
        builder.add_node("tools", ToolNode(self.tools))
        
        # Add edges
        builder.add_edge(START, "agent")
        builder.add_conditional_edges("agent", should_continue, ["tools", END])
        builder.add_edge("tools", "agent")  # Loop back after tool execution
        
        # Compile WITHOUT memory checkpointer (we handle history manually)
        return builder.compile()
    
    async def invoke(
        self, 
        message: str, 
        session_id: str = "default",
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Process a user message through the agent.
        
        Args:
            message: User message
            session_id: Session ID for conversation memory
            config: Additional configuration
            
        Returns:
            Dict with response and metadata
        """
        try:
            # Get session history
            history = get_session_history(session_id)
            
            # Build messages with history
            # IMPORTANT: We manually inject history into the graph input
            messages = list(history.messages) + [HumanMessage(content=message)]
            
            logger.info(f"🤖 Invoking agent with {len(messages)} messages (Session: {session_id})")
            
            # Invoke the graph
            # We don't pass thread_id because we're injecting full history manually
            result = await self.graph.ainvoke(
                {"messages": messages}
            )
            
            # Extract final response
            final_messages = result.get("messages", [])
            
            # Find the last AI message
            ai_response = None
            tool_calls_made = []
            
            for msg in reversed(final_messages):
                if isinstance(msg, AIMessage):
                    if msg.content and not ai_response:
                        # Handle both string and list content formats
                        content = msg.content
                        if isinstance(content, list):
                            # Extract text from list format (Gemini multimodal response)
                            text_parts = []
                            for part in content:
                                if isinstance(part, dict) and part.get('type') == 'text':
                                    text_parts.append(part.get('text', ''))
                                elif isinstance(part, str):
                                    text_parts.append(part)
                            ai_response = ''.join(text_parts)
                        else:
                            ai_response = str(content)
                    if hasattr(msg, 'tool_calls') and msg.tool_calls:
                        tool_calls_made.extend(msg.tool_calls)
                elif isinstance(msg, ToolMessage):
                    pass  # Track tool results if needed
            
            # Save to history
            history.add_user_message(message)
            if ai_response:
                history.add_ai_message(ai_response)
            
            return {
                "success": True,
                "message": ai_response or "Maaf, saya tidak dapat memproses permintaan anda.",
                "session_id": session_id,
                "tool_calls": [
                    {"name": tc.get("name"), "args": tc.get("args")}
                    for tc in tool_calls_made
                ] if tool_calls_made else [],
                "source": "langchain_agent"
            }
            
        except Exception as e:
            error_str = str(e)
            logger.error(f"Error in agent invoke: {e}", exc_info=True)
            
            # Check for rate limit error - provide helpful fallback
            is_rate_limit = any(keyword in error_str.upper() for keyword in [
                "429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE_LIMIT", "RATE LIMIT"
            ])
            
            if is_rate_limit:
                fallback_message = (
                    "Hai! 👋 Terima kasih kerana bertanya. "
                    "Buat masa sekarang, saya sedang memproses banyak permintaan. "
                    "Sementara menunggu, anda boleh:\n\n"
                    "📚 Layari bahagian 'Aktiviti' untuk melihat event terkini\n"
                    "🎯 Semak profil anda di tab 'Profil'\n"
                    "💬 Berbual dengan rakan di 'Chat'\n\n"
                    "Cuba tanya saya semula dalam beberapa minit ya! 😊"
                )
                return {
                    "success": False,
                    "message": fallback_message,
                    "session_id": session_id,
                    "error": "rate_limit",
                    "retry_after": 60,
                    "source": "langchain_agent"
                }
            
            # Generic error
            return {
                "success": False,
                "message": f"Maaf, terjadi kesalahan: {error_str}",
                "session_id": session_id,
                "error": error_str,
                "source": "langchain_agent"
            }
    
    def invoke_sync(
        self, 
        message: str, 
        session_id: str = "default",
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Synchronous version of invoke for non-async contexts.
        
        Args:
            message: User message
            session_id: Session ID for conversation memory
            config: Additional configuration
            
        Returns:
            Dict with response and metadata
        """
        try:
            # Get session history
            history = get_session_history(session_id)
            
            # Build messages with history
            messages = list(history.messages) + [HumanMessage(content=message)]
            
            # Prepend system message
            messages = [SystemMessage(content=CONCISE_SYSTEM_PROMPT)] + messages
            
            logger.info(f"🤖 Invoking agent_sync with {len(messages)} messages (Session: {session_id})")
            
            # Invoke the graph synchronously
            result = self.graph.invoke(
                {"messages": messages}
            )
            
            # Extract final response
            final_messages = result.get("messages", [])
            
            # Find the last AI message with content
            ai_response = None
            tool_calls_made = []
            
            for msg in reversed(final_messages):
                if isinstance(msg, AIMessage):
                    if msg.content and not ai_response:
                        # Handle both string and list content formats
                        content = msg.content
                        if isinstance(content, list):
                            # Extract text from list format (Gemini multimodal response)
                            text_parts = []
                            for part in content:
                                if isinstance(part, dict) and part.get('type') == 'text':
                                    text_parts.append(part.get('text', ''))
                                elif isinstance(part, str):
                                    text_parts.append(part)
                            ai_response = ''.join(text_parts)
                        else:
                            ai_response = str(content)
                    if hasattr(msg, 'tool_calls') and msg.tool_calls:
                        tool_calls_made.extend(msg.tool_calls)
            
            # Save to history
            history.add_user_message(message)
            if ai_response:
                history.add_ai_message(ai_response)
            
            return {
                "success": True,
                "message": ai_response or "Maaf, saya tidak dapat memproses permintaan anda.",
                "session_id": session_id,
                "tool_calls": [
                    {"name": tc.get("name"), "args": tc.get("args")}
                    for tc in tool_calls_made
                ] if tool_calls_made else [],
                "source": "langchain_agent"
            }
            
        except Exception as e:
            error_str = str(e)
            logger.error(f"Error in agent invoke_sync: {e}", exc_info=True)
            
            # Check for rate limit error - provide helpful fallback
            is_rate_limit = any(keyword in error_str.upper() for keyword in [
                "429", "RESOURCE_EXHAUSTED", "QUOTA", "RATE_LIMIT", "RATE LIMIT"
            ])
            
            if is_rate_limit:
                fallback_message = (
                    "Hai! 👋 Terima kasih kerana bertanya. "
                    "Buat masa sekarang, saya sedang memproses banyak permintaan. "
                    "Sementara menunggu, anda boleh:\n\n"
                    "📚 Layari bahagian 'Aktiviti' untuk melihat event terkini\n"
                    "🎯 Semak profil anda di tab 'Profil'\n"
                    "💬 Berbual dengan rakan di 'Chat'\n\n"
                    "Cuba tanya saya semula dalam beberapa minit ya! 😊"
                )
                return {
                    "success": False,
                    "message": fallback_message,
                    "session_id": session_id,
                    "error": "rate_limit",
                    "retry_after": 60,
                    "source": "langchain_agent"
                }
            
            # Generic error
            return {
                "success": False,
                "message": f"Maaf, terjadi kesalahan: {error_str}",
                "session_id": session_id,
                "error": error_str,
                "source": "langchain_agent"
            }
    
    def clear_session(self, session_id: str) -> None:
        """Clear conversation history for a session."""
        memory_manager.clear_session(session_id)
        logger.info(f"Cleared session: {session_id}")


def create_agent(
    db: Session,
    provider: Optional[str] = None,
    model_name: Optional[str] = None,
    temperature: Optional[float] = None
) -> StudentTalentAgent:
    """
    Factory function to create a StudentTalentAgent.
    
    Args:
        db: SQLAlchemy database session
        provider: LLM provider ("gemini" or "ollama", default from env)
        model_name: Model name (default from env)
        temperature: Temperature 0-1 (default from env)
        
    Returns:
        Configured StudentTalentAgent instance
    """
    return StudentTalentAgent(
        db=db,
        provider=provider,
        model_name=model_name,
        temperature=temperature
    )
