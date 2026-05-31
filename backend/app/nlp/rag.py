"""Retrieval-Augmented Generation (RAG) System.

Combines semantic search with LLM generation for intelligent
document-based question answering.
"""

from typing import List, Dict, Any, Optional, Tuple
import logging
import os

logger = logging.getLogger(__name__)


class RAGSystem:
    """RAG system using LangChain and vector stores."""
    
    def __init__(
        self,
        collection_name: str = "student_talent_docs",
        embedding_model: str = "paraphrase-multilingual-MiniLM-L12-v2"
    ):
        self.collection_name = collection_name
        self.embedding_model_name = embedding_model
        
        self._vectorstore = None
        self._embeddings = None
        self._llm = None
        self._retriever = None
        self._rag_chain = None
        
        self._setup()
    
    def _setup(self):
        """Setup RAG components."""
        try:
            self._setup_embeddings()
            self._setup_vectorstore()
            self._setup_llm()
            self._setup_chain()
            logger.info("✅ RAG system initialized successfully")
        except Exception as e:
            logger.error(f"❌ Error setting up RAG: {e}")
    
    def _setup_embeddings(self):
        """Setup embedding model."""
        try:
            from langchain_community.embeddings import HuggingFaceEmbeddings
            
            self._embeddings = HuggingFaceEmbeddings(
                model_name=self.embedding_model_name,
                model_kwargs={'device': 'cpu'},
                encode_kwargs={'normalize_embeddings': True}
            )
            logger.info(f"✅ Embeddings loaded: {self.embedding_model_name}")
            
        except ImportError:
            logger.warning("⚠️ HuggingFace embeddings not available, using fallback")
            self._embeddings = None
    
    def _setup_vectorstore(self):
        """Setup vector store (ChromaDB)."""
        if self._embeddings is None:
            return
            
        try:
            from langchain_community.vectorstores import Chroma
            
            # Use in-memory store for simplicity
            # In production, persist to disk
            self._vectorstore = Chroma(
                collection_name=self.collection_name,
                embedding_function=self._embeddings,
            )
            
            self._retriever = self._vectorstore.as_retriever(
                search_type="similarity",
                search_kwargs={"k": 5}
            )
            
            logger.info("✅ Vector store initialized")
            
        except ImportError:
            logger.warning("⚠️ ChromaDB not available")
            self._vectorstore = None
    
    def _setup_llm(self):
        """Setup LLM for generation with key rotation."""
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
            from app.core.key_manager import get_gemini_key, key_manager
            
            api_key = get_gemini_key()
            if not api_key:
                logger.warning("⚠️ GEMINI_API_KEY not set")
                return
            
            self._llm = ChatGoogleGenerativeAI(
                model="gemini-2.5-flash",
                google_api_key=api_key,
                temperature=0.3,
                convert_system_message_to_human=True
            )
            
            logger.info(f"✅ LLM initialized with {key_manager.key_count} key(s)")
            
        except Exception as e:
            logger.error(f"❌ Error setting up LLM: {e}")
            self._llm = None
    
    def _setup_chain(self):
        """Setup RAG chain."""
        if self._llm is None or self._retriever is None:
            logger.warning("⚠️ RAG chain not initialized - missing LLM or retriever")
            return
        
        try:
            from langchain_core.prompts import ChatPromptTemplate
            from langchain_core.output_parsers import StrOutputParser
            from langchain_core.runnables import RunnablePassthrough
            
            # RAG prompt template
            template = """Anda adalah pembantu AI yang membantu menjawab soalan berdasarkan konteks yang diberikan.
            
Konteks yang berkaitan:
{context}

Soalan pengguna: {question}

Arahan:
1. Jawab berdasarkan konteks yang diberikan
2. Jika konteks tidak mencukupi, nyatakan dengan jelas
3. Jawab dalam Bahasa Melayu
4. Berikan jawapan yang tepat dan ringkas

Jawapan:"""
            
            prompt = ChatPromptTemplate.from_template(template)
            
            def format_docs(docs):
                return "\n\n".join(doc.page_content for doc in docs)
            
            self._rag_chain = (
                {"context": self._retriever | format_docs, "question": RunnablePassthrough()}
                | prompt
                | self._llm
                | StrOutputParser()
            )
            
            logger.info("✅ RAG chain created")
            
        except Exception as e:
            logger.error(f"❌ Error creating RAG chain: {e}")
            self._rag_chain = None
    
    def add_documents(
        self, 
        documents: List[Dict[str, Any]],
        text_field: str = "content"
    ) -> int:
        """
        Add documents to the RAG system.
        
        Args:
            documents: List of documents with content and metadata
            text_field: Field containing the text content
            
        Returns:
            Number of documents added
        """
        if self._vectorstore is None:
            logger.warning("Vector store not available")
            return 0
        
        try:
            from langchain_core.documents import Document
            
            langchain_docs = []
            for doc in documents:
                content = doc.get(text_field, str(doc))
                metadata = {k: v for k, v in doc.items() if k != text_field}
                
                langchain_docs.append(Document(
                    page_content=content,
                    metadata=metadata
                ))
            
            self._vectorstore.add_documents(langchain_docs)
            
            logger.info(f"Added {len(documents)} documents to RAG")
            return len(documents)
            
        except Exception as e:
            logger.error(f"Error adding documents: {e}")
            return 0
    
    def add_texts(
        self, 
        texts: List[str],
        metadatas: Optional[List[Dict[str, Any]]] = None
    ) -> int:
        """
        Add texts directly to the RAG system.
        
        Args:
            texts: List of text strings
            metadatas: Optional list of metadata dicts
            
        Returns:
            Number of texts added
        """
        if self._vectorstore is None:
            logger.warning("Vector store not available")
            return 0
        
        try:
            self._vectorstore.add_texts(texts, metadatas=metadatas)
            logger.info(f"Added {len(texts)} texts to RAG")
            return len(texts)
            
        except Exception as e:
            logger.error(f"Error adding texts: {e}")
            return 0
    
    def query(
        self, 
        question: str,
        use_chain: bool = True
    ) -> Dict[str, Any]:
        """
        Query the RAG system.
        
        Args:
            question: User question
            use_chain: Whether to use the full RAG chain or just retrieval
            
        Returns:
            Answer with sources
        """
        if self._vectorstore is None:
            return {
                "success": False,
                "answer": "RAG system not available",
                "sources": []
            }
        
        try:
            # Retrieve relevant documents
            if self._retriever:
                docs = self._retriever.invoke(question)
            else:
                docs = self._vectorstore.similarity_search(question, k=5)
            
            sources = [
                {
                    "content": doc.page_content[:200] + "..." if len(doc.page_content) > 200 else doc.page_content,
                    "metadata": doc.metadata
                }
                for doc in docs
            ]
            
            # Generate answer
            if use_chain and self._rag_chain:
                answer = self._rag_chain.invoke(question)
            else:
                # Just return the context without generation
                context = "\n\n".join(doc.page_content for doc in docs)
                answer = f"Konteks berkaitan:\n{context}"
            
            return {
                "success": True,
                "answer": answer,
                "sources": sources,
                "num_sources": len(sources)
            }
            
        except Exception as e:
            logger.error(f"Error querying RAG: {e}")
            return {
                "success": False,
                "answer": f"Error: {str(e)}",
                "sources": []
            }
    
    def search(
        self, 
        query: str, 
        k: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Search for similar documents.
        
        Args:
            query: Search query
            k: Number of results
            
        Returns:
            List of matching documents
        """
        if self._vectorstore is None:
            return []
        
        try:
            docs = self._vectorstore.similarity_search_with_score(query, k=k)
            
            return [
                {
                    "content": doc.page_content,
                    "metadata": doc.metadata,
                    "score": float(score)
                }
                for doc, score in docs
            ]
            
        except Exception as e:
            logger.error(f"Error searching: {e}")
            return []
    
    def is_available(self) -> bool:
        """Check if RAG system is available."""
        return self._vectorstore is not None
    
    def get_stats(self) -> Dict[str, Any]:
        """Get RAG system statistics."""
        doc_count = 0
        if self._vectorstore:
            try:
                # Try to get collection count
                collection = self._vectorstore._collection
                doc_count = collection.count() if collection else 0
            except:
                pass
        
        return {
            "vectorstore_available": self._vectorstore is not None,
            "llm_available": self._llm is not None,
            "rag_chain_available": self._rag_chain is not None,
            "document_count": doc_count,
            "embedding_model": self.embedding_model_name,
            "collection_name": self.collection_name
        }


# Singleton instance
_rag_system = None


def get_rag_system() -> RAGSystem:
    """Get singleton RAG system instance."""
    global _rag_system
    if _rag_system is None:
        _rag_system = RAGSystem()
    return _rag_system


class DocumentLoader:
    """Helper class to load various document types for RAG."""
    
    @staticmethod
    def load_text_file(filepath: str) -> List[Dict[str, Any]]:
        """Load a text file."""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            return [{
                "content": content,
                "source": filepath,
                "type": "text"
            }]
        except Exception as e:
            logger.error(f"Error loading text file: {e}")
            return []
    
    @staticmethod
    def load_markdown(filepath: str) -> List[Dict[str, Any]]:
        """Load a markdown file and split by headers."""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Split by headers
            import re
            sections = re.split(r'\n(?=#{1,3}\s)', content)
            
            documents = []
            for section in sections:
                if section.strip():
                    # Extract header
                    lines = section.strip().split('\n')
                    header = lines[0].lstrip('#').strip() if lines else "Untitled"
                    body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else lines[0]
                    
                    documents.append({
                        "content": body,
                        "title": header,
                        "source": filepath,
                        "type": "markdown"
                    })
            
            return documents
            
        except Exception as e:
            logger.error(f"Error loading markdown: {e}")
            return []
    
    @staticmethod
    def chunk_text(
        text: str, 
        chunk_size: int = 500, 
        overlap: int = 50
    ) -> List[str]:
        """Split text into overlapping chunks."""
        if len(text) <= chunk_size:
            return [text]
        
        chunks = []
        start = 0
        
        while start < len(text):
            end = start + chunk_size
            
            # Try to break at sentence boundary
            if end < len(text):
                # Look for sentence ending
                for char in ['.', '!', '?', '\n']:
                    last_break = text[start:end].rfind(char)
                    if last_break > chunk_size // 2:
                        end = start + last_break + 1
                        break
            
            chunks.append(text[start:end].strip())
            start = end - overlap
        
        return chunks
