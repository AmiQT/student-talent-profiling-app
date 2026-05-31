"""
Showcase API endpoints for managing student showcase posts
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
# Firebase auth removed - using Supabase auth
from app.auth import verify_supabase_token
from app.models.showcase import ShowcasePost
from app.models.user import User
from app.database import get_db
from app.services.media_service import MediaService
import logging
import json
from datetime import datetime

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/showcase", tags=["Showcase"])

class CreateShowcasePostRequest(BaseModel):
    title: Optional[str] = ""
    description: Optional[str] = ""
    content: str
    category: str = "general"
    tags: List[str] = []
    skills_used: List[str] = []
    media_urls: List[str] = []
    media_types: List[str] = []
    is_public: bool = True
    allow_comments: bool = True

@router.post("/")
async def create_showcase_post(
    post_data: CreateShowcasePostRequest,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Create a new showcase post"""
    try:
        user_id = current_user["uid"]
        user_email = current_user.get("email", "")
        user_name = current_user.get("name", "")
        
        # Generate unique ID for the post
        import uuid
        import json
        post_id = str(uuid.uuid4())
        
        # Get user information from Firebase token instead of database to avoid transaction issues
        user_role = "student"  # Default role
        user_department = None
        user_profile_image = None
        user_headline = None
        
        # Try to get user data from database, but don't fail if it doesn't work
        try:
            from app.models.user import User
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                user_name = user.name or user_name
                user_role = str(user.role.value) if user.role else "student"
                user_department = getattr(user, 'department', None)
                user_profile_image = None  # Add if available in user model
                user_headline = None  # Add if available in user model
        except Exception as e:
            logger.warning(f"Could not fetch user data, using defaults: {e}")
            # Rollback any failed transaction
            db.rollback()
        
        # Prepare media data for storage
        media_data = []
        if post_data.media_urls:
            for i, url in enumerate(post_data.media_urls):
                media_type = post_data.media_types[i] if i < len(post_data.media_types) else 'image'
                media_data.append({
                    'id': f'media_{i}',
                    'url': url,
                    'type': media_type,
                    'thumbnailUrl': None,
                    'duration': None,
                    'aspectRatio': None,
                    'fileSize': None,
                    'uploadedAt': datetime.utcnow().isoformat()
                })
        
        # Create new showcase post with updated field names
        new_post = ShowcasePost(
            id=post_id,
            user_id=user_id,  # Updated field name
            title=post_data.title or "",
            description=post_data.description or "",
            content=post_data.content,
            category=post_data.category,
            privacy='public' if post_data.is_public else 'private',
            media_urls=post_data.media_urls,
            media_types=post_data.media_types,
            media=media_data if media_data else None,
            tags=post_data.tags,
            skills_used=post_data.skills_used,
            mentions=[],  # Empty for now
            user_name=user_name,
            user_profile_image=user_profile_image,
            user_role=user_role,
            user_department=user_department,
            user_headline=user_headline,
            is_public=post_data.is_public,
            allow_comments=post_data.allow_comments,
            # Other fields will use defaults
        )
        
        # Start a fresh transaction
        db.rollback()  # Clear any previous failed transaction
        db.add(new_post)
        db.commit()
        db.refresh(new_post)
        
        logger.info(f"Showcase post created successfully: {new_post.id} for user {user_id}")
        
        return {
            "success": True,
            "message": "Showcase post created successfully",
            "post_id": new_post.id
        }
        
    except Exception as e:
        db.rollback()
        logger.error(f"Error creating showcase post: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to create post: {str(e)}")

