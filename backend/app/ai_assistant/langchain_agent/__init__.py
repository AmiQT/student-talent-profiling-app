"""LangChain Agentic AI Module.

This module provides a robust, production-ready agentic AI implementation
using LangChain and LangGraph for the Student Talent Analytics system.
Includes NLP-enhanced tools for semantic search and entity extraction.
"""

from .agent import StudentTalentAgent, create_agent
from .tools import get_student_tools, get_all_tools
from .prompts import SYSTEM_PROMPT

__all__ = [
    "StudentTalentAgent",
    "create_agent", 
    "get_student_tools",
    "get_all_tools",
    "SYSTEM_PROMPT",
]
