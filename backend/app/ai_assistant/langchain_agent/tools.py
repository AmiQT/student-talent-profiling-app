"""LangChain Tools for Student Talent Analytics.

These tools allow the AI agent to interact with the database
and perform various operations on student data.
Includes NLP tools for semantic search and entity extraction.
"""

from typing import Optional, List, Dict, Any
from langchain_core.tools import tool
from sqlalchemy.orm import Session
from sqlalchemy import text, func
import logging
import random

# NLP imports
from app.nlp import (
    NLPProcessor,
    MalayEntityExtractor,
    SemanticSearchEngine,
    MalayNLPProcessor,
    RAGSystem
)

logger = logging.getLogger(__name__)

# Global NLP instances (lazy loaded)
_nlp_processor: Optional[NLPProcessor] = None
_malay_extractor: Optional[MalayEntityExtractor] = None
_semantic_search: Optional[SemanticSearchEngine] = None
_malay_nlp: Optional[MalayNLPProcessor] = None
_rag_system: Optional[RAGSystem] = None


def get_nlp_processor() -> NLPProcessor:
    """Get or create NLP processor instance."""
    global _nlp_processor
    if _nlp_processor is None:
        _nlp_processor = NLPProcessor()
    return _nlp_processor


def get_malay_extractor() -> MalayEntityExtractor:
    """Get or create Malay entity extractor instance."""
    global _malay_extractor
    if _malay_extractor is None:
        _malay_extractor = MalayEntityExtractor()
    return _malay_extractor


def get_semantic_search() -> SemanticSearchEngine:
    """Get or create semantic search engine instance."""
    global _semantic_search
    if _semantic_search is None:
        _semantic_search = SemanticSearchEngine()
    return _semantic_search


def get_malay_nlp() -> MalayNLPProcessor:
    """Get or create Malay NLP processor instance."""
    global _malay_nlp
    if _malay_nlp is None:
        _malay_nlp = MalayNLPProcessor()
    return _malay_nlp


def get_rag_system() -> RAGSystem:
    """Get or create RAG system instance."""
    global _rag_system
    if _rag_system is None:
        _rag_system = RAGSystem()
    return _rag_system


