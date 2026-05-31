#!/usr/bin/env python3
"""
Simple FSKTM Knowledge Base Ingestion Script.

Uses native google-generativeai for faster loading.
Ingest FSKTM knowledge base into Supabase pgvector.

Usage:
    cd backend
    python scripts/ingest_simple.py
"""

import os
import sys
import json
import logging
from typing import List, Dict, Any, Optional
from pathlib import Path
from datetime import datetime
import hashlib
import uuid

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def get_api_key() -> str:
    """Get Gemini API key from environment."""
    key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
    if not key:
        keys_str = os.getenv("GEMINI_API_KEYS", "")
        if keys_str:
            keys = [k.strip() for k in keys_str.split(",") if k.strip()]
            key = keys[0] if keys else None
    if not key:
        raise ValueError("No API key found. Set GEMINI_API_KEY or GEMINI_API_KEYS")
    return key


def load_knowledge_base() -> Dict[str, Any]:
    """Load the FSKTM knowledge base JSON."""
    json_paths = [
        Path(__file__).parent.parent.parent / "mobile_app" / "assets" / "data" / "fsktm_comprehensive_knowledge_base.json",
        Path(__file__).parent.parent / "data" / "fsktm_knowledge_base.json",
    ]
    
    for path in json_paths:
        if path.exists():
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            logger.info(f"✅ Loaded knowledge base from: {path}")
            return data
    
    raise FileNotFoundError(f"Knowledge base not found in: {json_paths}")


