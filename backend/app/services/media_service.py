import cloudinary
import cloudinary.uploader
from fastapi import UploadFile, HTTPException
import uuid
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

class MediaService:
    """
    Service for handling media uploads to Cloudinary
    """
    
    @staticmethod
    async def upload_image(file: UploadFile, user_id: str) -> Dict[str, Any]:
        """
        Upload and optimize image to Cloudinary
        """
        try:
            # Validate file type
            if not file.content_type or not file.content_type.startswith("image/"):
                raise HTTPException(400, "File must be an image")
            
            # Check file size (10MB limit)
            if file.size and file.size > 10 * 1024 * 1024:
                raise HTTPException(400, "Image file too large (max 10MB)")
            
            # Generate unique file ID
            file_id = str(uuid.uuid4())
            
            # Upload to Cloudinary with optimizations
            result = cloudinary.uploader.upload(
                file.file,
                public_id=f"showcase/{user_id}/{file_id}",
                transformation=[
                    {"quality": "auto", "fetch_format": "auto"},
                    {"width": 1920, "height": 1080, "crop": "limit"}
                ],
                eager=[
                    {"width": 400, "height": 300, "crop": "fill", "quality": "auto"},  # Thumbnail
                    {"width": 800, "height": 600, "crop": "fill", "quality": "auto"},  # Medium
                ],
                eager_async=True,
                folder="showcase"
            )
            
            logger.info(f"Image uploaded successfully: {file_id} for user {user_id}")
            
            return {
                "id": file_id,
                "url": result["secure_url"],
                "thumbnail": result["eager"][0]["secure_url"] if result.get("eager") else result["secure_url"],
                "medium": result["eager"][1]["secure_url"] if len(result.get("eager", [])) > 1 else result["secure_url"],
                "public_id": result["public_id"],
                "format": result["format"],
                "bytes": result["bytes"],
                "width": result.get("width"),
                "height": result.get("height"),
                "created_at": result["created_at"]
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Image upload failed: {str(e)}")
            raise HTTPException(500, f"Image upload failed: {str(e)}")
    
    @staticmethod
    async def upload_video(file: UploadFile, user_id: str) -> Dict[str, Any]:
        """
        Upload and process video to Cloudinary
        """
        try:
            # Validate file type
            if not file.content_type or not file.content_type.startswith("video/"):
                raise HTTPException(400, "File must be a video")
            
            # Check file size (100MB limit)
            if file.size and file.size > 100 * 1024 * 1024:
                raise HTTPException(400, "Video file too large (max 100MB)")
            
            # Generate unique file ID
            file_id = str(uuid.uuid4())
            
            # Upload to Cloudinary with video processing
            result = cloudinary.uploader.upload(
                file.file,
                public_id=f"videos/{user_id}/{file_id}",
                resource_type="video",
                transformation=[
                    {"quality": "auto", "format": "mp4"},
                    {"width": 1280, "height": 720, "crop": "limit"}
                ],
                eager=[
                    {"width": 640, "height": 360, "format": "mp4", "quality": "auto"},  # Compressed
                    {"resource_type": "image", "format": "jpg", "quality": "auto"}      # Thumbnail
                ],
                eager_async=True,
                folder="videos"
            )
            
            logger.info(f"Video uploaded successfully: {file_id} for user {user_id}")
            
            return {
                "id": file_id,
                "url": result["secure_url"],
                "thumbnail": result["eager"][1]["secure_url"] if len(result.get("eager", [])) > 1 else None,
                "compressed": result["eager"][0]["secure_url"] if result.get("eager") else result["secure_url"],
                "public_id": result["public_id"],
                "duration": result.get("duration", 0),
                "format": result["format"],
                "bytes": result["bytes"],
                "width": result.get("width"),
                "height": result.get("height"),
                "created_at": result["created_at"]
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Video upload failed: {str(e)}")
            raise HTTPException(500, f"Video upload failed: {str(e)}")
    
    @staticmethod
    def get_optimized_url(public_id: str, width: int = None, height: int = None, quality: str = "auto") -> str:
        """
        Generate optimized Cloudinary URL with transformations
        """
        try:
            transformation = [{"quality": quality, "fetch_format": "auto"}]
            
            if width and height:
                transformation.append({"width": width, "height": height, "crop": "fill"})
            elif width:
                transformation.append({"width": width, "crop": "scale"})
            elif height:
                transformation.append({"height": height, "crop": "scale"})
            
            url, _ = cloudinary.utils.cloudinary_url(
                public_id,
                transformation=transformation,
                secure=True
            )
            
            return url
            
        except Exception as e:
            logger.error(f"URL generation failed: {str(e)}")
            return f"https://res.cloudinary.com/{cloudinary.config().cloud_name}/image/upload/{public_id}"
    
    @staticmethod
    async def delete_media(public_id: str, resource_type: str = "image") -> bool:
        """
        Delete media from Cloudinary
        """
        try:
            result = cloudinary.uploader.destroy(public_id, resource_type=resource_type)
            success = result.get("result") == "ok"
            
            if success:
                logger.info(f"Media deleted successfully: {public_id}")
            else:
                logger.warning(f"Media deletion failed: {public_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"Media deletion error: {str(e)}")
            return False
