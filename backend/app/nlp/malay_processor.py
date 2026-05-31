"""Malay NLP Processor.

Specialized NLP processing for Bahasa Melayu including:
- Malay stopwords
- Malay stemming (basic)
- Malay-specific entity recognition
- Code-switching detection (Malay-English)
"""

from typing import List, Dict, Any, Optional, Tuple, Set
import re
import logging

logger = logging.getLogger(__name__)


class MalayNLPProcessor:
    """NLP processor optimized for Bahasa Melayu."""
    
    def __init__(self):
        self._setup_resources()
    
    def _setup_resources(self):
        """Setup Malay language resources."""
        
        # Common Malay stopwords
        self.stopwords: Set[str] = {
            # Common function words
            'yang', 'dan', 'di', 'ke', 'dari', 'untuk', 'dengan', 'pada',
            'adalah', 'ini', 'itu', 'akan', 'telah', 'sudah', 'boleh',
            'dapat', 'ada', 'atau', 'jika', 'bila', 'kita', 'kami',
            'mereka', 'anda', 'saya', 'dia', 'beliau', 'ia',
            'oleh', 'dalam', 'lagi', 'juga', 'sahaja', 'hanya',
            'antara', 'lebih', 'sangat', 'amat', 'paling', 'sekali',
            'seperti', 'sebagai', 'apabila', 'kerana', 'supaya',
            'tetapi', 'namun', 'walau', 'walaupun', 'meskipun',
            'sebelum', 'selepas', 'semasa', 'ketika', 'sejak',
            'tersebut', 'berkenaan', 'mengenai', 'tentang',
            'setiap', 'semua', 'segala', 'pelbagai', 'berbagai',
            'satu', 'dua', 'tiga', 'empat', 'lima',
            
            # English stopwords commonly mixed
            'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
            'of', 'in', 'to', 'for', 'on', 'at', 'by', 'as', 'with',
            'this', 'that', 'these', 'those', 'it', 'its',
        }
        
        # Common Malay prefixes and suffixes for stemming
        self.prefixes = ['me', 'mem', 'men', 'meng', 'meny', 'pe', 'pem', 'pen', 
                        'peng', 'peny', 'ber', 'be', 'ter', 'di', 'ke', 'se']
        self.suffixes = ['kan', 'an', 'i', 'nya', 'lah', 'kah', 'ku', 'mu']
        
        # Malay question words
        self.question_words = {
            'apa': 'what',
            'siapa': 'who',
            'bila': 'when',
            'bilakah': 'when',
            'mana': 'where/which',
            'di mana': 'where',
            'ke mana': 'where to',
            'dari mana': 'where from',
            'kenapa': 'why',
            'mengapa': 'why',
            'bagaimana': 'how',
            'macam mana': 'how',
            'berapa': 'how many/much',
            'yang mana': 'which one',
        }
        
        # Intent keywords in Malay
        self.intent_keywords = {
            'query': ['tunjuk', 'senarai', 'cari', 'dapatkan', 'beri', 'papar', 'lihat'],
            'count': ['berapa', 'jumlah', 'bilangan', 'banyak'],
            'analyze': ['analisis', 'kaji', 'teliti', 'tinjau', 'bandingkan'],
            'create': ['buat', 'cipta', 'hasilkan', 'jana', 'tambah'],
            'update': ['kemaskini', 'ubah', 'tukar', 'edit'],
            'delete': ['padam', 'buang', 'hapus', 'keluarkan'],
            'help': ['tolong', 'bantu', 'bantuan', 'cara', 'macam mana'],
        }
    
    def tokenize(self, text: str) -> List[str]:
        """
        Tokenize Malay text.
        
        Args:
            text: Input text
            
        Returns:
            List of tokens
        """
        # Handle common contractions
        text = text.replace("'", " ")
        
        # Split on whitespace and punctuation
        tokens = re.findall(r'\b\w+\b', text.lower())
        
        return tokens
    
    def remove_stopwords(self, tokens: List[str]) -> List[str]:
        """
        Remove stopwords from tokens.
        
        Args:
            tokens: List of tokens
            
        Returns:
            Filtered tokens
        """
        return [t for t in tokens if t.lower() not in self.stopwords]
    
    def stem(self, word: str) -> str:
        """
        Basic Malay stemming (rule-based).
        
        Args:
            word: Word to stem
            
        Returns:
            Stemmed word
        """
        original = word.lower()
        
        # Remove suffixes first
        for suffix in sorted(self.suffixes, key=len, reverse=True):
            if original.endswith(suffix) and len(original) > len(suffix) + 2:
                original = original[:-len(suffix)]
                break
        
        # Remove prefixes
        for prefix in sorted(self.prefixes, key=len, reverse=True):
            if original.startswith(prefix) and len(original) > len(prefix) + 2:
                original = original[len(prefix):]
                break
        
        return original
    
    def stem_tokens(self, tokens: List[str]) -> List[str]:
        """
        Stem a list of tokens.
        
        Args:
            tokens: List of tokens
            
        Returns:
            Stemmed tokens
        """
        return [self.stem(t) for t in tokens]
    
    def detect_language(self, text: str) -> Dict[str, Any]:
        """
        Detect language of text (Malay, English, or mixed).
        
        Args:
            text: Input text
            
        Returns:
            Language detection result
        """
        tokens = self.tokenize(text)
        
        malay_indicators = 0
        english_indicators = 0
        
        # Malay-specific words
        malay_words = {'yang', 'dan', 'atau', 'untuk', 'dengan', 'adalah', 
                      'dalam', 'ada', 'ini', 'itu', 'saya', 'anda', 'mereka',
                      'pelajar', 'sistem', 'maklumat', 'jabatan'}
        
        # English-specific words
        english_words = {'the', 'and', 'or', 'for', 'with', 'is', 'are',
                        'in', 'have', 'this', 'that', 'student', 'system',
                        'information', 'department'}
        
        for token in tokens:
            if token in malay_words:
                malay_indicators += 1
            if token in english_words:
                english_indicators += 1
        
        total = malay_indicators + english_indicators
        
        if total == 0:
            return {"language": "unknown", "confidence": 0.0, "is_mixed": False}
        
        malay_ratio = malay_indicators / total
        
        if malay_ratio > 0.7:
            language = "malay"
        elif malay_ratio < 0.3:
            language = "english"
        else:
            language = "mixed"
        
        return {
            "language": language,
            "confidence": max(malay_ratio, 1 - malay_ratio),
            "is_mixed": 0.3 <= malay_ratio <= 0.7,
            "malay_ratio": malay_ratio,
            "english_ratio": 1 - malay_ratio
        }
    
    def extract_intent(self, text: str) -> Dict[str, Any]:
        """
        Extract user intent from Malay text.
        
        Args:
            text: Input text
            
        Returns:
            Intent extraction result
        """
        text_lower = text.lower()
        
        detected_intents = []
        
        for intent, keywords in self.intent_keywords.items():
            for keyword in keywords:
                if keyword in text_lower:
                    detected_intents.append({
                        "intent": intent,
                        "keyword": keyword,
                        "confidence": 0.8
                    })
                    break
        
        # Check for questions
        is_question = False
        question_type = None
        
        for q_word, q_meaning in self.question_words.items():
            if q_word in text_lower:
                is_question = True
                question_type = q_meaning
                break
        
        if text.strip().endswith('?'):
            is_question = True
        
        primary_intent = detected_intents[0]["intent"] if detected_intents else "unknown"
        
        return {
            "primary_intent": primary_intent,
            "all_intents": detected_intents,
            "is_question": is_question,
            "question_type": question_type,
            "confidence": detected_intents[0]["confidence"] if detected_intents else 0.0
        }
    
    def normalize(self, text: str) -> str:
        """
        Normalize Malay text (fix common variations).
        
        Args:
            text: Input text
            
        Returns:
            Normalized text
        """
        # Common spelling variations
        replacements = {
            r'\bmcm\b': 'macam',
            r'\bmcmana\b': 'macam mana',
            r'\bxnak\b': 'tidak mahu',
            r'\bx\b': 'tidak',
            r'\btak\b': 'tidak',
            r'\btp\b': 'tetapi',
            r'\bdgn\b': 'dengan',
            r'\byg\b': 'yang',
            r'\bsbb\b': 'sebab',
            r'\bklu\b': 'kalau',
            r'\bkalo\b': 'kalau',
            r'\bnk\b': 'nak',
            r'\bnak\b': 'hendak',
            r'\bapa2\b': 'apa-apa',
            r'\bsape\b': 'siapa',
            r'\bbrape\b': 'berapa',
            r'\bwht\b': 'what',
            r'\bu\b': 'you',
            r'\br\b': 'are',
        }
        
        result = text
        for pattern, replacement in replacements.items():
            result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)
        
        return result
    
    def extract_entities_malay(self, text: str) -> Dict[str, List[str]]:
        """
        Extract Malay-specific entities.
        
        Args:
            text: Input text
            
        Returns:
            Dict of entity types and values
        """
        entities = {
            "PERSON": [],
            "ORGANIZATION": [],
            "LOCATION": [],
            "ACADEMIC": [],
        }
        
        # Person names (bin/binti pattern)
        name_pattern = r'(\w+(?:\s+\w+)*)\s+(bin|binti)\s+(\w+(?:\s+\w+)*)'
        for match in re.finditer(name_pattern, text, re.IGNORECASE):
            entities["PERSON"].append(match.group(0))
        
        # Common Malaysian organizations
        org_patterns = [
            r'\bUTHM\b', r'\bUSM\b', r'\bUTM\b', r'\bUUM\b', r'\bUKM\b',
            r'\bUniversiti\s+\w+(?:\s+\w+)*',
            r'\bFSKTM\b', r'\bFKAAB\b', r'\bFKEE\b',
        ]
        for pattern in org_patterns:
            for match in re.finditer(pattern, text, re.IGNORECASE):
                entities["ORGANIZATION"].append(match.group(0))
        
        # Academic terms
        academic_patterns = [
            r'\bCGPA\s*:?\s*\d+\.?\d*',
            r'\b[Ss]emester\s*\d+',
            r'\b[Tt]ahun\s*\d+',
        ]
        for pattern in academic_patterns:
            for match in re.finditer(pattern, text):
                entities["ACADEMIC"].append(match.group(0))
        
        # Remove empty categories
        return {k: list(set(v)) for k, v in entities.items() if v}
    
    def get_keywords(self, text: str, top_n: int = 10) -> List[Tuple[str, int]]:
        """
        Extract keywords from Malay text.
        
        Args:
            text: Input text
            top_n: Number of keywords to return
            
        Returns:
            List of (keyword, frequency) tuples
        """
        from collections import Counter
        
        # Tokenize and clean
        tokens = self.tokenize(text)
        tokens = self.remove_stopwords(tokens)
        
        # Filter short tokens
        tokens = [t for t in tokens if len(t) > 2]
        
        # Count frequencies
        word_counts = Counter(tokens)
        
        return word_counts.most_common(top_n)


# Singleton instance
_malay_processor = None


def get_malay_processor() -> MalayNLPProcessor:
    """Get singleton Malay NLP processor instance."""
    global _malay_processor
    if _malay_processor is None:
        _malay_processor = MalayNLPProcessor()
    return _malay_processor