class StudentToolsProvider:
    """Provides tools with database access for the LangChain agent."""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_tools(self):
        """Return list of tools with database access."""
        
        @tool
        def query_students(
            department: Optional[str] = None,
            limit: int = 10,
            random_select: bool = False,
            min_cgpa: Optional[float] = None,
            max_cgpa: Optional[float] = None,
            sort_by: str = "cgpa",
            sort_order: str = "desc"
        ) -> Dict[str, Any]:
            """Cari pelajar dari pangkalan data UTHM.
            
            Gunakan tool ini untuk:
            - Mencari senarai pelajar
            - Filter mengikut jabatan atau CGPA
            - Pilih pelajar secara rawak
            
            Args:
                department: Filter mengikut jabatan (cth: 'Computer Science', 'Civil Engineering')
                limit: Bilangan maksimum pelajar (default: 10, max: 100)
                random_select: Jika True, pilih pelajar secara rawak
                min_cgpa: CGPA minimum (0.0 - 4.0)
                max_cgpa: CGPA maksimum (0.0 - 4.0)
                sort_by: Field untuk susun ('cgpa', 'name', 'student_id')
                sort_order: Susunan ('asc' atau 'desc')
            
            Returns:
                Dict dengan senarai pelajar dan metadata
            """
            try:
                # Build SQL query (using correct column names from Profile model)
                sql = """
                    SELECT 
                        id,
                        COALESCE(full_name, '') as full_name,
                        COALESCE(department, '') as department,
                        COALESCE(faculty, '') as faculty,
                        COALESCE(student_id, '') as student_id,
                        COALESCE(cgpa, '0') as cgpa,
                        COALESCE(headline, '') as program
                    FROM profiles 
                    WHERE 1=1
                """
                params = {}
                
                if department:
                    sql += ' AND department ILIKE :dept'
                    params['dept'] = f'%{department}%'
                
                if min_cgpa is not None:
                    sql += ' AND CAST(NULLIF(cgpa, \'\') AS FLOAT) >= :min_cgpa'
                    params['min_cgpa'] = min_cgpa
                    
                if max_cgpa is not None:
                    sql += ' AND CAST(NULLIF(cgpa, \'\') AS FLOAT) <= :max_cgpa'
                    params['max_cgpa'] = max_cgpa
                
                # Execute query
                limit = min(int(limit), 100)
                sql += f" LIMIT {limit * 2 if random_select else limit}"
                
                result = self.db.execute(text(sql), params).fetchall()
                
                students = []
                for row in result:
                    try:
                        cgpa_val = float(row[5]) if row[5] and row[5] != '' else 0.0
                    except (ValueError, TypeError):
                        cgpa_val = 0.0
                        
                    students.append({
                        "id": str(row[0]),
                        "full_name": row[1] or "Tidak Diketahui",
                        "department": row[2] or "Tidak Dinyatakan",
                        "faculty": row[3] or "",
                        "student_id": row[4] or "",
                        "cgpa": cgpa_val,
                        "program": row[6] or ""
                    })
                
                # Random selection
                if random_select and len(students) > limit:
                    students = random.sample(students, limit)
                
                # Sort
                if sort_by in ['cgpa', 'full_name', 'student_id']:
                    key = 'full_name' if sort_by == 'name' else sort_by
                    reverse = sort_order.lower() == 'desc'
                    students = sorted(
                        students,
                        key=lambda x: x.get(key, 0) if key == 'cgpa' else str(x.get(key, '')),
                        reverse=reverse
                    )
                
                return {
                    "success": True,
                    "count": len(students),
                    "students": students[:limit],
                    "criteria": {
                        "department": department,
                        "min_cgpa": min_cgpa,
                        "max_cgpa": max_cgpa,
                        "random": random_select
                    }
                }
                
            except Exception as e:
                logger.error(f"Error querying students: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "count": 0,
                    "students": []
                }
        
        @tool
        def query_events(
            limit: int = 10,
            upcoming_only: bool = True,
            event_type: Optional[str] = None
        ) -> Dict[str, Any]:
            """Cari maklumat acara dari sistem.
            
            Gunakan tool ini untuk:
            - Senarai acara akan datang
            - Maklumat acara tertentu
            - Statistik penyertaan
            
            Args:
                limit: Bilangan maksimum acara (default: 10)
                upcoming_only: Jika True, hanya acara akan datang
                event_type: Filter mengikut jenis acara
            
            Returns:
                Dict dengan senarai acara
            """
            try:
                from app.models.event import Event
                from datetime import datetime
                
                query = self.db.query(Event)
                
                if upcoming_only:
                    query = query.filter(Event.start_date >= datetime.now())
                
                if event_type:
                    query = query.filter(Event.event_type.ilike(f'%{event_type}%'))
                
                events = query.order_by(Event.start_date).limit(limit).all()
                
                return {
                    "success": True,
                    "count": len(events),
                    "events": [
                        {
                            "id": str(e.id),
                            "title": e.title,
                            "description": e.description[:100] if e.description else "",
                            "start_date": e.start_date.isoformat() if e.start_date else None,
                            "end_date": e.end_date.isoformat() if e.end_date else None,
                            "location": e.location,
                            "event_type": e.event_type
                        }
                        for e in events
                    ]
                }
                
            except Exception as e:
                logger.error(f"Error querying events: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "count": 0,
                    "events": []
                }
        
        @tool
        def get_system_stats() -> Dict[str, Any]:
            """Dapatkan statistik keseluruhan sistem.
            
            Gunakan tool ini untuk:
            - Jumlah pelajar dalam sistem
            - Jumlah acara
            - Statistik pencapaian
            - Gambaran keseluruhan sistem
            
            Returns:
                Dict dengan statistik sistem
            """
            try:
                # Count profiles
                profile_count = self.db.execute(
                    text("SELECT COUNT(*) FROM profiles")
                ).scalar() or 0
                
                # Count users
                user_count = self.db.execute(
                    text("SELECT COUNT(*) FROM users")
                ).scalar() or 0
                
                # Count events
                event_count = self.db.execute(
                    text("SELECT COUNT(*) FROM events")
                ).scalar() or 0
                
                # Count showcase posts
                showcase_count = self.db.execute(
                    text("SELECT COUNT(*) FROM showcase_posts")
                ).scalar() or 0
                
                # Department distribution
                dept_stats = self.db.execute(text("""
                    SELECT department as dept, COUNT(*) as count
                    FROM profiles
                    WHERE department IS NOT NULL 
                    AND department != ''
                    GROUP BY department
                    ORDER BY count DESC
                    LIMIT 5
                """)).fetchall()
                
                # Average CGPA
                avg_cgpa = self.db.execute(text("""
                    SELECT AVG(CAST(NULLIF(cgpa, '') AS FLOAT))
                    FROM profiles
                    WHERE cgpa IS NOT NULL 
                    AND cgpa != ''
                    AND cgpa ~ '^[0-9.]+$'
                """)).scalar() or 0.0
                
                return {
                    "success": True,
                    "stats": {
                        "total_students": profile_count,
                        "total_users": user_count,
                        "total_events": event_count,
                        "total_showcase_posts": showcase_count,
                        "average_cgpa": round(float(avg_cgpa), 2) if avg_cgpa else 0.0,
                        "departments": [
                            {"name": row[0], "count": row[1]}
                            for row in dept_stats
                        ] if dept_stats else []
                    }
                }
                
            except Exception as e:
                logger.error(f"Error getting system stats: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "stats": {}
                }
        
        @tool
        def query_analytics(
            metric: str = "cgpa_distribution",
            department: Optional[str] = None
        ) -> Dict[str, Any]:
            """Dapatkan analitik terperinci sistem.
            
            Gunakan tool ini untuk:
            - Taburan CGPA
            - Prestasi mengikut jabatan
            - Trend penyertaan
            
            Args:
                metric: Jenis metrik ('cgpa_distribution', 'department_performance', 'participation_trends')
                department: Filter mengikut jabatan (optional)
            
            Returns:
                Dict dengan data analitik
            """
            try:
                if metric == "cgpa_distribution":
                    sql = """
                        SELECT 
                            CASE 
                                WHEN CAST(NULLIF(cgpa, '') AS FLOAT) >= 3.5 THEN 'Cemerlang (3.5-4.0)'
                                WHEN CAST(NULLIF(cgpa, '') AS FLOAT) >= 3.0 THEN 'Baik (3.0-3.49)'
                                WHEN CAST(NULLIF(cgpa, '') AS FLOAT) >= 2.5 THEN 'Sederhana (2.5-2.99)'
                                WHEN CAST(NULLIF(cgpa, '') AS FLOAT) >= 2.0 THEN 'Lulus (2.0-2.49)'
                                ELSE 'Perlu Perhatian (<2.0)'
                            END as kategori,
                            COUNT(*) as bilangan
                        FROM profiles
                        WHERE cgpa IS NOT NULL 
                        AND cgpa != ''
                        AND cgpa ~ '^[0-9.]+$'
                    """
                    if department:
                        sql += f" AND department ILIKE '%{department}%'"
                    sql += " GROUP BY kategori ORDER BY bilangan DESC"
                    
                    result = self.db.execute(text(sql)).fetchall()
                    
                    return {
                        "success": True,
                        "metric": "cgpa_distribution",
                        "data": [
                            {"category": row[0], "count": row[1]}
                            for row in result
                        ]
                    }
                    
                elif metric == "department_performance":
                    sql = """
                        SELECT 
                            department as jabatan,
                            COUNT(*) as bilangan_pelajar,
                            AVG(CAST(NULLIF(cgpa, '') AS FLOAT)) as purata_cgpa
                        FROM profiles
                        WHERE department IS NOT NULL 
                        AND department != ''
                        AND cgpa IS NOT NULL
                        AND cgpa ~ '^[0-9.]+$'
                        GROUP BY department
                        ORDER BY purata_cgpa DESC
                    """
                    
                    result = self.db.execute(text(sql)).fetchall()
                    
                    return {
                        "success": True,
                        "metric": "department_performance",
                        "data": [
                            {
                                "department": row[0],
                                "student_count": row[1],
                                "average_cgpa": round(float(row[2]), 2) if row[2] else 0.0
                            }
                            for row in result
                        ]
                    }
                    
                else:
                    return {
                        "success": False,
                        "error": f"Metrik tidak dikenali: {metric}",
                        "available_metrics": ["cgpa_distribution", "department_performance"]
                    }
                    
            except Exception as e:
                logger.error(f"Error querying analytics: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "data": []
                }
        
        @tool
        def create_event(
            title: str,
            description: str,
            event_date: str,
            location: Optional[str] = None,
            category: str = "general",
            max_participants: Optional[int] = None
        ) -> Dict[str, Any]:
            """Cipta acara/event baru dalam sistem (ADMIN ONLY).
            
            Gunakan tool ini untuk:
            - Mencipta event/acara baru
            - Menambah program universiti
            - Mendaftarkan workshop, seminar, atau aktiviti
            
            Args:
                title: Tajuk acara (WAJIB)
                description: Penerangan acara (WAJIB)
                event_date: Tarikh acara dalam format YYYY-MM-DD atau YYYY-MM-DD HH:MM
                location: Lokasi acara (optional)
                category: Kategori acara - 'seminar', 'workshop', 'conference', 'competition', 'talk', 'ceremony', 'general'
                max_participants: Had peserta maksimum (optional, None = unlimited)
            
            Returns:
                Dict dengan maklumat event yang dicipta
            """
            try:
                from app.models.event import Event
                from datetime import datetime
                import uuid
                
                # Parse event date
                try:
                    if " " in event_date:
                        parsed_date = datetime.strptime(event_date, "%Y-%m-%d %H:%M")
                    else:
                        parsed_date = datetime.strptime(event_date, "%Y-%m-%d")
                except ValueError:
                    return {
                        "success": False,
                        "error": f"Format tarikh tidak sah: {event_date}. Gunakan format YYYY-MM-DD atau YYYY-MM-DD HH:MM"
                    }
                
                # Create new event
                new_event = Event(
                    id=uuid.uuid4(),
                    title=title,
                    description=description,
                    event_date=parsed_date,
                    location=location,
                    category=category,
                    max_participants=max_participants,
                    is_active=True
                )
                
                self.db.add(new_event)
                self.db.commit()
                self.db.refresh(new_event)
                
                logger.info(f"✅ Event created: {title} (ID: {new_event.id})")
                
                return {
                    "success": True,
                    "message": f"Acara '{title}' berjaya dicipta!",
                    "event": {
                        "id": str(new_event.id),
                        "title": new_event.title,
                        "description": new_event.description[:100] if new_event.description else "",
                        "event_date": new_event.event_date.isoformat() if new_event.event_date else None,
                        "location": new_event.location,
                        "category": new_event.category,
                        "max_participants": new_event.max_participants
                    }
                }
                
            except Exception as e:
                self.db.rollback()
                logger.error(f"Error creating event: {e}")
                return {
                    "success": False,
                    "error": str(e)
                }
        
        @tool
        def update_event(
            event_id: str,
            title: Optional[str] = None,
            description: Optional[str] = None,
            event_date: Optional[str] = None,
            location: Optional[str] = None,
            category: Optional[str] = None,
            is_active: Optional[bool] = None
        ) -> Dict[str, Any]:
            """Kemaskini maklumat acara sedia ada (ADMIN ONLY).
            
            Gunakan tool ini untuk:
            - Mengubah tajuk atau penerangan acara
            - Menukar tarikh atau lokasi
            - Mengaktifkan atau menyahaktifkan acara
            
            Args:
                event_id: ID acara untuk dikemaskini (WAJIB)
                title: Tajuk baru (optional)
                description: Penerangan baru (optional)
                event_date: Tarikh baru dalam format YYYY-MM-DD (optional)
                location: Lokasi baru (optional)
                category: Kategori baru (optional)
                is_active: Status aktif (True/False) (optional)
            
            Returns:
                Dict dengan maklumat event yang dikemaskini
            """
            try:
                from app.models.event import Event
                from datetime import datetime
                import uuid
                
                # Find the event
                try:
                    event_uuid = uuid.UUID(event_id)
                except ValueError:
                    return {
                        "success": False,
                        "error": f"ID acara tidak sah: {event_id}"
                    }
                
                event = self.db.query(Event).filter(Event.id == event_uuid).first()
                
                if not event:
                    return {
                        "success": False,
                        "error": f"Acara dengan ID {event_id} tidak ditemui"
                    }
                
                # Update fields if provided
                if title:
                    event.title = title
                if description:
                    event.description = description
                if location:
                    event.location = location
                if category:
                    event.category = category
                if is_active is not None:
                    event.is_active = is_active
                if event_date:
                    try:
                        if " " in event_date:
                            event.event_date = datetime.strptime(event_date, "%Y-%m-%d %H:%M")
                        else:
                            event.event_date = datetime.strptime(event_date, "%Y-%m-%d")
                    except ValueError:
                        return {
                            "success": False,
                            "error": f"Format tarikh tidak sah: {event_date}"
                        }
                
                self.db.commit()
                self.db.refresh(event)
                
                logger.info(f"✅ Event updated: {event.title} (ID: {event.id})")
                
                return {
                    "success": True,
                    "message": f"Acara '{event.title}' berjaya dikemaskini!",
                    "event": {
                        "id": str(event.id),
                        "title": event.title,
                        "description": event.description[:100] if event.description else "",
                        "event_date": event.event_date.isoformat() if event.event_date else None,
                        "location": event.location,
                        "category": event.category,
                        "is_active": event.is_active
                    }
                }
                
            except Exception as e:
                self.db.rollback()
                logger.error(f"Error updating event: {e}")
                return {
                    "success": False,
                    "error": str(e)
                }
        
        return [query_students, query_events, get_system_stats, query_analytics, create_event, update_event]
    
    def get_nlp_tools(self):
        """Return list of NLP-enhanced tools."""
        
        @tool
        def semantic_search_students(
            query: str,
            limit: int = 10
        ) -> Dict[str, Any]:
            """Cari pelajar menggunakan semantic search (NLP).
            
            Gunakan tool ini untuk:
            - Mencari pelajar dengan query natural language
            - Mencari berdasarkan kemahiran, minat, atau deskripsi
            - Pencarian yang lebih pintar daripada keyword matching
            
            Args:
                query: Query dalam bahasa natural (BM atau English)
                limit: Bilangan hasil maksimum
            
            Returns:
                Dict dengan hasil pencarian semantic
            """
            try:
                search_engine = get_semantic_search()
                
                # Get all students for indexing
                result = self.db.execute(text("""
                    SELECT 
                        id,
                        COALESCE(full_name, '') as full_name,
                        COALESCE(department, '') as department,
                        COALESCE(skills::text, '[]') as skills,
                        COALESCE(bio, '') as bio
                    FROM profiles
                    LIMIT 500
                """)).fetchall()
                
                # Build documents for search
                documents = []
                for row in result:
                    doc_text = f"{row[1]} {row[2]} {row[3]} {row[4]}"
                    documents.append({
                        "id": str(row[0]),
                        "text": doc_text,
                        "metadata": {
                            "full_name": row[1],
                            "department": row[2],
                            "skills": row[3],
                            "bio": row[4]
                        }
                    })
                
                # Index and search
                search_engine.index_documents(
                    texts=[d["text"] for d in documents],
                    metadata=[d["metadata"] for d in documents]
                )
                
                results = search_engine.search(query, top_k=limit)
                
                return {
                    "success": True,
                    "query": query,
                    "count": len(results),
                    "results": results
                }
                
            except Exception as e:
                logger.error(f"Error in semantic search: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "results": []
                }
        
        @tool
        def analyze_text(
            text: str,
            analysis_type: str = "full"
        ) -> Dict[str, Any]:
            """Analisis teks menggunakan NLP.
            
            Gunakan tool ini untuk:
            - Mengekstrak entiti dari teks
            - Analisis sentimen
            - Pengesanan bahasa (BM/English)
            
            Args:
                text: Teks untuk dianalisis
                analysis_type: Jenis analisis ('full', 'entities', 'sentiment', 'language')
            
            Returns:
                Dict dengan hasil analisis
            """
            try:
                nlp_processor = get_nlp_processor()
                malay_nlp = get_malay_nlp()
                malay_extractor = get_malay_extractor()
                
                result = {
                    "success": True,
                    "input_text": text[:200],  # Truncate for display
                }
                
                if analysis_type in ["full", "language"]:
                    lang_result = malay_nlp.detect_language(text)
                    result["language"] = lang_result
                
                if analysis_type in ["full", "sentiment"]:
                    sentiment = malay_nlp.analyze_sentiment(text)
                    result["sentiment"] = sentiment
                
                if analysis_type in ["full", "entities"]:
                    # Use both processors for comprehensive extraction
                    spacy_entities = nlp_processor.extract_entities(text)
                    malay_entities = malay_extractor.extract_all(text)
                    
                    result["entities"] = {
                        "general": spacy_entities,
                        "malaysian": malay_entities
                    }
                
                return result
                
            except Exception as e:
                logger.error(f"Error in text analysis: {e}")
                return {
                    "success": False,
                    "error": str(e)
                }
        
        @tool
        def extract_malaysian_entities(
            text: str
        ) -> Dict[str, Any]:
            """Ekstrak entiti khusus Malaysia dari teks.
            
            Gunakan tool ini untuk:
            - Mengenal pasti nama pelajar Malaysia
            - Mengesan nama universiti/institusi
            - Mengenal pasti jabatan/fakulti
            - Mengesan nombor matrik
            
            Args:
                text: Teks untuk dianalisis
            
            Returns:
                Dict dengan entiti Malaysia yang diekstrak
            """
            try:
                extractor = get_malay_extractor()
                entities = extractor.extract_all(text)
                
                return {
                    "success": True,
                    "input_text": text[:200],
                    "entities": entities,
                    "summary": {
                        "names_found": len(entities.get("names", [])),
                        "universities_found": len(entities.get("universities", [])),
                        "departments_found": len(entities.get("departments", [])),
                        "student_ids_found": len(entities.get("student_ids", []))
                    }
                }
                
            except Exception as e:
                logger.error(f"Error extracting Malaysian entities: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "entities": {}
                }
        
        @tool
        def answer_from_knowledge(
            question: str,
            context_topic: Optional[str] = None
        ) -> Dict[str, Any]:
            """Jawab soalan menggunakan sistem RAG dengan Supabase pgvector.
            
            Gunakan tool ini untuk:
            - Menjawab soalan tentang FSKTM/fakulti
            - Maklumat program akademik
            - Maklumat staff dan kepakaran
            - Maklumat penyelidikan dan pusat
            - Hubungi fakulti
            
            Args:
                question: Soalan untuk dijawab
                context_topic: Topik konteks tambahan (optional)
            
            Returns:
                Dict dengan jawapan dan sumber
            """
            try:
                # Try new Supabase RAG first
                try:
                    from app.ai_assistant.rag_chain import get_supabase_rag
                    rag = get_supabase_rag()
                    
                    if rag._initialized:
                        result = rag.query_sync(question)
                        
                        if result.confidence > 0.5:
                            return {
                                "success": True,
                                "question": question,
                                "answer": result.answer,
                                "confidence": result.confidence,
                                "sources": len(result.sources),
                                "source": "supabase_rag"
                            }
                except Exception as e:
                    logger.warning(f"Supabase RAG failed, falling back: {e}")
                
                # Fallback to old RAG system
                rag = get_rag_system()
                
                # Build context from database
                students_result = self.db.execute(text("""
                    SELECT 
                        COALESCE(full_name, '') || ' - ' || 
                        COALESCE(department, '') || ' - CGPA: ' ||
                        COALESCE(cgpa, 'N/A')
                    FROM profiles
                    LIMIT 100
                """)).fetchall()
                
                context_docs = [row[0] for row in students_result if row[0]]
                
                if context_topic:
                    context_docs.append(f"Topik konteks: {context_topic}")
                
                # Index context
                rag.add_documents(context_docs)
                
                # Get answer
                answer = rag.answer(question)
                
                return {
                    "success": True,
                    "question": question,
                    "answer": answer,
                    "context_size": len(context_docs),
                    "source": "legacy_rag"
                }
                
            except Exception as e:
                logger.error(f"Error in RAG answer: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "answer": None
                }
        
        @tool
        def query_fsktm_knowledge(
            query: str
        ) -> Dict[str, Any]:
            """Cari maklumat dalam pangkalan pengetahuan FSKTM.
            
            Gunakan tool ini untuk soalan tentang:
            - Maklumat fakulti (visi, misi, sejarah)
            - Program sarjana muda dan pascasiswazah
            - Pusat penyelidikan dan kumpulan fokus
            - Kepakaran dan bidang penyelidikan
            - Maklumat hubungan (email, telefon, alamat)
            - Jabatan dan struktur organisasi
            
            Args:
                query: Soalan atau kata kunci pencarian
            
            Returns:
                Dict dengan hasil pencarian dan jawapan
            """
            try:
                from app.ai_assistant.rag_chain import get_supabase_rag
                
                rag = get_supabase_rag()
                result = rag.query_sync(query)
                
                return {
                    "success": True,
                    "query": query,
                    "answer": result.answer,
                    "confidence": result.confidence,
                    "sources": [
                        {
                            "content": s.get("content", "")[:150],
                            "category": s.get("metadata", {}).get("category", "unknown")
                        }
                        for s in result.sources[:3]
                    ]
                }
                
            except Exception as e:
                logger.error(f"Error querying FSKTM knowledge: {e}")
                return {
                    "success": False,
                    "error": str(e),
                    "answer": "Maaf, tidak dapat mengakses pangkalan pengetahuan."
                }
        
        return [
            semantic_search_students,
            analyze_text,
            extract_malaysian_entities,
            answer_from_knowledge,
            query_fsktm_knowledge
        ]


def get_student_tools(db: Session):
    """Factory function to get tools with database session."""
    provider = StudentToolsProvider(db)
    return provider.get_tools()


def get_all_tools(db: Session):
    """Factory function to get all tools including NLP tools."""
    provider = StudentToolsProvider(db)
    return provider.get_tools() + provider.get_nlp_tools()
