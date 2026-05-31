"""Entity Extractor for Malaysian Academic Context.

Specialized entity extraction for Malaysian names, universities, and academic terms.
"""

from typing import List, Dict, Any, Optional, Tuple
import re
import logging

logger = logging.getLogger(__name__)


class EntityExtractor:
    """Extract entities specific to Malaysian academic context."""
    
    def __init__(self):
        self._setup_patterns()
    
    def _setup_patterns(self):
        """Setup regex patterns for entity extraction."""
        
        # Malaysian name patterns
        self.malay_male_patterns = [
            r'\b(Muhammad|Mohd|Ahmad|Mohamed|Mohammad|Abu|Wan|Nik)\s+\w+',
            r'\b\w+\s+bin\s+\w+',
            r'\b(Hafiz|Hakim|Haziq|Haris|Irfan|Izzat|Aiman|Aidil|Arif)\b',
        ]
        
        self.malay_female_patterns = [
            r'\b(Nur|Nurul|Siti|Noor|Noraini|Fatimah|Aisyah|Aini)\s+\w+',
            r'\b\w+\s+binti\s+\w+',
            r'\b(Aina|Alya|Amira|Athirah|Balqis|Izzah|Husna)\b',
        ]
        
        # Academic patterns
        self.cgpa_pattern = r'(?:CGPA|cgpa|GPA|gpa|pointer)\s*[:=]?\s*(\d+\.?\d*)'
        self.semester_pattern = r'(?:semester|sem)\s*(\d+)'
        self.year_pattern = r'(?:tahun|year)\s*(\d+)'
        self.matric_pattern = r'\b([A-Z]{2}\d{6})\b'  # e.g., AI200001
        
        # Department/Faculty patterns
        self.faculty_codes = {
            'FSKTM': 'Fakulti Sains Komputer dan Teknologi Maklumat',
            'FKAAB': 'Fakulti Kejuruteraan Awam dan Alam Bina',
            'FKEE': 'Fakulti Kejuruteraan Elektrik dan Elektronik',
            'FKMP': 'Fakulti Kejuruteraan Mekanikal dan Pembuatan',
            'FPTP': 'Fakulti Pengurusan Teknologi dan Perniagaan',
            'FPTV': 'Fakulti Pendidikan Teknikal dan Vokasional',
            'FAST': 'Fakulti Sains Gunaan dan Teknologi',
        }
    
    def extract_person_names(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract person names from text with gender inference.
        
        Args:
            text: Input text
            
        Returns:
            List of extracted names with metadata
        """
        names = []
        
        # Check for bin/binti pattern (most reliable)
        bin_pattern = r'(\w+(?:\s+\w+)*)\s+(bin|binti)\s+(\w+(?:\s+\w+)*)'
        for match in re.finditer(bin_pattern, text, re.IGNORECASE):
            full_name = match.group(0)
            given_name = match.group(1)
            connector = match.group(2).lower()
            parent_name = match.group(3)
            
            gender = "male" if connector == "bin" else "female"
            
            names.append({
                "full_name": full_name,
                "given_name": given_name,
                "parent_name": parent_name,
                "gender": gender,
                "confidence": 0.95,
                "pattern": "bin/binti"
            })
        
        # Check for common name prefixes
        for pattern in self.malay_male_patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                name = match.group(0)
                # Skip if already captured by bin/binti
                if not any(name in n["full_name"] for n in names):
                    names.append({
                        "full_name": name,
                        "gender": "male",
                        "confidence": 0.75,
                        "pattern": "male_prefix"
                    })
        
        for pattern in self.malay_female_patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                name = match.group(0)
                if not any(name in n["full_name"] for n in names):
                    names.append({
                        "full_name": name,
                        "gender": "female",
                        "confidence": 0.75,
                        "pattern": "female_prefix"
                    })
        
        return names
    
    def extract_academic_info(self, text: str) -> Dict[str, Any]:
        """
        Extract academic information from text.
        
        Args:
            text: Input text
            
        Returns:
            Dict with extracted academic info
        """
        info = {}
        
        # CGPA
        cgpa_match = re.search(self.cgpa_pattern, text, re.IGNORECASE)
        if cgpa_match:
            try:
                cgpa = float(cgpa_match.group(1))
                if 0 <= cgpa <= 4.0:
                    info["cgpa"] = cgpa
            except ValueError:
                pass
        
        # Semester
        sem_match = re.search(self.semester_pattern, text, re.IGNORECASE)
        if sem_match:
            info["semester"] = int(sem_match.group(1))
        
        # Year
        year_match = re.search(self.year_pattern, text, re.IGNORECASE)
        if year_match:
            info["year"] = int(year_match.group(1))
        
        # Matric number
        matric_match = re.search(self.matric_pattern, text)
        if matric_match:
            info["matric_number"] = matric_match.group(1)
        
        # Faculty
        for code, full_name in self.faculty_codes.items():
            if code in text.upper() or full_name.lower() in text.lower():
                info["faculty_code"] = code
                info["faculty_name"] = full_name
                break
        
        return info
    
    def extract_numbers(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract numbers with context from text.
        
        Args:
            text: Input text
            
        Returns:
            List of numbers with context
        """
        numbers = []
        
        # Find all numbers with surrounding context
        pattern = r'(\w+\s+)?(\d+\.?\d*)\s*(\w+)?'
        for match in re.finditer(pattern, text):
            before = match.group(1) or ""
            number = match.group(2)
            after = match.group(3) or ""
            
            # Try to determine number type
            context = (before + after).lower()
            
            number_type = "unknown"
            if "cgpa" in context or "gpa" in context or "pointer" in context:
                number_type = "cgpa"
            elif "student" in context or "pelajar" in context:
                number_type = "count"
            elif "semester" in context or "sem" in context:
                number_type = "semester"
            elif "year" in context or "tahun" in context:
                number_type = "year"
            elif "%" in context or "percent" in context or "peratus" in context:
                number_type = "percentage"
            
            try:
                value = float(number)
                numbers.append({
                    "value": value,
                    "text": number,
                    "type": number_type,
                    "context": match.group(0).strip()
                })
            except ValueError:
                pass
        
        return numbers
    
    def extract_dates(self, text: str) -> List[Dict[str, Any]]:
        """
        Extract dates from text.
        
        Args:
            text: Input text
            
        Returns:
            List of extracted dates
        """
        dates = []
        
        # Common date patterns
        patterns = [
            (r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})', 'dd/mm/yyyy'),
            (r'(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})', 'yyyy/mm/dd'),
            (r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})', 'dd Mon yyyy'),
        ]
        
        for pattern, format_type in patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                dates.append({
                    "text": match.group(0),
                    "format": format_type,
                    "start": match.start(),
                    "end": match.end()
                })
        
        return dates
    
    def analyze_gender_from_names(self, names: List[str]) -> Dict[str, Any]:
        """
        Analyze gender distribution from a list of names.
        
        Args:
            names: List of full names
            
        Returns:
            Gender distribution analysis
        """
        male_count = 0
        female_count = 0
        unknown_count = 0
        
        male_indicators = ['bin', 'muhammad', 'mohd', 'ahmad', 'mohamed', 'abu', 'wan']
        female_indicators = ['binti', 'nur', 'nurul', 'siti', 'noor', 'fatimah', 'aisyah']
        
        for name in names:
            name_lower = name.lower()
            
            if any(ind in name_lower for ind in male_indicators):
                male_count += 1
            elif any(ind in name_lower for ind in female_indicators):
                female_count += 1
            else:
                unknown_count += 1
        
        total = male_count + female_count + unknown_count
        
        return {
            "total": total,
            "male": {
                "count": male_count,
                "percentage": round(male_count / total * 100, 1) if total > 0 else 0
            },
            "female": {
                "count": female_count,
                "percentage": round(female_count / total * 100, 1) if total > 0 else 0
            },
            "unknown": {
                "count": unknown_count,
                "percentage": round(unknown_count / total * 100, 1) if total > 0 else 0
            },
            "method": "name_pattern_analysis"
        }
