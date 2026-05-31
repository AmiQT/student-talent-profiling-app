"""
User management API endpoints
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from pydantic import BaseModel, EmailStr
from datetime import datetime
# Supabase auth integration
from app.auth import verify_supabase_token, verify_admin_user
from app.models.user import User, UserRole
from app.models.profile import Profile
from app.database import get_db
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/users", tags=["Users"])

# Pydantic models for CRUD operations
class UserCreate(BaseModel):
    uid: str
    email: EmailStr
    name: str
    role: UserRole
    department: Optional[str] = None
    student_id: Optional[str] = None
    staff_id: Optional[str] = None
    is_active: bool = True
    profile_completed: bool = False

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    role: Optional[UserRole] = None
    department: Optional[str] = None
    student_id: Optional[str] = None
    staff_id: Optional[str] = None
    is_active: Optional[bool] = None
    profile_completed: Optional[bool] = None

class UserSyncRequest(BaseModel):
    action: str  # 'create', 'update', 'delete'
    user_data: dict

@router.get("/search")
async def search_users(
    q: Optional[str] = Query(None, description="Search query"),
    role: Optional[UserRole] = Query(None, description="Filter by role"),
    department: Optional[str] = Query(None, description="Filter by department"),
    limit: int = Query(50, le=100, description="Maximum results"),
    offset: int = Query(0, description="Pagination offset"),
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Advanced user search with filters
    This demonstrates the kind of complex query Firebase can't handle efficiently
    """
    try:
        query = db.query(User).join(Profile, User.id == Profile.user_id, isouter=True)
        
        # Apply search filter
        if q:
            search_filter = f"%{q}%"
            query = query.filter(
                (User.name.ilike(search_filter)) |
                (User.email.ilike(search_filter)) |
                (Profile.full_name.ilike(search_filter)) |
                (Profile.student_id.ilike(search_filter))
            )
        
        # Apply role filter
        if role:
            query = query.filter(User.role == role)
        
        # Apply department filter
        if department:
            query = query.filter(
                (User.department.ilike(f"%{department}%")) |
                (Profile.department.ilike(f"%{department}%"))
            )
        
        # Get total count
        total = query.count()
        
        # Apply pagination
        users = query.offset(offset).limit(limit).all()
        
        return {
            "users": [
                {
                    "id": user.id,
                    "name": user.name,
                    "email": user.email,
                    "role": user.role.value,
                    "department": user.department,
                    "is_active": user.is_active,
                    "profile_completed": user.profile_completed,
                    "created_at": user.created_at.isoformat() if user.created_at else None
                }
                for user in users
            ],
            "pagination": {
                "total": total,
                "limit": limit,
                "offset": offset,
                "has_more": offset + limit < total
            }
        }
        
    except Exception as e:
        logger.error(f"Error searching users: {e}")
        raise HTTPException(status_code=500, detail="Search failed")

