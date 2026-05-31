"""
ML Configuration

Centralized settings for ML analytics including Gemini API configuration,
model parameters, and risk assessment thresholds.
"""

import os
import logging
from typing import Optional
from datetime import timedelta

from app.core.key_manager import key_manager, get_gemini_key

logger = logging.getLogger(__name__)



def _get_gemini_api_key() -> str:
    """Get Gemini API key using rotation from key_manager."""
    key = get_gemini_key()
    return key if key else ""



class MLConfig:
    """ML module configuration"""

    # Gemini API Configuration
    GEMINI_API_KEY: str = _get_gemini_api_key()
    GEMINI_MODEL: str = "gemini-2.5-flash"
    GEMINI_TEMPERATURE: float = 0.7
    GEMINI_MAX_TOKENS: int = 500

    # Cache Configuration
    CACHE_TTL: timedelta = timedelta(hours=24)  # Cache predictions for 24 hours
    CACHE_MAX_SIZE: int = 1000  # Maximum cached items

    # Rate Limiting (for Gemini free tier: 50 requests/day)
    REQUESTS_PER_DAY: int = 50
    BATCH_PROCESS_SIZE: int = 10  # Process students in batches

    # Risk Assessment Thresholds
    RISK_THRESHOLDS = {
        "low": 0.30,  # < 30% = Low risk
        "medium": 0.60,  # 30-60% = Medium risk
        "high": 1.0,  # > 60% = High risk
    }

    # Feature Weights (for risk calculation)
    # Simplified: Only CGPA and Kokurikulum matter
    FEATURE_WEIGHTS = {
        "academic_score": 0.50,  # CGPA weight (50%)
        "kokurikulum_score": 0.50,  # Kokurikulum weight (50%)
    }

    # Performance Score Thresholds
    PERFORMANCE_THRESHOLDS = {
        "excellent": 0.85,  # > 85%
        "good": 0.70,  # 70-85%
        "satisfactory": 0.50,  # 50-70%
        "needs_improvement": 0.0,  # < 50%
    }

    # Engagement Score Calculation
    ENGAGEMENT_SETTINGS = {
        "min_events_good": 3,  # Good if attended >= 3 events/month
        "min_events_fair": 1,  # Fair if attended >= 1 event/month
        "activity_weight": 0.6,
        "event_weight": 0.4,
    }

    # Gemini Prompt Template
    GEMINI_PROMPT_TEMPLATE = """
You are an educational data analyst for a Malaysian campus talent profiling system.
Analyze this student data and provide a risk assessment.

Student Data:
{student_data}

Provide a JSON response with:
1. risk_score (0-1): Overall risk of student needing intervention
2. risk_factors: List of top 3 risk factors
3. strengths: List of 2 key strengths
4. recommendations: 2-3 specific actions to support this student
5. confidence (0-1): How confident is this prediction

Keep recommendations specific, actionable, and supportive. Consider Malaysian campus context.
Focus on: Academic progress, engagement levels, social connections, behavioral patterns.

Respond ONLY with valid JSON, no additional text.
"""

    # Logging Configuration
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    LOG_FILE = "ml_analytics.log"

    @classmethod
    def validate(cls) -> bool:
        """Validate configuration"""
        if not cls.GEMINI_API_KEY:
            logger.warning("⚠️  WARNING: GEMINI_API_KEY not set in environment")
            return False
        return True

    @classmethod
    def get_risk_level(cls, risk_score: float) -> str:
        """Convert risk score (0-1) to risk level"""
        if risk_score < cls.RISK_THRESHOLDS["low"]:
            return "low"
        elif risk_score < cls.RISK_THRESHOLDS["medium"]:
            return "medium"
        else:
            return "high"

    @classmethod
    def get_risk_emoji(cls, risk_level: str) -> str:
        """Get emoji for risk level"""
        emoji_map = {
            "low": "🟢",
            "medium": "🟡",
            "high": "🔴",
        }
        return emoji_map.get(risk_level, "❓")
