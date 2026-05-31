"""
Supabase RAG Chain for Hybrid AI Architecture.

Uses Supabase pgvector for vector similarity search,
replacing ChromaDB with a production-ready cloud solution.

Features:
- Google text-embedding-004 (768 dimensions)
- Supabase pgvector for vector storage
- LangChain integration
- Caching support
- Fallback mechanisms
"""

import logging
import os
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass
import hashlib

logger = logging.getLogger(__name__)


@dataclass
class RAGResult:
    """Result from RAG query."""
    answer: str
    sources: List[Dict[str, Any]]
    confidence: float
    tokens_used: int = 0
    cached: bool = False


class SupabaseRAGChain:
    """
    Production-ready RAG chain using Supabase pgvector.
    
    Replaces ChromaDB with Supabase for:
    - Cloud-based persistence
    - Automatic backups
    - Horizontal scaling
    - Built-in authentication
    """
    
    def __init__(
        self,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
        table_name: str = "knowledge_base",
        embedding_model: str = "models/text-embedding-004",
        llm_model: str = "gemini-2.5-flash",
        temperature: float = 0.3,
        top_k: int = 5,
        similarity_threshold: float = 0.7
    ):
        """
        Initialize Supabase RAG Chain.
        
        Args:
            supabase_url: Supabase project URL
            supabase_key: Supabase API key (service key recommended)
            table_name: Table containing embeddings
            embedding_model: Google embedding model name
            llm_model: Gemini model for generation
            temperature: LLM temperature
            top_k: Number of similar documents to retrieve
            similarity_threshold: Minimum similarity score (0-1)
        """
        self.supabase_url = supabase_url or os.getenv("SUPABASE_URL")
        self.supabase_key = supabase_key or os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY")
        self.table_name = table_name
        self.embedding_model = embedding_model
        self.llm_model = llm_model
        self.temperature = temperature
        self.top_k = top_k
        self.similarity_threshold = similarity_threshold
        
        # Components
        self._supabase = None
        self._embeddings = None
        self._llm = None
        self._cache: Dict[str, RAGResult] = {}
        
        self._initialized = False
        self._setup()
    
    def _setup(self):
        """Initialize all components."""
        try:
            self._setup_supabase()
            self._setup_embeddings()
            self._setup_llm()
            self._initialized = True
            logger.info("✅ SupabaseRAGChain initialized successfully")
        except Exception as e:
            logger.error(f"❌ SupabaseRAGChain setup failed: {e}")
            self._initialized = False
    
    def _setup_supabase(self):
        """Setup Supabase client."""
        if not self.supabase_url or not self.supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_KEY are required")
        
        try:
            from supabase import create_client
            
            self._supabase = create_client(self.supabase_url, self.supabase_key)
            logger.info(f"✅ Supabase client connected")
        except ImportError:
            raise ImportError("supabase package not installed. Run: pip install supabase")
    
    def _setup_embeddings(self):
        """Setup Google embeddings."""
        try:
            from langchain_google_genai import GoogleGenerativeAIEmbeddings
            from app.core.key_manager import get_gemini_key
            
            api_key = get_gemini_key()
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set")
            
            self._embeddings = GoogleGenerativeAIEmbeddings(
                model=self.embedding_model,
                google_api_key=api_key
            )
            
            logger.info(f"✅ Embeddings model loaded: {self.embedding_model}")
        except Exception as e:
            logger.error(f"❌ Failed to setup embeddings: {e}")
            raise
    
    def _setup_llm(self):
        """Setup LLM for generation using factory pattern."""
        try:
            from app.ai_assistant.llm_factory import create_llm
            
            # Use LLM factory for provider flexibility (Gemini/Ollama)
            self._llm = create_llm(
                model_name=self.llm_model if self.llm_model != "gemini-2.5-flash" else None,
                temperature=self.temperature
            )
            
            logger.info(f"✅ LLM initialized via factory: {type(self._llm).__name__}")
        except Exception as e:
            logger.error(f"❌ Failed to setup LLM: {e}")
            raise
    
    def _get_cache_key(self, query: str) -> str:
        """Generate cache key for query."""
        normalized = query.lower().strip()
        return hashlib.md5(normalized.encode()).hexdigest()
    
    async def embed_query(self, text: str) -> List[float]:
        """Generate embedding for a query."""
        try:
            embedding = await self._embeddings.aembed_query(text)
            return embedding
        except Exception as e:
            logger.error(f"❌ Embedding generation failed: {e}")
            raise
    
    def embed_query_sync(self, text: str) -> List[float]:
        """Synchronous version of embed_query."""
        try:
            embedding = self._embeddings.embed_query(text)
            return embedding
        except Exception as e:
            logger.error(f"❌ Embedding generation failed: {e}")
            raise
    
    async def similarity_search(
        self, 
        query: str, 
        top_k: Optional[int] = None,
        filter_metadata: Optional[Dict[str, Any]] = None
    ) -> List[Dict[str, Any]]:
        """
        Search for similar documents in Supabase.
        
        Args:
            query: Search query
            top_k: Number of results to return
            filter_metadata: Optional metadata filters
            
        Returns:
            List of matching documents with similarity scores
        """
        top_k = top_k or self.top_k
        
        # Generate query embedding
        query_embedding = await self.embed_query(query)
        
        # Call Supabase RPC function for vector search
        try:
            result = self._supabase.rpc(
                "match_knowledge",
                {
                    "query_embedding": query_embedding,
                    "match_threshold": self.similarity_threshold,
                    "match_count": top_k
                }
            ).execute()
            
            if result.data:
                return result.data
            
            # Fallback: Direct query if RPC not available
            return await self._fallback_search(query_embedding, top_k)
            
        except Exception as e:
            logger.warning(f"⚠️ RPC search failed, using fallback: {e}")
            return await self._fallback_search(query_embedding, top_k)
    
    async def _fallback_search(
        self, 
        query_embedding: List[float], 
        top_k: int
    ) -> List[Dict[str, Any]]:
        """
        Fallback search using direct Supabase query.
        Note: Less efficient than RPC but works without custom function.
        """
        try:
            # Get all documents (for small knowledge bases)
            result = self._supabase.table(self.table_name).select(
                "id, content, metadata, embedding"
            ).limit(100).execute()
            
            if not result.data:
                return []
            
            # Calculate similarities locally
            import numpy as np
            
            query_vec = np.array(query_embedding)
            
            scored_docs = []
            for doc in result.data:
                if doc.get("embedding"):
                    doc_vec = np.array(doc["embedding"])
                    # Cosine similarity
                    similarity = np.dot(query_vec, doc_vec) / (
                        np.linalg.norm(query_vec) * np.linalg.norm(doc_vec)
                    )
                    
                    if similarity >= self.similarity_threshold:
                        scored_docs.append({
                            "id": doc["id"],
                            "content": doc["content"],
                            "metadata": doc["metadata"],
                            "similarity": float(similarity)
                        })
            
            # Sort by similarity and return top_k
            scored_docs.sort(key=lambda x: x["similarity"], reverse=True)
            return scored_docs[:top_k]
            
        except Exception as e:
            logger.error(f"❌ Fallback search failed: {e}")
            return []
    
    def similarity_search_sync(
        self, 
        query: str, 
        top_k: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """Synchronous version of similarity_search."""
        import asyncio
        
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(self.similarity_search(query, top_k))
    
    def _format_context(self, documents: List[Dict[str, Any]]) -> str:
        """Format retrieved documents as context string."""
        if not documents:
            return "Tiada maklumat berkaitan ditemui."
        
        context_parts = []
        for i, doc in enumerate(documents, 1):
            content = doc.get("content", "")
            metadata = doc.get("metadata", {})
            category = metadata.get("category", "general")
            source = metadata.get("source", "knowledge_base")
            
            context_parts.append(
                f"[{i}] ({category}) {content}"
            )
        
        return "\n\n".join(context_parts)
    
    def _build_prompt(self, query: str, context: str) -> str:
        """Build RAG prompt."""
        return f"""Anda adalah pembantu AI untuk Fakulti Sains Komputer dan Teknologi Maklumat (FSKTM), UTHM.

MAKLUMAT BERKAITAN:
{context}

SOALAN PENGGUNA:
{query}

ARAHAN:
1. Jawab berdasarkan maklumat yang diberikan di atas
2. Jika maklumat tidak mencukupi, nyatakan dengan jujur
3. Jawab dalam Bahasa Melayu yang mesra
4. Berikan jawapan yang tepat dan ringkas
5. Jika ada sumber/rujukan, nyatakan

JAWAPAN:"""
    
    async def query(
        self, 
        query: str, 
        use_cache: bool = True
    ) -> RAGResult:
        """
        Run RAG query pipeline.
        
        Args:
            query: User query
            use_cache: Whether to use cached results
            
        Returns:
            RAGResult with answer, sources, and confidence
        """
        if not self._initialized:
            return RAGResult(
                answer="Maaf, sistem RAG belum sedia. Sila cuba sebentar lagi.",
                sources=[],
                confidence=0.0
            )
        
        # Check cache
        cache_key = self._get_cache_key(query)
        if use_cache and cache_key in self._cache:
            cached = self._cache[cache_key]
            cached.cached = True
            logger.debug(f"🎯 Cache hit for query: {query[:50]}...")
            return cached
        
        try:
            # 1. Retrieve relevant documents
            documents = await self.similarity_search(query)
            
            if not documents:
                return RAGResult(
                    answer="Maaf, saya tidak menemui maklumat berkaitan dalam pangkalan pengetahuan. "
                           "Boleh saya bantu dengan soalan lain?",
                    sources=[],
                    confidence=0.3
                )
            
            # 2. Format context
            context = self._format_context(documents)
            
            # 3. Generate answer
            prompt = self._build_prompt(query, context)
            response = await self._llm.ainvoke(prompt)
            
            # 4. Calculate confidence from similarity scores
            avg_similarity = sum(d.get("similarity", 0) for d in documents) / len(documents)
            
            # 5. Prepare result
            result = RAGResult(
                answer=response.content if hasattr(response, 'content') else str(response),
                sources=[
                    {
                        "content": doc.get("content", "")[:200],
                        "metadata": doc.get("metadata", {}),
                        "similarity": doc.get("similarity", 0)
                    }
                    for doc in documents
                ],
                confidence=avg_similarity,
                cached=False
            )
            
            # Cache result
            if use_cache:
                self._cache[cache_key] = result
            
            return result
            
        except Exception as e:
            logger.error(f"❌ RAG query failed: {e}")
            return RAGResult(
                answer=f"Maaf, terdapat ralat semasa memproses soalan. Sila cuba lagi.",
                sources=[],
                confidence=0.0
            )
    
    def query_sync(self, query: str, use_cache: bool = True) -> RAGResult:
        """Synchronous version of query."""
        import asyncio
        
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        return loop.run_until_complete(self.query(query, use_cache))
    
    def clear_cache(self):
        """Clear the query cache."""
        self._cache.clear()
        logger.info("🧹 RAG cache cleared")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get RAG chain statistics."""
        return {
            "initialized": self._initialized,
            "table_name": self.table_name,
            "embedding_model": self.embedding_model,
            "llm_model": self.llm_model,
            "cache_size": len(self._cache),
            "top_k": self.top_k,
            "similarity_threshold": self.similarity_threshold
        }


# Global instance
_supabase_rag: Optional[SupabaseRAGChain] = None


def get_supabase_rag() -> SupabaseRAGChain:
    """Get or create global SupabaseRAGChain instance."""
    global _supabase_rag
    if _supabase_rag is None:
        _supabase_rag = SupabaseRAGChain()
    return _supabase_rag


# LangChain Tool wrapper for use with agent
def create_rag_tool():
    """Create a LangChain tool for RAG queries."""
    from langchain_core.tools import tool
    
    @tool
    def knowledge_base_query(query: str) -> str:
        """Query the FSKTM knowledge base for faculty information.
        
        Use this tool to answer questions about:
        - Faculty staff and leadership
        - Academic programs (undergraduate and postgraduate)
        - Research centers and expertise
        - Contact information and locations
        - General faculty information
        
        Args:
            query: The question to search for in the knowledge base
            
        Returns:
            Answer based on the knowledge base with sources
        """
        try:
            rag = get_supabase_rag()
            result = rag.query_sync(query)
            
            if result.confidence < 0.5:
                return f"[Confidence rendah: {result.confidence:.2f}] {result.answer}"
            
            return result.answer
            
        except Exception as e:
            logger.error(f"RAG tool error: {e}")
            return "Maaf, tidak dapat mengakses pangkalan pengetahuan sekarang."
    
    return knowledge_base_query


# Test function
async def test_rag():
    """Test the Supabase RAG chain."""
    print("\n" + "=" * 70)
    print("🧪 Supabase RAG Chain Test")
    print("=" * 70)
    
    rag = SupabaseRAGChain()
    print(f"\nStats: {rag.get_stats()}")
    
    test_queries = [
        "Siapa dekan FSKTM?",
        "Apa program undergraduate yang ditawarkan?",
        "Siapa pakar AI di fakulti?",
        "Bagaimana nak hubungi fakulti?",
    ]
    
    for query in test_queries:
        print(f"\n{'=' * 50}")
        print(f"Query: {query}")
        result = await rag.query(query)
        print(f"Answer: {result.answer[:200]}...")
        print(f"Confidence: {result.confidence:.2f}")
        print(f"Sources: {len(result.sources)}")


if __name__ == "__main__":
    import asyncio
    asyncio.run(test_rag())
