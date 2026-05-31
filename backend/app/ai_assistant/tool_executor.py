"""Tool Executor - Executes tool calls from AI.

Handles the execution of tools that the AI requests,
similar to function calling in ChatGPT/Claude/Gemini.
"""

from __future__ import annotations
from typing import Dict, Any, Optional
import logging
import json

from .service_bridge import AssistantServiceBridge
from .tools import get_tool_by_name, get_all_tool_names

logger = logging.getLogger(__name__)


class ToolExecutor:
    """Executes tool calls requested by the AI."""
    
    def __init__(self, service_bridge: AssistantServiceBridge):
        self.service_bridge = service_bridge
    
    async def execute_tool(self, tool_name: str, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute a tool with given arguments.
        
        Args:
            tool_name: Name of the tool to execute
            arguments: Arguments to pass to the tool
            
        Returns:
            Dict containing the tool execution results
        """
        logger.info(f"🔧 Executing tool: {tool_name} with arguments: {arguments}")
        
        try:
            # Validate tool exists
            if tool_name not in get_all_tool_names():
                return {
                    "error": f"Unknown tool: {tool_name}",
                    "success": False
                }
            
            # Route to appropriate handler
            if tool_name == "query_students":
                return await self._execute_query_students(arguments)
            elif tool_name == "query_events":
                return await self._execute_query_events(arguments)
            elif tool_name == "get_system_stats":
                return await self._execute_get_system_stats(arguments)
            elif tool_name == "query_analytics":
                return await self._execute_query_analytics(arguments)
            elif tool_name == "analyze_student_names":
                return await self._execute_analyze_student_names(arguments)
            elif tool_name == "query_users":
                return await self._execute_query_users(arguments)
            elif tool_name == "query_profiles":
                return await self._execute_query_profiles(arguments)
            elif tool_name == "query_showcase_posts":
                return await self._execute_query_showcase_posts(arguments)
            elif tool_name == "query_achievements":
                return await self._execute_query_achievements(arguments)
            elif tool_name == "query_event_participations":
                return await self._execute_query_event_participations(arguments)
            elif tool_name == "advanced_analytics":
                return await self._execute_advanced_analytics(arguments)
            elif tool_name == "cross_entity_query":
                return await self._execute_cross_entity_query(arguments)
            elif tool_name == "intelligent_search":
                return await self._execute_intelligent_search(arguments)
            elif tool_name == "predictive_insights":
                return await self._execute_predictive_insights(arguments)
            elif tool_name == "admin_dashboard_analytics":
                return await self._execute_admin_dashboard_analytics(arguments)
            else:
                return {
                    "error": f"Tool not implemented: {tool_name}",
                    "success": False
                }
                
        except Exception as e:
            logger.error(f"Error executing tool {tool_name}: {e}", exc_info=True)
            return {
                "error": str(e),
                "success": False,
                "tool_name": tool_name
            }
    
    async def _execute_query_students(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute student query tool with enhanced filtering."""
        try:
            # Build criteria from arguments
            criteria = {}
            
            if "department" in arguments:
                criteria["department"] = arguments["department"]
            
            # Safety limit - ensure integer! (Gemini might send float)
            requested_limit = arguments.get("limit", 10)
            criteria["limit"] = int(min(requested_limit, 100))  # ✅ Cast to int!
            
            if "min_cgpa" in arguments:
                criteria["cgpa_min"] = float(arguments["min_cgpa"])
            
            if "max_cgpa" in arguments:
                criteria["cgpa_max"] = float(arguments["max_cgpa"])
            
            # Execute query
            students = self.service_bridge.search_students_by_criteria(criteria)
            
            if not students:
                return {
                    "success": True,
                    "count": 0,
                    "students": [],
                    "message": "No students found matching criteria",
                    "criteria_used": criteria
                }
            
            # Handle random selection if requested
            if arguments.get("random", False):
                import random
                select_count = min(criteria.get("limit", 1), len(students))
                students = random.sample(students, select_count) if len(students) > select_count else students
                logger.info(f"🎲 Randomly selected {len(students)} from pool")
            
            # Sort if requested
            if "sort_by" in arguments and students:
                field = arguments["sort_by"]
                reverse = arguments.get("sort_order", "desc") == "desc"
                if field in ["cgpa", "name", "student_id"]:
                    students = sorted(
                        students,
                        key=lambda x: x.get(field, "") if field == "name" else x.get(field, 0),
                        reverse=reverse
                    )
                    logger.info(f"📊 Sorted {len(students)} students by {field}")
            
            return {
                "success": True,
                "count": len(students),
                "students": students[:criteria["limit"]],  # Ensure limit
                "total_matched": len(students),
                "criteria_used": criteria
            }
            
        except Exception as e:
            logger.error(f"Error in query_students: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "students": []
            }
    
    async def _execute_query_events(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute event query tool with date filtering."""
        try:
            criteria = {
                "limit": int(min(arguments.get("limit", 10), 50))  # ✅ Cast to int! Max 50 events
            }
            
            if "event_type" in arguments:
                criteria["type"] = arguments["event_type"]
            
            if "date_from" in arguments:
                criteria["date_from"] = arguments["date_from"]
            
            if "date_to" in arguments:
                criteria["date_to"] = arguments["date_to"]
            
            # Execute query
            events = self.service_bridge._search_events_advanced(criteria)
            
            if not events:
                return {
                    "success": True,
                    "count": 0,
                    "events": [],
                    "message": "No events found matching criteria. This could be because: 1) No events are scheduled, 2) All events are in the past, 3) Events are filtered out by date criteria",
                    "criteria_used": criteria,
                    "suggestion": "Try removing date filters or check if events exist in the system"
                }
            
            # Filter upcoming if requested (default to False for better results)
            if arguments.get("upcoming_only", False):
                from datetime import datetime
                now = datetime.now()
                original_count = len(events)
                events = [e for e in events if e.get("date") and e["date"] >= now.strftime("%Y-%m-%d")]
                logger.info(f"📅 Filtered to {len(events)} upcoming events from {original_count} total")
            
            # Add helpful message if no events after filtering
            if not events:
                return {
                    "success": True,
                    "count": 0,
                    "events": [],
                    "message": f"No upcoming events found. Found {original_count} total events, but all are in the past or today",
                    "criteria_used": criteria,
                    "suggestion": "Try asking for 'all events' or 'past events' to see what's available"
                }
            
            return {
                "success": True,
                "count": len(events),
                "events": events[:criteria["limit"]],
                "total_matched": len(events),
                "criteria_used": criteria
            }
            
        except Exception as e:
            logger.error(f"Error in query_events: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "events": []
            }
    
    async def _execute_get_system_stats(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute system stats tool with enhanced gender analysis."""
        try:
            stats = self.service_bridge.get_system_stats()
            
            # Add gender analysis if requested
            if arguments.get("include_gender_analysis", False):
                gender_stats = await self._analyze_gender_distribution()
                stats["gender_distribution"] = gender_stats
            
            if not arguments.get("detailed", False):
                # Return simplified stats
                simplified = {
                    "total_users": stats.get("total_users", 0),
                    "total_students": stats.get("user_breakdown", {}).get("students", 0),
                    "total_events": stats.get("total_events", 0),
                    "profile_completion_rate": stats.get("profile_completion_rate", 0)
                }
                
                # Include gender analysis if available
                if "gender_distribution" in stats:
                    simplified["gender_distribution"] = stats["gender_distribution"]
                
                return {
                    "success": True,
                    "stats": simplified
                }
            
            # Return full detailed stats
            return {
                "success": True,
                "stats": stats
            }
            
        except Exception as e:
            logger.error(f"Error in get_system_stats: {e}")
            return {
                "success": False,
                "error": str(e),
                "stats": {}
            }
    
    async def _analyze_gender_distribution(self) -> Dict[str, Any]:
        """Analyze gender distribution from student names using bin/binti patterns."""
        try:
            # Get all student names
            students = self.service_bridge.search_students_by_criteria({"limit": 1000})
            
            male_count = 0
            female_count = 0
            unknown_count = 0
            
            for student in students:
                name = student.get("name", "").lower()
                
                # Check for Malaysian naming patterns
                if "bin " in name or name.startswith("muhammad") or name.startswith("ahmad") or name.startswith("mohd"):
                    male_count += 1
                elif "binti " in name or name.startswith("nur") or name.startswith("siti") or name.startswith("nurul"):
                    female_count += 1
                else:
                    # Try to infer from common Malaysian names
                    if any(male_name in name for male_name in ["zulkifli", "aidil", "hakim", "farid", "hassan", "razak"]):
                        male_count += 1
                    elif any(female_name in name for female_name in ["aina", "haliza", "nurhaliza", "yusof"]):
                        female_count += 1
                    else:
                        unknown_count += 1
            
            total_analyzed = male_count + female_count + unknown_count
            
            return {
                "male_count": male_count,
                "female_count": female_count,
                "unknown_count": unknown_count,
                "total_analyzed": total_analyzed,
                "male_percentage": round((male_count / total_analyzed * 100), 1) if total_analyzed > 0 else 0,
                "female_percentage": round((female_count / total_analyzed * 100), 1) if total_analyzed > 0 else 0,
                "analysis_method": "Malaysian naming patterns (bin/binti, common names)"
            }
            
        except Exception as e:
            logger.error(f"Error in gender analysis: {e}")
            return {
                "error": str(e),
                "male_count": 0,
                "female_count": 0,
                "unknown_count": 0
            }
    
    async def _execute_query_analytics(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute analytics query tool with enhanced NLP capabilities."""
        try:
            analytics_type = arguments.get("type")
            if not analytics_type:
                return {
                    "success": False,
                    "error": "Analytics type is required"
                }
            
            # Handle gender and name analysis
            if analytics_type in ["gender_analysis", "name_analysis"]:
                gender_stats = await self._analyze_gender_distribution()
                return {
                    "success": True,
                    "analytics_type": analytics_type,
                    "results": gender_stats,
                    "criteria_used": {"type": analytics_type}
                }
            
            criteria = {
                "type": analytics_type,
                "department": arguments.get("department"),
                "time_period": arguments.get("time_period", "all_time")
            }
            
            # Execute analytics query
            results = self.service_bridge._search_analytics(criteria)
            
            return {
                "success": True,
                "analytics_type": analytics_type,
                "results": results,
                "criteria_used": criteria
            }
            
        except Exception as e:
            logger.error(f"Error in query_analytics: {e}")
            return {
                "success": False,
                "error": str(e),
                "results": {}
            }
    
    async def _execute_analyze_student_names(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute advanced student name analysis with NLP capabilities."""
        try:
            analysis_type = arguments.get("analysis_type", "gender_distribution")
            department = arguments.get("department")
            limit = int(min(arguments.get("limit", 100), 1000))
            
            # Build criteria for student search
            criteria = {"limit": limit}
            if department:
                criteria["department"] = department
            
            # Get students
            students = self.service_bridge.search_students_by_criteria(criteria)
            
            if not students:
                return {
                    "success": True,
                    "analysis_type": analysis_type,
                    "results": {
                        "total_analyzed": 0,
                        "message": "No students found for analysis"
                    }
                }
            
            # Perform analysis based on type
            if analysis_type == "gender_distribution":
                results = await self._perform_gender_analysis(students)
            elif analysis_type == "naming_patterns":
                results = await self._perform_naming_pattern_analysis(students)
            elif analysis_type == "demographics":
                results = await self._perform_demographic_analysis(students)
            elif analysis_type == "ethnic_analysis":
                results = await self._perform_ethnic_analysis(students)
            else:
                results = {"error": f"Unknown analysis type: {analysis_type}"}
            
            return {
                "success": True,
                "analysis_type": analysis_type,
                "results": results,
                "total_analyzed": len(students),
                "criteria_used": criteria
            }
            
        except Exception as e:
            logger.error(f"Error in analyze_student_names: {e}")
            return {
                "success": False,
                "error": str(e),
                "results": {}
            }
    
    async def _perform_gender_analysis(self, students: List[Dict]) -> Dict[str, Any]:
        """Perform detailed gender analysis on student names."""
        male_count = 0
        female_count = 0
        unknown_count = 0
        male_names = []
        female_names = []
        
        for student in students:
            name = student.get("name", "").lower()
            
            # Enhanced Malaysian naming pattern detection
            if ("bin " in name or 
                name.startswith(("muhammad", "ahmad", "mohd", "abdul", "syed", "wan", "tengku")) or
                any(male_name in name for male_name in ["zulkifli", "aidil", "hakim", "farid", "hassan", "razak", "azman", "ismail"])):
                male_count += 1
                male_names.append(student.get("name", ""))
            elif ("binti " in name or 
                  name.startswith(("nur", "siti", "nurul", "fatimah", "khadijah", "aishah")) or
                  any(female_name in name for female_name in ["aina", "haliza", "nurhaliza", "yusof", "zahra", "sarah"])):
                female_count += 1
                female_names.append(student.get("name", ""))
            else:
                unknown_count += 1
        
        total = male_count + female_count + unknown_count
        
        return {
            "male_count": male_count,
            "female_count": female_count,
            "unknown_count": unknown_count,
            "total_analyzed": total,
            "male_percentage": round((male_count / total * 100), 1) if total > 0 else 0,
            "female_percentage": round((female_count / total * 100), 1) if total > 0 else 0,
            "sample_male_names": male_names[:5],  # Show first 5 as examples
            "sample_female_names": female_names[:5],
            "analysis_method": "Enhanced Malaysian naming patterns with common name detection"
        }
    
    async def _perform_naming_pattern_analysis(self, students: List[Dict]) -> Dict[str, Any]:
        """Analyze naming patterns in student names."""
        patterns = {
            "bin_pattern": 0,
            "binti_pattern": 0,
            "muhammad_start": 0,
            "nur_start": 0,
            "siti_start": 0,
            "single_name": 0,
            "three_parts": 0,
            "four_parts": 0
        }
        
        for student in students:
            name = student.get("name", "").strip()
            name_parts = name.split()
            
            if "bin " in name.lower():
                patterns["bin_pattern"] += 1
            if "binti " in name.lower():
                patterns["binti_pattern"] += 1
            if name.lower().startswith("muhammad"):
                patterns["muhammad_start"] += 1
            if name.lower().startswith("nur"):
                patterns["nur_start"] += 1
            if name.lower().startswith("siti"):
                patterns["siti_start"] += 1
            
            if len(name_parts) == 1:
                patterns["single_name"] += 1
            elif len(name_parts) == 3:
                patterns["three_parts"] += 1
            elif len(name_parts) >= 4:
                patterns["four_parts"] += 1
        
        total = len(students)
        return {
            "total_analyzed": total,
            "patterns": patterns,
            "pattern_percentages": {k: round((v / total * 100), 1) for k, v in patterns.items()},
            "most_common_pattern": max(patterns, key=patterns.get) if patterns else "none"
        }
    
    async def _perform_demographic_analysis(self, students: List[Dict]) -> Dict[str, Any]:
        """Perform demographic analysis combining name patterns with academic data."""
        gender_stats = await self._perform_gender_analysis(students)
        
        # Analyze by department
        dept_stats = {}
        for student in students:
            dept = student.get("department", "Unknown")
            if dept not in dept_stats:
                dept_stats[dept] = {"total": 0, "male": 0, "female": 0}
            
            dept_stats[dept]["total"] += 1
            name = student.get("name", "").lower()
            
            if ("bin " in name or name.startswith(("muhammad", "ahmad", "mohd"))):
                dept_stats[dept]["male"] += 1
            elif ("binti " in name or name.startswith(("nur", "siti", "nurul"))):
                dept_stats[dept]["female"] += 1
        
        return {
            "gender_distribution": gender_stats,
            "department_breakdown": dept_stats,
            "total_departments": len(dept_stats),
            "analysis_scope": "Combined gender and department analysis"
        }
    
    async def _perform_ethnic_analysis(self, students: List[Dict]) -> Dict[str, Any]:
        """Analyze ethnic patterns in student names."""
        ethnic_patterns = {
            "malay_muslim": 0,
            "chinese": 0,
            "indian": 0,
            "other": 0
        }
        
        for student in students:
            name = student.get("name", "").lower()
            
            # Malay/Muslim patterns
            if ("bin " in name or "binti " in name or 
                name.startswith(("muhammad", "ahmad", "mohd", "abdul", "nur", "siti"))):
                ethnic_patterns["malay_muslim"] += 1
            # Chinese patterns (common surnames)
            elif any(surname in name for surname in ["tan", "lim", "lee", "wong", "chan", "ng", "teo", "koh"]):
                ethnic_patterns["chinese"] += 1
            # Indian patterns (common names)
            elif any(name_part in name for name_part in ["kumar", "singh", "raj", "devi", "sharma", "patel"]):
                ethnic_patterns["indian"] += 1
            else:
                ethnic_patterns["other"] += 1
        
        total = sum(ethnic_patterns.values())
        return {
            "total_analyzed": total,
            "ethnic_distribution": ethnic_patterns,
            "ethnic_percentages": {k: round((v / total * 100), 1) for k, v in ethnic_patterns.items()},
            "analysis_method": "Name-based ethnic pattern recognition"
        }
    
    async def _execute_query_users(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute query_users tool to search all users (students, staff, admin)."""
        try:
            # Get all users from service bridge
            users = self.service_bridge._search_users_advanced(arguments)
            
            return {
                "success": True,
                "count": len(users),
                "users": users,
                "criteria_used": arguments
            }
            
        except Exception as e:
            logger.error(f"Error in query_users: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "users": []
            }
    
    async def _execute_query_profiles(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute query_profiles tool to search user profiles."""
        try:
            # Get profiles from service bridge
            profiles = self.service_bridge._search_profiles_advanced(arguments)
            
            return {
                "success": True,
                "count": len(profiles),
                "profiles": profiles,
                "criteria_used": arguments
            }
            
        except Exception as e:
            logger.error(f"Error in query_profiles: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "profiles": []
            }
    
    async def _execute_query_showcase_posts(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute query_showcase_posts tool to search showcase posts."""
        try:
            # Get showcase posts from service bridge
            posts = self.service_bridge._search_showcase_posts_advanced(arguments)
            
            return {
                "success": True,
                "count": len(posts),
                "posts": posts,
                "criteria_used": arguments
            }
            
        except Exception as e:
            logger.error(f"Error in query_showcase_posts: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "posts": []
            }
    
    async def _execute_query_achievements(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute query_achievements tool to search achievements."""
        try:
            # Get achievements from service bridge
            achievements = self.service_bridge._search_achievements_advanced(arguments)
            
            return {
                "success": True,
                "count": len(achievements),
                "achievements": achievements,
                "criteria_used": arguments
            }
            
        except Exception as e:
            logger.error(f"Error in query_achievements: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "achievements": []
            }
    
    async def _execute_query_event_participations(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute query_event_participations tool to search event participations."""
        try:
            # Get event participations from service bridge
            participations = self.service_bridge._search_event_participations_advanced(arguments)
            
            return {
                "success": True,
                "count": len(participations),
                "participations": participations,
                "criteria_used": arguments
            }
            
        except Exception as e:
            logger.error(f"Error in query_event_participations: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__,
                "count": 0,
                "participations": []
            }
    
    async def _execute_advanced_analytics(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute advanced analytics with complex analysis capabilities."""
        try:
            analysis_type = arguments.get("analysis_type", "trend_analysis")
            entities = arguments.get("entities", ["users", "events"])
            time_range = arguments.get("time_range", "all_time")
            
            # Perform advanced analytics based on type
            if analysis_type == "trend_analysis":
                return await self._perform_trend_analysis(entities, time_range, arguments)
            elif analysis_type == "correlation_analysis":
                return await self._perform_correlation_analysis(entities, arguments)
            elif analysis_type == "performance_metrics":
                return await self._perform_performance_metrics(entities, arguments)
            elif analysis_type == "engagement_analysis":
                return await self._perform_engagement_analysis(entities, arguments)
            elif analysis_type == "demographic_insights":
                return await self._perform_demographic_insights(entities, arguments)
            elif analysis_type == "predictive_analysis":
                return await self._perform_predictive_analysis(entities, arguments)
            elif analysis_type == "comparative_analysis":
                return await self._perform_comparative_analysis(entities, arguments)
            elif analysis_type == "anomaly_detection":
                return await self._perform_anomaly_detection(entities, arguments)
            else:
                return {
                    "success": False,
                    "error": f"Unknown analysis type: {analysis_type}",
                    "analysis_type": analysis_type
                }
                
        except Exception as e:
            logger.error(f"Error in advanced_analytics: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _execute_cross_entity_query(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute cross-entity queries with relationship analysis."""
        try:
            query_type = arguments.get("query_type", "user_event_analysis")
            primary_entity = arguments.get("primary_entity", "users")
            secondary_entities = arguments.get("secondary_entities", ["events"])
            relationship_type = arguments.get("relationship_type", "direct")
            depth = arguments.get("depth", 2)
            
            # Perform cross-entity analysis
            if query_type == "user_event_analysis":
                return await self._analyze_user_event_relationships(primary_entity, secondary_entities, relationship_type, depth)
            elif query_type == "department_performance":
                return await self._analyze_department_performance(primary_entity, secondary_entities, arguments)
            elif query_type == "skill_correlation":
                return await self._analyze_skill_correlations(primary_entity, secondary_entities, arguments)
            elif query_type == "engagement_patterns":
                return await self._analyze_engagement_patterns(primary_entity, secondary_entities, arguments)
            elif query_type == "activity_analysis":
                return await self._analyze_activity_patterns(primary_entity, secondary_entities, arguments)
            elif query_type == "relationship_mapping":
                return await self._map_entity_relationships(primary_entity, secondary_entities, depth, arguments)
            else:
                return {
                    "success": False,
                    "error": f"Unknown query type: {query_type}",
                    "query_type": query_type
                }
                
        except Exception as e:
            logger.error(f"Error in cross_entity_query: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _execute_intelligent_search(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute intelligent semantic search with NLP understanding."""
        try:
            query = arguments.get("query", "")
            search_scope = arguments.get("search_scope", ["users", "events", "profiles"])
            search_type = arguments.get("search_type", "semantic")
            include_related = arguments.get("include_related", True)
            ranking_criteria = arguments.get("ranking_criteria", ["relevance", "recency"])
            
            # Perform intelligent search based on type
            if search_type == "semantic":
                return await self._perform_semantic_search(query, search_scope, include_related, ranking_criteria)
            elif search_type == "fuzzy":
                return await self._perform_fuzzy_search(query, search_scope, arguments)
            elif search_type == "exact":
                return await self._perform_exact_search(query, search_scope, arguments)
            elif search_type == "pattern":
                return await self._perform_pattern_search(query, search_scope, arguments)
            elif search_type == "contextual":
                return await self._perform_contextual_search(query, search_scope, arguments)
            else:
                return {
                    "success": False,
                    "error": f"Unknown search type: {search_type}",
                    "search_type": search_type
                }
                
        except Exception as e:
            logger.error(f"Error in intelligent_search: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _execute_predictive_insights(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute predictive insights and forecasting."""
        try:
            prediction_type = arguments.get("prediction_type", "trend_forecast")
            target_entity = arguments.get("target_entity", "users")
            time_horizon = arguments.get("time_horizon", "medium_term")
            confidence_level = arguments.get("confidence_level", 0.8)
            factors = arguments.get("factors", [])
            
            # Generate predictive insights
            if prediction_type == "trend_forecast":
                return await self._generate_trend_forecast(target_entity, time_horizon, confidence_level, factors)
            elif prediction_type == "behavior_prediction":
                return await self._predict_behavior_patterns(target_entity, time_horizon, confidence_level, factors)
            elif prediction_type == "performance_prediction":
                return await self._predict_performance_metrics(target_entity, time_horizon, confidence_level, factors)
            elif prediction_type == "engagement_forecast":
                return await self._forecast_engagement(target_entity, time_horizon, confidence_level, factors)
            elif prediction_type == "growth_prediction":
                return await self._predict_growth_patterns(target_entity, time_horizon, confidence_level, factors)
            elif prediction_type == "risk_assessment":
                return await self._assess_risks(target_entity, time_horizon, confidence_level, factors)
            else:
                return {
                    "success": False,
                    "error": f"Unknown prediction type: {prediction_type}",
                    "prediction_type": prediction_type
                }
                
        except Exception as e:
            logger.error(f"Error in predictive_insights: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _execute_admin_dashboard_analytics(self, arguments: Dict[str, Any]) -> Dict[str, Any]:
        """Execute admin dashboard analytics with KPIs and insights."""
        try:
            dashboard_type = arguments.get("dashboard_type", "overview")
            time_period = arguments.get("time_period", "this_month")
            include_recommendations = arguments.get("include_recommendations", True)
            alert_thresholds = arguments.get("alert_thresholds", {})
            visualization_type = arguments.get("visualization_type", "mixed")
            
            # Generate admin dashboard analytics
            if dashboard_type == "overview":
                return await self._generate_overview_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            elif dashboard_type == "user_management":
                return await self._generate_user_management_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            elif dashboard_type == "event_management":
                return await self._generate_event_management_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            elif dashboard_type == "performance_metrics":
                return await self._generate_performance_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            elif dashboard_type == "engagement_analysis":
                return await self._generate_engagement_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            elif dashboard_type == "system_health":
                return await self._generate_system_health_dashboard(time_period, include_recommendations, alert_thresholds, visualization_type)
            else:
                return {
                    "success": False,
                    "error": f"Unknown dashboard type: {dashboard_type}",
                    "dashboard_type": dashboard_type
                }
                
        except Exception as e:
            logger.error(f"Error in admin_dashboard_analytics: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }

    async def _perform_trend_analysis(self, entities: list, time_range: str, arguments: dict) -> dict:
        """Perform trend analysis on specified entities over a given time range."""
        from datetime import datetime, timedelta

        try:
            # Determine date range
            end_date = datetime.now()
            if time_range == 'last_quarter':
                start_date = end_date - timedelta(days=90)
            elif time_range == 'last_month':
                start_date = end_date - timedelta(days=30)
            elif time_range == 'last_week':
                start_date = end_date - timedelta(days=7)
            else: # all_time or other
                start_date = None

            results = {}
            
            if 'users' in entities or 'engagement' in arguments.get('metrics', []):
                # Analyze user engagement trend (showcase posts and event participations)
                
                # Fetch data
                showcase_posts = self.service_bridge._search_showcase_posts_advanced({})
                event_participations = self.service_bridge._search_event_participations_advanced({})

                # Filter by date and combine
                combined_activities = []
                for post in showcase_posts:
                    if 'created_at' in post and post['created_at']:
                        try:
                            created_at = datetime.fromisoformat(post['created_at'].replace('Z', '+00:00'))
                            if not start_date or created_at >= start_date:
                                combined_activities.append({'type': 'showcase_post', 'date': created_at})
                        except (ValueError, TypeError):
                            logger.warning(f"Could not parse date for showcase post: {post.get('post_id')}")
                
                for participation in event_participations:
                    if 'created_at' in participation and participation['created_at']:
                        try:
                            created_at = datetime.fromisoformat(participation['created_at'].replace('Z', '+00:00'))
                            if not start_date or created_at >= start_date:
                                combined_activities.append({'type': 'event_participation', 'date': created_at})
                        except (ValueError, TypeError):
                            logger.warning(f"Could not parse date for event participation: {participation.get('id')}")

                # Group by week
                trend_data = {}
                for activity in combined_activities:
                    week_start = (activity['date'] - timedelta(days=activity['date'].weekday())).strftime('%Y-%m-%d')
                    trend_data.setdefault(week_start, {'showcase_posts': 0, 'event_participations': 0, 'total': 0})
                    if activity['type'] == 'showcase_post':
                        trend_data[week_start]['showcase_posts'] += 1
                    else:
                        trend_data[week_start]['event_participations'] += 1
                    trend_data[week_start]['total'] += 1
                
                # Sort by week
                sorted_trend = sorted(trend_data.items())

                # Basic trend calculation
                trend = 'stable'
                if len(sorted_trend) > 1:
                    first_week_total = sorted_trend[0][1]['total']
                    last_week_total = sorted_trend[-1][1]['total']
                    if last_week_total > first_week_total:
                        trend = 'increasing'
                    elif last_week_total < first_week_total:
                        trend = 'decreasing'

                results['user_engagement_trend'] = {
                    'data': dict(sorted_trend),
                    'summary': f"Found {len(combined_activities)} engagement activities in the specified time range.",
                    'trend': trend,
                    'time_range': time_range
                }

            if 'events' in entities:
                # Analyze event creation trend
                events = self.service_bridge._search_events_advanced({})
                
                event_activities = []
                if events:
                    for event in events:
                        if 'created_at' in event and event['created_at']:
                            try:
                                created_at = datetime.fromisoformat(event['created_at'].replace('Z', '+00:00'))
                                if not start_date or created_at >= start_date:
                                    event_activities.append({'date': created_at})
                            except (ValueError, TypeError):
                                logger.warning(f"Could not parse date for event: {event.get('event_id')}")

                trend_data = {}
                for activity in event_activities:
                    week_start = (activity['date'] - timedelta(days=activity['date'].weekday())).strftime('%Y-%m-%d')
                    trend_data.setdefault(week_start, 0)
                    trend_data[week_start] += 1
                
                sorted_trend = sorted(trend_data.items())

                results['event_creation_trend'] = {
                    'data': dict(sorted_trend),
                    'summary': f"Found {len(event_activities)} events created in the specified time range.",
                    'time_range': time_range
                }

            if not results:
                 return {
                    "success": True,
                    "analysis_type": "trend_analysis",
                    "results": {"message": "No data found for the specified entities and time range."},
                    "criteria_used": arguments
                }


            return {
                "success": True,
                "analysis_type": "trend_analysis",
                "results": results,
                "criteria_used": arguments
            }

        except Exception as e:
            logger.error(f"Error in _perform_trend_analysis: {e}", exc_info=True)
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    async def _perform_correlation_analysis(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Correlation analysis not implemented."}

    async def _perform_performance_metrics(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Performance metrics not implemented."}

    async def _perform_engagement_analysis(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Engagement analysis not implemented."}

    async def _perform_demographic_insights(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Demographic insights not implemented."}

    async def _perform_predictive_analysis(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Predictive analysis not implemented."}

    async def _perform_comparative_analysis(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Comparative analysis not implemented."}

    async def _perform_anomaly_detection(self, entities: list, arguments: dict) -> dict:
        return {"success": True, "message": "Anomaly detection not implemented."}

