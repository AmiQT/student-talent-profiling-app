from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
# Firebase auth removed - using Supabase auth
from app.auth import verify_supabase_token
from app.services.media_service import MediaService
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

@router.post("/upload/image")
async def upload_image(
    file: UploadFile = File(...),
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Upload an image file to Cloudinary
    """
    try:
        user_id = current_user["uid"]
        
        # Upload image using MediaService
        result = await MediaService.upload_image(file, user_id)
        
        logger.info(f"Image uploaded successfully for user {user_id}: {result['id']}")
        
        return {
            "success": True,
            "message": "Image uploaded successfully",
            "media": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Image upload endpoint error: {str(e)}")
        raise HTTPException(500, f"Upload failed: {str(e)}")

@router.post("/upload/video")
async def upload_video(
    file: UploadFile = File(...),
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Upload a video file to Cloudinary
    """
    try:
        user_id = current_user["uid"]
        
        # Upload video using MediaService
        result = await MediaService.upload_video(file, user_id)
        
        logger.info(f"Video uploaded successfully for user {user_id}: {result['id']}")
        
        return {
            "success": True,
            "message": "Video uploaded successfully",
            "media": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Video upload endpoint error: {str(e)}")
        raise HTTPException(500, f"Upload failed: {str(e)}")

@router.get("/optimize/{public_id}")
async def get_optimized_url(
    public_id: str,
    width: int = None,
    height: int = None,
    quality: str = "auto",
    current_user: dict = Depends(verify_supabase_token)
):
    """
    Get optimized URL for a media file
    """
    try:
        optimized_url = MediaService.get_optimized_url(
            public_id=public_id,
            width=width,
            height=height,
            quality=quality
        )
        
        return {
            "success": True,
            "optimized_url": optimized_url,
            "transformations": {
                "width": width,
                "height": height,
                "quality": quality
            }
        }
        
    except Exception as e:
        logger.error(f"URL optimization error: {str(e)}")
        raise HTTPException(500, f"URL optimization failed: {str(e)}")

@router.delete("/delete/{public_id}")
async def delete_media(
    public_id: str,
    resource_type: str = "image",
    current_user: dict = Depends(verify_supabase_token)
):
    """Delete a media file from Cloudinary by public_id."""
    try:
        success = await MediaService.delete_media(public_id, resource_type)
        if not success:
            raise HTTPException(404, "Media not found or could not be deleted")
        return {"success": True, "deleted": public_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Media delete error: {str(e)}")
        raise HTTPException(500, f"Delete failed: {str(e)}")
