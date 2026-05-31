"""Response Variation System for Agentic AI Assistant."""

from __future__ import annotations
from typing import Dict, List, Any, Optional
import random
import logging
from dataclasses import dataclass
from enum import Enum

logger = logging.getLogger(__name__)

class ResponseTemplateType(Enum):
    """Types of response templates for different scenarios."""
    GREETING = "greeting"
    HELP = "help"
    CONFIRMATION = "confirmation"
    ERROR = "error"
    QUERY_RESULT = "query_result"
    CLARIFICATION = "clarification"
    GOODBYE = "goodbye"
    GENERIC = "generic"
    STUDENT_QUERY = "student_query"
    EVENT_QUERY = "event_query"
    ANALYTICS_QUERY = "analytics_query"
    MULTI_INTENT = "multi_intent"


@dataclass
class ResponseTemplate:
    """Template for generating varied responses."""
    template_id: str
    template_type: ResponseTemplateType
    content: str  # Can include placeholders like {user_name}, {result_count}, etc.
    tags: List[str]  # Tags for context matching
    weight: float  # Weight for selection probability (1.0 = normal, >1.0 = more frequent)


class ResponseVariationSystem:
    """System for generating varied responses to avoid repetition."""
    
    def __init__(self):
        self.templates = self._initialize_templates()
        self.used_templates_per_session = {}  # session_id -> [template_ids]
        self.min_reuse_distance = 5  # Minimum distance before reusing template
    
    def _initialize_templates(self) -> Dict[ResponseTemplateType, List[ResponseTemplate]]:
        """Initialize response templates for different scenarios."""
        templates = {}
        
        # Greeting templates
        templates[ResponseTemplateType.GREETING] = [
            ResponseTemplate(
                template_id="greeting_001",
                template_type=ResponseTemplateType.GREETING,
                content="Hai! Apa khabar? {user_name}, saya AI assistant UTHM sedia nak tolong. Ada apa yang awak perlukan?",
                tags=["friendly", "welcoming"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="greeting_002", 
                template_type=ResponseTemplateType.GREETING,
                content="Wah bestnya jumpa awak! 😊 Saya AI assistant UTHM, ready to help. Boleh tolong saya dengan apa-apa yang awak nak?",
                tags=["enthusiastic", "helpful"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="greeting_003",
                template_type=ResponseTemplateType.GREETING,
                content="Hi there! Saya AI assistant untuk dashboard UTHM. Sure lah! Boleh tolong awak dengan macam-macam perkara. Apa yang awak nak tahu hari ni?",
                tags=["professional", "informative"],
                weight=1.0
            )
        ]
        
        # Help templates
        templates[ResponseTemplateType.HELP] = [
            ResponseTemplate(
                template_id="help_001",
                template_type=ResponseTemplateType.HELP,
                content="Sure! Saya sedia tolong awak. Awak boleh tanya pasal students, events, analytics, atau apa-apa related dengan UTHM. Tqvm!",
                tags=["detailed", "helpful"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="help_002",
                template_type=ResponseTemplateType.HELP,
                content="Best lah! 😊 Boleh saya tolong awak dengan query students, events, reports, atau analytics. Just tell me what you need, okay?",
                tags=["casual", "reassuring"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="help_003",
                template_type=ResponseTemplateType.HELP,
                content="No prob! Saya AI assistant UTHM, expert lah dalam bantu student-student UTHM. Boleh query pasal profiles, events, achievements, etc.",
                tags=["confident", "student_focused"],
                weight=1.0
            )
        ]
        
        # Confirmation templates
        templates[ResponseTemplateType.CONFIRMATION] = [
            ResponseTemplate(
                template_id="confirm_001",
                template_type=ResponseTemplateType.CONFIRMATION,
                content="Wah bestnya! Saya dah proses permintaan awak. Sure lah! Saya dah faham dan execute kan.",
                tags=["positive", "confirming"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="confirm_002",
                template_type=ResponseTemplateType.CONFIRMATION,
                content="Tqvm! Dah done proses tadi. Everything is set and ready for awak.",
                tags=["appreciative", "confirming"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="confirm_003",
                template_type=ResponseTemplateType.CONFIRMATION,
                content="Okay lah! Saya dah handle permintaan awak. Kalau ada lagi, jangan segan-segan tolong saya. 😊",
                tags=["reassuring", "open"],
                weight=1.0
            )
        ]
        
        # Error templates - REMOVED: Let actual errors propagate for debugging
        # templates[ResponseTemplateType.ERROR] = []
        
        # Query result templates (for different query types)
        templates[ResponseTemplateType.STUDENT_QUERY] = [
            ResponseTemplate(
                template_id="student_query_001",
                template_type=ResponseTemplateType.STUDENT_QUERY,
                content="Wah bestnya! 🎉 Saya jumpa **{result_count} students** mengikut permintaan awak!",
                tags=["excited", "results_focused"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="student_query_002",
                template_type=ResponseTemplateType.STUDENT_QUERY,
                content="Jumpa lah! Saya dapatkan {result_count} students untuk awak. Best kan?",
                tags=["positive", "results_focused"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="student_query_003", 
                template_type=ResponseTemplateType.STUDENT_QUERY,
                content="Sure lah! Berjaya dapatkan maklumat {result_count} students yang awak cari. Tqvm!",
                tags=["confident", "results_focused"],
                weight=1.0
            )
        ]
        
        templates[ResponseTemplateType.EVENT_QUERY] = [
            ResponseTemplate(
                template_id="event_query_001",
                template_type=ResponseTemplateType.EVENT_QUERY,
                content="Wah bestnya! Jumpa **{result_count} events** untuk awak!",
                tags=["excited", "events_focused"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="event_query_002",
                template_type=ResponseTemplateType.EVENT_QUERY,
                content="Event-event menarik ni untuk awak: {result_count} events ready for you!",
                tags=["enthusiastic", "events_focused"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="event_query_003",
                template_type=ResponseTemplateType.EVENT_QUERY,
                content="Sure lah! Ni {result_count} events yang awak cari. Tqvm sebab tanya saya. 😊",
                tags=["helpful", "events_focused"],
                weight=1.0
            )
        ]
        
        templates[ResponseTemplateType.ANALYTICS_QUERY] = [
            ResponseTemplate(
                template_id="analytics_query_001",
                template_type=ResponseTemplateType.ANALYTICS_QUERY,
                content="Wah bestnya! Ni analytics yang awak nak. Saya buatkan analysis yang detailed untuk awak. Tqvm!",
                tags=["detailed", "analytics_focused"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="analytics_query_002",
                template_type=ResponseTemplateType.ANALYTICS_QUERY,
                content="Best lah! Saya dah analyze data dan ni results untuk awak. Ada insights yang menarik lah.",
                tags=["analytical", "insightful"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="analytics_query_003",
                template_type=ResponseTemplateType.ANALYTICS_QUERY,
                content="Sure! Saya dah run analytics untuk awak. Ni data terkini dan trends yang saya jumpa.",
                tags=["informative", "data_focused"],
                weight=1.0
            )
        ]
        
        # Clarification templates
        templates[ResponseTemplateType.CLARIFICATION] = [
            ResponseTemplate(
                template_id="clarification_001",
                template_type=ResponseTemplateType.CLARIFICATION,
                content="Wah, sorry lah! Saya perlukan sedikit maklumat tambahan untuk bantu awak. Boleh tolong bagi details yang lebih spesifik tak?",
                tags=["apologetic", "requesting_info"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="clarification_002",
                template_type=ResponseTemplateType.CLARIFICATION,
                content="Sure lah! Tapi saya perlukan lebih details untuk proses permintaan awak. Boleh clarify sikit?",
                tags=["understanding", "requesting_clarity"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="clarification_003",
                template_type=ResponseTemplateType.CLARIFICATION,
                content="Hmm, saya faham awak nak tolong, tapi boleh tolong bagi lebih specific details tak? Saya sedia nak tolong!",
                tags=["helpful", "requesting_specifics"],
                weight=1.0
            )
        ]
        
        # Generic templates
        templates[ResponseTemplateType.GENERIC] = [
            ResponseTemplate(
                template_id="generic_001",
                template_type=ResponseTemplateType.GENERIC,
                content="Wah bestnya! Saya dah proses permintaan awak. Tqvm kerana guna services saya!",
                tags=["positive", "generic"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="generic_002", 
                template_type=ResponseTemplateType.GENERIC,
                content="Sure lah! Saya dah handle permintaan awak. Kalau ada lagi, jangan segan-segan. 😊",
                tags=["reassuring", "open"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="generic_003",
                template_type=ResponseTemplateType.GENERIC,
                content="No prob! Saya dah execute kan apa yang awak minta. Tqvm sudi tunggu!",
                tags=["casual", "reassuring"],
                weight=1.0
            )
        ]
        
        # Goodbye templates
        templates[ResponseTemplateType.GOODBYE] = [
            ResponseTemplate(
                template_id="goodbye_001",
                template_type=ResponseTemplateType.GOODBYE,
                content="Bye! Take care! Kalau ada apa-apa lagi, saya always ready to help. Tqvm! 😊",
                tags=["warm", "reassuring"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="goodbye_002",
                template_type=ResponseTemplateType.GOODBYE,
                content="Sure lah! Jumpa lagi awak. Saya standby kalau awak perlukan tolong. Tqvm! 😊",
                tags=["friendly", "available"],
                weight=1.0
            ),
            ResponseTemplate(
                template_id="goodbye_003",
                template_type=ResponseTemplateType.GOODBYE,
                content="Best lah chat dengan awak! Kalau perlukan saya lagi, sure lah! Tqvm! 😊",
                tags=["positive", "appreciative"],
                weight=1.0
            )
        ]
        
        return templates
    
    def get_template_by_type(self, template_type: ResponseTemplateType) -> List[ResponseTemplate]:
        """Get all templates of a specific type."""
        return self.templates.get(template_type, [])
    
    def select_template(self, template_type: ResponseTemplateType, session_id: str = "") -> Optional[ResponseTemplate]:
        """Select a template based on type, avoiding recently used ones."""
        templates = self.get_template_by_type(template_type)
        if not templates:
            return None
        
        # Get templates that haven't been used recently in this session
        available_templates = []
        used_recently = self.used_templates_per_session.get(session_id, [])[-self.min_reuse_distance:]
        
        for template in templates:
            if template.template_id not in used_recently:
                # Add template multiple times based on weight for probability
                for _ in range(int(template.weight * 10)):  # Scale weight for better probability
                    available_templates.append(template)
        
        # If all templates were used recently, just pick from all templates
        if not available_templates:
            available_templates = templates
        
        if not available_templates:
            return None
        
        # Randomly select a template
        selected = random.choice(available_templates)
        
        # Record that this template was used in the session
        if session_id:
            if session_id not in self.used_templates_per_session:
                self.used_templates_per_session[session_id] = []
            self.used_templates_per_session[session_id].append(selected.template_id)
        
        return selected
    
    def render_template(self, template: ResponseTemplate, context: Dict[str, Any] = None) -> str:
        """Render template with context variables."""
        content = template.content
        context = context or {}
        
        # Replace placeholders in content
        for key, value in context.items():
            placeholder = f"{{{key}}}"
            if placeholder in content:
                content = content.replace(placeholder, str(value))
        
        # Also include some random personalization if not already present
        if "{user_name}" in content and "user_name" not in context:
            # If no user name provided, use a general placeholder
            content = content.replace("{user_name}", "friend")
        
        return content
    
    def generate_response(self, template_type: ResponseTemplateType, 
                         context: Dict[str, Any] = None, session_id: str = "") -> str:
        """Generate a varied response using appropriate template."""
        template = self.select_template(template_type, session_id)
        if not template:
            # If no template found, raise error instead of using fallback
            raise ValueError(f"No template found for type: {template_type}")
        
        return self.render_template(template, context)
    
    def clear_session_history(self, session_id: str):
        """Clear template usage history for a session."""
        if session_id in self.used_templates_per_session:
            del self.used_templates_per_session[session_id]
    
    def get_used_templates_in_session(self, session_id: str) -> List[str]:
        """Get list of template IDs used in a session."""
        return self.used_templates_per_session.get(session_id, [])


# Singleton instance
response_variation_system = ResponseVariationSystem()


class DynamicResponseGenerator:
    """Higher-level class to generate context-aware responses."""
    
    def __init__(self):
        self.variation_system = response_variation_system
    
    def generate_for_intent(self, intent: str, context: Dict[str, Any] = None, 
                           session_id: str = "") -> str:
        """Generate response based on intent."""
        if intent == "student_query":
            template_type = ResponseTemplateType.STUDENT_QUERY
        elif intent == "event_query":
            template_type = ResponseTemplateType.EVENT_QUERY
        elif intent == "analytics_query":
            template_type = ResponseTemplateType.ANALYTICS_QUERY
        elif intent == "multi_intent":
            template_type = ResponseTemplateType.MULTI_INTENT
        elif intent == "clarification_needed":
            template_type = ResponseTemplateType.CLARIFICATION
        else:
            template_type = ResponseTemplateType.GENERIC
        
        return self.variation_system.generate_response(template_type, context, session_id)
    
    def generate_generic_response(self, context: Dict[str, Any] = None, session_id: str = "") -> str:
        """Generate a generic response."""
        return self.variation_system.generate_response(
            ResponseTemplateType.GENERIC, context, session_id
        )
    
    def generate_error_response(self, context: Dict[str, Any] = None, session_id: str = "") -> str:
        """Generate an error response - DISABLED: Errors should propagate naturally."""
        raise NotImplementedError("Error responses are disabled. Actual errors will be shown for debugging.")
    
    def generate_greeting(self, context: Dict[str, Any] = None, session_id: str = "") -> str:
        """Generate a greeting response."""
        return self.variation_system.generate_response(
            ResponseTemplateType.GREETING, context, session_id
        )


if __name__ == "__main__":
    # Example usage
    generator = DynamicResponseGenerator()
    
    # Generate different types of responses
    print("Greeting:", generator.generate_greeting({"user_name": "Ali"}))
    print("Student Query:", generator.generate_for_intent("student_query", {"result_count": 5}))
    print("Event Query:", generator.generate_for_intent("event_query", {"result_count": 3}))
    print("Analytics:", generator.generate_for_intent("analytics_query"))
    print("Error:", generator.generate_error_response())
    
    # Show template diversity - generate same type multiple times
    print("\nMultiple responses of same type (should be different):")
    for i in range(3):
        resp = generator.generate_for_intent("student_query", {"result_count": 7})
        print(f"{i+1}. {resp}")