@router.get("/")
async def get_showcase_posts(
    limit: int = 20,
    offset: int = 0,
    category: Optional[str] = None,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Get showcase posts with pagination"""
    try:
        query = db.query(ShowcasePost).filter(ShowcasePost.is_public == True)
        
        if category:
            query = query.filter(ShowcasePost.category == category)
        
        posts = query.order_by(ShowcasePost.created_at.desc()).offset(offset).limit(limit).all()
        
        result = []
        for post in posts:
            # Use cached user information from the post
            user_name = post.user_name or "Unknown User"
            user_profile_image = post.user_profile_image
            user_role = post.user_role
            user_department = post.user_department
            
            # Handle media data
            media_data = []
            media_urls = []
            media_types = []
            
            if post.media:
                try:
                    # If media is already a list/dict, use it directly
                    if isinstance(post.media, list):
                        media_data = post.media
                    elif isinstance(post.media, str):
                        # If it's a JSON string, parse it
                        import json
                        media_data = json.loads(post.media)
                    else:
                        # If it's already a dict/object, convert to list
                        media_data = [post.media] if post.media else []
                except Exception as e:
                    logger.warning(f"Error parsing media data: {e}")
                    media_data = []
            
            # Use direct media_urls and media_types if available
            if post.media_urls:
                media_urls = post.media_urls if isinstance(post.media_urls, list) else []
            if post.media_types:
                media_types = post.media_types if isinstance(post.media_types, list) else []
            
            # Fallback to extracting from media_data
            if not media_urls and media_data:
                media_urls = [item.get('url', '') for item in media_data if isinstance(item, dict)]
                media_types = [item.get('type', 'image') for item in media_data if isinstance(item, dict)]
            
            post_dict = {
                "id": post.id,
                "user_id": post.user_id,
                "user_name": user_name,
                "user_profile_image": user_profile_image,
                "user_role": user_role,
                "user_department": user_department,
                "title": post.title or "",
                "description": post.description or "",
                "content": post.content or "",
                "category": post.category or "general",
                "tags": post.tags or [],
                "skills_used": post.skills_used or [],
                "media_urls": media_urls,
                "media_types": media_types,
                "likes_count": post.likes_count or 0,
                "comments_count": post.comments_count or 0,
                "shares_count": post.shares_count or 0,
                "views_count": post.views_count or 0,
                "is_public": post.is_public,
                "is_featured": post.is_featured or False,
                "allow_comments": post.allow_comments,
                "created_at": post.created_at.isoformat() if post.created_at else None,
                "updated_at": post.updated_at.isoformat() if post.updated_at else None,
            }
            result.append(post_dict)
        
        return {
            "posts": result,
            "total": len(result),
            "limit": limit,
            "offset": offset
        }
        
    except Exception as e:
        logger.error(f"Error getting showcase posts: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to get posts")

@router.get("/{post_id}")
async def get_showcase_post(
    post_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Get a specific showcase post by ID"""
    try:
        post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
        
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        
        # Increment view count
        post.views_count = (post.views_count or 0) + 1
        db.commit()
        
        # Handle media data
        media_urls = []
        media_types = []
        
        if post.media_urls:
            media_urls = post.media_urls if isinstance(post.media_urls, list) else []
        if post.media_types:
            media_types = post.media_types if isinstance(post.media_types, list) else []
        
        return {
            "id": post.id,
            "user_id": post.user_id,
            "user_name": post.user_name,
            "user_profile_image": post.user_profile_image,
            "user_role": post.user_role,
            "user_department": post.user_department,
            "title": post.title or "",
            "description": post.description or "",
            "content": post.content,
            "category": post.category,
            "tags": post.tags or [],
            "skills_used": post.skills_used or [],
            "media_urls": media_urls,
            "media_types": media_types,
            "likes_count": post.likes_count or 0,
            "comments_count": post.comments_count or 0,
            "shares_count": post.shares_count or 0,
            "views_count": post.views_count or 0,
            "is_public": post.is_public,
            "is_featured": post.is_featured or False,
            "allow_comments": post.allow_comments,
            "created_at": post.created_at.isoformat() if post.created_at else None,
            "updated_at": post.updated_at.isoformat() if post.updated_at else None,
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting showcase post: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to get post")

@router.post("/{post_id}/like")
async def toggle_like_post(
    post_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Toggle like on a showcase post"""
    try:
        user_id = current_user["uid"]
        
        post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        
        # Check if user already liked this post
        from app.models.showcase import ShowcaseLike
        existing_like = db.query(ShowcaseLike).filter(
            ShowcaseLike.post_id == post_id,
            ShowcaseLike.user_id == user_id
        ).first()
        
        if existing_like:
            # Unlike: remove the like
            db.delete(existing_like)
            # The trigger will automatically decrease the count
            action = "unliked"
        else:
            # Like: add new like
            new_like = ShowcaseLike(
                post_id=post_id,
                user_id=user_id
            )
            db.add(new_like)
            # The trigger will automatically increase the count
            action = "liked"
        
        db.commit()
        
        # Refresh post to get updated count
        db.refresh(post)
        
        return {
            "success": True,
            "message": f"Post {action} successfully",
            "action": action,
            "likes_count": post.likes_count or 0
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error toggling like: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to toggle like")

@router.post("/upload")
async def upload_showcase_media(
    file: UploadFile = File(...),
    user_id: str = None,
    type: str = "showcase_image",
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Upload media for showcase posts"""
    try:
        current_user_id = current_user["uid"]
        
        # Use the provided user_id or default to current user
        target_user_id = user_id or current_user_id
        
        # Upload based on file type
        if file.content_type and file.content_type.startswith("image/"):
            result = await MediaService.upload_image(file, target_user_id)
        elif file.content_type and file.content_type.startswith("video/"):
            result = await MediaService.upload_video(file, target_user_id)
        else:
            raise HTTPException(400, "Unsupported file type")
        
        return {
            "success": True,
            "message": "Media uploaded successfully",
            "url": result["url"],
            "media": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error uploading showcase media: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Upload failed: {str(e)}")

@router.delete("/{post_id}")
async def delete_showcase_post(
    post_id: str,
    current_user: dict = Depends(verify_supabase_token),
    db: Session = Depends(get_db)
):
    """Delete a showcase post"""
    try:
        user_id = current_user["uid"]
        
        post = db.query(ShowcasePost).filter(
            ShowcasePost.id == post_id,
            ShowcasePost.user_id == user_id
        ).first()
        
        if not post:
            raise HTTPException(status_code=404, detail="Post not found or not authorized")
        
        db.delete(post)
        db.commit()
        
        return {
            "success": True,
            "message": "Post deleted successfully"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting showcase post: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to delete post")