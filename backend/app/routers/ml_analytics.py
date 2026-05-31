"""
ML Analytics Router

FastAPI endpoints for ML analytics, student risk predictions, and cache management.
"""

from fastapi import APIRouter, HTTPException, Query, Depends
from sqlalchemy.orm import Session
from typing import Optional, List
import logging
import uuid
from datetime import timedelta

from app.ml_analytics import MLPredictor, CacheManager, MLConfig
from app.database import get_db
from app.models.profile import Profile

logger = logging.getLogger(__name__)

# Initialize router
router = APIRouter(prefix="/api/ml", tags=["ML Analytics"])

# Initialize ML services
cache_manager = CacheManager(
    max_size=MLConfig.CACHE_MAX_SIZE,
    default_ttl=MLConfig.CACHE_TTL,
)
predictor = MLPredictor(cache_manager=cache_manager)


@router.get("/health")
async def health_check():
    """
    Check ML system health

    Returns:
        Health status including API configuration and cache stats
    """
    health = predictor.health_check()
    return {
        "status": health["status"],
        "gemini_api_configured": health["gemini_api_configured"],
        "model": health["model"],
        "cache": health["cache_status"],
        "message": "ML Analytics service is operational" if health["status"] == "healthy" else "ML service degraded",
    }


@router.post("/student/{student_id}/predict")
async def predict_student_risk(
    student_id: str,
    student_data: Optional[dict] = None,
    db: Session = Depends(get_db),
):
    """
    Predict student risk

    Predicts student risk level based on their profile data.
    Results are cached for 24 hours to respect API rate limits.

    Args:
        student_id: Student ID (e.g., CE210002)
        student_data: Student data dictionary with features (optional, will fetch from DB)

    Returns:
        Risk prediction with factors, strengths, recommendations
    """
    try:
        # If no student_data provided, fetch from database
        if not student_data or not student_data.get("cgpa"):
            # Try to find student by student_id first
            profile = db.query(Profile).filter(Profile.student_id == student_id).first()
            
            # If not found, try UUID
            if not profile:
                try:
                    val = uuid.UUID(student_id, version=4)
                    profile = db.query(Profile).filter(Profile.id == student_id).first()
                except ValueError:
                    pass
            
            if profile:
                # Build full student data from database
                cgpa_value = 0.0
                if profile.cgpa:
                    try:
                        cgpa_value = float(profile.cgpa)
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid CGPA for {student_id}: {profile.cgpa}")
                
                student_data = {
                    "id": str(profile.id),
                    "student_id": profile.student_id or str(profile.id)[:8],
                    "name": profile.full_name,
                    "full_name": profile.full_name,
                    "cgpa": cgpa_value,
                    "department": profile.department,
                    "faculty": profile.faculty,
                    "kokurikulum_score": float(profile.kokurikulum_score) if profile.kokurikulum_score else 0,
                    "academic_info": profile.academic_info or {},
                }
                logger.info(f"Fetched from DB - Student {student_id}: CGPA={cgpa_value}, Koku={student_data['kokurikulum_score']}")
            else:
                # Student not found
                logger.warning(f"Student {student_id} not found in database")
                student_data = {"id": student_id, "student_id": student_id}

        prediction = await predictor.predict_student_risk(student_data)
        
        # Add display fields
        prediction["display_id"] = student_data.get("student_id", student_id)
        prediction["full_name"] = student_data.get("full_name", "Unknown")
        prediction["current_cgpa"] = student_data.get("cgpa", 0.0)
        prediction["kokurikulum_score"] = student_data.get("kokurikulum_score", 0)
        
        return prediction

    except Exception as e:
        logger.error(f"Error predicting risk for {student_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")




@router.get("/student/{student_id}/performance")
async def get_student_performance(
    student_id: str,
    student_data: Optional[dict] = None,
):
    """
    Get student performance analysis

    Provides detailed performance breakdown for a student.

    Args:
        student_id: Student ID
        student_data: Optional student data (if not in cache)

    Returns:
        Performance metrics including academic, engagement, activity, profile, social
    """
    try:
        # Check cache for prediction
        cached = cache_manager.get(f"prediction_{student_id}")

        if cached:
            return {
                "student_id": student_id,
                "performance_metrics": cached.get("performance_metrics"),
                "risk_level": cached.get("risk_level"),
                "risk_emoji": cached.get("risk_emoji"),
                "from_cache": True,
            }

        # If not cached, generate prediction
        if not student_data:
            student_data = {"id": student_id}

        prediction = await predictor.predict_student_risk(student_data)
        return {
            "student_id": student_id,
            "performance_metrics": prediction.get("performance_metrics"),
            "risk_level": prediction.get("risk_level"),
            "risk_emoji": prediction.get("risk_emoji"),
            "from_cache": False,
        }

    except Exception as e:
        logger.error(f"Error getting performance for {student_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/cache/invalidate")
async def invalidate_cache(
    student_id: Optional[str] = Query(None),
):
    """
    Invalidate cache

    Clears cached predictions to force fresh analysis.
    Admin endpoint - should be protected.

    Args:
        student_id: Specific student to invalidate, or None for all

    Returns:
        Confirmation message
    """
    try:
        predictor.invalidate_cache(student_id)

        if student_id:
            return {
                "status": "success",
                "message": f"Cache invalidated for student {student_id}",
            }
        else:
            return {
                "status": "success",
                "message": "All cache invalidated",
            }

    except Exception as e:
        logger.error(f"Error invalidating cache: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats")
