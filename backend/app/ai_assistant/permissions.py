"""Permission utility untuk AI assistant."""

from __future__ import annotations

from typing import Any


ROLE_PERMISSION_MATRIX = {
    "admin": {
        "user_management": True,
        "analytics": True,
        "reports": True,
    },
    "manager": {
        "user_management": True,
        "analytics": True,
        "reports": True,
    },
    "lecturer": {
        "user_management": False,
        "analytics": True,
        "reports": True,
    },
    "student": {
        "user_management": False,
        "analytics": False,
        "reports": False,
    },
}


def can_run_action(user: dict[str, Any], action: str) -> bool:
    if not user:
        return False
        
    role = user.get("role", "student")
    email = user.get("email", "")
    
    # DEBUG: Log user info untuk troubleshoot
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"Permission check - Email: {email}, Role: {role}, Action: {action}")
    
    # Special check for admin emails (bypass role detection issues)
    admin_emails = ["admin@uthm.edu.my", "admin@example.com"]
    if email in admin_emails:
        logger.info(f"Admin email access granted to: {email}")
        return True
    
    # Admin & manager: continue action apa pun
    if role in {"admin", "manager", "administrator"}:
        return True

    if role == "lecturer":
        return action in {"search", "report", "analytics", "multilingual", "creative"}

    # Selain tu (student dsb) disable semua
    logger.warning(f"Permission denied - Email: {email}, Role: {role}")
    return False

