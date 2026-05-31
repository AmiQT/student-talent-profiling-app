"""
Profile management API endpoints for Supabase structure
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
# Firebase auth removed - using Supabase auth
from app.database import get_db
from app.auth import verify_supabase_token
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/profiles", tags=["Profiles"])

@router.get("/")
async def get_all_profiles(
    limit: int = Query(50, le=100),
    offset: int = Query(0),
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Get all profiles using raw SQL for Supabase structure"""
    try:
        result = db.execute(text("""
            SELECT 
                id,
                COALESCE("fullName", '') as full_name,
                COALESCE(bio, '') as bio,
                COALESCE(address, '') as address,
                COALESCE("academicInfo/department", '') as department,
                COALESCE("academicInfo/faculty", '') as faculty,
                COALESCE("academicInfo/program", '') as program,
                COALESCE("academicInfo/studentId", '') as student_id,
                COALESCE("academicInfo/cgpa", '') as cgpa
            FROM profiles 
            LIMIT :limit OFFSET :offset
        """), {"limit": limit, "offset": offset}).fetchall()
        
        profiles = []
        for row in result:
            profile_dict = {
                "id": row[0],
                "user_id": row[0],
                "full_name": row[1] or "",
                "bio": row[2] or "",
                "address": row[3] or "",
                "department": row[4] or "",
                "faculty": row[5] or "",
                "program": row[6] or "",
                "student_id": row[7] or "",
                "cgpa": row[8] or "",
                "skills": [],
                "interests": [],
                "languages": [],
                "experiences": [],
                "projects": [],
                "achievements": [],
                "linkedin_url": "",
                "github_url": "",
                "portfolio_url": "",
                "phone": "",
                "profile_image_url": "",
                "created_at": None,
                "updated_at": None,
                # Academic info object that your Flutter app expects
                "academicInfo": {
                    "studentId": row[7] or "",
                    "department": row[4] or "",
                    "faculty": row[5] or "",
                    "program": row[6] or "",
                    "cgpa": float(row[8]) if row[8] and row[8] != "" else None,
                    "currentSemester": 1,
                    "completedCredits": 0,
                    "totalCredits": 120,
                    "specialization": None,
                    "enrollmentDate": None,
                    "expectedGraduation": None,
                }
            }
            profiles.append(profile_dict)
        
        return profiles
        
    except Exception as e:
        logger.error(f"Error getting profiles: {e}")
        raise HTTPException(status_code=500, detail="Failed to get profiles")

@router.get("/{user_id}")
async def get_profile_by_user_id(
    user_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Get profile by user ID using raw SQL"""
    try:
        result = db.execute(text("""
            SELECT 
                id,
                COALESCE("fullName", '') as full_name,
                COALESCE(bio, '') as bio,
                COALESCE(address, '') as address,
                COALESCE("academicInfo/department", '') as department,
                COALESCE("academicInfo/faculty", '') as faculty,
                COALESCE("academicInfo/program", '') as program,
                COALESCE("academicInfo/studentId", '') as student_id,
                COALESCE("academicInfo/cgpa", '') as cgpa
            FROM profiles 
            WHERE id = :user_id
            LIMIT 1
        """), {"user_id": user_id}).fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Profile not found")
        
        return {
            "id": result[0],
            "user_id": result[0],  # Use id as user_id for compatibility
            "full_name": result[1] or "",
            "bio": result[2] or "",
            "address": result[3] or "",
            "department": result[4] or "",
            "faculty": result[5] or "",
            "program": result[6] or "",
            "student_id": result[7] or "",
            "cgpa": result[8] or "",
            "skills": [],
            "interests": [],
            "languages": [],
            "experiences": [],
            "projects": [],
            "achievements": [],
            "linkedin_url": "",
            "github_url": "",
            "portfolio_url": "",
            "phone": "",
            "profile_image_url": "",
            "created_at": None,
            "updated_at": None,
            # Academic info object that your Flutter app expects
            "academicInfo": {
                "studentId": result[7] or "",
                "department": result[4] or "",
                "faculty": result[5] or "",
                "program": result[6] or "",
                "cgpa": float(result[8]) if result[8] and result[8] != "" else None,
                "currentSemester": 1,
                "completedCredits": 0,
                "totalCredits": 120,
                "specialization": None,
                "enrollmentDate": None,
                "expectedGraduation": None,
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting profile: {e}")
        raise HTTPException(status_code=500, detail="Failed to get profile")

@router.get("/search")
async def search_profiles(
    q: Optional[str] = Query(None, description="Search query"),
    department: Optional[str] = Query(None),
    limit: int = Query(20, le=100),
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Search profiles using raw SQL"""
    try:
        # Build the WHERE clause dynamically
        where_conditions = []
        params = {"limit": limit}
        
        if q:
            where_conditions.append('("fullName" ILIKE :search_query OR bio ILIKE :search_query)')
            params["search_query"] = f"%{q}%"
        
        if department:
            where_conditions.append('"academicInfo/department" ILIKE :department')
            params["department"] = f"%{department}%"
        
        where_clause = ""
        if where_conditions:
            where_clause = "WHERE " + " AND ".join(where_conditions)
        
        sql_query = f"""
            SELECT 
                id,
                "fullName",
                bio,
                "academicInfo/department" as department,
                "academicInfo/faculty" as faculty,
                "academicInfo/program" as program
            FROM profiles 
            {where_clause}
            LIMIT :limit
        """
        
        result = db.execute(text(sql_query), params).fetchall()
        
        profiles = []
        for row in result:
            profile_dict = {
                "id": row[0],
                "full_name": row[1] or "",
                "bio": row[2] or "",
                "department": row[3] or "",
                "faculty": row[4] or "",
                "program": row[5] or "",
            }
            profiles.append(profile_dict)
        
        return profiles
        
    except Exception as e:
        logger.error(f"Error searching profiles: {e}")
        raise HTTPException(status_code=500, detail="Search failed")