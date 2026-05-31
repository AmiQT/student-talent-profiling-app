"""Tool definitions for Agentic AI - Function Calling System.

This module defines tools that the AI can call to interact with the system,
similar to Claude Computer Use, ChatGPT Plugins, or Gemini Function Calling.
"""

from __future__ import annotations
from typing import Dict, List, Any, Optional, Callable
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class ToolDefinition:
    """Definition of a tool that AI can use."""
    name: str
    description: str
    parameters: Dict[str, Any]
    function: Optional[Callable] = None  # Actual Python function to execute


# Tool definitions in OpenAI function calling format
AVAILABLE_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query_students",
            "description": "Query students from the UTHM database. Use this when user asks for student information, random selection, or filtered searches. Returns student data including name, email, department, CGPA, etc.",
            "parameters": {
                "type": "object",
                "properties": {
                    "department": {
                        "type": "string",
                        "description": "Filter by department/faculty. Accept any format - AI should normalize to database values. Common mappings: 'Computer Science'/'Sains Komputer'/'CS'/'IT' -> 'FSKTM', 'Electrical'/'Elektrik'/'EE' -> 'FKEE', 'Civil'/'Awam' -> 'FKAAB', 'Mechanical'/'Mekanikal' -> 'FTK'. Use the faculty code (FSKTM, FKEE, FKAAB, FTK) when querying database."
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of students to return (default: 10)",
                        "default": 10,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random students instead of ordered results",
                        "default": False
                    },
                    "min_cgpa": {
                        "type": "number",
                        "description": "Filter students with CGPA greater than or equal to this value",
                        "minimum": 0.0,
                        "maximum": 4.0
                    },
                    "max_cgpa": {
                        "type": "number",
                        "description": "Filter students with CGPA less than or equal to this value",
                        "minimum": 0.0,
                        "maximum": 4.0
                    },
                    "sort_by": {
                        "type": "string",
                        "description": "Field to sort results by",
                        "enum": ["cgpa", "name", "student_id"],
                        "default": "cgpa"
                    },
                    "sort_order": {
                        "type": "string",
                        "description": "Sort order",
                        "enum": ["asc", "desc"],
                        "default": "desc"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_events",
            "description": "Query events from the UTHM event management system. Use this for upcoming events, event schedules, or event information searches.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of events to return (default: 10)",
                        "default": 10,
                        "minimum": 1,
                        "maximum": 50
                    },
                    "upcoming_only": {
                        "type": "boolean",
                        "description": "If true, only return future events. If false, return all events including past ones",
                        "default": False
                    },
                    "event_type": {
                        "type": "string",
                        "description": "Filter by event type",
                        "enum": ["seminar", "workshop", "conference", "competition", "talk", "ceremony"]
                    },
                    "date_from": {
                        "type": "string",
                        "description": "Start date for event range (YYYY-MM-DD format)"
                    },
                    "date_to": {
                        "type": "string",
                        "description": "End date for event range (YYYY-MM-DD format)"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "get_system_stats",
            "description": "Get system statistics and overview of the UTHM dashboard. Use this when user asks about totals, counts, or system-wide information. Can analyze gender distribution from names.",
            "parameters": {
                "type": "object",
                "properties": {
                    "detailed": {
                        "type": "boolean",
                        "description": "If true, return detailed breakdown including department distribution, completion rates, etc.",
                        "default": False
                    },
                    "include_gender_analysis": {
                        "type": "boolean",
                        "description": "If true, analyze gender distribution from student names (bin/binti patterns)",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_analytics",
            "description": "Get analytics and insights about students, events, or system performance. Use for trend analysis, comparisons, or statistical queries.",
            "parameters": {
                "type": "object",
                "properties": {
                    "type": {
                        "type": "string",
                        "description": "Type of analytics to retrieve",
                        "enum": ["department_performance", "event_participation", "profile_completion", "cgpa_distribution", "gender_analysis", "name_analysis"],
                        "required": True
                    },
                    "department": {
                        "type": "string",
                        "description": "Filter analytics by specific department"
                    },
                    "time_period": {
                        "type": "string",
                        "description": "Time period for analytics",
                        "enum": ["last_week", "last_month", "last_semester", "all_time"],
                        "default": "all_time"
                    }
                },
                "required": ["type"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "analyze_student_names",
            "description": "Advanced NLP analysis of student names for demographic insights, gender distribution, and naming patterns. Use when user asks about gender, demographics, or name analysis.",
            "parameters": {
                "type": "object",
                "properties": {
                    "analysis_type": {
                        "type": "string",
                        "description": "Type of name analysis to perform",
                        "enum": ["gender_distribution", "naming_patterns", "demographics", "ethnic_analysis"],
                        "default": "gender_distribution"
                    },
                    "department": {
                        "type": "string",
                        "description": "Filter analysis by specific department"
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of students to analyze",
                        "default": 100,
                        "minimum": 10,
                        "maximum": 1000
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_users",
            "description": "Search and filter all users (students, staff, admin) from the UTHM system. Use this for comprehensive user queries across all roles.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of users to return (default: 20)",
                        "default": 20,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "role": {
                        "type": "string",
                        "description": "Filter by user role",
                        "enum": ["student", "lecturer", "admin"]
                    },
                    "department": {
                        "type": "string",
                        "description": "Filter by department"
                    },
                    "name": {
                        "type": "string",
                        "description": "Search by user name (partial match)"
                    },
                    "email": {
                        "type": "string",
                        "description": "Search by user email"
                    },
                    "is_active": {
                        "type": "boolean",
                        "description": "Filter by active status"
                    },
                    "profile_completed": {
                        "type": "boolean",
                        "description": "Filter by profile completion status"
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random users",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_profiles",
            "description": "Search and filter user profiles with detailed information including academic info, skills, interests, and experiences.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of profiles to return (default: 20)",
                        "default": 20,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "full_name": {
                        "type": "string",
                        "description": "Search by full name (partial match)"
                    },
                    "skills": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Filter by skills (array of skill names)"
                    },
                    "interests": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Filter by interests (array of interest names)"
                    },
                    "department": {
                        "type": "string",
                        "description": "Filter by department from academic_info"
                    },
                    "faculty": {
                        "type": "string",
                        "description": "Filter by faculty from academic_info"
                    },
                    "is_profile_complete": {
                        "type": "boolean",
                        "description": "Filter by profile completion status"
                    },
                    "has_skills": {
                        "type": "boolean",
                        "description": "Filter profiles that have skills listed"
                    },
                    "has_experiences": {
                        "type": "boolean",
                        "description": "Filter profiles that have experiences listed"
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random profiles",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_showcase_posts",
            "description": "Search and filter showcase posts from the UTHM showcase system. Use this for project showcases, student work, and portfolio queries.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of posts to return (default: 20)",
                        "default": 20,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "category": {
                        "type": "string",
                        "description": "Filter by post category",
                        "enum": ["general", "project", "achievement", "event", "academic", "personal"]
                    },
                    "user_id": {
                        "type": "string",
                        "description": "Filter by specific user ID"
                    },
                    "user_name": {
                        "type": "string",
                        "description": "Filter by user name"
                    },
                    "department": {
                        "type": "string",
                        "description": "Filter by user department"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Filter by tags (array of tag names)"
                    },
                    "skills_used": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Filter by skills used (array of skill names)"
                    },
                    "is_featured": {
                        "type": "boolean",
                        "description": "Filter by featured status"
                    },
                    "is_public": {
                        "type": "boolean",
                        "description": "Filter by public status"
                    },
                    "min_likes": {
                        "type": "integer",
                        "description": "Minimum number of likes",
                        "minimum": 0
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random posts",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_achievements",
            "description": "Search and filter achievements from the UTHM achievement system. Use this for achievement queries, awards, and recognition tracking.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of achievements to return (default: 20)",
                        "default": 20,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "title": {
                        "type": "string",
                        "description": "Search by achievement title (partial match)"
                    },
                    "category": {
                        "type": "string",
                        "description": "Filter by achievement category"
                    },
                    "is_verified": {
                        "type": "boolean",
                        "description": "Filter by verification status"
                    },
                    "user_id": {
                        "type": "string",
                        "description": "Filter achievements by specific user"
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random achievements",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "query_event_participations",
            "description": "Search and filter event participations to see who attended which events. Use this for attendance tracking and event engagement analysis.",
            "parameters": {
                "type": "object",
                "properties": {
                    "limit": {
                        "type": "integer",
                        "description": "Maximum number of participations to return (default: 20)",
                        "default": 20,
                        "minimum": 1,
                        "maximum": 100
                    },
                    "event_id": {
                        "type": "string",
                        "description": "Filter by specific event ID"
                    },
                    "user_id": {
                        "type": "string",
                        "description": "Filter by specific user ID"
                    },
                    "status": {
                        "type": "string",
                        "description": "Filter by participation status",
                        "enum": ["registered", "attended", "completed", "cancelled"]
                    },
                    "random": {
                        "type": "boolean",
                        "description": "If true, return random participations",
                        "default": False
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "advanced_analytics",
            "description": "Perform advanced analytics and insights across multiple entities. Use for complex analysis, trends, correlations, and predictive insights.",
            "parameters": {
                "type": "object",
                "properties": {
                    "analysis_type": {
                        "type": "string",
                        "description": "Type of advanced analysis to perform",
                        "enum": ["trend_analysis", "correlation_analysis", "performance_metrics", "engagement_analysis", "demographic_insights", "predictive_analysis", "comparative_analysis", "anomaly_detection"]
                    },
                    "entities": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Entities to analyze (users, events, profiles, etc.)"
                    },
                    "time_range": {
                        "type": "string",
                        "description": "Time range for analysis",
                        "enum": ["last_week", "last_month", "last_quarter", "last_year", "all_time"]
                    },
                    "filters": {
                        "type": "object",
                        "description": "Additional filters for analysis"
                    },
                    "metrics": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Specific metrics to calculate"
                    }
                },
                "required": ["analysis_type"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "cross_entity_query",
            "description": "Perform complex queries across multiple entities with relationships. Use for finding connections, patterns, and complex data relationships.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query_type": {
                        "type": "string",
                        "description": "Type of cross-entity query",
                        "enum": ["user_event_analysis", "department_performance", "skill_correlation", "engagement_patterns", "activity_analysis", "relationship_mapping"]
                    },
                    "primary_entity": {
                        "type": "string",
                        "description": "Primary entity to focus on"
                    },
                    "secondary_entities": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Secondary entities to analyze with primary"
                    },
                    "relationship_type": {
                        "type": "string",
                        "description": "Type of relationship to analyze",
                        "enum": ["direct", "indirect", "correlation", "causation", "temporal"]
                    },
                    "depth": {
                        "type": "integer",
                        "description": "Depth of relationship analysis",
                        "default": 2,
                        "minimum": 1,
                        "maximum": 5
                    }
                },
                "required": ["query_type"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "intelligent_search",
            "description": "Perform intelligent semantic search across all data with natural language understanding. Use for complex, multi-faceted queries.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Natural language search query"
                    },
                    "search_scope": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Scope of search (users, events, profiles, etc.)"
                    },
                    "search_type": {
                        "type": "string",
                        "description": "Type of search to perform",
                        "enum": ["semantic", "fuzzy", "exact", "pattern", "contextual"]
                    },
                    "include_related": {
                        "type": "boolean",
                        "description": "Include related/connected data",
                        "default": True
                    },
                    "ranking_criteria": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Criteria for ranking results"
                    }
                },
                "required": ["query"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "predictive_insights",
            "description": "Generate predictive insights and forecasts based on historical data patterns. Use for trend prediction and future analysis.",
            "parameters": {
                "type": "object",
                "properties": {
                    "prediction_type": {
                        "type": "string",
                        "description": "Type of prediction to generate",
                        "enum": ["trend_forecast", "behavior_prediction", "performance_prediction", "engagement_forecast", "growth_prediction", "risk_assessment"]
                    },
                    "target_entity": {
                        "type": "string",
                        "description": "Entity to make predictions about"
                    },
                    "time_horizon": {
                        "type": "string",
                        "description": "Time horizon for prediction",
                        "enum": ["short_term", "medium_term", "long_term"]
                    },
                    "confidence_level": {
                        "type": "number",
                        "description": "Confidence level for predictions",
                        "minimum": 0.1,
                        "maximum": 1.0,
                        "default": 0.8
                    },
                    "factors": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Factors to consider in prediction"
                    }
                },
                "required": ["prediction_type", "target_entity"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "admin_dashboard_analytics",
            "description": "Generate comprehensive admin dashboard analytics with key performance indicators, insights, and recommendations.",
            "parameters": {
                "type": "object",
                "properties": {
                    "dashboard_type": {
                        "type": "string",
                        "description": "Type of admin dashboard to generate",
                        "enum": ["overview", "user_management", "event_management", "performance_metrics", "engagement_analysis", "system_health"]
                    },
                    "time_period": {
                        "type": "string",
                        "description": "Time period for dashboard data",
                        "enum": ["today", "this_week", "this_month", "this_quarter", "this_year"]
                    },
                    "include_recommendations": {
                        "type": "boolean",
                        "description": "Include actionable recommendations",
                        "default": True
                    },
                    "alert_thresholds": {
                        "type": "object",
                        "description": "Thresholds for generating alerts"
                    },
                    "visualization_type": {
                        "type": "string",
                        "description": "Type of visualization to suggest",
                        "enum": ["charts", "tables", "graphs", "metrics", "mixed"]
                    }
                },
                "required": ["dashboard_type"]
            }
        }
    }
]


def get_tool_by_name(tool_name: str) -> Optional[Dict[str, Any]]:
    """Get tool definition by name."""
    for tool in AVAILABLE_TOOLS:
        if tool["function"]["name"] == tool_name:
            return tool
    return None


def get_all_tool_names() -> List[str]:
    """Get list of all available tool names."""
    return [tool["function"]["name"] for tool in AVAILABLE_TOOLS]


def get_tool_description(tool_name: str) -> Optional[str]:
    """Get description of a specific tool."""
    tool = get_tool_by_name(tool_name)
    if tool:
        return tool["function"]["description"]
    return None


# Tool registry for mapping names to implementations
TOOL_REGISTRY: Dict[str, ToolDefinition] = {}


def register_tool(tool_def: ToolDefinition):
    """Register a tool implementation."""
    TOOL_REGISTRY[tool_def.name] = tool_def
    logger.info(f"Registered tool: {tool_def.name}")


def get_registered_tool(tool_name: str) -> Optional[ToolDefinition]:
    """Get a registered tool implementation."""
    return TOOL_REGISTRY.get(tool_name)

