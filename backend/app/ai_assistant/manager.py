"""Coordinator for AI assistant commands."""

from __future__ import annotations

import json
import logging
from datetime import date, datetime, timedelta
from typing import Any
from uuid import UUID

from fastapi import Depends
from sqlalchemy.orm import Session

from app.database import get_db
from . import schemas, permissions
from .config import AISettings, get_ai_settings
# OpenRouter removed - using Gemini only
from .gemini_client import GeminiClient
from .service_bridge import AssistantServiceBridge
from .supabase_bridge import SupabaseAIBridge
from .admin_db_assistant import AdminDatabaseAssistant
# Import our new agentic features
from .plan_generator import PlanGenerator
from .intent_classifier import IntentClassifier
from .clarification_system import ClarificationSystem
from .tool_selector import ToolSelector
from .orchestrator import AgenticOrchestrator
from .conversation_memory import conversation_memory
from .response_variation import DynamicResponseGenerator, ResponseTemplateType
from .template_manager import AdvancedResponseGenerator
from .tools import AVAILABLE_TOOLS
from .tool_executor import ToolExecutor
from .rate_limiter import gemini_rate_limiter
from .key_rotator import initialize_key_rotator, get_key_rotator
from .request_validator import get_request_validator
from .cache_manager import get_ai_cache
from .circuit_breaker import get_all_circuit_breakers
from .monitoring import get_metrics_collector
from .logger import ai_logger

log = logging.getLogger(__name__)


def serialize_tool_result(obj: Any) -> str:
    """Serialize tool result with proper UUID handling."""
    def json_serializer(obj):
        """Custom JSON serializer for UUID and other non-serializable objects."""
        if isinstance(obj, UUID):
            return str(obj)
        elif isinstance(obj, datetime):
            return obj.isoformat()
        elif isinstance(obj, date):
            return obj.isoformat()
        elif hasattr(obj, '__dict__'):
            return obj.__dict__
        else:
            return str(obj)
    
    try:
        return json.dumps(obj, default=json_serializer, ensure_ascii=False)
    except Exception as e:
        log.error(f"Error serializing tool result: {e}")
        return json.dumps({"error": "Serialization failed", "original_error": str(e)})


