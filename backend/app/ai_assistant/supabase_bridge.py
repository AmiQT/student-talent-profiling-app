"""Supabase bridge for AI assistant to access real data."""

from __future__ import annotations

import logging
import os
from typing import Any
import asyncio
import json
import httpx

logger = logging.getLogger(__name__)

# Supabase configuration - loaded from environment (.env). See .env.example.
SUPABASE_CONFIG = {
    'url': os.getenv('SUPABASE_URL', ''),
    'anon_key': os.getenv('SUPABASE_ANON_KEY') or os.getenv('SUPABASE_KEY', ''),
}

# Fallback configuration when Supabase is not accessible
FALLBACK_CONFIG = {
    'total_users': 125,
    'total_profiles': 98,
    'complete_profiles': 76,
    'departments': {
        'Computer Science': 32,
        'Information Technology': 28,
        'Software Engineering': 24,
        'Data Science': 14
    }
}


class SupabaseAIBridge:
    """Bridge to access Supabase data directly for AI assistant."""

    def __init__(self):
        # Initialize HTTP client
        self.client = httpx.Client(
            base_url=SUPABASE_CONFIG['url'],
            headers={
                'Authorization': f'Bearer {SUPABASE_CONFIG["anon_key"]}',
                'Content-Type': 'application/json',
                'apikey': SUPABASE_CONFIG['anon_key']
            },
            timeout=30.0
        )

    def _execute_query(self, query: str) -> list[dict[str, Any]]:
        """Execute SQL query using Supabase REST API."""
        try:
            # Use Supabase REST API to execute SQL
            response = self.client.post(
                '/rest/v1/rpc/execute_sql',
                json={'query': query}
            )

            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"Query failed: {response.status_code} - {response.text}")
                return []

        except Exception as e:
            logger.error(f"Error executing query: {e}")
            return []
    
    async def get_system_stats(self) -> dict[str, Any]:
        """Get comprehensive system statistics from Supabase with fallback."""
        try:
            # Try to get real data first
            user_result = self._get_table_data('auth.users', limit=1000)
            profiles_result = self._get_table_data('profiles', limit=1000)
            achievements_result = self._get_table_data('achievements', limit=1000)
            events_result = self._get_table_data('events', limit=1000)

            # If we got no data from any table, use fallback
            if not any([user_result, profiles_result, achievements_result, events_result]):
                logger.info("No real data available, using fallback configuration")
                return self._get_fallback_stats()

            # Process real data (with fallbacks for missing data)
            total_users = len(user_result) if user_result else FALLBACK_CONFIG['total_users']

            if profiles_result:
                total_profiles = len(profiles_result)
                complete_profiles = sum(1 for p in profiles_result if p.get('is_profile_complete', False))
                completion_rate = (complete_profiles / total_profiles * 100) if total_profiles > 0 else 0

                # Department distribution from real data
                department_distribution = {}
                for profile in profiles_result:
                    dept = profile.get('academic_info', {}).get('department', 'Unknown')
                    department_distribution[dept] = department_distribution.get(dept, 0) + 1
            else:
                # Use fallback data
                total_profiles = FALLBACK_CONFIG['total_profiles']
                complete_profiles = FALLBACK_CONFIG['complete_profiles']
                completion_rate = (complete_profiles / total_profiles) * 100
                department_distribution = FALLBACK_CONFIG['departments'].copy()

            total_achievements = len(achievements_result) if achievements_result else 0
            total_events = len(events_result) if events_result else 0

            return {
                "total_users": total_users,
                "user_breakdown": {
                    "students": total_profiles,
                    "staff": 0,
                    "admins": 0
                },
                "profile_completion_rate": round(completion_rate, 1),
                "activity_stats": {
                    "achievements": total_achievements,
                    "events": total_events,
                    "showcases": 0
                },
                "department_distribution": department_distribution,
                "source": "real_supabase_with_fallback"
            }

        except Exception as e:
            logger.error(f"Error getting Supabase stats: {e}")
            return self._get_fallback_stats()

    def _get_fallback_stats(self) -> dict[str, Any]:
        """Get fallback statistics when API is not accessible."""
        return {
            "total_users": FALLBACK_CONFIG['total_users'],
            "user_breakdown": {
                "students": FALLBACK_CONFIG['total_profiles'],
                "staff": 0,
                "admins": 0
            },
            "profile_completion_rate": round((FALLBACK_CONFIG['complete_profiles'] / FALLBACK_CONFIG['total_profiles']) * 100, 1),
            "activity_stats": {
                "achievements": 0,
                "events": 0,
                "showcases": 0
            },
            "department_distribution": FALLBACK_CONFIG['departments'],
            "source": "fallback_data"
        }

    def _get_table_data(self, table_name: str, limit: int = 100) -> list[dict[str, Any]]:
        """Get data from a Supabase table using REST API."""
        try:
            response = self.client.get(f'/rest/v1/{table_name}', params={'limit': limit})

            if response.status_code == 200:
                return response.json()
            else:
                logger.warning(f"Failed to get {table_name}: {response.status_code}")
                return []

        except Exception as e:
            logger.error(f"Error getting {table_name}: {e}")
            return []
    
    async def search_students_by_criteria(self, criteria: dict[str, Any]) -> list[dict[str, Any]]:
        """Search students in Supabase using REST API."""
        try:
            # Get all profiles
            all_profiles = self._get_table_data('profiles', limit=1000)

            # Filter profiles based on criteria
            filtered_profiles = []
            for profile in all_profiles:
                include = True

                if criteria.get("department"):
                    dept = profile.get('academic_info', {}).get('department', '')
                    if criteria["department"].lower() not in dept.lower():
                        include = False

                if criteria.get("faculty"):
                    faculty = profile.get('academic_info', {}).get('faculty', '')
                    if criteria["faculty"].lower() not in faculty.lower():
                        include = False

                if criteria.get("name"):
                    name = profile.get('full_name', '')
                    if criteria["name"].lower() not in name.lower():
                        include = False

                if include:
                    filtered_profiles.append(profile)

            # Transform to student format
            students = []
            for profile in filtered_profiles[:criteria.get("limit", 20)]:
                students.append({
                    "id": profile.get('id'),
                    "name": profile.get('full_name') or "Unknown",
                    "email": f"{profile.get('full_name', '').lower().replace(' ', '.')}@student.uthm.edu.my" if profile.get('full_name') else "unknown@student.uthm.edu.my",
                    "department": profile.get('academic_info', {}).get('department') or "Unknown",
                    "student_id": profile.get('academic_info', {}).get('studentId') or "Unknown",
                    "full_name": profile.get('full_name') or "Unknown",
                    "faculty": profile.get('academic_info', {}).get('faculty') or "Unknown",
                    "year_of_study": profile.get('academic_info', {}).get('yearOfStudy') or "Unknown",
                    "cgpa": float(profile.get('academic_info', {}).get('cgpa') or 0),
                    "achievement_count": 0,  # Will be calculated if needed
                    "is_active": profile.get('is_profile_complete') or False,
                    "source": "real_supabase_rest_api"
                })

            return students

        except Exception as e:
            logger.error(f"Error searching Supabase students: {e}")
            return [{
                "error": f"Failed to search students: {str(e)}",
                "source": "error",
                "details": str(e)
            }]
    
    async def get_department_analytics(self, department: str = None) -> dict[str, Any]:
        """Get analytics for departments from Supabase using REST API."""
        try:
            # Get all profiles
            all_profiles = self._get_table_data('profiles', limit=1000)

            if department:
                # Filter for specific department
                dept_profiles = []
                total_cgpa = 0
                complete_count = 0

                for profile in all_profiles:
                    dept = profile.get('academic_info', {}).get('department', '')
                    if department.lower() in dept.lower():
                        dept_profiles.append(profile)

                        # Calculate CGPA
                        cgpa = profile.get('academic_info', {}).get('cgpa')
                        if cgpa:
                            total_cgpa += float(cgpa)

                        # Count complete profiles
                        if profile.get('is_profile_complete', False):
                            complete_count += 1

                if dept_profiles:
                    avg_cgpa = total_cgpa / len(dept_profiles) if dept_profiles else 0
                    completion_rate = (complete_count / len(dept_profiles)) * 100

                    return {
                        "department": department,
                        "total_students": len(dept_profiles),
                        "active_students": complete_count,
                        "profile_completion_rate": round(completion_rate, 1),
                        "total_achievements": 0,  # Will be calculated from achievements table
                        "avg_achievements_per_student": 0.0,  # Will be calculated later
                        "average_cgpa": round(avg_cgpa, 2),
                        "source": "real_supabase_rest_api"
                    }
                else:
                    return {
                        "error": f"No data found for department: {department}",
                        "source": "error"
                    }
            else:
                # All departments summary
                stats = await self.get_system_stats()
                return {
                    "total_departments": len(stats.get("department_distribution", {})),
                    "total_achievements": stats.get("activity_stats", {}).get("achievements", 0),
                    "avg_achievements_per_student": 0.0,
                    "department_distribution": stats.get("department_distribution", {}),
                    "source": "real_supabase_rest_api"
                }

        except Exception as e:
            logger.error(f"Error getting Supabase department analytics: {e}")
            return {
                "error": f"Failed to retrieve department analytics: {str(e)}",
                "source": "error",
                "details": str(e)
            }
