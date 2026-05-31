"""Semantic Search Engine using Sentence Transformers.

Provides vector-based semantic search capabilities for finding
similar content based on meaning rather than exact keyword matching.
"""

from typing import List, Dict, Any, Optional, Tuple
import logging
import numpy as np
from dataclasses import dataclass

logger = logging.getLogger(__name__)

# Lazy loading for fastembed
_model = None
_model_available = None


def _load_sentence_transformer():
    """Lazy load fastembed model (ONNX-based, no PyTorch required)."""
    global _model, _model_available

    if _model_available is not None:
        return _model

    try:
        from fastembed import TextEmbedding

        model_name = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
        logger.info(f"📥 Loading fastembed model: {model_name}")

        _model = TextEmbedding(model_name)
        _model_available = True

        logger.info("✅ fastembed model loaded successfully")
        return _model

    except ImportError:
        logger.warning("⚠️ fastembed not installed. Semantic search disabled.")
        _model_available = False
        return None
    except Exception as e:
        logger.error(f"❌ Error loading fastembed model: {e}")
        _model_available = False
        return None


@dataclass
class SearchResult:
    """Represents a search result."""
    id: str
    text: str
    score: float
    metadata: Dict[str, Any]


class SemanticSearchEngine:
    """Semantic search engine using sentence embeddings."""
    
    def __init__(self, dimension: int = 384):
        self.model = _load_sentence_transformer()
        self.dimension = dimension
        
        # In-memory vector store (for simplicity)
        # In production, use ChromaDB or FAISS
        self._documents: List[Dict[str, Any]] = []
        self._embeddings: Optional[np.ndarray] = None
        
        # Try to use FAISS for faster search
        self._faiss_index = None
        self._setup_faiss()
    
    def _setup_faiss(self):
        """Setup FAISS index if available."""
        try:
            import faiss
            self._faiss_index = faiss.IndexFlatIP(self.dimension)  # Inner product (cosine)
            logger.info("✅ FAISS index initialized")
        except ImportError:
            logger.info("ℹ️ FAISS not available, using numpy for search")
            self._faiss_index = None
    
    def encode(self, texts: List[str]) -> np.ndarray:
        """
        Encode texts to embeddings.
        
        Args:
            texts: List of texts to encode
            
        Returns:
            Numpy array of embeddings
        """
        if not self.model:
            # Fallback: use simple TF-IDF-like encoding
            return self._simple_encode(texts)
        
        embeddings = np.array(list(self.model.embed(texts)))

        # Normalize for cosine similarity
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        embeddings = embeddings / (norms + 1e-10)
        
        return embeddings
    
    def _simple_encode(self, texts: List[str]) -> np.ndarray:
        """Simple encoding fallback using word vectors."""
        from collections import Counter
        import re
        
        # Build vocabulary
        all_words = []
        for text in texts:
            words = re.findall(r'\b\w+\b', text.lower())
            all_words.extend(words)
        
        vocab = list(set(all_words))[:self.dimension]
        word_to_idx = {w: i for i, w in enumerate(vocab)}
        
        # Encode each text
        embeddings = np.zeros((len(texts), self.dimension))
        for i, text in enumerate(texts):
            words = re.findall(r'\b\w+\b', text.lower())
            word_counts = Counter(words)
            for word, count in word_counts.items():
                if word in word_to_idx:
                    embeddings[i, word_to_idx[word]] = count
        
        # Normalize
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        embeddings = embeddings / (norms + 1e-10)
        
        return embeddings
    
    def add_documents(
        self, 
        documents: List[Dict[str, Any]],
        text_field: str = "text"
    ) -> int:
        """
        Add documents to the search index.
        
        Args:
            documents: List of documents with text and metadata
            text_field: Field name containing the text to index
            
        Returns:
            Number of documents added
        """
        if not documents:
            return 0
        
        # Extract texts
        texts = [doc.get(text_field, str(doc)) for doc in documents]
        
        # Encode
        new_embeddings = self.encode(texts)
        
        # Store documents
        for i, doc in enumerate(documents):
            self._documents.append({
                "id": doc.get("id", str(len(self._documents))),
                "text": texts[i],
                "metadata": {k: v for k, v in doc.items() if k not in ["id", text_field]},
                "embedding_idx": len(self._documents)
            })
        
        # Update embeddings
        if self._embeddings is None:
            self._embeddings = new_embeddings
        else:
            self._embeddings = np.vstack([self._embeddings, new_embeddings])
        
        # Update FAISS index
        if self._faiss_index is not None:
            self._faiss_index.add(new_embeddings.astype(np.float32))
        
        logger.info(f"Added {len(documents)} documents. Total: {len(self._documents)}")
        return len(documents)
    
    def search(
        self, 
        query: str, 
        top_k: int = 10,
        threshold: float = 0.0
    ) -> List[SearchResult]:
        """
        Search for similar documents.
        
        Args:
            query: Search query
            top_k: Number of results to return
            threshold: Minimum similarity score
            
        Returns:
            List of SearchResult objects
        """
        if not self._documents or self._embeddings is None:
            return []
        
        # Encode query
        query_embedding = self.encode([query])[0]
        
        # Search
        if self._faiss_index is not None:
            # FAISS search
            scores, indices = self._faiss_index.search(
                query_embedding.reshape(1, -1).astype(np.float32), 
                min(top_k, len(self._documents))
            )
            scores = scores[0]
            indices = indices[0]
        else:
            # Numpy search
            scores = np.dot(self._embeddings, query_embedding)
            indices = np.argsort(scores)[::-1][:top_k]
            scores = scores[indices]
        
        # Build results
        results = []
        for idx, score in zip(indices, scores):
            if idx < 0 or score < threshold:
                continue
            
            doc = self._documents[idx]
            results.append(SearchResult(
                id=doc["id"],
                text=doc["text"],
                score=float(score),
                metadata=doc["metadata"]
            ))
        
        return results
    
    def similarity(self, text1: str, text2: str) -> float:
        """
        Calculate similarity between two texts.
        
        Args:
            text1: First text
            text2: Second text
            
        Returns:
            Similarity score (0-1)
        """
        embeddings = self.encode([text1, text2])
        return float(np.dot(embeddings[0], embeddings[1]))
    
    def find_similar(
        self, 
        document_id: str, 
        top_k: int = 5
    ) -> List[SearchResult]:
        """
        Find documents similar to a given document.
        
        Args:
            document_id: ID of the reference document
            top_k: Number of similar documents to return
            
        Returns:
            List of similar documents
        """
        # Find the document
        doc_idx = None
        for i, doc in enumerate(self._documents):
            if doc["id"] == document_id:
                doc_idx = i
                break
        
        if doc_idx is None:
            return []
        
        # Use the document's embedding as query
        if self._embeddings is None:
            return []
        
        query_embedding = self._embeddings[doc_idx]
        
        # Search (skip the document itself)
        if self._faiss_index is not None:
            scores, indices = self._faiss_index.search(
                query_embedding.reshape(1, -1).astype(np.float32),
                top_k + 1
            )
            scores = scores[0]
            indices = indices[0]
        else:
            scores = np.dot(self._embeddings, query_embedding)
            indices = np.argsort(scores)[::-1][:top_k + 1]
            scores = scores[indices]
        
        # Build results (excluding the query document)
        results = []
        for idx, score in zip(indices, scores):
            if idx < 0 or idx == doc_idx:
                continue
            
            doc = self._documents[idx]
            results.append(SearchResult(
                id=doc["id"],
                text=doc["text"],
                score=float(score),
                metadata=doc["metadata"]
            ))
        
        return results[:top_k]
    
    def clear(self):
        """Clear all documents from the index."""
        self._documents = []
        self._embeddings = None
        if self._faiss_index is not None:
            self._faiss_index.reset()
        logger.info("Search index cleared")
    
    def is_available(self) -> bool:
        """Check if semantic search is available."""
        return self.model is not None
    
    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about the search engine."""
        return {
            "document_count": len(self._documents),
            "model_available": self.model is not None,
            "faiss_available": self._faiss_index is not None,
            "embedding_dimension": self.dimension
        }


# Singleton instance
_search_engine = None


def get_search_engine() -> SemanticSearchEngine:
    """Get singleton search engine instance."""
    global _search_engine
    if _search_engine is None:
        _search_engine = SemanticSearchEngine()
    return _search_engine
