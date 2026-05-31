"""NLP Module for Student Talent Analytics.

This module provides advanced NLP capabilities including:
- Named Entity Recognition (NER) with spaCy
- Semantic Search with Sentence Transformers
- Malay Language Processing
- Retrieval-Augmented Generation (RAG)
"""

from .core import NLPProcessor, get_nlp_processor
from .semantic_search import SemanticSearchEngine, get_search_engine
from .malay_processor import MalayNLPProcessor, get_malay_processor
from .rag import RAGSystem, get_rag_system
from .entities import EntityExtractor as MalayEntityExtractor

__all__ = [
    "NLPProcessor",
    "get_nlp_processor",
    "SemanticSearchEngine", 
    "get_search_engine",
    "MalayNLPProcessor",
    "get_malay_processor",
    "RAGSystem",
    "get_rag_system",
    "MalayEntityExtractor",
]
