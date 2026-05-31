"""
ML Predictor

Gemini API integration for student risk prediction and analysis.
Uses Google's generative AI model for intelligent risk assessment.
"""

import json
import logging
from typing import Dict, Any, Optional
import google.generativeai as genai
from .config import MLConfig
from .data_processor import DataProcessor
from .feature_engineer import FeatureEngineer
from .cache_manager import CacheManager
from app.core.key_manager import get_gemini_key, key_manager

logger = logging.getLogger(__name__)


class MLPredictor:
    """
    Gemini API-based ML predictor

    Uses cloud-based LLM for intelligent student risk prediction
    without requiring local model training.

    Example:
        predictor = MLPredictor()
        prediction = await predictor.predict_student_risk(student_data)
    """

    def __init__(self, cache_manager: Optional[CacheManager] = None):
        """
        Initialize predictor

        Args:
            cache_manager: Optional cache manager for caching predictions
        """
        self.config = MLConfig
        self.cache = cache_manager or CacheManager()
        self.data_processor = DataProcessor()
        self.feature_engineer = FeatureEngineer()

        # Initialize Gemini API with key rotation
        self._init_api_key = get_gemini_key()
        if not self._init_api_key:
            logger.error("GEMINI_API_KEY not configured!")
        else:
            genai.configure(api_key=self._init_api_key)
            self.model = genai.GenerativeModel(self.config.GEMINI_MODEL)
            logger.info(f"Gemini model initialized: {self.config.GEMINI_MODEL}")
            logger.info(f"🔑 Using key rotation with {key_manager.key_count} key(s)")

    async def predict_student_risk(self, student_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Predict student risk using Gemini API

        Args:
            student_data: Student data from database

        Returns:
            Risk prediction with factors, recommendations, confidence
        """
        student_id = student_data.get("id", "unknown")

        # Check cache first
        cached = self.cache.get(f"prediction_{student_id}")
        if cached:
            logger.info(f"Cache hit for student {student_id}")
            return cached

        try:
            # Extract features from raw data
            features = self.data_processor.extract_student_features(student_data)
            logger.debug(f"Extracted features for {student_id}")

            # Calculate local risk score
            risk_score = self.feature_engineer.calculate_risk_score(features)
            logger.debug(f"Calculated risk score: {risk_score:.2f}")

            # Get local analysis
            risk_factors = self.feature_engineer.get_risk_factors(features)
            strengths = self.feature_engineer.get_strengths(features)
            recommendations = self.feature_engineer.get_recommendations(
                features, risk_factors
            )

            # Get Gemini analysis for validation and enhancement
            gemini_analysis = None
            try:
                gemini_analysis = await self._get_gemini_analysis(features)
                logger.debug(f"Got Gemini analysis for {student_id}")
            except Exception as e:
                logger.warning(f"Gemini analysis failed: {e}. Using local analysis.")

            # Combine analyses
            final_prediction = self.feature_engineer.generate_summary(
                student_id=student_id,
                features=features,
                risk_score=risk_score,
                risk_factors=risk_factors,
                strengths=strengths,
                recommendations=recommendations,
            )

            # Add Gemini insights if available
            if gemini_analysis:
                final_prediction["gemini_insights"] = gemini_analysis

            # Cache the prediction
            self.cache.set(f"prediction_{student_id}", final_prediction)

            logger.info(
                f"Risk prediction for {student_id}: {final_prediction['risk_level']} "
                f"({final_prediction['risk_score']:.1%})"
            )
            return final_prediction

        except Exception as e:
            logger.error(f"Error predicting risk for {student_id}: {e}")
            raise

    async def _get_gemini_analysis(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Get analysis from Gemini API

        Args:
            features: Processed student features

        Returns:
            Gemini analysis with enhanced insights
        """
        try:
            # Format features for Gemini
            student_profile = self.data_processor.format_for_gemini(features)

            # Create prompt
            prompt = self.config.GEMINI_PROMPT_TEMPLATE.format(
                student_data=student_profile
            )

            # Call Gemini API with rotated key
            rotated_key = get_gemini_key()
            if rotated_key:
                genai.configure(api_key=rotated_key)
            logger.debug(f"Calling Gemini API with rotated key...")
            response = self.model.generate_content(
                prompt,
                generation_config={
                    "temperature": self.config.GEMINI_TEMPERATURE,
                    "max_output_tokens": self.config.GEMINI_MAX_TOKENS,
                },
            )

            # Parse response
            response_text = response.text.strip()
            logger.debug(f"Gemini response: {response_text[:200]}...")

            # Try to extract JSON from response
            try:
                # Handle case where response includes code block markers
                if "```json" in response_text:
                    json_str = response_text.split("```json")[1].split("```")[0].strip()
                elif "```" in response_text:
                    json_str = response_text.split("```")[1].split("```")[0].strip()
                else:
                    json_str = response_text

                analysis = json.loads(json_str)
                logger.debug("Successfully parsed Gemini JSON response")
                return analysis

            except json.JSONDecodeError as e:
                logger.warning(f"Failed to parse Gemini JSON: {e}")
                logger.debug(f"Response text: {response_text}")
                return {
                    "error": "Could not parse Gemini response",
                    "raw_response": response_text,
                }

        except Exception as e:
            logger.error(f"Gemini API error: {e}")
            raise

    async def batch_predict(
        self, students_data: list[Dict[str, Any]]
    ) -> list[Dict[str, Any]]:
        """
        Predict risk for multiple students

        Args:
            students_data: List of student data dictionaries

        Returns:
            List of predictions
        """
        predictions = []
        batch_size = self.config.BATCH_PROCESS_SIZE

        logger.info(f"Batch predicting for {len(students_data)} students")

        for i, student in enumerate(students_data):
            try:
                prediction = await self.predict_student_risk(student)
                predictions.append(prediction)

                # Log progress
                if (i + 1) % batch_size == 0:
                    logger.info(f"Processed {i + 1}/{len(students_data)} students")

            except Exception as e:
                logger.error(f"Error predicting for student {i}: {e}")
                continue

        logger.info(f"Batch prediction complete: {len(predictions)}/{len(students_data)}")
        return predictions

    def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        return self.cache.get_stats()

    def invalidate_cache(self, student_id: Optional[str] = None) -> None:
        """
        Invalidate cache

        Args:
            student_id: Specific student to invalidate, or None for all
        """
        if student_id:
            self.cache.invalidate(f"prediction_{student_id}")
            logger.info(f"Cache invalidated for student {student_id}")
        else:
            self.cache.invalidate_all()
            logger.info("Cache invalidated for all predictions")

    def health_check(self) -> Dict[str, Any]:
        """Check ML system health"""
        try:
            api_key_configured = bool(self.config.GEMINI_API_KEY)
            cache_stats = self.get_cache_stats()

            health = {
                "status": "healthy" if api_key_configured else "degraded",
                "gemini_api_configured": api_key_configured,
                "cache_status": cache_stats,
                "model": self.config.GEMINI_MODEL,
            }

            return health

        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e),
            }
