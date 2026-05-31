"""Core NLP Processor with spaCy.

Provides Named Entity Recognition, POS Tagging, and text analysis.
"""

from typing import List, Dict, Any, Optional, Tuple
import logging
import re

logger = logging.getLogger(__name__)

# Lazy loading for spaCy to avoid startup delays
_nlp_model = None
_nlp_available = None


def _load_spacy():
    """Lazy load spaCy model."""
    global _nlp_model, _nlp_available
    
    if _nlp_available is not None:
        return _nlp_model
    
    try:
        import spacy
        
        # Try to load English model (multilingual)
        try:
            _nlp_model = spacy.load("en_core_web_sm")
            logger.info("✅ spaCy model 'en_core_web_sm' loaded")
        except OSError:
            # Model not installed, download it
            logger.info("📥 Downloading spaCy model...")
            import subprocess
            subprocess.run(["python", "-m", "spacy", "download", "en_core_web_sm"], check=True)
            _nlp_model = spacy.load("en_core_web_sm")
            logger.info("✅ spaCy model downloaded and loaded")
        
        _nlp_available = True
        return _nlp_model
        
    except ImportError:
        logger.warning("⚠️ spaCy not installed. NER features disabled.")
        _nlp_available = False
        return None
    except Exception as e:
        logger.error(f"❌ Error loading spaCy: {e}")
        _nlp_available = False
        return None