async def get_ml_stats():
    """
    Get ML system statistics

    Returns cache hit rates, prediction counts, and system performance.

    Returns:
        System statistics
    """
    try:
        cache_stats = predictor.get_cache_stats()

        return {
            "cache": cache_stats,
            "configuration": {
                "model": MLConfig.GEMINI_MODEL,
                "cache_ttl_hours": MLConfig.CACHE_TTL.total_seconds() / 3600,
                "cache_max_size": MLConfig.CACHE_MAX_SIZE,
                "batch_size": MLConfig.BATCH_PROCESS_SIZE,
            },
            "gemini_api_configured": bool(MLConfig.GEMINI_API_KEY),
        }

    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/batch/predict")
async def batch_predict(body: dict = None, db: Session = Depends(get_db)):
    """
    Batch predict risk for multiple students

    Args:
        body: Request body with student_ids list
              Accepts student_id (AI220001) or UUID
              Example: {"student_ids": ["AI220001", "AI220002"]}

    Returns:
        List of predictions with full student data
    """
    try:
        if body is None:
            raise HTTPException(status_code=400, detail="Request body required")

        # Get student IDs from request
        student_ids = body.get("student_ids", [])

        if not student_ids:
            raise HTTPException(status_code=400, detail="student_ids list required")

        logger.info(f"Starting batch prediction for {len(student_ids)} students")
        
        # Lookup students from database by student_id or UUID
        students_data = []
        for sid in student_ids:
            # Try student_id first (user-friendly: AI220001)
            profile = db.query(Profile).filter(Profile.student_id == sid).first()
            
            # If not found, try UUID
            if not profile:
                try:
                    # Validate UUID before querying to avoid data type mismatch error
                    val = uuid.UUID(sid, version=4)
                    profile = db.query(Profile).filter(Profile.id == sid).first()
                except ValueError:
                    # strictly not a UUID, ignore
                    pass
            
            if profile:
                # Build full student data for prediction
                cgpa_value = 0.0
                if profile.cgpa:
                    try:
                        cgpa_value = float(profile.cgpa)
                    except (ValueError, TypeError):
                        logger.warning(f"Invalid CGPA for {sid}: {profile.cgpa}")
                
                student_dict = {
                    "id": str(profile.id),
                    "student_id": profile.student_id or str(profile.id)[:8],
                    "name": profile.full_name,  # Use 'name' key for data processor
                    "full_name": profile.full_name,
                    "cgpa": cgpa_value,
                    "department": profile.department,
                    "faculty": profile.faculty,
                    "kokurikulum_score": float(profile.kokurikulum_score) if profile.kokurikulum_score else 0,
                    "academic_info": profile.academic_info or {},
                }
                logger.info(f"Student data for {sid}: CGPA={cgpa_value}, Koku={student_dict['kokurikulum_score']}")
                students_data.append(student_dict)
            else:
                # Student not found - still add minimal data
                students_data.append({"id": sid, "student_id": sid})
        
        predictions = await predictor.batch_predict(students_data)
        
        # Enhance predictions with student_id
        for pred in predictions:
            # Find matching student data
            for sd in students_data:
                if sd.get("id") == pred.get("student_id") or sd.get("student_id") == pred.get("student_id"):
                    pred["display_id"] = sd.get("student_id", pred.get("student_id", "")[:8])
                    pred["full_name"] = sd.get("full_name", "Unknown")
                    
                    print(f"DEBUG: MATCH FOUND! Merging data for {pred['student_id']}")
                    print(f"DEBUG: Setting CGPA={sd.get('cgpa')} and Koku={sd.get('kokurikulum_score')}")

                    # Force merge CGPA and Koku for display/heatmap (Frontend expects current_cgpa)
                    # Use the values we fetched from DB, default to 0 if missing
                    pred["current_cgpa"] = sd.get("cgpa", 0.0)
                    pred["kokurikulum_score"] = sd.get("kokurikulum_score", 0)
                    
                    break
            else:
                print(f"DEBUG: NO MATCH found for pred_id={pred.get('student_id')}")

        return {
            "status": "success",
            "total": len(student_ids),
            "predicted": len(predictions),
            "results": predictions,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in batch prediction: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/recommendations/{risk_level}")
async def get_recommendations_by_risk(risk_level: str):
    """
    Get generic recommendations for a risk level

    Args:
        risk_level: 'low', 'medium', or 'high'

    Returns:
        Recommendations for the risk level
    """
    if risk_level not in ["low", "medium", "high"]:
        raise HTTPException(
            status_code=400,
            detail="risk_level must be 'low', 'medium', or 'high'",
        )

    recommendations = {
        "low": {
            "emoji": "🟢",
            "actions": [
                "Monitor regularly",
                "Encourage continued engagement",
                "Celebrate achievements",
            ],
        },
        "medium": {
            "emoji": "🟡",
            "actions": [
                "Reach out this week",
                "Understand concerns",
                "Offer relevant support",
                "Schedule follow-up",
            ],
        },
        "high": {
            "emoji": "🔴",
            "actions": [
                "Contact immediately",
                "Assess situation",
                "Develop intervention plan",
                "Involve counselor/advisor",
                "Weekly follow-ups",
            ],
        },
    }

    return {
        "risk_level": risk_level,
        "emoji": recommendations[risk_level]["emoji"],
        "recommended_actions": recommendations[risk_level]["actions"],
    }
