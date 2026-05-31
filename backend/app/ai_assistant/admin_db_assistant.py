"""
Admin Database Assistant - Standalone module for admin database queries
"""

import logging
from typing import Any, Dict, List
from sqlalchemy.orm import Session
from sqlalchemy import text

from . import schemas

log = logging.getLogger(__name__)


class AdminDatabaseAssistant:
    """Admin-only database query assistant"""
    
    def __init__(self, db: Session):
        self.db = db
        
    def is_admin_user(self, user: Dict[str, Any]) -> bool:
        """Check if user is admin"""
        if not user:
            return False
        return (
            user.get("role") == "admin" or 
            user.get("email") in ["admin@uthm.edu.my", "admin@example.com"]
        )
    
    async def handle_admin_query(
        self, 
        command: str, 
        current_user: Dict[str, Any]
    ) -> schemas.AICommandResponse | None:
        """Handle admin database queries"""
        
        # DEBUG: Log user info untuk troubleshoot
        log.info("🔍 ADMIN DEBUG - User check: %s", current_user)
        log.info("🔍 ADMIN DEBUG - Email: %s", current_user.get("email") if current_user else "None")
        log.info("🔍 ADMIN DEBUG - Role: %s", current_user.get("role") if current_user else "None")
        
        # Production: enforce admin-only access. Do NOT allow non-admin users to run admin queries.
        if not self.is_admin_user(current_user):
            log.warning("❌ ADMIN ACCESS DENIED - User not recognized as admin")
            # Return a structured AICommandResponse indicating permission denied
            return schemas.AICommandResponse(
                success=False,
                message=("Access denied: You must be an admin to run this command. "
                         "If you believe this is an error, contact the system administrator."),
                source=schemas.AISource.MANUAL,
                data={"admin_query": True, "permission": "denied"}
            )
            
        log.info("🔐 ADMIN DATABASE QUERY: %s", command)
        
        # Parse admin intent
        db_intent = self._parse_admin_intent(command)
        if not db_intent:
            return None
        
        log.info("📊 Parsed admin intent: %s", db_intent)
        
        try:
            # Execute query
            result = await self._execute_admin_query(db_intent)
            
            # Format response
            return self._format_admin_response(result, command)
            
        except Exception as e:
            log.error(f"Admin database query error: {e}")
            return schemas.AICommandResponse(
            success=False,
            message=f"❌ Sorry lah! Database query failed: {str(e)}",
            source=schemas.AISource.MANUAL,
            data={"error": str(e), "admin_query": True}
        )
    
    def _parse_admin_intent(self, command: str) -> Dict[str, Any] | None:
        """Parse admin command to database intent"""
        command_lower = command.lower()
        
        # Student queries
        if any(word in command_lower for word in ["students", "pelajar", "student"]):
            if any(word in command_lower for word in ["list", "show", "tunjuk"]):
                return {"type": "list_students"}
            elif any(word in command_lower for word in ["incomplete", "tak lengkap"]):
                return {"type": "incomplete_profiles"}
        
        # Event queries  
        elif any(word in command_lower for word in ["events", "acara", "event"]):
            if any(word in command_lower for word in ["list", "show", "tunjuk"]):
                return {"type": "list_events"}
        
        # Analytics queries
        elif any(word in command_lower for word in ["analytics", "stats", "department"]):
            return {"type": "department_stats"}
        
        return None
    
    async def _execute_admin_query(self, db_intent: Dict[str, Any]) -> Dict[str, Any]:
        """Execute admin database query"""
        
        query_type = db_intent["type"]
        
        if query_type == "list_students":
            query = """
                SELECT u.name, u.email, u.department, u.student_id, u.created_at, u.is_active 
                FROM users u 
                WHERE u.role='student' 
                ORDER BY u.created_at DESC 
                LIMIT 20
            """
            
        elif query_type == "incomplete_profiles":
            query = """
                SELECT u.name, u.email, u.department, u.created_at 
                FROM users u 
                LEFT JOIN profiles p ON u.id = p.user_id 
                WHERE u.role='student' AND (p.is_profile_complete = false OR p.id IS NULL)
                ORDER BY u.created_at DESC
            """
            
        elif query_type == "list_events":
            query = """
                SELECT e.title, e.event_date, e.location, e.is_active, u.name as organizer_name
                FROM events e
                LEFT JOIN users u ON e.organizer_id = u.id
                WHERE e.is_active = true
                ORDER BY e.event_date DESC
                LIMIT 15
            """
            
        elif query_type == "department_stats":
            query = """
                SELECT u.department, 
                       COUNT(*) as total_students,
                       COUNT(CASE WHEN p.is_profile_complete = true THEN 1 END) as completed_profiles
                FROM users u
                LEFT JOIN profiles p ON u.id = p.user_id
                WHERE u.role = 'student' AND u.department IS NOT NULL
                GROUP BY u.department
                ORDER BY total_students DESC
            """
            
        else:
            return {"type": "unknown", "data": []}
        
        # Execute SQL
        try:
            raw_result = self.db.execute(text(query)).fetchall()
            
            # Convert to dict format
            results = []
            for row in raw_result:
                row_dict = {}
                for i, column in enumerate(row.keys()):
                    row_dict[column] = row[i]
                results.append(row_dict)
            
            return {"type": query_type, "data": results}
            
        except Exception as e:
            log.error(f"SQL execution failed: {e}")
            return {"type": "error", "data": [], "error": str(e)}
    
    def _format_admin_response(
        self, 
        result: Dict[str, Any], 
        original_query: str
    ) -> schemas.AICommandResponse:
        """Format admin database response"""

        query_type = result["type"]
        data = result["data"]

        if query_type == "list_students":
            if not data:
                message = "Wah, sorry lah! 🙈 I couldn't find any students matching your criteria. Can you try adjusting your search parameters maybe?"
            else:
                count = len(data)
                message = f"Wah bestnya! 🎉 I found **{count} students** for you! Here's the info:\n\n"
                
                for i, student in enumerate(data[:10], 1):
                    status = "🟢" if student.get('is_active') else "🔴"
                    status_text = "Active" if student.get('is_active') else "Inactive"
                    message += f"{i}. {status} **{student.get('name', 'N/A')}** ({status_text})\n"
                    message += f"   📧 Email: {student.get('email', 'N/A')}\n"
                    message += f"   🏢 Department: {student.get('department', 'N/A')}\n"
                    if student.get('student_id'):
                        message += f"   🆔 Student ID: {student['student_id']}\n"
                    message += "\n"
                
                if len(data) > 10:
                    message += f"... and {len(data) - 10} more students! Tqvm for your patience!\n\n"
                message += "Let me know if you need more specific details about any particular student!"
        
        elif query_type == "incomplete_profiles":
            if not data:
                message = "Wah bestnya! 🎉 Great news! All students have completed their profiles! The database is looking super tidy! 📋✅"
            else:
                count = len(data)
                message = f"Here are **{count} students** whose profiles need attention: 📝\n\n"
                
                for i, student in enumerate(data[:8], 1):
                    message += f"{i}. **{student.get('name', 'N/A')}**\n"
                    message += f"   📧 Email: {student.get('email', 'N/A')}\n"
                    message += f"   🏢 Department: {student.get('department', 'N/A')}\n\n"
                
                if len(data) > 8:
                    message += f"... and {len(data) - 8} more students need profile completion.\n\n"
                message += "Maybe you'd like to send them a friendly reminder about completing their profiles? 😊"
        
        elif query_type == "list_events":
            if not data:
                message = "Hmm, sorry lah! 🙈 I couldn't find any events matching your criteria. But don't worry, you can always create new ones or adjust your search! 🗓️"
            else:
                count = len(data)
                message = f"Found **{count} events** in the system! Here they are: 📅\n\n"
                
                for i, event in enumerate(data[:8], 1):
                    message += f"{i}. **{event.get('title', 'N/A')}**\n"
                    message += f"   📅 Date: {event.get('event_date', 'N/A')}\n"
                    message += f"   📍 Location: {event.get('location', 'N/A')}\n"
                    if event.get('organizer_name'):
                        message += f"   👤 Organizer: {event['organizer_name']}\n"
                    message += "\n"
                
                if len(data) > 8:
                    message += f"... and {len(data) - 8} more events!\n\n"
                message += "Need details about any specific event? Just ask me! 🤗"
        
        elif query_type == "department_stats":
            if not data:
                message = "Hmm, sorry lah! 🙈 I couldn't retrieve the department statistics. Maybe try again in a bit? 📊"
            else:
                count = len(data)
                message = f"Here's the breakdown for **{count} departments**: 🏢\n\n"
                
                for dept in data:
                    total = dept.get('total_students', 0)
                    completed = dept.get('completed_profiles', 0)
                    rate = round((completed / total * 100), 1) if total > 0 else 0
                    rate_emoji = "🟢" if rate >= 80 else "🟡" if rate >= 60 else "🔴"
                    
                    status_desc = "Excellent!" if rate >= 80 else "Good!" if rate >= 60 else "Needs attention"
                    
                    message += f"{rate_emoji} **{dept.get('department', 'N/A')}** - {status_desc}\n"
                    message += f"   👥 Total students: {total}\n"
                    message += f"   ✅ Completed profiles: {completed} ({rate}%)\n\n"
                
                message += "This data shows how well-engaged students are across different departments! 🚀"
        
        else:
            count = len(data) if isinstance(data, list) else 0
            message = f"✅ Query executed successfully! I found **{count} results** for you! No prob! 🎉"

        return schemas.AICommandResponse(
            success=True,
            message=message,
            source=schemas.AISource.OPENROUTER,
            data={
                "query_type": "admin_database",
                "original_query": original_query,
                "results": data,
                "admin_only": True
            },
            steps=[
                schemas.AICommandStep(
                    label="🔐 Admin Database Access",
                    detail=f"Executed {query_type} using direct SQL"
                )
            ]
        )
