"""Advanced Intent Classification System for Agentic AI."""

from __future__ import annotations
from typing import Dict, List, Tuple, Optional, Any
from enum import Enum
import re
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

class IntentType(Enum):
    STUDENT_QUERY = "student_query"
    EVENT_QUERY = "event_query"
    ACHIEVEMENT_QUERY = "achievement_query"
    ANALYTICS_QUERY = "analytics_query"
    REPORT_GENERATION = "report_generation"
    COMMUNICATION_TASK = "communication_task"
    DATA_MANIPULATION = "data_manipulation"
    SYSTEM_QUERY = "system_query"
    MULTI_INTENT = "multi_intent"
    UNCLEAR = "unclear"


@dataclass
class IntentClassification:
    """Result of intent classification."""
    intent_type: IntentType
    confidence: float  # 0.0 to 1.0
    detected_entities: Dict[str, Any]
    alternative_intents: List[Tuple[IntentType, float]]  # List of possible intents with confidence
    clarification_needed: bool
    required_context: List[str]


class IntentClassifier:
    """Classify user intents in natural language commands."""
    
    def __init__(self):
        # Define keyword patterns for different intents
        self.intent_patterns = {
            IntentType.STUDENT_QUERY: {
                'patterns': [
                    r'\b(students?|pelajar|mahasiswa|mahasiswi|student)\b',
                    r'\b(top|best|highest|ranking|rank|performing)\b',
                    r'\b(CGPA|cgpa|gpa|cumulative|grade|marka|purata)\b',
                    r'\b(department|faculty|fakulti|kursus|course|program)\b',
                    r'\b(profile|profil|completed|incomplete|lengkap|tidak lengkap)\b',
                    r'\b(student id|matric|id pelajar)\b'
                ],
                'context_words': ['show', 'list', 'find', 'tunjuk', 'senarai', 'cari']
            },
            IntentType.EVENT_QUERY: {
                'patterns': [
                    r'\b(events?|acara|aktiviti|seminar|workshop|talk|ceramah|peringkat|event)\b',
                    r'\b(date|tarikh|when|bilakah|bila|schedule|jadual)\b',
                    r'\b(location|venue|tempat|venue|lokasi)\b',
                    r'\b(organizer|pengurus|penganjur|pengaturcara)\b',
                    r'\b(participant|attendee|peserta|hadirin)\b'
                ],
                'context_words': ['show', 'list', 'find', 'tunjuk', 'senarai', 'cari', 'upcoming', 'akan datang']
            },
            IntentType.ACHIEVEMENT_QUERY: {
                'patterns': [
                    r'\b(achievements?|pencapaian|award|anugerah|prize|hadiah|recognition|penghargaan)\b',
                    r'\b(category|kategori|type|jenis)\b',
                    r'\b(recipient|penerima)\b',
                    r'\b(date|tarikh|when|bilakah|bila)\b'
                ],
                'context_words': ['show', 'list', 'find', 'tunjuk', 'senarai', 'cari', 'winners?', 'pemenang']
            },
            IntentType.ANALYTICS_QUERY: {
                'patterns': [
                    r'\b(analytics|analytics|report|lapan|trend|pattern|trend|corak|insight|pemahaman|statistic|statistik)\b',
                    r'\b(percentage|percentage|rate|kadar|ratio|nisbah)\b',
                    r'\b(comparison|compare|banding|perbandingan)\b',
                    r'\b(total|jumlah|sum|jumlah keseluruhan)\b',
                    r'\b(avg|average|purata|rata-rata)\b'
                ],
                'context_words': ['show', 'analyze', 'analyze', 'analysis', 'compare', 'tunjuk', 'analisis']
            },
            IntentType.REPORT_GENERATION: {
                'patterns': [
                    r'\b(generate|create|buat|hasilkan|generate|make|create)\b',
                    r'\b(report|laporan|summary|ringkasan|summary|hasil)\b',
                    r'\b(format|type|jenis|bentuk|format)\b',
                    r'\b(export|eksport|download|muat turun)\b'
                ],
                'context_words': ['generate', 'create', 'buat', 'hasilkan', 'export', 'download']
            },
            IntentType.COMMUNICATION_TASK: {
                'patterns': [
                    r'\b(send|email|message|text|mesej|email|teks|notify|maklumkan|beritahu)\b',
                    r'\b(notification|notifikasi|alert|peringatan|makluman)\b',
                    r'\b(contact|hubungi|reach out|hubungi|berkenaan)\b',
                    r'\b(reminder|peringatan|ingatkan)\b'
                ],
                'context_words': ['send', 'email', 'message', 'hantar', 'maklumkan', 'beritahu']
            },
            IntentType.DATA_MANIPULATION: {
                'patterns': [
                    r'\b(update|modify|change|kemaskini|ubah|tukar|edit)\b',
                    r'\b(add|create|tambah|buat|wujudkan)\b',
                    r'\b(delete|remove|padam|buang|hapus)\b',
                    r'\b(set|assign|assign|tetapkan|berikan)\b'
                ],
                'context_words': ['update', 'modify', 'change', 'kemaskini', 'ubah', 'tukar']
            },
            IntentType.SYSTEM_QUERY: {
                'patterns': [
                    r'\b(system|sistem|users?|pengguna|total|jumlah|count|bilangan|status|keadaan)\b',
                    r'\b(active|online|offline|aktif|dalam talian|luar talian)\b',
                    r'\b(usage|guna|utilization|penggunaan)\b'
                ],
                'context_words': ['how many', 'berapa', 'jumlah', 'total', 'count', 'bilangan']
            }
        }
        
        # Multi-intent indicators
        self.multi_intent_indicators = [
            r'\s+(and|dan|kemudian|then|after|selepas|before|sebelum|followed by|diikuti oleh)\s+',
            r'\s+also\s+|\s+juga\s+',
            r'(first.*then|pertama.*kemudian)',
            r'(find.*and.*send|cari.*dan.*hantar)',
        ]
        
        # Context keywords that indicate need for clarification
        self.clarification_keywords = [
            r'\b(they|them|those|itu|mereka|itu|tersebut)\b',  # Ambiguous references
            r'\b(some|certain|specific|beberapa|tertentu|tertentu)\b',  # Vague terms
            r'\b(more|further|lanjut|tambahan)\b',  # Imprecise requests
        ]

    def classify_intent(self, command: str, context: Optional[Dict[str, Any]] = None) -> IntentClassification:
        """Classify the intent of a user command."""
        logger.info(f"Classifying intent for command: {command}")
        
        # Check for multi-intent first
        if self._has_multi_intent(command):
            return self._handle_multi_intent(command, context)
        
        # Calculate scores for each intent
        intent_scores = self._calculate_intent_scores(command)
        
        # Determine the best intent
        best_intent, best_score = max(intent_scores, key=lambda x: x[1])
        
        # Get alternative intents
        alternative_intents = sorted(intent_scores, key=lambda x: x[1], reverse=True)[:3]
        
        # Calculate confidence based on score
        confidence = min(best_score / 10.0, 1.0)  # Normalize to 0-1 range
        
        # Extract entities and determine if clarification is needed
        detected_entities = self._extract_entities(command, best_intent)
        clarification_needed = self._needs_clarification(command, detected_entities, context)
        required_context = self._get_required_context(best_intent, detected_entities)
        
        logger.info(f"Classified intent: {best_intent.value} with confidence: {confidence}")
        
        return IntentClassification(
            intent_type=best_intent,
            confidence=confidence,
            detected_entities=detected_entities,
            alternative_intents=alternative_intents,
            clarification_needed=clarification_needed,
            required_context=required_context
        )
    
    def _calculate_intent_scores(self, command: str) -> List[Tuple[IntentType, float]]:
        """Calculate scores for each intent based on pattern matching."""
        scores = []
        command_lower = command.lower()
        
        for intent_type, config in self.intent_patterns.items():
            score = 0.0
            
            # Score based on patterns
            for pattern in config['patterns']:
                matches = re.findall(pattern, command_lower)
                score += len(matches) * 2  # Pattern matches get higher weight
            
            # Score based on context words
            for context_word in config['context_words']:
                if context_word in command_lower:
                    score += 1
            
            # Penalize if no patterns match
            if score == 0:
                score = 0.1  # Minimum score to avoid zero
            
            scores.append((intent_type, score))
        
        return scores
    
    def _has_multi_intent(self, command: str) -> bool:
        """Check if command has multiple intents."""
        command_lower = command.lower()
        
        for indicator in self.multi_intent_indicators:
            if re.search(indicator, command_lower):
                return True
        
        return False
    
    def _handle_multi_intent(self, command: str, context: Optional[Dict[str, Any]]) -> IntentClassification:
        """Handle commands that have multiple intents."""
        # For multi-intent, we'll return a special classification
        detected_entities = self._extract_entities(command, IntentType.MULTI_INTENT)
        required_context = self._get_required_context(IntentType.MULTI_INTENT, detected_entities)
        
        return IntentClassification(
            intent_type=IntentType.MULTI_INTENT,
            confidence=0.9,  # High confidence for multi-intent detection
            detected_entities=detected_entities,
            alternative_intents=[(IntentType.MULTI_INTENT, 0.9)],
            clarification_needed=False,  # Multi-intent is clear
            required_context=required_context
        )
    
    def _extract_entities(self, command: str, intent_type: IntentType) -> Dict[str, Any]:
        """Extract named entities from the command."""
        entities = {}
        command_lower = command.lower()
        
        # Extract numbers (for limits, amounts)
        number_matches = re.findall(r'\b(\d+)\b', command)
        if number_matches:
            entities['numbers'] = [int(n) for n in number_matches]
        
        # Extract departments/jurusan
        dept_matches = re.findall(
            r'(fsktm|computer science|information technology|software engineering|'
            r'data science|electrical|civil|mechanical|fakulti|faculty|department|'
            r'kursus|course)', command_lower
        )
        if dept_matches:
            entities['departments'] = list(set(dept_matches))
        
        # Extract date patterns
        date_matches = re.findall(r'(\d{4}-\d{2}-\d{2})|(\d{2}/\d{2}/\d{4})', command)
        if date_matches:
            entities['dates'] = [match[0] or match[1] for match in date_matches if any(match)]
        
        # Extract CGPA values
        cgpa_matches = re.findall(r'cgpa\s*([<>]?\s*[\d.]+)', command_lower)
        if cgpa_matches:
            entities['cgpa_values'] = []
            for val in cgpa_matches:
                clean_val = val.strip()
                if clean_val.startswith('>') or clean_val.startswith('>'):
                    entities['min_cgpa'] = float(clean_val[1:])
                elif clean_val.startswith('<') or clean_val.startswith('<'):
                    entities['max_cgpa'] = float(clean_val[1:])
                else:
                    entities['exact_cgpa'] = float(clean_val)
        
        # Extract specific entities based on intent type
        if intent_type == IntentType.EVENT_QUERY:
            # Extract event types or categories
            event_types = re.findall(
                r'(seminar|workshop|talk|ceramah|competition|pertandingan|'
                r'conference|konvensyen|celebration|majlis)', command_lower
            )
            if event_types:
                entities['event_types'] = list(set(event_types))
        
        elif intent_type == IntentType.STUDENT_QUERY:
            # Extract student year or level
            year_matches = re.findall(r'(year\s*(\d+)|tahun\s*(\d+)|level\s*(\d+))', command_lower)
            if year_matches:
                years = []
                for match in year_matches:
                    year_val = [val for val in match[1:] if val][0]  # Get the non-empty value
                    if year_val.isdigit():
                        years.append(int(year_val))
                if years:
                    entities['years'] = years
        
        elif intent_type == IntentType.ACHIEVEMENT_QUERY:
            # Extract achievement categories
            categories = re.findall(
                r'(academic|sports|arts|leadership|kepakaran|sukan|seni|'
                r'kepimpinan|co-curricular|kokurikulum)', command_lower
            )
            if categories:
                entities['categories'] = list(set(categories))
        
        # Add original command
        entities['original_command'] = command
        
        return entities
    
    def _needs_clarification(self, command: str, entities: Dict[str, Any], context: Optional[Dict[str, Any]]) -> bool:
        """Determine if intent needs clarification."""
        command_lower = command.lower()
        
        # Check for ambiguous references
        for pattern in self.clarification_keywords:
            if re.search(pattern, command_lower):
                return True
        
        # Check for vague terms without context
        vague_indicators = [
            'those', 'them', 'it', 'that', 'itu', 'mereka', 'ia', 'itu',
            'some', 'certain', 'several', 'beberapa', 'tertentu', 'pelbagai'
        ]
        
        for indicator in vague_indicators:
            if indicator in command_lower and not context:
                return True
        
        # If no entities were extracted and it's a complex query, it may need clarification
        if not entities and any(word in command_lower for word in ['find', 'show', 'list', 'cari', 'tunjuk', 'senarai']):
            return True
        
        return False
    
    def _get_required_context(self, intent_type: IntentType, entities: Dict[str, Any]) -> List[str]:
        """Get context required for specific intent."""
        required = []
        
        if intent_type in [IntentType.STUDENT_QUERY, IntentType.ANALYTICS_QUERY]:
            required.extend(['department', 'time_period', 'filter_criteria'])
        
        if intent_type == IntentType.EVENT_QUERY:
            required.extend(['date_range', 'event_type', 'location'])
        
        if intent_type == IntentType.COMMUNICATION_TASK:
            required.extend(['target_audience', 'message_content', 'delivery_method'])
        
        if intent_type == IntentType.REPORT_GENERATION:
            required.extend(['report_type', 'time_period', 'format'])
        
        if intent_type == IntentType.DATA_MANIPULATION:
            required.extend(['target_records', 'changes_to_make', 'validation_rules'])
        
        # Remove duplicates
        return list(set(required))


# Example usage:
if __name__ == "__main__":
    classifier = IntentClassifier()
    
    # Test commands
    test_commands = [
        "Show me the top 5 students in Computer Science",
        "List all upcoming events",
        "Find students with CGPA above 3.5 and email them",
        "Generate a report on achievement statistics",
        "Update student status to active",
        "How many users are in the system?",
        "Show me top students and then their achievements",
        "Send notification about the event to all participants"
    ]
    
    for cmd in test_commands:
        result = classifier.classify_intent(cmd)
        print(f"\nCommand: {cmd}")
        print(f"Intent: {result.intent_type.value}")
        print(f"Confidence: {result.confidence:.2f}")
        print(f"Entities: {result.detected_entities}")
        print(f"Clarification needed: {result.clarification_needed}")
        print(f"Required context: {result.required_context}")
        print(f"Alternatives: {[(i.value, c) for i, c in result.alternative_intents]}")