class NLPProcessor:
    """Core NLP processor using spaCy."""
    
    def __init__(self):
        self.nlp = _load_spacy()
        self._custom_entities = self._load_custom_entities()
    
    def _load_custom_entities(self) -> Dict[str, List[str]]:
        """Load custom entity patterns for Malaysian context."""
        return {
            "DEPARTMENT": [
                "Computer Science", "Sains Komputer", "FSKTM",
                "Civil Engineering", "Kejuruteraan Awam", "FKAAB",
                "Electrical Engineering", "Kejuruteraan Elektrik", "FKEE",
                "Mechanical Engineering", "Kejuruteraan Mekanikal", "FKMP",
                "Data Science", "Information Technology", "IT",
                "Computer Network", "Computer Security", "Software Engineering"
            ],
            "FACULTY": [
                "FSKTM", "FKAAB", "FKEE", "FKMP", "FPTP", "FPTV", "FAST", "FKPM",
                "Fakulti Sains Komputer", "Fakulti Kejuruteraan Awam",
                "Fakulti Kejuruteraan Elektrik", "Fakulti Kejuruteraan Mekanikal"
            ],
            "ACADEMIC_TERM": [
                "semester", "tahun", "year", "term", "sesi",
                "semester 1", "semester 2", "sem 1", "sem 2"
            ],
            "GRADE_TERM": [
                "CGPA", "GPA", "cgpa", "gpa", "purata", "pointer",
                "Dean's List", "first class", "second class"
            ],
            "MALAY_TITLE": [
                "bin", "binti", "Encik", "Cik", "Puan", "Dr", "Prof"
            ]
        }
    
    def extract_entities(self, text: str) -> Dict[str, List[Dict[str, Any]]]:
        """
        Extract named entities from text.
        
        Args:
            text: Input text
            
        Returns:
            Dict with entity types and their occurrences
        """
        entities = {
            "PERSON": [],
            "ORG": [],
            "GPE": [],  # Geopolitical entities (locations)
            "DATE": [],
            "CARDINAL": [],  # Numbers
            "DEPARTMENT": [],
            "FACULTY": [],
            "GRADE_TERM": [],
            "CUSTOM": []
        }
        
        # Extract custom entities first
        for entity_type, patterns in self._custom_entities.items():
            for pattern in patterns:
                if pattern.lower() in text.lower():
                    # Find exact position
                    start = text.lower().find(pattern.lower())
                    if start != -1:
                        entities[entity_type if entity_type in entities else "CUSTOM"].append({
                            "text": text[start:start + len(pattern)],
                            "label": entity_type,
                            "start": start,
                            "end": start + len(pattern)
                        })
        
        # Use spaCy for standard NER if available
        if self.nlp:
            doc = self.nlp(text)
            for ent in doc.ents:
                if ent.label_ in entities:
                    entities[ent.label_].append({
                        "text": ent.text,
                        "label": ent.label_,
                        "start": ent.start_char,
                        "end": ent.end_char
                    })
        
        # Remove empty categories
        return {k: v for k, v in entities.items() if v}
    
    def extract_keywords(self, text: str, top_n: int = 10) -> List[Tuple[str, float]]:
        """
        Extract keywords from text using TF-IDF-like scoring.
        
        Args:
            text: Input text
            top_n: Number of keywords to return
            
        Returns:
            List of (keyword, score) tuples
        """
        if not self.nlp:
            # Fallback: simple word frequency
            words = re.findall(r'\b\w+\b', text.lower())
            stopwords = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
                        'dan', 'yang', 'di', 'ke', 'dari', 'untuk', 'dengan', 'ini', 'itu',
                        'of', 'in', 'to', 'for', 'on', 'at', 'by', 'as'}
            words = [w for w in words if w not in stopwords and len(w) > 2]
            
            from collections import Counter
            word_counts = Counter(words)
            total = sum(word_counts.values())
            return [(word, count/total) for word, count in word_counts.most_common(top_n)]
        
        # Use spaCy for better keyword extraction
        doc = self.nlp(text)
        
        # Extract nouns and proper nouns
        keywords = []
        for token in doc:
            if token.pos_ in ['NOUN', 'PROPN'] and not token.is_stop and len(token.text) > 2:
                keywords.append(token.lemma_.lower())
        
        from collections import Counter
        word_counts = Counter(keywords)
        total = sum(word_counts.values()) or 1
        
        return [(word, count/total) for word, count in word_counts.most_common(top_n)]
    
    def analyze_sentiment(self, text: str) -> Dict[str, Any]:
        """
        Analyze sentiment of text (basic implementation).
        
        Args:
            text: Input text
            
        Returns:
            Dict with sentiment analysis results
        """
        # Positive and negative word lists (BM + EN)
        positive_words = [
            'good', 'great', 'excellent', 'amazing', 'wonderful', 'best', 'fantastic',
            'baik', 'bagus', 'cemerlang', 'hebat', 'terbaik', 'menarik', 'cantik',
            'success', 'berjaya', 'tahniah', 'congratulations', 'awesome'
        ]
        
        negative_words = [
            'bad', 'poor', 'terrible', 'awful', 'worst', 'horrible', 'fail',
            'buruk', 'teruk', 'gagal', 'lemah', 'kurang', 'masalah', 'problem',
            'error', 'failed', 'unsuccessful'
        ]
        
        text_lower = text.lower()
        
        pos_count = sum(1 for word in positive_words if word in text_lower)
        neg_count = sum(1 for word in negative_words if word in text_lower)
        
        total = pos_count + neg_count
        if total == 0:
            sentiment = "neutral"
            score = 0.0
        elif pos_count > neg_count:
            sentiment = "positive"
            score = pos_count / total
        else:
            sentiment = "negative"
            score = -neg_count / total
        
        return {
            "sentiment": sentiment,
            "score": score,
            "positive_count": pos_count,
            "negative_count": neg_count,
            "confidence": abs(score) if total > 0 else 0.5
        }
    
    def tokenize(self, text: str) -> List[Dict[str, Any]]:
        """
        Tokenize text with POS tags.
        
        Args:
            text: Input text
            
        Returns:
            List of token dictionaries
        """
        if not self.nlp:
            # Fallback: simple tokenization
            words = re.findall(r'\b\w+\b', text)
            return [{"text": w, "pos": "UNKNOWN", "lemma": w.lower()} for w in words]
        
        doc = self.nlp(text)
        return [
            {
                "text": token.text,
                "pos": token.pos_,
                "tag": token.tag_,
                "lemma": token.lemma_,
                "is_stop": token.is_stop,
                "is_punct": token.is_punct
            }
            for token in doc
        ]
    
    def similarity(self, text1: str, text2: str) -> float:
        """
        Calculate similarity between two texts.
        
        Args:
            text1: First text
            text2: Second text
            
        Returns:
            Similarity score (0-1)
        """
        if not self.nlp:
            # Fallback: Jaccard similarity
            words1 = set(re.findall(r'\b\w+\b', text1.lower()))
            words2 = set(re.findall(r'\b\w+\b', text2.lower()))
            intersection = words1 & words2
            union = words1 | words2
            return len(intersection) / len(union) if union else 0.0
        
        doc1 = self.nlp(text1)
        doc2 = self.nlp(text2)
        return doc1.similarity(doc2)
    
    def is_available(self) -> bool:
        """Check if NLP processor is available."""
        return self.nlp is not None


# Singleton instance
_processor_instance = None


def get_nlp_processor() -> NLPProcessor:
    """Get singleton NLP processor instance."""
    global _processor_instance
    if _processor_instance is None:
        _processor_instance = NLPProcessor()
    return _processor_instance
