"""
Student Analytics API endpoints - Personal insights for mobile app users
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from typing import List, Dict, Any
import logging
from datetime import datetime, timedelta

# Supabase auth integration
from app.auth import verify_supabase_token, verify_admin_user
from app.database import get_db
from app.models.user import User, UserRole
from app.models.profile import Profile
from app.models.achievement import Achievement
from app.models.event import Event, EventParticipation
from app.models.showcase import ShowcasePost

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/student", tags=["Student Analytics"])

@router.get("/dashboard")
async def get_student_dashboard(
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get personalized dashboard data for the current student
    """
    try:
        user_id = current_user["uid"]
        
        # Get user and profile
        user = db.query(User).filter(User.uid == user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        profile = db.query(Profile).filter(Profile.user_id == user_id).first()
        
        # Get achievement stats
        total_achievements = db.query(Achievement).filter(Achievement.user_id == user_id).count()
        recent_achievements = db.query(Achievement)\
            .filter(Achievement.user_id == user_id)\
            .order_by(desc(Achievement.created_at))\
            .limit(3).all()
        
        # Get event participation stats
        total_events = db.query(EventParticipation).filter(EventParticipation.user_id == user_id).count()
        recent_events = db.query(EventParticipation)\
            .join(Event, EventParticipation.event_id == Event.id)\
            .filter(EventParticipation.user_id == user_id)\
            .order_by(desc(EventParticipation.created_at))\
            .limit(3).all()
        
        # Get showcase posts stats
        total_posts = db.query(ShowcasePost).filter(ShowcasePost.user_id == user_id).count()
        total_likes = db.query(func.sum(ShowcasePost.likes_count))\
            .filter(ShowcasePost.user_id == user_id).scalar() or 0
        
        # Calculate profile completion
        profile_completion = 0
        if profile:
            fields = [
                profile.full_name, profile.bio, profile.phone,
                profile.department, profile.faculty, profile.year_of_study,
                profile.skills, profile.interests
            ]
            completed_fields = sum(1 for field in fields if field)
            profile_completion = round((completed_fields / len(fields)) * 100)
        
        # Get department ranking (simplified)
        dept_students = []
        if profile and profile.department:
            dept_students = db.query(User)\
                .join(Profile, User.id == Profile.user_id)\
                .filter(Profile.department == profile.department)\
                .count()
        
        return {
            "user_info": {
                "name": user.name,
                "email": user.email,
                "department": profile.department if profile else None,
                "student_id": profile.student_id if profile else None,
                "profile_completion": profile_completion
            },
            "stats": {
                "achievements": {
                    "total": total_achievements,
                    "recent": [
                        {
                            "title": ach.title,
                            "category": ach.category,
                            "date": ach.created_at.isoformat() if ach.created_at else None
                        } for ach in recent_achievements
                    ]
                },
                "events": {
                    "total": total_events,
                    "recent": [
                        {
                            "event_title": participation.event.title if participation.event else "Unknown Event",
                            "date": participation.created_at.isoformat() if participation.created_at else None
                        } for participation in recent_events
                    ]
                },
                "showcase": {
                    "total_posts": total_posts,
                    "total_likes": total_likes
                },
                "department": {
                    "name": profile.department if profile else None,
                    "total_students": dept_students
                }
            },
            "insights": {
                "profile_completion": profile_completion,
                "activity_level": "High" if (total_achievements + total_events) > 5 else "Medium" if (total_achievements + total_events) > 2 else "Low",
                "engagement_score": min(100, (total_achievements * 10) + (total_events * 5) + (total_posts * 3))
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting student dashboard: {e}")
        raise HTTPException(status_code=500, detail="Failed to get dashboard data")

@router.get("/recommendations")
async def get_student_recommendations(
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get personalized recommendations for the current student
    """
    try:
        user_id = current_user["uid"]
        
        # Get user profile
        profile = db.query(Profile).filter(Profile.user_id == user_id).first()
        if not profile:
            return {
                "recommendations": [],
                "message": "Complete your profile to get personalized recommendations"
            }
        
        recommendations = []
        
        # Recommend events based on department
        if profile.department:
            dept_events = db.query(Event)\
                .filter(Event.category.ilike(f"%{profile.department}%"))\
                .filter(Event.is_active == True)\
                .order_by(desc(Event.created_at))\
                .limit(3).all()
            
            for event in dept_events:
                recommendations.append({
                    "type": "event",
                    "title": f"Event: {event.title}",
                    "description": f"Recommended based on your department ({profile.department})",
                    "data": {
                        "event_id": event.id,
                        "event_title": event.title,
                        "event_category": event.category,
                        "start_date": event.start_date.isoformat() if event.start_date else None
                    },
                    "priority": "high"
                })
        
        # Recommend skills to develop
        if profile.skills:
            current_skills = [skill.lower() for skill in profile.skills]
            related_skills = []
            
            # Simple skill recommendations based on current skills
            skill_suggestions = {
                "python": ["Machine Learning", "Data Science", "Django"],
                "javascript": ["React", "Node.js", "Vue.js"],
                "java": ["Spring Boot", "Android Development", "Microservices"],
                "flutter": ["Dart", "Mobile UI/UX", "Firebase"]
            }
            
            for skill in current_skills:
                if skill in skill_suggestions:
                    related_skills.extend(skill_suggestions[skill])
            
            for suggested_skill in related_skills[:2]:
                recommendations.append({
                    "type": "skill",
                    "title": f"Learn {suggested_skill}",
                    "description": f"Complements your existing {', '.join(current_skills[:2])} skills",
                    "data": {
                        "skill_name": suggested_skill,
                        "related_to": current_skills[:2]
                    },
                    "priority": "medium"
                })
        
        # Recommend profile completion
        if profile:
            missing_fields = []
            if not profile.bio: missing_fields.append("bio")
            if not profile.skills: missing_fields.append("skills")
            if not profile.interests: missing_fields.append("interests")
            if not profile.linkedin_url: missing_fields.append("LinkedIn profile")
            
            if missing_fields:
                recommendations.append({
                    "type": "profile",
                    "title": "Complete Your Profile",
                    "description": f"Add {', '.join(missing_fields[:2])} to improve your visibility",
                    "data": {
                        "missing_fields": missing_fields,
                        "completion_benefit": "Better recommendations and networking opportunities"
                    },
                    "priority": "high"
                })
        
        # Find similar students for networking
        if profile.department:
            similar_students = db.query(User)\
                .join(Profile, User.id == Profile.user_id)\
                .filter(Profile.department == profile.department)\
                .filter(User.id != user_id)\
                .limit(2).all()
            
            if similar_students:
                recommendations.append({
                    "type": "networking",
                    "title": "Connect with Peers",
                    "description": f"Found {len(similar_students)} students in your department",
                    "data": {
                        "students": [
                            {
                                "name": student.name,
                                "department": student.profile[0].department if student.profile else None
                            } for student in similar_students
                        ]
                    },
                    "priority": "low"
                })
        
        return {
            "recommendations": recommendations,
            "total_count": len(recommendations),
            "last_updated": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting recommendations: {e}")
        raise HTTPException(status_code=500, detail="Failed to get recommendations")

@router.get("/progress")
async def get_student_progress(
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get student progress analytics over time
    """
    try:
        user_id = current_user["uid"]
        
        # Get achievements over time (last 6 months)
        six_months_ago = datetime.utcnow() - timedelta(days=180)
        
        achievements_timeline = db.query(
            func.date_trunc('month', Achievement.created_at).label('month'),
            func.count(Achievement.id).label('count')
        ).filter(
            Achievement.user_id == user_id,
            Achievement.created_at >= six_months_ago
        ).group_by(
            func.date_trunc('month', Achievement.created_at)
        ).order_by('month').all()
        
        # Get event participation over time
        events_timeline = db.query(
            func.date_trunc('month', EventParticipation.created_at).label('month'),
            func.count(EventParticipation.id).label('count')
        ).filter(
            EventParticipation.user_id == user_id,
            EventParticipation.created_at >= six_months_ago
        ).group_by(
            func.date_trunc('month', EventParticipation.created_at)
        ).order_by('month').all()
        
        # Calculate growth metrics
        total_achievements = db.query(Achievement).filter(Achievement.user_id == user_id).count()
        total_events = db.query(EventParticipation).filter(EventParticipation.user_id == user_id).count()
        
        # Recent activity (last 30 days)
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        recent_achievements = db.query(Achievement)\
            .filter(Achievement.user_id == user_id, Achievement.created_at >= thirty_days_ago)\
            .count()
        recent_events = db.query(EventParticipation)\
            .filter(EventParticipation.user_id == user_id, EventParticipation.created_at >= thirty_days_ago)\
            .count()
        
        return {
            "timeline": {
                "achievements": [
                    {
                        "month": item.month.isoformat() if item.month else None,
                        "count": item.count
                    } for item in achievements_timeline
                ],
                "events": [
                    {
                        "month": item.month.isoformat() if item.month else None,
                        "count": item.count
                    } for item in events_timeline
                ]
            },
            "totals": {
                "achievements": total_achievements,
                "events": total_events,
                "showcase_posts": db.query(ShowcasePost).filter(ShowcasePost.user_id == user_id).count()
            },
            "recent_activity": {
                "achievements_last_30_days": recent_achievements,
                "events_last_30_days": recent_events,
                "activity_trend": "increasing" if (recent_achievements + recent_events) > 2 else "stable"
            },
            "milestones": [
                {"name": "First Achievement", "achieved": total_achievements > 0},
                {"name": "Event Participant", "achieved": total_events > 0},
                {"name": "Active Member", "achieved": (total_achievements + total_events) > 5},
                {"name": "High Achiever", "achieved": total_achievements > 10}
            ]
        }
        
    except Exception as e:
        logger.error(f"Error getting student progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to get progress data")