"""
Supabase Authentication Middleware
"""
import os
import jwt
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Dict, Any
import logging
from app.database import SessionLocal
from app.models.user import User

logger = logging.getLogger(__name__)

# Supabase JWT settings - MUST be set via environment variables
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET")
SUPABASE_URL = os.getenv("SUPABASE_URL")

if not SUPABASE_JWT_SECRET:
    logger.warning("⚠️ SUPABASE_JWT_SECRET not set! Authentication will fail.")
if not SUPABASE_URL:
    logger.warning("⚠️ SUPABASE_URL not set! Please configure environment variables.")

security = HTTPBearer()

async def verify_supabase_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    Verify Supabase JWT token and return user info including role from database
    """
    try:
        if not credentials:
            logger.error("❌ No Authorization header provided")
            raise HTTPException(status_code=401, detail="Missing authorization header")

        token = credentials.credentials

        if not token:
            logger.error("❌ No token in Authorization header")
            raise HTTPException(status_code=401, detail="Missing token")

        logger.info(f"🔐 Verifying token: {token[:50]}...")

        try:
            if not SUPABASE_JWT_SECRET:
                logger.error("❌ SUPABASE_JWT_SECRET not configured!")
                raise HTTPException(status_code=500, detail="Server configuration error")

            payload = jwt.decode(
                token,
                SUPABASE_JWT_SECRET,
                algorithms=["HS256"],
                audience=None,
                options={"verify_aud": False},
            )

            logger.info(f"✅ JWT decoded successfully. Payload: {payload}")

            uid = payload.get("sub")
            email = payload.get("email")

            logger.info(f"📋 User from token - UID: {uid}, Email: {email}")

            db = SessionLocal()
            try:
                user = db.query(User).filter(User.id == uid).first()
                role = user.role if user else payload.get("user_metadata", {}).get("role", "student")
                logger.info(f"User {email} role from database: {role}")
            except Exception as db_error:
                logger.error(f"Error querying database for role: {db_error}")
                role = payload.get("user_metadata", {}).get("role", "student")
                logger.info(f"Using fallback role from token: {role}")
            finally:
                db.close()

            user_info = {
                "uid": uid,
                "email": email,
                "name": payload.get("user_metadata", {}).get("name", email.split("@")[0] if email else "Unknown"),
                "role": role,
                "email_verified": payload.get("email_confirmed_at") is not None
            }

            logger.info(f"✅ Supabase token verified for user: {user_info['email']} (role: {user_info['role']})")
            return user_info

        except jwt.InvalidTokenError as e:
            logger.error(f"Invalid JWT token: {e}")
            raise HTTPException(status_code=401, detail="Invalid authentication token")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token verification failed: {e}", exc_info=True)
        raise HTTPException(status_code=401, detail="Authentication failed")

async def verify_admin_user(current_user: Dict[str, Any] = Depends(verify_supabase_token)) -> Dict[str, Any]:
    """
    Verify that the current user is an admin
    """
    logger.info(f"🔍 verify_admin_user called with current_user: {current_user}")

    if not current_user:
        logger.error("❌ current_user is None or False!")
        raise HTTPException(status_code=401, detail="Not authenticated")

    user_role = current_user.get("role", "student").lower()
    user_email = current_user.get("email", "unknown")

    logger.info(f"📋 Checking admin access for {user_email}, role: {user_role}")

    if user_role not in ["admin", "administrator"]:
        logger.warning(f"❌ Non-admin user {user_email} (role: {user_role}) attempted admin access")
        raise HTTPException(status_code=403, detail=f"Admin access required. Your role: {user_role}")

    logger.info(f"✅ Admin access granted to: {user_email}")
    return current_user
