"""
Feature Engineer

Calculate performance scores and risk indicators based on student features.
Uses weighted calculations to combine multiple metrics into risk predictions.
"""

from typing import Dict, List, Any
import logging
from .config import MLConfig

logger = logging.getLogger(__name__)


class FeatureEngineer:
    """
    Engineer features for ML prediction

    Combines processed features into meaningful indicators:
    - Performance scores
    - Risk factors
    - Strength areas
    - Trend analysis
    """

    @staticmethod
    def calculate_risk_score(features: Dict[str, Any]) -> float:
        """
        Calculate overall risk score (0-1)

        SIMPLIFIED: Based only on CGPA and Kokurikulum.
        Higher score = higher risk of needing intervention.

        Args:
            features: Processed features dictionary

        Returns:
            Risk score 0-1
        """
        weights = MLConfig.FEATURE_WEIGHTS

        # Get academic score (from CGPA, normalized 0-1)
        academic_score = features.get("academic_score", 0.0)
        cgpa = features.get("cgpa", 0.0)
        
        # If academic_score not calculated, use CGPA directly
        if academic_score == 0 and cgpa > 0:
            academic_score = cgpa  # Already normalized in data_processor
        
        # Get kokurikulum score (0-100 in DB, normalize to 0-1)
        koku_raw = features.get("kokurikulum_score", 0.0)
        koku_score = koku_raw / 100.0 if koku_raw > 1 else koku_raw
        
        # Convert scores to risk (inverse: high score = low risk)
        academic_risk = 1.0 - academic_score
        koku_risk = 1.0 - koku_score

        # Calculate weighted risk (50% academic, 50% kokurikulum)
        total_risk = (
            (academic_risk * weights.get("academic_score", 0.5))
            + (koku_risk * weights.get("kokurikulum_score", 0.5))
        )

        risk_score = min(max(total_risk, 0.0), 1.0)
        
        logger.info(
            f"Risk calc for {features.get('student_id')}: "
            f"CGPA={cgpa:.2f}, Koku={koku_raw:.0f}%, "
            f"Academic={academic_score:.2f}, KokuNorm={koku_score:.2f}, "
            f"Risk={risk_score:.2f}"
        )
        return risk_score

    @staticmethod
    def get_risk_factors(features: Dict[str, Any]) -> List[str]:
        """
        Identify risk factors based on CGPA and Kokurikulum only.

        Returns:
            List of risk factor descriptions
        """
        risk_factors = []
        
        # Get normalized values
        cgpa = features.get("cgpa", 0)
        koku = features.get("kokurikulum_score", 0)
        
        # Academic risk (CGPA < 2.5 out of 4.0 = 0.625 normalized)
        if cgpa < 0.625:
            cgpa_actual = cgpa * 4.0
            risk_factors.append(f"CGPA rendah ({cgpa_actual:.2f}/4.00)")
        
        # Kokurikulum risk (< 50%)
        if koku < 50:
            risk_factors.append(f"Skor kokurikulum rendah ({koku:.0f}%)")
        
        # Balance check
        if cgpa >= 0.75 and koku < 30:
            risk_factors.append("Terlalu fokus akademik, kurang kokurikulum")
        elif cgpa < 0.5 and koku >= 70:
            risk_factors.append("Terlalu fokus kokurikulum, perlu tingkatkan akademik")

        return risk_factors if risk_factors else ["Prestasi memuaskan"]

    @staticmethod
    def get_strengths(features: Dict[str, Any]) -> List[str]:
        """
        Identify student strengths

        Returns:
            List of strength descriptions
        """
        strengths = []

        # Academic strength
        cgpa = features.get("cgpa", 0)
        koku = features.get("kokurikulum_score", 0)
        
        if cgpa >= 0.875:  # 3.5/4.0
            strengths.append(f"CGPA cemerlang ({cgpa * 4:.2f}/4.00)")
        elif cgpa >= 0.75:  # 3.0/4.0
            strengths.append(f"CGPA baik ({cgpa * 4:.2f}/4.00)")

        # Kokurikulum strength
        if koku >= 80:
            strengths.append(f"Kokurikulum cemerlang ({koku:.0f}%)")
        elif koku >= 60:
            strengths.append(f"Kokurikulum baik ({koku:.0f}%)")
        
        # Balance strength
        if cgpa >= 0.75 and koku >= 70:
            strengths.append("Keseimbangan akademik-kokurikulum yang baik")

        return strengths[:3] if strengths else ["Ada ruang untuk penambahbaikan"]

    @staticmethod
    def get_recommendations(
        features: Dict[str, Any], risk_factors: List[str]
    ) -> List[str]:
        """
        Generate recommendations based on CGPA and Kokurikulum.

        Args:
            features: Student features
            risk_factors: Identified risk factors

        Returns:
            List of actionable recommendations in Bahasa Melayu
        """
        recommendations = []
        
        cgpa = features.get("cgpa", 0)
        koku = features.get("kokurikulum_score", 0)

        # Academic recommendations
        if cgpa < 0.5:  # < 2.0
            recommendations.append("Jumpa Penasihat Akademik untuk bincang strategi peningkatan CGPA")
            recommendations.append("Pertimbangkan kelas tambahan atau tutor")
        elif cgpa < 0.625:  # < 2.5
            recommendations.append("Tingkatkan prestasi akademik dengan kumpulan belajar")

        # Kokurikulum recommendations
        if koku < 30:
            recommendations.append("Sertai sekurang-kurangnya satu kelab atau persatuan")
            recommendations.append("Hadiri program anjuran fakulti")
        elif koku < 50:
            recommendations.append("Tingkatkan penglibatan kokurikulum")

        # Balance recommendations
        if cgpa >= 0.75 and koku < 40:
            recommendations.append("Perlu seimbangkan akademik dengan aktiviti kokurikulum")
        
        return recommendations[:3] if recommendations else ["Teruskan usaha baik!"]

        # Activity boost
        if features.get("days_since_activity", 999) > 14:
            recommendations.append("Schedule regular campus activities and check-ins")

        # Profile completion
        if features.get("profile_completion", 0) < 0.5:
            recommendations.append("Complete profile to improve visibility and opportunities")

        # Social development
        if features.get("social_score", 0) < 0.3:
            recommendations.append("Join group activities to build social connections")

        # Return top 3 recommendations
        return recommendations[:3] if recommendations else ["Continue current activities"]

    @staticmethod
    def calculate_performance_metrics(features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Calculate comprehensive performance metrics
        SIMPLIFIED: Focus only on CGPA and Kokurikulum

        Returns:
            Dictionary with performance breakdown
        """
        cgpa = features.get("cgpa", 0)
        koku_score = features.get("kokurikulum_score", 0)
        
        # Normalized values (0-1 scale)
        cgpa_normalized = min(cgpa / 4.0, 1.0) if cgpa else 0
        koku_normalized = koku_score / 100.0 if koku_score else 0
        
        return {
            "cgpa": cgpa,
            "cgpa_normalized": cgpa_normalized,
            "koku_score": koku_score,
            "koku_normalized": koku_normalized,
            "academic_level": FeatureEngineer._get_performance_level(cgpa_normalized),
            "koku_level": FeatureEngineer._get_performance_level(koku_normalized),
        }

    @staticmethod
    def _get_performance_level(score: float) -> str:
        """Convert score to performance level"""
        thresholds = MLConfig.PERFORMANCE_THRESHOLDS
        if score > thresholds["excellent"]:
            return "Excellent"
        elif score > thresholds["good"]:
            return "Good"
        elif score > thresholds["satisfactory"]:
            return "Satisfactory"
        else:
            return "Needs Improvement"

    @staticmethod
    def identify_trend(
        current_features: Dict[str, Any],
        previous_features: Dict[str, Any] = None,
    ) -> Dict[str, str]:
        """
        Identify trends in student performance

        Args:
            current_features: Current student metrics
            previous_features: Previous period metrics (optional)

        Returns:
            Trend analysis dictionary
        """
        trends = {}

        if previous_features:
            # Academic trend
            current_academic = current_features.get("academic_score", 0)
            previous_academic = previous_features.get("academic_score", 0)
            academic_change = current_academic - previous_academic

            if academic_change > 0.05:
                trends["academic"] = "📈 Improving"
            elif academic_change < -0.05:
                trends["academic"] = "📉 Declining"
            else:
                trends["academic"] = "➡️ Stable"

            # Engagement trend
            current_engagement = current_features.get("engagement_score", 0)
            previous_engagement = previous_features.get("engagement_score", 0)
            engagement_change = current_engagement - previous_engagement

            if engagement_change > 0.05:
                trends["engagement"] = "📈 Improving"
            elif engagement_change < -0.05:
                trends["engagement"] = "📉 Declining"
            else:
                trends["engagement"] = "➡️ Stable"
        else:
            # No previous data, show current status
            trends["academic"] = (
                "✅ Good" if current_features.get("academic_score", 0) > 0.5 else "⚠️ Needs attention"
            )
            trends["engagement"] = (
                "✅ Good" if current_features.get("engagement_score", 0) > 0.5 else "⚠️ Needs attention"
            )

        return trends

    @staticmethod
    def generate_summary(
        student_id: str,
        features: Dict[str, Any],
        risk_score: float,
        risk_factors: List[str],
        strengths: List[str],
        recommendations: List[str],
    ) -> Dict[str, Any]:
        """
        Generate complete ML analysis summary

        Returns:
            Comprehensive analysis dictionary
        """
        risk_level = MLConfig.get_risk_level(risk_score)
        emoji = MLConfig.get_risk_emoji(risk_level)

        return {
            "student_id": student_id,
            "risk_score": round(risk_score, 3),
            "risk_level": risk_level,
            "risk_emoji": emoji,
            "risk_factors": risk_factors,
            "strengths": strengths,
            "recommendations": recommendations,
            "performance_metrics": FeatureEngineer.calculate_performance_metrics(
                features
            ),
            "confidence": min(0.85, 0.7 + (features.get("profile_completion", 0) * 0.15)),
            "generated_at": "now",
        }
