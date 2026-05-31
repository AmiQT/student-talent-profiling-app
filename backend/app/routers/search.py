"""
Advanced Search API endpoints - Features Firebase cannot handle efficiently
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func, and_, or_, text
from typing import List, Optional, Dict, Any
import logging
from datetime import datetime, timedelta

# Firebase auth removed - using Supabase auth
from app.database import get_db
from app.auth import verify_supabase_token
from app.models.user import User, UserRole
from app.models.profile import Profile
from app.models.achievement import Achievement
from app.models.event import Event, EventParticipation
from app.models.showcase import ShowcasePost

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/search", tags=["Advanced Search"])

# =============================================================================
# ACCESS CONTROL HELPERS
# =============================================================================

# Sensitive fields that only PAK or admin can see
SENSITIVE_FIELDS = [
    'cgpa', 'phone_number', 'address', 'email', 'academic_info',
    'kokurikulum_score', 'kokurikulum_credits', 'kokurikulum_activities',
    'balance_metrics', 'personal_advisor', 'personal_advisor_email',
    'experiences', 'projects', 'phone', 'headline'
]

def is_user_pak_of_student(pak_user: User, student_profile: Profile) -> bool:
    """
    Check if the given user (PAK) is the personal advisor of the student.
    Returns True if the user is the PAK for this student.
    """
    if not pak_user or not student_profile:
        return False
    
    pak_name = pak_user.name.lower() if pak_user.name else ""
    pak_email = pak_user.email.lower() if pak_user.email else ""
    
    # Check direct personal_advisor field
    if student_profile.personal_advisor:
        if pak_name in student_profile.personal_advisor.lower():
            return True
    
    # Check personal_advisor_email field
    if student_profile.personal_advisor_email:
        if pak_email == student_profile.personal_advisor_email.lower():
            return True
    
    # Check in academic_info JSON
    if student_profile.academic_info and isinstance(student_profile.academic_info, dict):
        academic_pak = student_profile.academic_info.get('personalAdvisor') or \
                       student_profile.academic_info.get('personal_advisor') or ''
        if academic_pak and pak_name in academic_pak.lower():
            return True
    
    return False

def filter_student_data(student_data: dict, can_view_sensitive: bool = False) -> dict:
    """
    Filter student data based on access level.
    - PAK/Admin: can see all data
    - Others: only basic public info (name, department, skills, interests)
    """
    if can_view_sensitive:
        return student_data
    
    # Create filtered version - only public info
    public_data = {
        'id': student_data.get('id'),
        'name': student_data.get('name'),
        'full_name': student_data.get('full_name'),
        'department': student_data.get('department'),
        'faculty': student_data.get('faculty'),
        'year_of_study': student_data.get('year_of_study'),
        'student_id': student_data.get('student_id'),
        'skills': student_data.get('skills', []),
        'interests': student_data.get('interests', []),
        'profile_image_url': student_data.get('profile_image_url'),
        'bio': student_data.get('bio'),
        'created_at': student_data.get('created_at'),
        'achievement_count': student_data.get('achievement_count'),
        'event_participation_count': student_data.get('event_participation_count'),
    }
    
    # Remove None values
    return {k: v for k, v in public_data.items() if v is not None}

def get_user_access_level(current_user: dict, db: Session) -> tuple:
    """
    Get the current user's access level and user object.
    Returns: (user_object, role, is_admin)
    """
    user_id = current_user.get("sub") or current_user.get("user_id")
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        return None, None, False
    
    role = user.role
    is_admin = role == "admin"
    
    return user, role, is_admin

@router.get("/students")
async def search_students(
    # Search parameters
    q: Optional[str] = Query(None, description="General search query"),
    name: Optional[str] = Query(None, description="Search by name"),
    email: Optional[str] = Query(None, description="Search by email"),
    student_id: Optional[str] = Query(None, description="Search by student ID"),
    
    # PAK (Personal Advisor) filter - NEW
    pak: Optional[str] = Query(None, description="Search by Personal Advisor (PAK) name"),
    personal_advisor: Optional[str] = Query(None, description="Alias for PAK search"),
    
    # Filter parameters
    department: Optional[str] = Query(None, description="Filter by department"),
    faculty: Optional[str] = Query(None, description="Filter by faculty"),
    year_of_study: Optional[str] = Query(None, description="Filter by year of study"),
    skills: Optional[str] = Query(None, description="Filter by skills (comma-separated)"),
    interests: Optional[str] = Query(None, description="Filter by interests (comma-separated)"),
    
    # Achievement filters
    min_achievements: Optional[int] = Query(None, description="Minimum number of achievements"),
    achievement_category: Optional[str] = Query(None, description="Filter by achievement category"),
    
    # Event participation filters
    min_events: Optional[int] = Query(None, description="Minimum number of events attended"),
    event_category: Optional[str] = Query(None, description="Filter by event category"),
    
    # CGPA filter
    min_cgpa: Optional[float] = Query(None, description="Minimum CGPA"),
    max_cgpa: Optional[float] = Query(None, description="Maximum CGPA"),
    
    # Kokurikulum filters - NEW
    min_koku_score: Optional[float] = Query(None, description="Minimum kokurikulum score"),
    max_koku_score: Optional[float] = Query(None, description="Maximum kokurikulum score"),
    
    # Pagination
    limit: int = Query(20, le=100, description="Maximum results"),
    offset: int = Query(0, description="Pagination offset"),
    
    # Sorting
    sort_by: Optional[str] = Query("name", description="Sort by field"),
    sort_order: Optional[str] = Query("asc", description="Sort order (asc/desc)"),
    
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Advanced student search with multiple filters and sorting
    This demonstrates complex queries that Firebase cannot handle efficiently
    """
    try:
        # Base query with joins
        query = db.query(User).join(Profile, User.id == Profile.user_id, isouter=True)\
                  .filter(User.role == UserRole.student)
        
        # Apply search filters
        if q:
            search_term = f"%{q}%"
            query = query.filter(
                or_(
                    User.name.ilike(search_term),
                    User.email.ilike(search_term),
                    Profile.full_name.ilike(search_term),
                    Profile.student_id.ilike(search_term),
                    Profile.bio.ilike(search_term),
                    Profile.personal_advisor.ilike(search_term),  # Search by PAK
                    # Also search in academic_info JSON for PAK
                    func.cast(Profile.academic_info, text('TEXT')).ilike(search_term)
                )
            )
        
        if name:
            name_term = f"%{name}%"
            query = query.filter(
                or_(
                    User.name.ilike(name_term),
                    Profile.full_name.ilike(name_term)
                )
            )
        
        if email:
            query = query.filter(User.email.ilike(f"%{email}%"))
        
        if student_id:
            query = query.filter(
                or_(
                    User.student_id.ilike(f"%{student_id}%"),
                    Profile.student_id.ilike(f"%{student_id}%")
                )
            )
        
        # Apply PAK (Personal Advisor) filter - NEW
        pak_search = pak or personal_advisor
        if pak_search:
            pak_term = f"%{pak_search}%"
            query = query.filter(
                or_(
                    Profile.personal_advisor.ilike(pak_term),
                    # Also search in academic_info JSON for personalAdvisor
                    func.cast(Profile.academic_info, text('TEXT')).ilike(f'%personalAdvisor%{pak_search}%'),
                    func.cast(Profile.academic_info, text('TEXT')).ilike(f'%personal_advisor%{pak_search}%')
                )
            )
        
        # Apply department/faculty filters
        if department:
            query = query.filter(
                or_(
                    User.department.ilike(f"%{department}%"),
                    Profile.department.ilike(f"%{department}%")
                )
            )
        
        if faculty:
            query = query.filter(Profile.faculty.ilike(f"%{faculty}%"))
        
        if year_of_study:
            query = query.filter(Profile.year_of_study == year_of_study)
        
        # Apply CGPA filters (handle as string first)
        if min_cgpa is not None:
            query = query.filter(
                and_(
                    Profile.cgpa.isnot(None),
                    Profile.cgpa != '',
                    text("CAST(profiles.cgpa AS FLOAT) >= :min_cgpa")
                )
            ).params(min_cgpa=min_cgpa)
        
        if max_cgpa is not None:
            query = query.filter(
                and_(
                    Profile.cgpa.isnot(None),
                    Profile.cgpa != '',
                    text("CAST(profiles.cgpa AS FLOAT) <= :max_cgpa")
                )
            ).params(max_cgpa=max_cgpa)
        
        # Apply skills filter (PostgreSQL JSON array search)
        if skills:
            skill_list = [skill.strip() for skill in skills.split(',')]
            for skill in skill_list:
                query = query.filter(
                    func.cast(Profile.skills, text('TEXT')).like(f'%{skill}%')
                )
        
        # Apply interests filter (PostgreSQL JSON array search)
        if interests:
            interest_list = [interest.strip() for interest in interests.split(',')]
            for interest in interest_list:
                query = query.filter(
                    func.cast(Profile.interests, text('TEXT')).like(f'%{interest}%')
                )
        
        # Apply kokurikulum score filters - NEW
        if min_koku_score is not None:
            query = query.filter(
                and_(
                    Profile.kokurikulum_score.isnot(None),
                    Profile.kokurikulum_score >= min_koku_score
                )
            )
        
        if max_koku_score is not None:
            query = query.filter(
                and_(
                    Profile.kokurikulum_score.isnot(None),
                    Profile.kokurikulum_score <= max_koku_score
                )
            )
        
        # Apply achievement filters (subquery)
        if min_achievements is not None or achievement_category:
            achievement_subquery = db.query(Achievement.user_id)
            
            if achievement_category:
                achievement_subquery = achievement_subquery.filter(
                    Achievement.category.ilike(f"%{achievement_category}%")
                )
            
            if min_achievements is not None:
                achievement_counts = achievement_subquery.group_by(Achievement.user_id)\
                                                       .having(func.count(Achievement.id) >= min_achievements)
                query = query.filter(User.id.in_(achievement_counts))
            else:
                query = query.filter(User.id.in_(achievement_subquery))
        
        # Apply event participation filters (subquery)
        if min_events is not None or event_category:
            event_subquery = db.query(EventParticipation.user_id)\
                              .join(Event, EventParticipation.event_id == Event.id)
            
            if event_category:
                event_subquery = event_subquery.filter(
                    Event.category.ilike(f"%{event_category}%")
                )
            
            if min_events is not None:
                event_counts = event_subquery.group_by(EventParticipation.user_id)\
                                           .having(func.count(EventParticipation.id) >= min_events)
                query = query.filter(User.id.in_(event_counts))
            else:
                query = query.filter(User.id.in_(event_subquery))
        
        # Apply sorting
        if sort_by == "name":
            sort_field = User.name
        elif sort_by == "email":
            sort_field = User.email
        elif sort_by == "department":
            sort_field = Profile.department
        elif sort_by == "cgpa":
            sort_field = Profile.cgpa
        elif sort_by == "created_at":
            sort_field = User.created_at
        else:
            sort_field = User.name
        
        if sort_order.lower() == "desc":
            sort_field = sort_field.desc()
        
        query = query.order_by(sort_field)
        
        # Get total count before pagination
        total_count = query.count()
        
        # Apply pagination
        students = query.offset(offset).limit(limit).all()
        
        # Get current user's access level
        requester_user, requester_role, is_admin = get_user_access_level(current_user, db)
        is_lecturer = requester_role == "lecturer"
        
        # Format results with access control
        results = []
        for user in students:
            profile = user.profile[0] if user.profile else None
            
            # Determine if requester can view sensitive info for this student
            # PAK can only see full info of THEIR OWN students, Admin can see all
            can_view_sensitive = False
            if is_admin:
                can_view_sensitive = True
            elif is_lecturer and profile:
                can_view_sensitive = is_user_pak_of_student(requester_user, profile)
            elif requester_user and str(requester_user.id) == str(user.id):
                # Users can always see their own full data
                can_view_sensitive = True
            
            # Get achievement count
            achievement_count = db.query(Achievement).filter(Achievement.user_id == user.id).count()
            
            # Get event participation count
            event_count = db.query(EventParticipation).filter(EventParticipation.user_id == user.id).count()
            
            # Build full student data
            full_student_data = {
                "id": user.id,
                "name": user.name,
                "email": user.email if can_view_sensitive else None,
                "student_id": user.student_id or (profile.student_id if profile else None),
                "department": user.department or (profile.department if profile else None),
                "faculty": profile.faculty if profile else None,
                "year_of_study": profile.year_of_study if profile else None,
                "cgpa": (profile.cgpa if profile else None) if can_view_sensitive else None,
                "skills": profile.skills if profile else [],
                "interests": profile.interests if profile else [],
                "achievement_count": achievement_count,
                "event_participation_count": event_count,
                "profile_image_url": profile.profile_image_url if profile else None,
                "bio": profile.bio if profile else None,
                "created_at": user.created_at.isoformat() if user.created_at else None,
                # Sensitive PAK fields - only if can view
                "personal_advisor": (profile.personal_advisor if profile else None) if can_view_sensitive else None,
                "personal_advisor_email": (profile.personal_advisor_email if profile else None) if can_view_sensitive else None,
                # Sensitive Kokurikulum metrics - only if can view
                "kokurikulum_score": (profile.kokurikulum_score if profile else None) if can_view_sensitive else None,
                "kokurikulum_credits": (profile.kokurikulum_credits if profile else None) if can_view_sensitive else None,
                "kokurikulum_activities": (profile.kokurikulum_activities if profile else []) if can_view_sensitive else None,
                "balance_metrics": (profile.get_balance_metrics() if profile else None) if can_view_sensitive else None,
                # Flag to indicate access level
                "_access_level": "full" if can_view_sensitive else "limited",
            }
            
            # Filter out None values and add to results
            filtered_data = {k: v for k, v in full_student_data.items() if v is not None}
            results.append(filtered_data)
        
        return {
            "students": results,
            "pagination": {
                "total": total_count,
                "limit": limit,
                "offset": offset,
                "has_more": offset + limit < total_count
            },
            "filters_applied": {
                "search_query": q,
                "department": department,
                "faculty": faculty,
                "skills": skills,
                "interests": interests,
                "min_achievements": min_achievements,
                "min_events": min_events,
                "min_cgpa": min_cgpa,
                "max_cgpa": max_cgpa,
                "personal_advisor": pak_search,  # NEW: PAK filter
                "min_koku_score": min_koku_score,  # NEW: Koku filter
                "max_koku_score": max_koku_score,  # NEW: Koku filter
            },
            "sorting": {
                "sort_by": sort_by,
                "sort_order": sort_order
            }
        }
        
    except Exception as e:
        logger.error(f"Error in advanced student search: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@router.get("/similar-students/{student_id}")
async def find_similar_students(
    student_id: str,
    limit: int = Query(10, le=20, description="Maximum similar students to return"),
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Find students similar to the given student based on skills, interests, and department
    This uses advanced similarity algorithms that Firebase cannot perform
    """
    try:
        # Get the target student's profile
        target_user = db.query(User).filter(User.id == student_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Student not found")
        
        target_profile = db.query(Profile).filter(Profile.user_id == student_id).first()
        if not target_profile:
            return {
                "similar_students": [],
                "message": "No profile data available for similarity matching"
            }
        
        # Get all other students with profiles
        other_students = db.query(User).join(Profile, User.id == Profile.user_id)\
                          .filter(User.role == UserRole.student)\
                          .filter(User.id != student_id).all()
        
        # Calculate similarity scores
        similar_students = []
        
        for student in other_students:
            profile = student.profile[0] if student.profile else None
            if not profile:
                continue
            
            similarity_score = 0
            factors = []
            
            # Department similarity (high weight)
            if target_profile.department and profile.department:
                if target_profile.department.lower() == profile.department.lower():
                    similarity_score += 30
                    factors.append("Same department")
            
            # Faculty similarity (medium weight)
            if target_profile.faculty and profile.faculty:
                if target_profile.faculty.lower() == profile.faculty.lower():
                    similarity_score += 20
                    factors.append("Same faculty")
            
            # Year of study similarity (low weight)
            if target_profile.year_of_study and profile.year_of_study:
                if target_profile.year_of_study == profile.year_of_study:
                    similarity_score += 10
                    factors.append("Same year")
            
            # Skills similarity (high weight)
            if target_profile.skills and profile.skills:
                target_skills = set([skill.lower() for skill in target_profile.skills])
                student_skills = set([skill.lower() for skill in profile.skills])
                common_skills = target_skills.intersection(student_skills)
                if common_skills:
                    skill_score = len(common_skills) * 5
                    similarity_score += skill_score
                    factors.append(f"{len(common_skills)} common skills")
            
            # Interests similarity (medium weight)
            if target_profile.interests and profile.interests:
                target_interests = set([interest.lower() for interest in target_profile.interests])
                student_interests = set([interest.lower() for interest in profile.interests])
                common_interests = target_interests.intersection(student_interests)
                if common_interests:
                    interest_score = len(common_interests) * 3
                    similarity_score += interest_score
                    factors.append(f"{len(common_interests)} common interests")
            
            # CGPA similarity (low weight)
            if target_profile.cgpa and profile.cgpa:
                try:
                    target_cgpa = float(target_profile.cgpa)
                    student_cgpa = float(profile.cgpa)
                    cgpa_diff = abs(target_cgpa - student_cgpa)
                    if cgpa_diff <= 0.5:
                        similarity_score += 15
                        factors.append("Similar CGPA")
                    elif cgpa_diff <= 1.0:
                        similarity_score += 5
                        factors.append("Close CGPA")
                except ValueError:
                    pass
            
            if similarity_score > 0:
                similar_students.append({
                    "student": {
                        "id": student.id,
                        "name": student.name,
                        "email": student.email,
                        "department": profile.department,
                        "faculty": profile.faculty,
                        "year_of_study": profile.year_of_study,
                        "cgpa": profile.cgpa,
                        "skills": profile.skills,
                        "interests": profile.interests,
                        "profile_image_url": profile.profile_image_url
                    },
                    "similarity_score": similarity_score,
                    "similarity_factors": factors
                })
        
        # Sort by similarity score and limit results
        similar_students.sort(key=lambda x: x["similarity_score"], reverse=True)
        similar_students = similar_students[:limit]
        
        return {
            "target_student": {
                "id": target_user.id,
                "name": target_user.name,
                "department": target_profile.department,
                "skills": target_profile.skills,
                "interests": target_profile.interests
            },
            "similar_students": similar_students,
            "total_found": len(similar_students)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error finding similar students: {e}")
        raise HTTPException(status_code=500, detail=f"Similarity search failed: {str(e)}")


@router.get("/pak/my-students")
async def get_pak_students(
    limit: int = Query(50, le=100, description="Maximum results"),
    offset: int = Query(0, description="Pagination offset"),
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get all students assigned to the current PAK (Personal Advisor)
    PAK can view full information of their assigned students
    Only accessible by lecturers
    """
    try:
        # Get current user info
        user_id = current_user.get("sub") or current_user.get("user_id")
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Verify user is a lecturer
        if user.role != "lecturer":
            raise HTTPException(
                status_code=403, 
                detail="Only lecturers (PAK) can access this endpoint"
            )
        
        # Get the lecturer's name/email to match with students' personal_advisor
        pak_name = user.name
        pak_email = user.email
        
        # Query students who have this PAK assigned
        query = db.query(User).join(Profile, User.id == Profile.user_id)\
                  .filter(User.role == "student")\
                  .filter(
                      or_(
                          Profile.personal_advisor.ilike(f"%{pak_name}%"),
                          Profile.personal_advisor_email == pak_email,
                          # Also check in academic_info JSON
                          func.cast(Profile.academic_info, text('TEXT')).ilike(f'%{pak_name}%')
                      )
                  )
        
        total_count = query.count()
        students = query.offset(offset).limit(limit).all()
        
        results = []
        for student in students:
            profile = student.profile[0] if student.profile else None
            
            # Get achievement count
            achievement_count = db.query(Achievement).filter(Achievement.user_id == student.id).count()
            
            # Get event participation count  
            event_count = db.query(EventParticipation).filter(EventParticipation.user_id == student.id).count()
            
            # Full student information for PAK
            student_data = {
                "id": student.id,
                "name": student.name,
                "email": student.email,
                "student_id": student.student_id or (profile.student_id if profile else None),
                "department": student.department or (profile.department if profile else None),
                "faculty": profile.faculty if profile else None,
                "year_of_study": profile.year_of_study if profile else None,
                "cgpa": profile.cgpa if profile else None,
                "skills": profile.skills if profile else [],
                "interests": profile.interests if profile else [],
                "bio": profile.bio if profile else None,
                "headline": profile.headline if profile else None,
                "phone_number": profile.phone_number if profile else None,
                "address": profile.address if profile else None,
                "profile_image_url": profile.profile_image_url if profile else None,
                "academic_info": profile.academic_info if profile else None,
                "experiences": profile.experiences if profile else [],
                "projects": profile.projects if profile else [],
                "achievement_count": achievement_count,
                "event_participation_count": event_count,
                # Kokurikulum metrics
                "kokurikulum_score": profile.kokurikulum_score if profile else None,
                "kokurikulum_credits": profile.kokurikulum_credits if profile else None,
                "kokurikulum_activities": profile.kokurikulum_activities if profile else [],
                "balance_metrics": profile.get_balance_metrics() if profile else None,
                "created_at": student.created_at.isoformat() if student.created_at else None,
                "last_login_at": student.last_login_at.isoformat() if student.last_login_at else None,
                "profile_completed": student.profile_completed,
            }
            results.append(student_data)
        
        return {
            "pak_info": {
                "id": user.id,
                "name": pak_name,
                "email": pak_email,
                "department": user.department
            },
            "students": results,
            "pagination": {
                "total": total_count,
                "limit": limit,
                "offset": offset,
                "has_more": offset + limit < total_count
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting PAK students: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get students: {str(e)}")


@router.get("/pak/student/{student_id}/full")
async def get_pak_student_full_info(
    student_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get full information of a specific student for PAK
    Only accessible by the student's assigned PAK
    """
    try:
        # Get current user info
        user_id = current_user.get("sub") or current_user.get("user_id")
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Get the student
        student = db.query(User).filter(User.id == student_id).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        
        profile = db.query(Profile).filter(Profile.user_id == student_id).first()
        
        # Verify PAK authorization (lecturer who is assigned to this student)
        if user.role == "lecturer":
            pak_name = user.name
            pak_email = user.email
            
            # Check if this lecturer is the PAK for this student
            is_pak = False
            if profile:
                if profile.personal_advisor and pak_name.lower() in profile.personal_advisor.lower():
                    is_pak = True
                elif profile.personal_advisor_email and profile.personal_advisor_email == pak_email:
                    is_pak = True
                # Check academic_info JSON
                elif profile.academic_info:
                    academic_pak = profile.academic_info.get('personalAdvisor') or profile.academic_info.get('personal_advisor')
                    if academic_pak and pak_name.lower() in academic_pak.lower():
                        is_pak = True
            
            if not is_pak:
                raise HTTPException(
                    status_code=403,
                    detail="You are not the PAK for this student"
                )
        elif user.role != "admin":
            raise HTTPException(
                status_code=403,
                detail="Only PAK or admin can access full student information"
            )
        
        # Get achievement details
        achievements = db.query(Achievement).filter(Achievement.user_id == student_id).all()
        
        # Get event participation details
        event_participations = db.query(EventParticipation, Event)\
            .join(Event, EventParticipation.event_id == Event.id)\
            .filter(EventParticipation.user_id == student_id).all()
        
        # Get showcase posts
        showcase_posts = db.query(ShowcasePost).filter(ShowcasePost.user_id == student_id).all()
        
        return {
            "student": {
                "id": student.id,
                "name": student.name,
                "email": student.email,
                "student_id": student.student_id or (profile.student_id if profile else None),
                "department": student.department or (profile.department if profile else None),
                "role": student.role,
                "is_active": student.is_active,
                "profile_completed": student.profile_completed,
                "created_at": student.created_at.isoformat() if student.created_at else None,
                "last_login_at": student.last_login_at.isoformat() if student.last_login_at else None,
            },
            "profile": {
                "full_name": profile.full_name if profile else None,
                "bio": profile.bio if profile else None,
                "headline": profile.headline if profile else None,
                "phone_number": profile.phone_number if profile else None,
                "address": profile.address if profile else None,
                "profile_image_url": profile.profile_image_url if profile else None,
                "academic_info": profile.academic_info if profile else None,
                "skills": profile.skills if profile else [],
                "interests": profile.interests if profile else [],
                "experiences": profile.experiences if profile else [],
                "projects": profile.projects if profile else [],
                "personal_advisor": profile.personal_advisor if profile else None,
                "personal_advisor_email": profile.personal_advisor_email if profile else None,
            },
            "kokurikulum": {
                "score": profile.kokurikulum_score if profile else None,
                "credits": profile.kokurikulum_credits if profile else None,
                "activities": profile.kokurikulum_activities if profile else [],
                "balance_metrics": profile.get_balance_metrics() if profile else None,
            },
            "achievements": [
                {
                    "id": ach.id,
                    "title": ach.title,
                    "description": ach.description,
                    "category": ach.category,
                    "date_achieved": ach.date_achieved.isoformat() if ach.date_achieved else None,
                } for ach in achievements
            ],
            "event_participations": [
                {
                    "event_id": ep.id,
                    "event_title": event.title,
                    "event_category": event.category,
                    "event_date": event.start_date.isoformat() if event.start_date else None,
                    "status": ep.status,
                } for ep, event in event_participations
            ],
            "showcase_posts_count": len(showcase_posts),
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting student full info: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get student info: {str(e)}")