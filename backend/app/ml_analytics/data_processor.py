"""
Data Processor

Extract and normalize student data from database for ML analysis.
"""

from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class DataProcessor:
    """
    Process student data for ML analysis

    Extracts relevant features from database and normalizes them
    for use in risk prediction and analysis.
    """

    @staticmethod
    def extract_student_features(student_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Extract and normalize ML features from student data

        SIMPLIFIED: Focus on CGPA and Kokurikulum only.

        Args:
            student_data: Raw student data from database

        Returns:
            Processed features dictionary
        """
        # Get kokurikulum score (0-100 scale)
        koku_score = student_data.get("kokurikulum_score", 0)
        if koku_score is None:
            koku_score = 0
        try:
            koku_score = float(koku_score)
        except (ValueError, TypeError):
            koku_score = 0
        
        features = {
            # Basic Info
            "student_id": student_data.get("id", ""),
            "name": student_data.get("name") or student_data.get("full_name", "Unknown"),
            
            # Academic Metrics (PRIMARY)
            "cgpa": DataProcessor._normalize_cgpa(student_data.get("cgpa", 0)),
            "academic_score": DataProcessor._calculate_academic_score(student_data),
            
            # Kokurikulum Metrics (PRIMARY)
            "kokurikulum_score": koku_score,  # Keep raw 0-100 scale
            
            # Optional extras (for display only, not used in risk calc)
            "department": student_data.get("department", ""),
            "faculty": student_data.get("faculty", ""),
        }
        
        logger.info(f"Features for {features['student_id']}: CGPA={features['cgpa']:.2f}, Koku={koku_score}")
        return features

    @staticmethod
    def _normalize_cgpa(cgpa) -> float:
        """Normalize CGPA to 0-1 scale"""
        if cgpa is None:
            return 0.0
        
        # Convert string to float if needed
        try:
            cgpa_float = float(cgpa)
        except (ValueError, TypeError):
            logger.warning(f"Invalid CGPA value: {cgpa}, defaulting to 0")
            return 0.0
        
        if cgpa_float <= 0:
            return 0.0
            
        # Assuming CGPA scale is 0-4.0
        normalized = min(cgpa_float / 4.0, 1.0)
        logger.debug(f"Normalized CGPA: {cgpa} -> {normalized}")
        return normalized

    @staticmethod
    def _calculate_academic_score(student_data: Dict) -> float:
        """Calculate overall academic score (0-1)"""
        cgpa = DataProcessor._normalize_cgpa(student_data.get("cgpa", 0))
        gpa_weight = 0.7

        # Additional academic metrics
        assignments_completed = student_data.get("assignments_completed", 0)
        assignments_total = student_data.get("assignments_total", 1)
        assignment_score = (
            min(assignments_completed / assignments_total, 1.0) if assignments_total > 0 else 0
        )
        assignment_weight = 0.3

        academic_score = (cgpa * gpa_weight) + (assignment_score * assignment_weight)
        return min(academic_score, 1.0)

    @staticmethod
    def _calculate_engagement_score(student_data: Dict) -> float:
        """Calculate engagement score based on activities (0-1)"""
        events_attended = student_data.get("events_attended", 0)
        events_organized = student_data.get("events_organized", 0)

        # Normalize: assume 5+ events/semester is excellent engagement
        max_events = 5
        event_score = min((events_attended + events_organized) / max_events, 1.0)

        # Activity frequency weight
        frequency_score = DataProcessor._calculate_activity_trend(student_data)

        engagement_score = (event_score * 0.6) + (frequency_score * 0.4)
        return min(engagement_score, 1.0)

    @staticmethod
    def _calculate_activity_trend(student_data: Dict) -> float:
        """Calculate activity trend (0-1). Higher = more recent activity"""
        last_activity = student_data.get("last_activity")

        if not last_activity:
            return 0.0

        try:
            if isinstance(last_activity, str):
                last_activity = datetime.fromisoformat(last_activity.replace("Z", "+00:00"))

            days_ago = (datetime.now(last_activity.tzinfo) - last_activity).days

            # Score based on recency: 0 days=1.0, 30 days=0.5, 60+ days=0.0
            trend_score = max(1.0 - (days_ago / 60), 0.0)
            return trend_score
        except Exception as e:
            logger.warning(f"Error calculating activity trend: {e}")
            return 0.0

    @staticmethod
    def _days_since_activity(last_activity: Optional[str]) -> int:
        """Calculate days since last activity"""
        if not last_activity:
            return 999  # Very old

        try:
            if isinstance(last_activity, str):
                last_activity = datetime.fromisoformat(last_activity.replace("Z", "+00:00"))

            days = (datetime.now(last_activity.tzinfo) - last_activity).days
            return days
        except Exception as e:
            logger.warning(f"Error calculating days since activity: {e}")
            return 999

    @staticmethod
    def _calculate_profile_completion(student_data: Dict) -> float:
        """Calculate profile completion percentage (0-1)"""
        required_fields = [
            "name",
            "email",
            "intake",
            "bio",
            "skills",
            "photo_url",
            "phone",
        ]

        completed = 0
        for field in required_fields:
            value = student_data.get(field)
            if value and (isinstance(value, str) and len(value) > 0 or isinstance(value, list) and len(value) > 0):
                completed += 1

        profile_completion = completed / len(required_fields) if required_fields else 0
        return min(profile_completion, 1.0)

    @staticmethod
    def _calculate_social_score(student_data: Dict) -> float:
        """Calculate social network strength (0-1)"""
        connections = student_data.get("connections", 0)
        followers = student_data.get("followers", 0)

        # Normalize: assume 20+ connections is good
        connection_score = min(connections / 20, 1.0)
        follower_score = min(followers / 10, 1.0)

        social_score = (connection_score * 0.6) + (follower_score * 0.4)
        return min(social_score, 1.0)

    @staticmethod
    def format_for_gemini(features: Dict[str, Any]) -> str:
        """
        Format features as text for Gemini API

        Returns formatted string suitable for LLM analysis
        """
        formatted = f"""
Student Profile Analysis:
========================
ID: {features.get('student_id')}
Name: {features.get('name')}
Intake: {features.get('intake')}

Academic Performance:
- CGPA: {features.get('cgpa', 0):.2f}/1.00
- Academic Score: {features.get('academic_score', 0):.1%}
- Days Since Activity: {features.get('days_since_activity', 999)}

Engagement:
- Events Attended: {features.get('events_attended', 0)}
- Events Organized: {features.get('events_organized', 0)}
- Engagement Score: {features.get('engagement_score', 0):.1%}
- Activity Trend: {features.get('activity_trend', 0):.1%}

Profile:
- Completion: {features.get('profile_completion', 0):.1%}
- Bio: {'Yes' if features.get('bio_filled') else 'No'}
- Skills Listed: {'Yes' if features.get('skills_filled') else 'No'}

Social Network:
- Connections: {features.get('connections', 0)}
- Followers: {features.get('followers', 0)}
- Social Score: {features.get('social_score', 0):.1%}

Activity:
- Messages Sent: {features.get('messages_sent', 0)}
- Posts Created: {features.get('posts_created', 0)}
- Interactions: {features.get('interactions', 0)}
"""
        return formatted

    @staticmethod
    def batch_extract_features(students_data: List[Dict]) -> List[Dict[str, Any]]:
        """Extract features for multiple students"""
        features_list = []
        for student in students_data:
            try:
                features = DataProcessor.extract_student_features(student)
                features_list.append(features)
            except Exception as e:
                logger.error(f"Error extracting features for student: {e}")
                continue

        logger.info(f"Extracted features for {len(features_list)}/{len(students_data)} students")
        return features_list