def chunk_knowledge_base(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Create chunks from knowledge base for embedding."""
    chunks = []
    
    # 1. Quick answers
    if "quick_answers" in data:
        for key, value in data["quick_answers"].items():
            chunks.append({
                "content": f"{key.replace('_', ' ').title()}: {value}",
                "metadata": {"category": "quick_answers", "key": key}
            })
    
    # 2. Faculty identity
    if "faculty_identity" in data:
        identity = data["faculty_identity"]
        official_name = identity.get("official_name", {})
        chunks.append({
            "content": f"Fakulti: {official_name.get('english', '')} ({official_name.get('acronym', '')}). "
                      f"Dalam Bahasa Melayu: {official_name.get('malay', '')}. "
                      f"Universiti: {identity.get('university', '')}. "
                      f"Visi: {identity.get('vision', '')}. "
                      f"Misi: {identity.get('mission', '')}. "
                      f"Falsafah Pendidikan: {identity.get('education_philosophy', '')}",
            "metadata": {"category": "faculty_identity"}
        })
    
    # 3. Establishment history
    if "establishment_history" in data:
        history_text = "Sejarah penubuhan FSKTM: "
        for event in data["establishment_history"]:
            history_text += f"{event.get('year', '')} - {event.get('milestone', '')}. "
        chunks.append({
            "content": history_text,
            "metadata": {"category": "history"}
        })
    
    # 4. Organizational structure - departments
    if "organizational_structure" in data:
        org = data["organizational_structure"]
        for dept in org.get("departments", []):
            chunks.append({
                "content": f"Jabatan: {dept.get('name', '')}. Bidang fokus: {dept.get('focus_area', '')}",
                "metadata": {"category": "department", "department_name": dept.get("name", "")}
            })
    
    # 5. Academic programs
    if "academic_programs" in data:
        programs = data["academic_programs"]
        
        # Undergraduate
        undergrad = programs.get("undergraduate", {})
        for prog in undergrad.get("programs", []):
            chunks.append({
                "content": f"Program Sarjana Muda: {prog.get('title', '')} (Kod: {prog.get('code', '')}). "
                          f"Jabatan: {prog.get('department', '')}. "
                          f"Laman web: {prog.get('url', '')}",
                "metadata": {"category": "undergraduate", "program_code": prog.get("code", "")}
            })
        
        # Postgraduate
        postgrad = programs.get("postgraduate", {})
        for prog in postgrad.get("programs", []):
            chunks.append({
                "content": f"Program Pascasiswazah: {prog.get('title', '')}. "
                          f"Jenis: {prog.get('type', '')}. "
                          f"Laman web: {prog.get('url', '')}",
                "metadata": {"category": "postgraduate"}
            })
    
    # 6. Research expertise
    if "research_expertise" in data:
        research = data["research_expertise"]
        
        # Research centers
        centers = research.get("research_centers", {})
        for center in centers.get("centers", []):
            chunks.append({
                "content": f"Pusat Penyelidikan: {center.get('name', '')} ({center.get('acronym', '')}). "
                          f"Bidang fokus: {center.get('focus', '')}",
                "metadata": {"category": "research_center", "center_name": center.get("name", "")}
            })
        
        # Focus groups
        focus_groups = research.get("focus_groups", {})
        for group in focus_groups.get("groups", []):
            chunks.append({
                "content": f"Kumpulan Penyelidikan: {group.get('name', '')} ({group.get('acronym', '')}). "
                          f"Bidang fokus: {group.get('focus', '')}",
                "metadata": {"category": "focus_group", "group_name": group.get("name", "")}
            })
        
        # Expertise keywords
        keywords = research.get("expertise_keywords", [])
        if keywords:
            chunks.append({
                "content": f"Bidang kepakaran FSKTM: {', '.join(keywords)}",
                "metadata": {"category": "expertise"}
            })
    
    # 7. Staff with expertise - sample key staff
    if "staff_directory" in data:
        staff = data.get("staff_directory", {})
        for category, members in staff.items():
            if isinstance(members, list):
                for person in members[:3]:  # Sample top 3 per category
                    if isinstance(person, dict):
                        chunks.append({
                            "content": f"Staff {category}: {person.get('name', '')}. "
                                      f"Jawatan: {person.get('position', '')}. "
                                      f"Kepakaran: {person.get('expertise', '')}. "
                                      f"Email: {person.get('email', '')}",
                            "metadata": {"category": "staff", "staff_category": category}
                        })
    
    # 8. Contact info from quick_answers
    if "quick_answers" in data:
        qa = data["quick_answers"]
        chunks.append({
            "content": f"Hubungi FSKTM: Email - {qa.get('email', '')}, "
                      f"Telefon - {qa.get('phone', '')}, "
                      f"Alamat - {qa.get('address', '')}, "
                      f"Laman web - {qa.get('website', '')}",
            "metadata": {"category": "contact"}
        })
    
    logger.info(f"✅ Created {len(chunks)} chunks from knowledge base")
    return chunks


def generate_embeddings(chunks: List[Dict[str, Any]], api_key: str) -> List[Dict[str, Any]]:
    """Generate embeddings using Google's API."""
    import google.generativeai as genai
    
    genai.configure(api_key=api_key)
    
    for i, chunk in enumerate(chunks):
        try:
            result = genai.embed_content(
                model="models/text-embedding-004",
                content=chunk["content"]
            )
            chunk["embedding"] = result["embedding"]
            logger.info(f"✅ Generated embedding {i+1}/{len(chunks)}")
        except Exception as e:
            logger.error(f"❌ Failed to generate embedding for chunk {i+1}: {e}")
            chunk["embedding"] = None
    
    return [c for c in chunks if c.get("embedding")]


def upsert_to_supabase(chunks: List[Dict[str, Any]]):
    """Upsert chunks to Supabase knowledge_base table."""
    from supabase import create_client
    
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_KEY")
    
    if not url or not key:
        raise ValueError("Missing SUPABASE_URL or SUPABASE_KEY")
    
    client = create_client(url, key)
    
    success_count = 0
    for chunk in chunks:
        try:
            # Generate deterministic ID from content
            content_hash = hashlib.md5(chunk["content"].encode()).hexdigest()
            doc_id = str(uuid.UUID(content_hash[:32]))
            
            record = {
                "id": doc_id,
                "content": chunk["content"],
                "metadata": chunk["metadata"],
                "embedding": chunk["embedding"],
                "created_at": datetime.now().isoformat()
            }
            
            client.table("knowledge_base").upsert(record, on_conflict="id").execute()
            success_count += 1
            
        except Exception as e:
            logger.error(f"❌ Failed to upsert: {e}")
    
    logger.info(f"✅ Successfully upserted {success_count}/{len(chunks)} chunks")
    return success_count


def main():
    """Main ingestion pipeline."""
    print("\n" + "=" * 60)
    print("🚀 FSKTM Knowledge Base Ingestion")
    print("=" * 60 + "\n")
    
    try:
        # 1. Get API key
        api_key = get_api_key()
        logger.info(f"✅ API key loaded: {api_key[:10]}...")
        
        # 2. Load knowledge base
        data = load_knowledge_base()
        
        # 3. Create chunks
        chunks = chunk_knowledge_base(data)
        
        # 4. Generate embeddings
        print("\n📊 Generating embeddings (this may take a minute)...")
        chunks_with_embeddings = generate_embeddings(chunks, api_key)
        
        # 5. Upsert to Supabase
        print("\n📤 Uploading to Supabase...")
        count = upsert_to_supabase(chunks_with_embeddings)
        
        print("\n" + "=" * 60)
        print(f"✅ INGESTION COMPLETE: {count} chunks uploaded")
        print("=" * 60 + "\n")
        
    except Exception as e:
        logger.error(f"❌ Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
