"""Interactive Clarification System for Agentic AI."""

from __future__ import annotations
from typing import Dict, List, Any, Optional, Tuple
import re
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class ClarificationRequest:
    """Represents a request for clarification from the user."""
    needed_info: str
    question: str
    suggestion: str
    parameter_key: str  # The parameter that needs clarification


class ClarificationSystem:
    """System for asking clarifying questions to the user."""
    
    def __init__(self):
        self.clarification_templates = {
            'missing_department': {
                'question': "Awak tanya pasal pelajar, tapi tak specify jabatan. Awak nak tengok pelajar dari semua jabatan atau jabatan tertentu?",
                'suggestion': "Cuba tambah jabatan macam 'Sains Komputer' atau 'FSKTM' dalam query awak."
            },
            'missing_limit': {
                'question': "Awak nak list pelajar. Berapa orang awak nak tengok? (contoh: 5 orang, 10 orang pertama)",
                'suggestion': "Tambah nombor macam 'top 5' atau '10 orang pertama' dalam query awak."
            },
            'missing_cgpa_threshold': {
                'question': "Awak nak pelajar dengan CGPA tinggi. CGPA berapa awak nak? (contoh: atas 3.5, lebih dari 3.0)",
                'suggestion': "Tambah syarat CGPA macam 'CGPA atas 3.5' atau 'dengan CGPA lebih 3.0'."
            },
            'missing_date_range': {
                'question': "Awak tanya pasal acara. Awak nak tengok acara akan datang, acara lepas, atau acara dalam tempoh tertentu?",
                'suggestion': "Specify tarikh macam 'acara minggu ni' atau 'acara bulan Mac'."
            },
            'missing_target_audience': {
                'question': "Awak nak hantar mesej. Siapa yang patut terima - semua pelajar, pelajar tertentu, atau peserta acara?",
                'suggestion': "Specify target macam 'kepada semua pelajar Sains Komputer' atau 'kepada peserta acara'."
            },
            'vague_request': {
                'question': "Saya tak pasti apa yang awak perlukan. Boleh awak terangkan lagi?",
                'suggestion': "Bagi lebih spesifik tentang maklumat yang awak nak atau tindakan yang awak mahu saya buat."
            },
            'ambiguous_reference': {
                'question': "Awak sebut 'mereka' atau 'itu', tapi saya tak pasti awak rujuk siapa. Boleh awak terangkan?",
                'suggestion': "Bagi spesifik tentang siapa atau apa yang awak maksudkan."
            }
        }
        
        # Patterns that indicate missing information
        self.missing_info_patterns = {
            'department': [
                r'\b(students?|pelajar)\b',
                r'\b(top|best|highest|ranking|rank)\b'
            ],
            'limit': [
                r'\b(list|show|find|senarai|tunjuk|cari)\s+(all|all the|every|semua|kesemua)\b'
            ],
            'cgpa_threshold': [
                r'\b(high|good|excellent|cemerlang|baik|hebat)\s+cgpa\b',
                r'\b(above|over|lebih)\b'
            ],
            'date_range': [
                r'\b(events?|acara|aktiviti)\b'
            ],
            'target_audience': [
                r'\b(send|email|message|hantar|emel|mesej)\b'
            ]
        }

    def check_for_clarifications(self, command: str, entities: Dict[str, Any], intent: str) -> List[ClarificationRequest]:
        """Check if clarification is needed and return appropriate questions."""
        clarifications = []
        
        command_lower = command.lower()
        
        # Check for missing department in student queries
        if intent in ['student_query', 'STUDENT_QUERY'] and 'students' in command_lower:
            if not self._has_department_info(entities, command_lower):
                clarifications.append(
                    ClarificationRequest(
                        needed_info='department',
                        question=self.clarification_templates['missing_department']['question'],
                        suggestion=self.clarification_templates['missing_department']['suggestion'],
                        parameter_key='department'
                    )
                )
        
        # Check for missing limit in listing queries
        if any(keyword in command_lower for keyword in ['list', 'show', 'find', 'senarai', 'tunjuk', 'cari']):
            if not self._has_limit_info(entities, command_lower):
                clarifications.append(
                    ClarificationRequest(
                        needed_info='limit',
                        question=self.clarification_templates['missing_limit']['question'],
                        suggestion=self.clarification_templates['missing_limit']['suggestion'],
                        parameter_key='limit'
                    )
                )
        
        # Check for missing CGPA threshold
        if any(keyword in command_lower for keyword in ['high cgpa', 'good cgpa', 'excellent cgpa', 'cemerlang', 'baik']):
            if not self._has_cgpa_info(entities, command_lower):
                clarifications.append(
                    ClarificationRequest(
                        needed_info='cgpa_threshold',
                        question=self.clarification_templates['missing_cgpa_threshold']['question'],
                        suggestion=self.clarification_templates['missing_cgpa_threshold']['suggestion'],
                        parameter_key='min_cgpa'
                    )
                )
        
        # Check for missing date in event queries
        if any(keyword in command_lower for keyword in ['events', 'acara', 'aktiviti']):
            if not self._has_date_info(entities, command_lower):
                clarifications.append(
                    ClarificationRequest(
                        needed_info='date_range',
                        question=self.clarification_templates['missing_date_range']['question'],
                        suggestion=self.clarification_templates['missing_date_range']['suggestion'],
                        parameter_key='date_range'
                    )
                )
        
        # Check for ambiguous references
        if self._has_ambiguous_references(command_lower):
            clarifications.append(
                ClarificationRequest(
                    needed_info='specific_reference',
                    question=self.clarification_templates['ambiguous_reference']['question'],
                    suggestion=self.clarification_templates['ambiguous_reference']['suggestion'],
                    parameter_key='specific_reference'
                )
            )
        
        # Check for vague requests
        if self._has_vague_request(command_lower):
            clarifications.append(
                ClarificationRequest(
                    needed_info='specific_request',
                    question=self.clarification_templates['vague_request']['question'],
                    suggestion=self.clarification_templates['vague_request']['suggestion'],
                    parameter_key='specific_request'
                )
            )
        
        return clarifications
    
    def _has_department_info(self, entities: Dict[str, Any], command_lower: str) -> bool:
        """Check if department information is provided."""
        if 'departments' in entities and entities['departments']:
            return True
        # Check if department is mentioned in command
        dept_keywords = ['fsktm', 'computer science', 'information technology', 'software engineering', 
                        'data science', 'electrical', 'civil', 'mechanical', 'fakulti', 'faculty', 
                        'department', 'kursus', 'course']
        return any(keyword in command_lower for keyword in dept_keywords)
    
    def _has_limit_info(self, entities: Dict[str, Any], command_lower: str) -> bool:
        """Check if limit information is provided."""
        if 'numbers' in entities and entities['numbers']:
            return True
        # Check for keywords indicating limit
        limit_keywords = ['top', 'first', 'last', 'bottom', 'best', 'top\\s*\\d+', 'first\\s*\\d+']
        for keyword in limit_keywords:
            if re.search(keyword, command_lower):
                return True
        return False
    
    def _has_cgpa_info(self, entities: Dict[str, Any], command_lower: str) -> bool:
        """Check if CGPA information is provided."""
        if 'min_cgpa' in entities or 'max_cgpa' in entities or 'exact_cgpa' in entities:
            return True
        # Check for CGPA ranges in command
        cgpa_patterns = [r'cgpa\s*[<>]?\s*\d+\.?\d*', r'above\s+\d+\.?\d+', r'over\s+\d+\.?\d+']
        for pattern in cgpa_patterns:
            if re.search(pattern, command_lower):
                return True
        return False
    
    def _has_date_info(self, entities: Dict[str, Any], command_lower: str) -> bool:
        """Check if date information is provided."""
        if 'dates' in entities and entities['dates']:
            return True
        # Check for date-related keywords
        date_keywords = ['upcoming', 'this week', 'next week', 'this month', 'next month', 
                        'past', 'previous', 'coming', 'akan datang', 'minggu ini', 'bulan ini']
        return any(keyword in command_lower for keyword in date_keywords)
    
    def _has_ambiguous_references(self, command_lower: str) -> bool:
        """Check for ambiguous references in command."""
        ambiguous_patterns = [
            r'\b(them|they|those|it|that)\b',
            r'\b(they|their|its|those)\b'
        ]
        for pattern in ambiguous_patterns:
            # Only flag if not preceded by clear reference
            if re.search(pattern, command_lower):
                # Check if there's no clear antecedent in recent context
                # For now, just return True if pattern exists
                # In a full implementation, we'd check against conversation history
                return True
        return False
    
    def _has_vague_request(self, command_lower: str) -> bool:
        """Check for vague requests."""
        vague_patterns = [
            r'\b(some|certain|specific|particular|beberapa|tertentu|tertentu|tertentu)\b',
            r'\b(more|further|additional|more info|lanjut|tambahan|maklumat lanjut)\b',
            r'\b(etc|and so on|dan sebagainya|dan lain-lain)\b'
        ]
        for pattern in vague_patterns:
            if re.search(pattern, command_lower):
                return True
        return False
    
    def generate_clarification_response(self, command: str, entities: Dict[str, Any], intent: str) -> Optional[Dict[str, Any]]:
        """Generate a complete clarification response."""
        clarifications = self.check_for_clarifications(command, entities, intent)
        
        if not clarifications:
            return None
        
        # Create a comprehensive response
        questions = []
        suggestions = []
        
        for clarification in clarifications:
            questions.append(clarification.question)
            suggestions.append(clarification.suggestion)
        
        response = {
            "needs_clarification": True,
            "questions": questions,
            "suggestions": suggestions,
            "clarification_objects": clarifications,
            "original_command": command
        }
        
        logger.info(f"Generated clarification response for command: {command}")
        
        return response
    
    def process_user_response(self, user_response: str, pending_clarifications: List[ClarificationRequest]) -> Dict[str, Any]:
        """Process a user's response to a clarification request."""
        extracted_params = {}
        
        user_lower = user_response.lower()
        
        # Process each type of clarification
        for clarification in pending_clarifications:
            if clarification.parameter_key == 'department':
                # Try to extract department from user response
                dept_patterns = [
                    r'(fsktm|computer science|information technology|software engineering|data science)',
                    r'(electrical|civil|mechanical|fakulti|faculty|department|kursus|course)'
                ]
                for pattern in dept_patterns:
                    match = re.search(pattern, user_lower)
                    if match:
                        extracted_params['department'] = match.group(1)
                        break
            
            elif clarification.parameter_key == 'limit':
                # Try to extract number
                number_match = re.search(r'(\d+)', user_lower)
                if number_match:
                    extracted_params['limit'] = int(number_match.group(1))
            
            elif clarification.parameter_key == 'min_cgpa':
                # Try to extract CGPA value
                cgpa_match = re.search(r'(\d+\.?\d*)', user_lower)
                if cgpa_match:
                    extracted_params['min_cgpa'] = float(cgpa_match.group(1))
        
        return extracted_params


# Example usage:
if __name__ == "__main__":
    clarifier = ClarificationSystem()
    
    # Test commands that need clarification
    test_commands = [
        "Show me students",
        "Find students with high CGPA", 
        "List events",
        "Send message to them",
        "Show top students"
    ]
    
    for cmd in test_commands:
        print(f"\nCommand: {cmd}")
        result = clarifier.generate_clarification_response(cmd, {}, "STUDENT_QUERY")
        if result:
            print("Clarification needed:")
            for q in result["questions"]:
                print(f"  - {q}")
            for s in result["suggestions"]:
                print(f"  - Suggestion: {s}")
        else:
            print("No clarification needed")