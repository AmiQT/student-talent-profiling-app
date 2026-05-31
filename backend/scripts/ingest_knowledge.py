#!/usr/bin/env python3
"""
FSKTM Knowledge Base Ingestion Script.

Ingest FSKTM comprehensive knowledge base into Supabase pgvector
for RAG (Retrieval Augmented Generation) system.

Usage:
    cd backend
    python scripts/ingest_knowledge.py

Requirements:
    - SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables
    - GOOGLE_API_KEY or GEMINI_API_KEY for embeddings
"""

import os
import sys
import json
import logging
from typing import List, Dict, Any, Optional
from pathlib import Path
from datetime import datetime
import hashlib

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class KnowledgeBaseIngestor:
    """Ingest knowledge base documents into Supabase pgvector."""
    
    def __init__(self):
        """Initialize the ingestor with API clients."""
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY")
        
        # Try multiple API key sources
        self.google_api_key = (
            os.getenv("GOOGLE_API_KEY") or 
            os.getenv("GEMINI_API_KEY") or
            self._get_first_gemini_key()
        )
        
        if not all([self.supabase_url, self.supabase_key]):
            raise ValueError("Missing SUPABASE_URL or SUPABASE_SERVICE_KEY environment variables")
        
        if not self.google_api_key:
            raise ValueError("Missing GOOGLE_API_KEY or GEMINI_API_KEY for embeddings")
        
        # Initialize Supabase client
        from supabase import create_client
        self.supabase = create_client(self.supabase_url, self.supabase_key)
        
        # Initialize embeddings
        self._init_embeddings()
        
        logger.info("✅ KnowledgeBaseIngestor initialized")
    
    def _get_first_gemini_key(self) -> Optional[str]:
        """Get first key from GEMINI_API_KEYS (comma-separated list)."""
        keys_str = os.getenv("GEMINI_API_KEYS", "")
        if keys_str:
            keys = [k.strip() for k in keys_str.split(",") if k.strip()]
            return keys[0] if keys else None
        return None
    
    def _init_embeddings(self):
        """Initialize Google embeddings model."""
        try:
            from langchain_google_genai import GoogleGenerativeAIEmbeddings
            
            self.embeddings = GoogleGenerativeAIEmbeddings(
                model="models/text-embedding-004",
                google_api_key=self.google_api_key
            )
            logger.info("✅ Google Embeddings initialized (text-embedding-004)")
        except ImportError:
            logger.error("❌ langchain-google-genai not installed. Run: pip install langchain-google-genai")
            raise
    
    def load_knowledge_base(self, file_path: str) -> Dict[str, Any]:
        """Load the FSKTM knowledge base JSON file."""
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"Knowledge base file not found: {file_path}")
        
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        logger.info(f"✅ Loaded knowledge base from {file_path}")
        return data
    
    def chunk_knowledge_base(self, data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Chunk the knowledge base into smaller, meaningful units.
        
        Strategy:
        - Each section becomes chunks
        - FAQ items become individual chunks
        - Programs become individual chunks
        - Metadata preserved for filtering
        """
        chunks = []
        
        # 1. Quick Answers - General Faculty Info
        if "quick_answers" in data:
            qa = data["quick_answers"]
            content = f"""FSKTM Quick Facts:
- FSKTM stands for: {qa.get('what_is_fsktm', 'N/A')}
- Total Students: {qa.get('total_students', 'N/A')}
- Total Academicians: {qa.get('total_academicians', 'N/A')}
- Total Programs: {qa.get('total_programs', 'N/A')}
- Phone: {qa.get('phone', 'N/A')}
- Email: {qa.get('email', 'N/A')}
- Address: {qa.get('address', 'N/A')}
- Website: {qa.get('website', 'N/A')}
- Established: {qa.get('establishment_year', 'N/A')}"""
            
            chunks.append({
                "content": content,
                "metadata": {
                    "category": "general",
                    "subcategory": "quick_facts",
                    "source": "fsktm_knowledge_base",
                    "keywords": ["fsktm", "fakulti", "contact", "phone", "email", "statistics"]
                }
            })
        
        # 2. Faculty Identity
        if "faculty_identity" in data:
            fi = data["faculty_identity"]
            content = f"""FSKTM Faculty Identity:
- Official Name (English): {fi.get('official_name', {}).get('english', 'N/A')}
- Official Name (Malay): {fi.get('official_name', {}).get('malay', 'N/A')}
- Acronym: {fi.get('official_name', {}).get('acronym', 'FSKTM')}
- University: {fi.get('university', 'N/A')}
- Vision: {fi.get('vision', 'N/A')}
- Mission: {fi.get('mission', 'N/A')}
- Education Philosophy: {fi.get('education_philosophy', 'N/A')}
- Strategic Direction: {fi.get('strategic_direction', 'N/A')}"""
            
            chunks.append({
                "content": content,
                "metadata": {
                    "category": "general",
                    "subcategory": "identity",
                    "source": "fsktm_knowledge_base",
                    "keywords": ["vision", "mission", "identity", "philosophy", "university"]
                }
            })
        
        # 3. Establishment History
        if "establishment_history" in data:
            history = data["establishment_history"]
            content = "FSKTM Establishment History:\n"
            for event in history:
                content += f"- {event.get('year', 'N/A')} ({event.get('month', '')}): {event.get('milestone', 'N/A')}\n"
            
            chunks.append({
                "content": content,
                "metadata": {
                    "category": "general",
                    "subcategory": "history",
                    "source": "fsktm_knowledge_base",
                    "keywords": ["history", "establishment", "timeline", "founded"]
                }
            })
        
        # 4. Organizational Structure - Departments
        if "organizational_structure" in data:
            org = data["organizational_structure"]
            if "departments" in org:
                content = "FSKTM Departments:\n"
                for dept in org["departments"]:
                    content += f"- {dept.get('name', 'N/A')}: {dept.get('focus_area', 'N/A')}\n"
                
                chunks.append({
                    "content": content,
                    "metadata": {
                        "category": "organization",
                        "subcategory": "departments",
                        "source": "fsktm_knowledge_base",
                        "keywords": ["department", "jabatan", "structure", "organization"]
                    }
                })
        
        # 5. Academic Programs - Undergraduate (Individual chunks)
        if "academic_programs" in data:
            programs = data["academic_programs"]
            
            # Undergraduate programs
            if "undergraduate" in programs:
                for prog in programs["undergraduate"].get("programs", []):
                    content = f"""Undergraduate Program:
- Title: {prog.get('title', 'N/A')}
- Code: {prog.get('code', 'N/A')}
- Department: {prog.get('department', 'N/A')}
- More Info: {prog.get('url', 'N/A')}"""
                    
                    chunks.append({
                        "content": content,
                        "metadata": {
                            "category": "programs",
                            "subcategory": "undergraduate",
                            "program_code": prog.get('code', ''),
                            "program_title": prog.get('title', ''),
                            "source": "fsktm_knowledge_base",
                            "keywords": ["program", "undergraduate", "bachelor", "degree", prog.get('department', '').lower()]
                        }
                    })
            
            # Postgraduate programs
            if "postgraduate" in programs:
                for prog in programs["postgraduate"].get("programs", []):
                    content = f"""Postgraduate Program:
- Title: {prog.get('title', 'N/A')}
- Type: {prog.get('type', 'N/A')}
- More Info: {prog.get('url', 'N/A')}"""
                    
                    chunks.append({
                        "content": content,
                        "metadata": {
                            "category": "programs",
                            "subcategory": "postgraduate",
                            "program_type": prog.get('type', ''),
                            "program_title": prog.get('title', ''),
                            "source": "fsktm_knowledge_base",
                            "keywords": ["program", "postgraduate", "master", "phd", "doctorate"]
                        }
                    })
        
        # 6. Research Centers
        if "research_expertise" in data:
            research = data["research_expertise"]
            
            # Research centers
            if "research_centers" in research:
                for center in research["research_centers"].get("centers", []):
                    content = f"""Research Center:
- Name: {center.get('name', 'N/A')}
- Acronym: {center.get('acronym', 'N/A')}
- Focus: {center.get('focus', 'N/A')}"""
                    
                    chunks.append({
                        "content": content,
                        "metadata": {
                            "category": "research",
                            "subcategory": "centers",
                            "center_name": center.get('name', ''),
                            "center_acronym": center.get('acronym', ''),
                            "source": "fsktm_knowledge_base",
                            "keywords": ["research", "center", "pusat", center.get('acronym', '').lower()]
                        }
                    })
            
            # Focus groups
            if "focus_groups" in research:
                for group in research["focus_groups"].get("groups", []):
                    content = f"""Research Focus Group:
- Name: {group.get('name', 'N/A')}
- Acronym: {group.get('acronym', 'N/A')}
- Focus: {group.get('focus', 'N/A')}"""
                    
                    chunks.append({
                        "content": content,
                        "metadata": {
                            "category": "research",
                            "subcategory": "focus_groups",
                            "group_name": group.get('name', ''),
                            "group_acronym": group.get('acronym', ''),
                            "source": "fsktm_knowledge_base",
                            "keywords": ["research", "group", "focus", group.get('acronym', '').lower()]
                        }
                    })
        
        # 7. Contact Information
        if "contact_information" in data:
            contact = data["contact_information"]
            main = contact.get("main_office", {})
            content = f"""FSKTM Contact Information:
- Phone: {main.get('phone', 'N/A')}
- Email: {main.get('email', 'N/A')}
- Address: {main.get('address', 'N/A')}

Social Media:"""
            for social in contact.get("social_media", []):
                content += f"\n- {social.get('platform', 'N/A')}: {social.get('url', 'N/A')}"
            
            content += f"\n\nFeedback Portal: {contact.get('feedback_portal', 'N/A')}"
            
            chunks.append({
                "content": content,
                "metadata": {
                    "category": "contact",
                    "subcategory": "main",
                    "source": "fsktm_knowledge_base",
                    "keywords": ["contact", "phone", "email", "address", "social media", "facebook", "instagram"]
                }
            })
        
        # 8. FAQs (Individual chunks)
        if "frequently_asked_questions" in data:
            for faq in data["frequently_asked_questions"]:
                content = f"""FAQ - {faq.get('category', 'General')}:
Q: {faq.get('question', 'N/A')}
A: {faq.get('answer', 'N/A')}"""
                
                chunks.append({
                    "content": content,
                    "metadata": {
                        "category": "faq",
                        "subcategory": faq.get('category', 'general').lower(),
                        "source": "fsktm_knowledge_base",
                        "keywords": faq.get('keywords', []) + ["faq", "soalan"]
                    }
                })
        
        logger.info(f"✅ Created {len(chunks)} chunks from knowledge base")
        return chunks
    
    def generate_embedding(self, text: str) -> List[float]:
        """Generate embedding for a text using Google's text-embedding-004."""
        try:
            embedding = self.embeddings.embed_query(text)
            return embedding
        except Exception as e:
            logger.error(f"❌ Error generating embedding: {e}")
            raise
    
    def generate_content_hash(self, content: str) -> str:
        """Generate a hash for content to detect duplicates."""
        return hashlib.md5(content.encode('utf-8')).hexdigest()
    
    def upsert_chunks(self, chunks: List[Dict[str, Any]], batch_size: int = 10) -> int:
        """
        Upsert chunks into Supabase knowledge_base table.
        
        Args:
            chunks: List of chunks with content and metadata
            batch_size: Number of chunks to process per batch
            
        Returns:
            Number of chunks successfully inserted
        """
        inserted = 0
        
        for i in range(0, len(chunks), batch_size):
            batch = chunks[i:i + batch_size]
            
            for chunk in batch:
                try:
                    content = chunk["content"]
                    metadata = chunk["metadata"]
                    
                    # Add timestamp to metadata
                    metadata["ingested_at"] = datetime.utcnow().isoformat()
                    metadata["content_hash"] = self.generate_content_hash(content)
                    
                    # Generate embedding
                    logger.info(f"  Generating embedding for chunk {inserted + 1}...")
                    embedding = self.generate_embedding(content)
                    
                    # Prepare record
                    record = {
                        "content": content,
                        "metadata": metadata,
                        "embedding": embedding
                    }
                    
                    # Upsert to Supabase
                    result = self.supabase.table("knowledge_base").insert(record).execute()
                    
                    if result.data:
                        inserted += 1
                        logger.info(f"  ✅ Inserted chunk {inserted}/{len(chunks)}: {metadata.get('subcategory', 'unknown')}")
                    
                except Exception as e:
                    logger.error(f"  ❌ Error inserting chunk: {e}")
                    continue
            
            logger.info(f"📦 Batch {i // batch_size + 1} complete. Total inserted: {inserted}")
        
        return inserted
    
    def clear_existing_data(self, source: str = "fsktm_knowledge_base") -> int:
        """Clear existing data from the specified source."""
        try:
            result = self.supabase.table("knowledge_base").delete().eq(
                "metadata->>source", source
            ).execute()
            
            deleted = len(result.data) if result.data else 0
            logger.info(f"🗑️ Cleared {deleted} existing records from source: {source}")
            return deleted
        except Exception as e:
            logger.warning(f"⚠️ Could not clear existing data: {e}")
            return 0
    
    def run(self, file_path: str, clear_existing: bool = True) -> Dict[str, Any]:
        """
        Run the full ingestion pipeline.
        
        Args:
            file_path: Path to the knowledge base JSON file
            clear_existing: Whether to clear existing data before inserting
            
        Returns:
            Summary of the ingestion process
        """
        logger.info("=" * 60)
        logger.info("🚀 Starting FSKTM Knowledge Base Ingestion")
        logger.info("=" * 60)
        
        start_time = datetime.now()
        
        # Load knowledge base
        data = self.load_knowledge_base(file_path)
        
        # Chunk the data
        chunks = self.chunk_knowledge_base(data)
        
        # Clear existing data if requested
        deleted = 0
        if clear_existing:
            deleted = self.clear_existing_data()
        
        # Upsert chunks
        inserted = self.upsert_chunks(chunks)
        
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        summary = {
            "status": "success" if inserted > 0 else "failed",
            "total_chunks": len(chunks),
            "inserted": inserted,
            "deleted": deleted,
            "duration_seconds": duration,
            "timestamp": end_time.isoformat()
        }
        
        logger.info("=" * 60)
        logger.info("✅ Ingestion Complete!")
        logger.info(f"   Total chunks: {len(chunks)}")
        logger.info(f"   Inserted: {inserted}")
        logger.info(f"   Deleted (old): {deleted}")
        logger.info(f"   Duration: {duration:.2f} seconds")
        logger.info("=" * 60)
        
        return summary


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Ingest FSKTM knowledge base to Supabase")
    parser.add_argument(
        "--file", "-f",
        default="../mobile_app/assets/data/fsktm_comprehensive_knowledge_base.json",
        help="Path to the knowledge base JSON file"
    )
    parser.add_argument(
        "--no-clear",
        action="store_true",
        help="Don't clear existing data before inserting"
    )
    
    args = parser.parse_args()
    
    try:
        ingestor = KnowledgeBaseIngestor()
        summary = ingestor.run(args.file, clear_existing=not args.no_clear)
        
        if summary["status"] == "success":
            print("\n✅ Ingestion successful!")
            print(f"   Inserted {summary['inserted']} chunks")
        else:
            print("\n❌ Ingestion failed!")
            sys.exit(1)
            
    except Exception as e:
        logger.error(f"❌ Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
