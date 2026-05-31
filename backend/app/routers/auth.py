"""
Authentication API endpoints
"""
from fastapi import APIRouter, Depends, HTTPException
# Supabase auth integration
from app.auth import verify_supabase_token, verify_admin_user
from app.models.user import User
from app.database import get_db
from sqlalchemy.orm import Session
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/verify")
async def verify_token(current_user: dict = Depends(verify_supabase_token)):
    """
    Verify Firebase token and return user info
    """
    return {
        "status": "authenticated",
        "user": {
            "uid": current_user["uid"],
            "email": current_user["email"],
            "name": current_user["name"],
            "role": current_user["role"],
            "email_verified": current_user["email_verified"]
        }
    }

@router.get("/profile")
async def get_user_profile(
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get current user's profile from database
    """
    try:
        # Find user in database
        user = db.query(User).filter(User.uid == current_user["uid"]).first()
        
        if not user:
            # User not in database yet, create them
            user = User(
                id=current_user["uid"],
                uid=current_user["uid"],
                email=current_user["email"],
                name=current_user["name"],
                role=current_user.get("role", "student")
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            logger.info(f"Created new user in database: {user.uid}")
        
        return {
            "user": {
                "id": user.id,
                "uid": user.uid,
                "email": user.email,
                "name": user.name,
                "role": user.role.value,
                "is_active": user.is_active,
                "profile_completed": user.profile_completed,
                "created_at": user.created_at.isoformat() if user.created_at else None
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting user profile: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user profile")