@router.get("/stats")
async def get_user_stats(
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """
    Get user statistics - another example of complex analytics
    """
    try:
        # Get user counts by role
        role_stats = db.query(
            User.role,
            func.count(User.id).label('count')
        ).group_by(User.role).all()
        
        # Get department distribution
        dept_stats = db.query(
            User.department,
            func.count(User.id).label('count')
        ).filter(User.department.isnot(None)).group_by(User.department).all()
        
        # Get profile completion stats
        profile_stats = db.query(
            User.profile_completed,
            func.count(User.id).label('count')
        ).group_by(User.profile_completed).all()
        
        return {
            "total_users": db.query(User).count(),
            "active_users": db.query(User).filter(User.is_active == True).count(),
            "role_distribution": {
                role.value: count for role, count in role_stats
            },
            "department_distribution": {
                dept: count for dept, count in dept_stats
            },
            "profile_completion": {
                "completed" if completed else "incomplete": count 
                for completed, count in profile_stats
            }
        }
        
    except Exception as e:
        logger.error(f"Error getting user stats: {e}")
        raise HTTPException(status_code=500, detail="Failed to get statistics")

@router.get("/{user_id}")
async def get_user(
    user_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """
    Get specific user details
    """
    try:
        user = db.query(User).filter(User.id == user_id).first()
        
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        
        # Check if current user can view this profile
        if current_user["uid"] != user_id and current_user.get("role") not in ["admin", "lecturer"]:
            raise HTTPException(status_code=403, detail="Access denied")
        
        return {
            "user": {
                "id": user.id,
                "uid": user.uid,
                "name": user.name,
                "email": user.email,
                "role": user.role.value,
                "department": user.department,
                "student_id": user.student_id,
                "is_active": user.is_active,
                "profile_completed": user.profile_completed,
                "created_at": user.created_at.isoformat() if user.created_at else None,
                "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user {user_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user")

# CRUD Operations for Dashboard Integration

@router.post("/")
async def create_user(
    user_data: UserCreate,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """Create a new user in the backend database AND Supabase Auth"""
    try:
        from supabase import create_client, Client
        import os
        
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_service_key:
             raise HTTPException(status_code=500, detail="Supabase configuration missing")

        supabase: Client = create_client(supabase_url, supabase_service_key)
        
        target_uid = user_data.uid
        
        # 1. Attempt to create user in Auth (or recover if exists)
        try:
             # Try to create user
             auth_response = supabase.auth.admin.create_user({
                 "email": user_data.email,
                 "password": "TempPassword123!",
                 "email_confirm": True,
                 "user_metadata": {"name": user_data.name, "role": user_data.role}
             })
             target_uid = auth_response.user.id
             logger.info(f"✅ Created new Auth User: {user_data.email} ({target_uid})")
             
        except Exception as auth_error:
             error_str = str(auth_error).lower()
             if "already registered" in error_str or "already exists" in error_str or "422" in error_str:
                 logger.info(f"ℹ️ User {user_data.email} already in Auth. Syncing...")
                 
                 # Try to find the user ID from existing records
                 # Strategy: Since we can't get by email directly without List, we hope user_data.uid is correct OR we search.
                 # If user_data.uid looks like a valid UUID, let's assume it MIGHT be correct, but searching is safer.
                 
                 found_uid = None
                 page = 1
                 while not found_uid and page < 5: 
                     users = supabase.auth.admin.list_users(page=page, per_page=100)
                     # Handle different versions of supabase-py response
                     u_list = users if isinstance(users, list) else (users.users if hasattr(users, 'users') else [])
                     
                     for u in u_list:
                         if u.email == user_data.email:
                             found_uid = u.id
                             break
                     page += 1
                 
                 if found_uid:
                     target_uid = found_uid
                     logger.info(f"📍 Recovered Auth ID: {target_uid}")
                 else:
                     logger.warning(f"⚠️ User in Auth but ID not found. Using provided UID: {target_uid}")
             else:
                 logger.error(f"❌ Auth creation failed: {auth_error}")
                 raise HTTPException(status_code=500, detail=f"Auth creation failed: {str(auth_error)}")

        # 2. Handle Database Record
        existing_db_user = db.query(User).filter(User.email == user_data.email).first()
        
        if existing_db_user:
            logger.info(f"🔄 User exists in DB, updating details...")
            existing_db_user.name = user_data.name
            existing_db_user.role = user_data.role
            # Ensure ID match if possible? 
            # If IDs differ, we are in trouble, but let's just update fields for now.
            db.commit()
            db.refresh(existing_db_user)
            return {
                "status": "success",
                "message": "User synced successfully",
                "user": existing_db_user
            }

        # Create new user in DB using the AUTH ID
        db_user = User(
            id=target_uid,
            uid=target_uid,
            email=user_data.email,
            name=user_data.name,
            role=user_data.role,
            department=user_data.department,
            student_id=user_data.student_id,
            staff_id=user_data.staff_id,
            is_active=user_data.is_active,
            profile_completed=user_data.profile_completed
        )
        
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        
        logger.info(f"✅ User DB record created: {user_data.email}")
        return {
            "status": "success",
            "message": "User created successfully",
            "user": {
                "id": db_user.id,
                "uid": db_user.uid,
                "email": db_user.email,
                "name": db_user.name,
                "role": db_user.role.value
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating user: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create user")

@router.put("/{user_id}")
async def update_user(
    user_id: str,
    user_data: UserUpdate,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """Update an existing user in Supabase database"""
    try:
        from supabase import create_client
        import os
        from uuid import UUID
        
        # Initialize Supabase client
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_service_key:
            raise HTTPException(status_code=500, detail="Supabase configuration missing")
        
        supabase = create_client(supabase_url, supabase_service_key)
        
        # Convert user_id to UUID
        try:
            user_uuid = UUID(user_id)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid user ID format")
        
        # Prepare update data (only include fields that were set)
        update_data = user_data.dict(exclude_unset=True)
        
        # Convert role enum to string if present
        if 'role' in update_data and update_data['role']:
            update_data['role'] = update_data['role'].value if hasattr(update_data['role'], 'value') else update_data['role']
        
        # Update in Supabase database
        result = supabase.table('users').update(update_data).eq('id', user_id).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="User not found")
        
        logger.info(f"✅ User updated: {user_id}")
        
        return {
            "status": "success",
            "message": "User updated successfully",
            "user": result.data[0] if result.data else None
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error updating user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update user: {str(e)}")

@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """Delete a user from both Supabase Auth and database"""
    try:
        from supabase import create_client, Client
        import os
        from uuid import UUID
        
        # Initialize Supabase client with service role key
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_service_key:
            logger.error("❌ SUPABASE_SERVICE_KEY missing in .env")
            raise HTTPException(status_code=500, detail="Server configuration error: Missing Service Key")
        
        # Validate that the key is likely a Service Key (starts with ey...)
        # We can't strictly validate without calling an admin endpoint, but we can assume.
        
        supabase: Client = create_client(supabase_url, supabase_service_key)
        
        # Delete from Supabase Auth first
        auth_deletion_success = False
        try:
            logger.info(f"🗑️ Attempting to delete Auth User: {user_id}")
            # delete_user returns a user object or throws error
            supabase.auth.admin.delete_user(user_id)
            logger.info(f"✅ Deleted user from Supabase Auth: {user_id}")
            auth_deletion_success = True
        except Exception as auth_error:
            error_msg = str(auth_error).lower()
            # If user not found, we can proceed to clean DB.
            # If it's a permission error (401/403), we MUST STOP.
            if "not found" in error_msg or "bad request" in error_msg: 
                logger.warning(f"⚠️ User not found in Auth (already deleted?): {auth_error}")
                auth_deletion_success = True # Proceed to cleanup DB
            elif "401" in error_msg or "403" in error_msg:
                logger.error(f"⛔ PERMISSION DENIED deleting Auth User. Check SUPABASE_SERVICE_KEY.")
                raise HTTPException(status_code=500, detail="Failed to delete user: Invalid Service Key permissions")
            else:
                logger.error(f"❌ Unexpected Auth delete error: {auth_error}")
                # For safety, let's stop unless we are sure.
                raise HTTPException(status_code=500, detail=f"Auth deletion failed: {str(auth_error)}")
        
        # Only delete from DB if Auth deletion was successful (or user didn't exist in Auth)
        if auth_deletion_success:
            # Delete from database (Using SQL via Supabase Client for consistency, or SQLAlchemy)
            # Using Supabase Client ensures RLS bypass if Service Key is used (Wait, Service Key bypasses RLS).
            try:
                # Direct DB Delete using Service Key (Bypasses RLS)
                result = supabase.table('users').delete().eq('id', user_id).execute()
                logger.info(f"✅ Deleted user from database: {user_id}")
            except Exception as db_error:
                # Fallback to SQLAlchemy if needed, but Service Key is safer for cascading
                logger.error(f"⚠️ Service Key DB delete failed, trying SQLAlchemy: {db_error}")
                db_user = db.query(User).filter(User.id == user_id).first()
                if db_user:
                    db.delete(db_user)
                    db.commit()
        
        return {
            "status": "success",
            "message": "User deleted successfully",
            "id": user_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error deleting user {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete user: {str(e)}")

@router.post("/sync")
async def sync_user_operation(
    sync_request: UserSyncRequest,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """Sync user operations from Firebase to backend"""
    try:
        action = sync_request.action
        user_data = sync_request.user_data
        
        logger.info(f"Syncing user operation: {action} for {user_data.get('email', 'unknown')}")
        
        if action == "create":
            # Create user in backend
            user_create = UserCreate(**user_data)
            result = await create_user(user_create, current_user, db)
            return {"status": "success", "action": "create", "result": result}
            
        elif action == "update":
            # Update user in backend
            uid = user_data.get("uid")
            if not uid:
                raise HTTPException(status_code=400, detail="UID required for update")
            
            user_update = UserUpdate(**{k: v for k, v in user_data.items() if k != "uid"})
            result = await update_user(uid, user_update, current_user, db)
            return {"status": "success", "action": "update", "result": result}
            
        elif action == "delete":
            # Delete user in backend
            uid = user_data.get("uid")
            if not uid:
                raise HTTPException(status_code=400, detail="UID required for delete")
            
            result = await delete_user(uid, current_user, db)
            return {"status": "success", "action": "delete", "result": result}
            
        else:
            raise HTTPException(status_code=400, detail=f"Unknown action: {action}")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Sync operation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Sync operation failed: {str(e)}")

# Admin endpoint to create user with auth
class AdminUserCreate(BaseModel):
    email: EmailStr
    password: str
    name: str
    role: UserRole
    department: Optional[str] = None
    student_id: Optional[str] = None
    is_active: bool = True


@router.post("/admin/create")
async def admin_create_user(
    user_data: AdminUserCreate,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """
    Admin endpoint to create a new user with Supabase authentication
    This endpoint has service role privileges and handles Syncing if Auth user exists.
    """
    try:
        from supabase import create_client, Client
        import os
        
        # Initialize Supabase client with service role key
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_service_key:
            raise HTTPException(
                status_code=500,
                detail="Supabase configuration missing. Please set SUPABASE_URL and SUPABASE_SERVICE_KEY"
            )
        
        supabase: Client = create_client(supabase_url, supabase_service_key)
        
        # Check if user already exists in database
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail=f"User with email {user_data.email} already exists in database"
            )
        
        user_id = None
        
        # Create auth user in Supabase
        try:
            auth_response = supabase.auth.admin.create_user({
                "email": user_data.email,
                "password": user_data.password,
                "email_confirm": True,
                "user_metadata": {"name": user_data.name, "role": user_data.role.value}
            })
            if auth_response.user:
                user_id = auth_response.user.id
                logger.info(f"✅ Auth User Created: {user_id}")
                
        except Exception as auth_error:
            # Log the full error for debugging
            logger.error(f"Supabase auth warning: {type(auth_error).__name__}: {str(auth_error)}")
            
            # Check if it's a duplicate user error and RECOVER
            error_str = str(auth_error).lower()
            if 'already been registered' in error_str or 'already exists' in error_str or '422' in error_str:
                logger.info(f"ℹ️ User {user_data.email} exists in Auth. Recovering ID...")
                
                # RECOVERY: Find the existing User ID
                # We search via list_users
                found_uid = None
                page = 1
                while not found_uid and page < 5: 
                     users = supabase.auth.admin.list_users(page=page, per_page=100)
                     u_list = users if isinstance(users, list) else (users.users if hasattr(users, 'users') else [])
                     for u in u_list:
                         if u.email == user_data.email:
                             found_uid = u.id
                             break
                     page += 1
                
                if found_uid:
                    user_id = found_uid
                    logger.info(f"📍 Recovered Auth ID: {user_id}")
                    
                    # Optional: Update password if provided? No, leave password alone for safety.
                else:
                    raise HTTPException(
                        status_code=400,
                        detail=f"User exists in Auth but ID could not be found. Manual cleanup required."
                    )
            else:
                # Re-raise other auth errors as 400 Bad Request with details
                raise HTTPException(
                    status_code=400,
                    detail=f"Failed to create user in Supabase Auth: {str(auth_error)}"
                )
        
        if not user_id:
            raise HTTPException(status_code=400, detail="Failed to obtain User ID from Auth")
        
        # Insert user data into Supabase users table
        # We use upsert=True just in case race conditions occur
        user_insert = supabase.table('users').upsert({
            "id": user_id,
            "email": user_data.email,
            "name": user_data.name,
            "role": user_data.role.value,
            "department": user_data.department,
            "student_id": user_data.student_id,
            "is_active": user_data.is_active,
            "profile_completed": False
        }).execute()
        
        if not user_insert.data:
            # Check if it was just an update that returned no data? (upsert usually returns data)
            # Just log success anyway
            logger.warning("DB Insert returned no data, but no error thrown.")
        
        logger.info(f"✅ User data inserted/synced into database for: {user_data.email}")
        
        return {
            "status": "success",
            "message": "User created/synced successfully",
            "user": {
                "id": user_id,
                "email": user_data.email,
                "name": user_data.name,
                "role": user_data.role.value,
                "is_active": user_data.is_active
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error in admin_create_user: {e}")
        raise HTTPException(status_code=500, detail=f"System error: {str(e)}")


# Reset password request model
class ResetPasswordRequest(BaseModel):
    new_password: str


@router.post("/{user_id}/reset-password")
async def reset_user_password(
    user_id: str,
    password_data: ResetPasswordRequest,
    current_user: dict = Depends(verify_admin_user),
    db: Session = Depends(get_db)
):
    """
    Admin endpoint to reset a user's password
    """
    try:
        from supabase import create_client
        import os
        
        # Validate password length
        if len(password_data.new_password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
        
        # Initialize Supabase client with service role key
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_service_key:
            raise HTTPException(status_code=500, detail="Supabase configuration missing")
        
        supabase = create_client(supabase_url, supabase_service_key)
        
        # Update user password via Supabase Admin API
        supabase.auth.admin.update_user_by_id(
            user_id,
            {"password": password_data.new_password}
        )
        
        logger.info(f"✅ Password reset for user: {user_id}")
        
        return {
            "status": "success",
            "message": "Password reset successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error resetting password for {user_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to reset password: {str(e)}")