class AIAssistantManager:
    """Main entry point for handling AI commands via Gemini API."""

    def __init__(self, settings: AISettings = Depends(get_ai_settings), db: Session = Depends(get_db)) -> None:
        self.settings = settings
        self.daily_usage = 0  # basic in-memory counter (future: persist/cache)
        self._usage_date = date.today()
        self._gemini_client: GeminiClient | None = None
        self._service_bridge = AssistantServiceBridge(db=db)
        self._supabase_bridge = SupabaseAIBridge()
        self._admin_db_assistant = AdminDatabaseAssistant(db=db)
        # Initialize our new agentic features
        self._plan_generator = PlanGenerator()
        self._intent_classifier = IntentClassifier()
        self._clarification_system = ClarificationSystem()
        self._tool_selector = ToolSelector()
        self._agentic_orchestrator = AgenticOrchestrator()
        self._conversation_memory = conversation_memory
        self._dynamic_response_generator = DynamicResponseGenerator()
        self._advanced_response_generator = AdvancedResponseGenerator()
        self._tool_executor = ToolExecutor(self._service_bridge)
        
        # Initialize request validator
        self._request_validator = get_request_validator()
        
        # Initialize cache and monitoring
        self._cache = get_ai_cache(max_size=1000, default_ttl=300)
        self._metrics = get_metrics_collector()
        
        # Initialize API key rotator if multiple keys available
        all_keys = settings.get_all_gemini_keys()
        if len(all_keys) > 1:
            initialize_key_rotator(all_keys, cooldown_seconds=60)
            log.info(f"🔑 Initialized key rotator with {len(all_keys)} API keys")
        elif len(all_keys) == 1:
            log.info(f"🔑 Using single API key (no rotation)")
        else:
            log.warning(f"⚠️  No Gemini API keys configured!")

    async def handle_command(
        self,
        command: str,
        context: dict[str, Any] | None = None,
        current_user: dict[str, Any] | None = None,
    ) -> schemas.AICommandResponse:
        """Process command using Gemini API (direct agentic mode)."""

        log.info("🤖 AI ASSISTANT: Received command: '%s'", command)
        log.info("🔍 Current user: %s", current_user.get("email") if current_user else "anonymous")
        
        # Validate and sanitize request
        is_valid, error_msg, sanitized_command, sanitized_context = self._request_validator.validate_and_sanitize(
            command, context
        )
        
        if not is_valid:
            log.warning(f"⚠️  Invalid request: {error_msg}")
            return schemas.AICommandResponse(
                success=False,
                message=f"Request tidak sah: {error_msg}",
                source=schemas.AISource.MANUAL,
                data={"validation_error": error_msg},
            )
        
        # Use sanitized values
        command = sanitized_command
        context = sanitized_context
        
        # Extract session information from context
        session_id = context.get("session_id", f"session_{current_user.get('uid', 'anonymous') if current_user else 'anonymous'}") if context else f"session_{current_user.get('uid', 'anonymous') if current_user else 'anonymous'}"
        user_id = current_user.get("uid", "anonymous") if current_user else "anonymous"
        
        # Add user message to conversation memory
        self._conversation_memory.add_user_message(
            user_id=user_id,
            session_id=session_id,
            content=command,
            metadata=context or {}
        )

        self._reset_usage_if_needed()

        if not self.settings.ai_enabled:
            response = schemas.AICommandResponse(
                success=False,
                message="AI assistant is disabled.",
                source=schemas.AISource.MANUAL,
                data={},
            )
            ai_logger.log_ai_action(current_user.get("uid"), command, response.model_dump())
            return response

        if not permissions.can_run_action(current_user or {}, "general"):
            response = schemas.AICommandResponse(
                success=False,
                message="You do not have permission to run AI actions.",
                source=schemas.AISource.MANUAL,
                data={},
                fallback_used=True,
            )
            # Add AI response to conversation memory
            self._conversation_memory.add_ai_response(
                user_id=current_user.get("uid", "anonymous") if current_user else "anonymous",
                session_id=session_id,
                content="You do not have permission to run AI actions.",
                metadata=response.data or {},
                intent="permission_denied"
            )
            ai_logger.log_ai_action(current_user.get("uid"), command, response.model_dump())
            return response

        # 🚀 ALL COMMANDS NOW ROUTE DIRECTLY TO GEMINI (AGENTIC AI)
        # No local processing, no templates - pure agentic behavior!
        log.info("🤖 Routing ALL commands to Gemini for agentic processing...")

        # Check rate limit before calling Gemini
        user_id = user_id  # Already defined above
        if not gemini_rate_limiter.can_make_request(user_id):
            wait_time = gemini_rate_limiter.get_wait_time(user_id)
            log.warning(f"⚠️  Rate limit exceeded for user {user_id}. Wait time: {wait_time:.1f}s")
            
            response = schemas.AICommandResponse(
                success=True,
                message=f"Maaf, anda telah mencapai had penggunaan. Sila tunggu {int(wait_time)} saat sebelum cuba lagi. 🙏",
                source=schemas.AISource.MANUAL,
                data={"rate_limited": True, "wait_time": wait_time},
            )
            
            # Add rate limit message to conversation memory
            self._conversation_memory.add_ai_response(
                user_id=user_id,
                session_id=session_id,
                content=response.message,
                metadata={"rate_limited": True},
                intent="rate_limit"
            )
            
            ai_logger.log_ai_action(user_id, command, response.model_dump())
            return response

        # Direct ke Gemini bila available - check ANY key available
        has_keys = self.settings.gemini_api_key or self.settings.gemini_api_keys
        if self.settings.enable_gemini and has_keys:
            # Ensure context has session_id for conversation memory
            context_with_session = context.copy() if context else {}
            context_with_session["session_id"] = session_id
            
            response = await self._call_gemini(command, context_with_session, current_user)
            if response:
                self.daily_usage += 1
                
                # Add AI response to conversation memory with tool usage tracking
                self._conversation_memory.add_ai_response(
                    user_id=current_user.get("uid", "anonymous") if current_user else "anonymous",
                    session_id=session_id,
                    content=response.message,
                    metadata={
                        **(response.data or {}),
                        "tools_used": response.data.get("tools_used", []) if response.data else [],
                        "iterations": response.data.get("iterations", 0) if response.data else 0,
                        "mode": response.data.get("mode", "conversational") if response.data else "conversational"
                    },
                    intent=response.data.get("intent") if response.data else "gemini_response"
                )
                
                ai_logger.log_ai_action(
                    current_user.get("uid") if current_user else "anonymous",
                    command,
                    response.model_dump(),
                )
                return response

        # If we reach here, no system could handle the request
        raise RuntimeError("No AI system available to handle the request. Gemini API key may not be configured.")

    # 🗑️ REMOVED: Local agentic processing (_handle_agentic_command, _execute_orchestrated_query, etc.)
    # ALL commands now route directly to Gemini for pure agentic AI behavior!
    
    async def _call_gemini(
        self, 
        command: str, 
        context: dict[str, Any] | None,
        current_user: dict[str, Any] | None = None,
    ) -> schemas.AICommandResponse | None:
        """Direct call to Gemini API with agentic tool calling."""
        # Use Gemini only - CHECK ANY KEY
        has_keys = self.settings.gemini_api_key or self.settings.gemini_api_keys
        use_gemini = self.settings.enable_gemini and has_keys
        use_tools = True  # Gemini supports tools

        try:
            system_stats = self._service_bridge.get_system_stats()
            db_status = "available" if not system_stats.get('error') else "maintenance"
        except Exception:
            system_stats = {}
            db_status = "maintenance"
        
        # Build messages with conversation history
        messages = [
            {
                "role": "system",
                "content": f"""Anda adalah pembantu AI agentic untuk sistem papan pemuka UTHM (Universiti Tun Hussein Onn Malaysia).

IDENTITI TERAS:
- ANDA MESTI RESPOND DALAM BAHASA MELAYU SECARA DEFAULT (ini penting untuk NLP pengguna Malaysia)
- Anda boleh faham dan respons dalam Bahasa Melayu dan English
- Code-switching (campuran bahasa) adalah normal dan digalakkan
- Padan dengan nada, gaya, dan tenaga pengguna
- Bersikap membantu, mesra, dan berperbualan
- Fahami rujukan konteks seperti "sekalai lagi", "tadi", "sebelum", "that", "again"
- Ingat tindakan sebelum dan bina berdasarkan konteks

KONTEKS SISTEM:
- Papan pemuka UTHM: Pengurusan pelajar, acara, analitik, profil
- Status pangkalan data: {db_status}
- Pengguna semasa: {system_stats.get('total_users', 'N/A')} jumlah ({system_stats.get('user_breakdown', {}).get('students', 'N/A')} pelajar)

KEUPAYAAN AGENTIC:
- Anda ada akses kepada tools yang membolehkan query pangkalan data secara real-time
- Bila pengguna minta data (pelajar, acara, statistik), GUNA TOOLS dulu untuk dapatkan data terkini
- Jangan buat-buat atau agak maklumat - panggil tools untuk dapat data yang tepat
- Gabungkan hasil tools dengan pemahaman bahasa semulajadi untuk beri respons yang terbaik

TOOLS YANG ADA:
- query_students: Cari/tapis pelajar (mengikut jabatan, CGPA, dll.)
- query_users: Cari dan tapis semua pengguna (pelajar, staf, admin) dari sistem UTHM
- query_profiles: Cari dan tapis profil pengguna dengan maklumat terperinci (kemahiran, minat, pengalaman)
- query_events: Dapatkan maklumat acara dan jadual
- query_showcase_posts: Cari dan tapis showcase posts (projek, kerja pelajar, portfolio)
- query_achievements: Cari dan tapis pencapaian dan anugerah
- query_event_participations: Cari penyertaan acara dan penjejakan kehadiran
- get_system_stats: Dapatkan statistik seluruh sistem dan overview (dengan analisis jantina)
- query_analytics: Dapatkan analitik, trend, dan insights (termasuk analisis jantina/nama)
- analyze_student_names: Analisis NLP lanjutan untuk nama pelajar (demografi)

TOOLS ADMIN LANJUTAN:
- advanced_analytics: Lakukan analitik kompleks (trend, korelasi, metrik prestasi, analisis penglibatan, insights demografi, analisis ramalan, analisis perbandingan, pengesanan anomali)
- cross_entity_query: Analisis hubungan antara entiti (analisis pengguna-acara, prestasi jabatan, korelasi kemahiran, corak penglibatan, analisis aktiviti, pemetaan hubungan)
- intelligent_search: Carian semantik dengan pemahaman bahasa semulajadi merentas semua data
- predictive_insights: Jana ramalan dan prediksi (ramalan trend, prediksi tingkah laku, prediksi prestasi, ramalan penglibatan, prediksi pertumbuhan, penilaian risiko)
- admin_dashboard_analytics: Jana papan pemuka admin komprehensif dengan KPI, insights, dan cadangan

KEUPAYAAN KHAS (INTERVENTION PLAN):
- Jika pengguna minta "Generate Intervention Plan" atau "Pelan Intervensi":
- ANDA DIBENARKAN untuk menjana pelan akademik terperinci berdasarkan data konteks yang diberikan.
- Gunakan data seperti CGPA, markah kokurikulum, dan faktor risiko yang diberikan dalam prompt/context.
- JANGAN tolak permintaan ini dengan alasan "tiada akses".
- Analisis data yang ada dan berikan cadangan tindakan yang spesifik, motivasi, dan strategi pemulihan.
- Format jawapan dalam struktur: Masalah Utama -> Analisis Punca -> Cadangan Tindakan -> Garis Masa.

CARA MEMBERI RESPONS:
1. **Fahami Konteks**: Baca sejarah perbualan penuh sebelum buat keputusan
2. **Guna Tools Untuk Data**: Kalau pengguna minta info, panggil tools yang sesuai DAHULU - jangan minta penjelasan melainkan sangat perlu
3. **Jawab Secara Semulajadi**: Bentangkan hasil tools dengan cara yang mesra dan perbualan
4. **Rujuk Sejarah**: Bila pengguna rujuk mesej sebelum ("tadi", "sebelum", "that", "sekalai lagi", dll.), guna konteks perbualan
5. **Beri Spesifik**: Guna data sebenar dari tools, bukan contoh rekaan
6. **Kekal Semulajadi**: Jangan paksa kata kunci atau pattern - bercakap biasa sahaja
7. **Kesedaran Konteks**: Kalau pengguna kata "again" atau "sekalai lagi", ulang tindakan terakhir dengan parameter yang sama
8. **Bantuan Proaktif**: Kalau tools tidak kembalikan hasil, terangkan kenapa dan cadangkan alternatif
9. **Ambil Tindakan**: Jangan minta penjelasan - buat andaian yang munasabah dan ambil tindakan
10. **Bersikap Membantu**: Sentiasa cuba berikan maklumat berguna walaupun bukan tepat yang ditanya

CONTOH PENGGUNAAN (RESPOND DALAM BAHASA MELAYU):
Pengguna: "Pilih 1 student random" → Panggil query_students dengan random=true, limit=1 | Respons: "Okay, saya dah pilih 1 pelajar secara rawak..."
Pengguna: "Berapa student dalam sistem?" → Panggil get_system_stats | Respons: "Ada [X] pelajar dalam sistem..."
Pengguna: "Show me students from Computer Science" → Panggil query_students dengan department filter | Respons: "Baiklah, ini pelajar dari Sains Komputer..."
Pengguna: "Berapa student kita pilih tadi?" → Semak sejarah perbualan | Respons: "Tadi kita pilih [X] pelajar..."
Pengguna: "How many men and women?" → Panggil get_system_stats dengan include_gender_analysis=true | Respons: "Berdasarkan analisis, ada [X] lelaki dan [Y] perempuan..."
Pengguna: "Gender distribution" → Panggil analyze_student_names dengan analysis_type=gender_distribution | Respons: "Taburan jantina menunjukkan..."
Pengguna: "Naming patterns" → Panggil analyze_student_names dengan analysis_type=naming_patterns | Respons: "Corak penamaan pelajar menunjukkan..."
Pengguna: "sekalai lagi" → Ulang panggilan tool terakhir dengan parameter sama | Respons: "Baik, saya ulang sekali lagi..."
Pengguna: "Tunjuk event" → Panggil query_events dengan upcoming_only=false | Respons: "Ini semua acara yang ada..."
Pengguna: "semua event" → Panggil query_events dengan upcoming_only=false | Respons: "Berikut adalah semua acara..."
Pengguna: "event yang akan datang" → Panggil query_events dengan upcoming_only=true | Respons: "Acara yang akan datang ialah..."
Pengguna: "Show me all users" → Panggil query_users | Respons: "Ini semua pengguna dalam sistem..."
Pengguna: "Find profiles with Python skills" → Panggil query_profiles dengan skills filter | Respons: "Profil yang ada kemahiran Python..."
Pengguna: "Show me showcase posts" → Panggil query_showcase_posts | Respons: "Berikut adalah showcase posts pelajar..."
Pengguna: "List achievements" → Panggil query_achievements | Respons: "Senarai pencapaian dan anugerah..."
Pengguna: "Who attended event X?" → Panggil query_event_participations dengan event_id filter | Respons: "Yang hadir acara ini ialah..."

CONTOH ADMIN LANJUTAN (RESPOND DALAM BAHASA MELAYU):
Pengguna: "Show me trend analysis for user engagement" → Panggil advanced_analytics dengan analysis_type=trend_analysis | Respons: "Analisis trend penglibatan pengguna menunjukkan..."
Pengguna: "Analyze correlation between department and performance" → Panggil cross_entity_query dengan query_type=department_performance | Respons: "Korelasi antara jabatan dan prestasi adalah..."
Pengguna: "Find all high-performing students with Python skills" → Panggil intelligent_search | Respons: "Pelajar berprestasi tinggi dengan kemahiran Python ialah..."
Pengguna: "Predict user growth for next quarter" → Panggil predictive_insights dengan prediction_type=growth_prediction | Respons: "Ramalan pertumbuhan pengguna untuk suku akan datang..."
Pengguna: "Generate admin dashboard overview" → Panggil admin_dashboard_analytics dengan dashboard_type=overview | Respons: "Overview papan pemuka admin menunjukkan..."
Pengguna: "What are the engagement patterns for FSKTM students?" → Panggil cross_entity_query dengan query_type=engagement_patterns | Respons: "Corak penglibatan pelajar FSKTM adalah..."
Pengguna: "Show me anomaly detection in user activity" → Panggil advanced_analytics dengan analysis_type=anomaly_detection | Respons: "Pengesanan anomali dalam aktiviti pengguna menunjukkan..."
Pengguna: "Predict which students might drop out" → Panggil predictive_insights dengan prediction_type=risk_assessment | Respons: "Pelajar yang mungkin berhenti adalah..."

PENTING: SENTIASA RESPONS DALAM BAHASA MELAYU sebagai default, kecuali pengguna terang-terang guna English sahaja.

Masa semasa: {datetime.now().isoformat()}"""
            }
        ]
        
        # Get session ID and retrieve structured context
        session_id = context.get("session_id") if context else None
        structured_ctx = None
        
        if session_id:
            # Get structured context (messages + tool calls + insights)
            # OPTIMIZED: Reduce limit from 10 to 3 to save more tokens and reduce Gemini load
            structured_ctx = self._conversation_memory.get_structured_context(session_id, limit=3)
            
            log.info(f"💬 Session context: {structured_ctx['insights']['message_count']} messages, {structured_ctx['insights']['tool_calls_count']} tools used")
            
            # Add conversation history messages (only last few to reduce token usage)
            for msg_dict in structured_ctx["messages"]:
                if msg_dict["type"] == "user_message":
                    messages.append({
                        "role": "user",
                        "content": msg_dict["content"]
                    })
                elif msg_dict["type"] == "ai_response":
                    # Truncate long AI responses to save tokens
                    content = msg_dict["content"]
                    if len(content) > 300:
                        content = content[:300] + "..."
                    messages.append({
                        "role": "assistant",
                        "content": content
                    })
            
            # If there are recent tool calls, add context about them
            if structured_ctx["tool_calls"]:
                recent_tools = structured_ctx["tool_calls"][-3:]  # Last 3 tool calls
                tools_summary = "\n".join([
                    f"- {tc['tool']}({tc['result_summary']})" 
                    for tc in recent_tools
                ])
                messages[0]["content"] += f"\n\nRECENT TOOL USAGE IN THIS SESSION:\n{tools_summary}"
                
                # Add last tool call details for "again" context
                if structured_ctx.get("last_tool_call"):
                    last_tool = structured_ctx["last_tool_call"]
                    messages[0]["content"] += f"\n\nLAST TOOL CALL (for 'again'/'sekalai lagi' context):\nTool: {last_tool['tool']}\nArguments: {last_tool.get('arguments', {})}\nResult: {last_tool['result_summary']}\n\nIMPORTANT: If user says 'sekalai lagi', 'again', or similar, repeat this exact tool call with the same arguments!"
        
        # Add current user message
        messages.append({
            "role": "user", 
            "content": command
        })

        try:
            # Initialize Gemini client with key rotation support
            if not self._gemini_client:
                rotator = get_key_rotator()
                if rotator:
                    # Use first key from rotator
                    first_key = rotator.get_next_key()
                    self._gemini_client = GeminiClient(first_key, key_rotator=rotator)
                    log.info("🔄 Gemini client initialized with key rotation")
                else:
                    # Use single key or first from list if rotator failed for some reason
                    # Fallback to whatever is available
                    available_key = self.settings.gemini_api_key
                    if not available_key and self.settings.gemini_api_keys:
                         available_key = self.settings.gemini_api_keys.split(",")[0].strip()
                    
                    self._gemini_client = GeminiClient(available_key)
                    log.info("🔑 Gemini client initialized with single/fallback key")
            
            ai_client = self._gemini_client
            ai_source = schemas.AISource.GEMINI
            log.info("🚀 Using Gemini 2.0 Flash (FREE + Tools)")

            # 🚀 AGENTIC LOOP: AI can call tools until it gets final answer
            max_iterations = 10  # Increased from 3 to 10 to allow complex tool chains
            iteration = 0
            tool_results_data = []
            
            # Filter tools to only include CRUD/Query tools (exclude advanced analytics)
            crud_tools = [
                t for t in AVAILABLE_TOOLS 
                if t["function"]["name"] in [
                    "query_students", "query_events", "query_users", 
                    "query_profiles", "query_showcase_posts", 
                    "query_achievements", "query_event_participations",
                    "get_system_stats"
                ]
            ]

            while iteration < max_iterations:
                iteration += 1
                log.info(f"🔄 Agentic loop iteration {iteration}/{max_iterations}")
                
                response = await ai_client.chat_completion(
                    messages=messages,
                    max_tokens=800,
                    temperature=0.7,
                    tools=crud_tools if use_tools else None
                )
                
                # Check if response is text or tool_calls
                if isinstance(response, str):
                    # Final text response - we're done!
                    log.info(f"✅ Got final text response from Gemini")
                    return schemas.AICommandResponse(
                        success=True,
                        message=response,
                        source=ai_source,
                        data={
                            "model": "gemini-2.0-flash-exp",
                            "mode": "agentic",
                            "database_status": db_status,
                            "iterations": iteration,
                            "tools_used": tool_results_data
                        },
                    )
                
                # AI wants to call tools!
                elif isinstance(response, dict) and response.get("type") == "tool_calls":
                    log.info(f"🔧 AI requested {len(response['tool_calls'])} tool calls")
                    
                    # Add AI's message (with tool calls) to conversation
                    messages.append(response["message"])
                    
                    # Execute each tool call
                    for tool_call in response["tool_calls"]:
                        tool_name = tool_call["function"]["name"]
                        tool_args = json.loads(tool_call["function"]["arguments"])
                        tool_id = tool_call["id"]
                        
                        log.info(f"⚙️ Executing tool: {tool_name} with args: {tool_args}")
                        
                        # Execute the tool
                        tool_result = await self._tool_executor.execute_tool(tool_name, tool_args)
                        
                        log.info(f"✅ Tool {tool_name} result: {tool_result.get('success', False)}")
                        
                        # Track tool usage
                        tool_results_data.append({
                            "tool": tool_name,
                            "arguments": tool_args,
                            "result": tool_result
                        })
                        
                        # Add tool call to conversation memory
                        self._conversation_memory.add_tool_call(
                            current_user.get("uid") if current_user else "anonymous",
                            session_id,
                            tool_name,
                            tool_args,
                            tool_result,
                            success=tool_result.get("success", True)
                        )
                        
                        # Add tool result to messages for next iteration
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tool_id,
                            "name": tool_name,
                            "content": serialize_tool_result(tool_result)
                        })
                    
                    # Continue loop - Gemini will process tool results
                    log.info("🔄 Tools executed, continuing agentic loop...")
                    continue
                
                else:
                    # Unexpected response format
                    log.error(f"Unexpected response format: {response}")
                    raise RuntimeError(f"Unexpected AI response: {response}")
            
            # Max iterations reached
            log.warning(f"⚠️ Max iterations ({max_iterations}) reached")
            return schemas.AICommandResponse(
                success=True,
                message="Maaf, saya perlu terlalu banyak steps untuk selesaikan task ni. Cuba simplify request awak? 🙏",
                source=ai_source,
                data={
                            "model": "gemini-2.0-flash-exp",
                    "mode": "agentic",
                    "database_status": db_status,
                    "iterations": iteration,
                    "tools_used": tool_results_data,
                    "max_iterations_reached": True
                },
            )

        except Exception as e:
            log.error(f"Gemini error: {e}")
            # Re-raise the exception so user can see actual errors
            raise

    def _attach_quota(self, response: schemas.AICommandResponse) -> schemas.AICommandResponse:
        """Attach quota information to response."""
        response.data = response.data or {}
        response.data["quota"] = {
            "daily_usage": self.daily_usage,
            "daily_limit": 1000,  # Gemini has generous limits
            "usage_date": self._usage_date.isoformat(),
        }
        return response

    def _reset_usage_if_needed(self) -> None:
        """Reset usage counter if we've moved to a new day."""
        today = date.today()
        if today != self._usage_date:
            self.daily_usage = 0
            self._usage_date = today
