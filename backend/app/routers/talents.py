"""
Talent router - API endpoints for soft skills, hobbies, and talent quiz
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime
import uuid

from app.database import get_db
from sqlalchemy.orm import Session
from app.models.profile import Profile

router = APIRouter(prefix="/talents", tags=["talents"])


# ==================== PYDANTIC MODELS ====================

class SoftSkillCreate(BaseModel):
    name: str
    category: str
    proficiency_level: str
    description: Optional[str] = None


class SoftSkillUpdate(BaseModel):
    soft_skills: List[Dict[str, Any]]


class HobbyCreate(BaseModel):
    name: str
    category: str
    subcategory: Optional[str] = None
    years_experience: Optional[int] = None
    description: Optional[str] = None
    achievements: Optional[List[str]] = []


class HobbyUpdate(BaseModel):
    hobbies: List[Dict[str, Any]]


class TalentQuizAnswer(BaseModel):
    question_id: str
    answer: str
    category: str
    score: int


class TalentQuizSubmit(BaseModel):
    answers: List[TalentQuizAnswer]


class TalentQuizResultResponse(BaseModel):
    id: str
    user_id: str
    category_scores: Dict[str, int]
    top_talents: List[str]
    answers: Dict[str, Any]
    completed_at: str


class TalentProfileResponse(BaseModel):
    user_id: str
    soft_skills: List[Dict[str, Any]]
    hobbies: List[Dict[str, Any]]
    quiz_results: Optional[Dict[str, Any]]
    updated_at: str


# ==================== SOFT SKILL CATEGORIES ====================

SOFT_SKILL_CATEGORIES = [
    "communication",
    "leadership",
    "teamwork",
    "criticalThinking",
    "problemSolving",
    "creativity",
    "timeManagement",
    "adaptability",
    "emotionalIntelligence",
]

SOFT_SKILL_DISPLAY_NAMES = {
    "communication": "Komunikasi",
    "leadership": "Kepimpinan",
    "teamwork": "Kerja Berpasukan",
    "criticalThinking": "Pemikiran Kritis",
    "problemSolving": "Penyelesaian Masalah",
    "creativity": "Kreativiti",
    "timeManagement": "Pengurusan Masa",
    "adaptability": "Kebolehsuaian",
    "emotionalIntelligence": "Kecerdasan Emosi",
}


# ==================== HOBBY CATEGORIES ====================

HOBBY_CATEGORIES = [
    "performingArts",
    "visualArts",
    "sports",
    "languageLiterature",
    "technicalHobbies",
    "communitySocial",
]

HOBBY_DISPLAY_NAMES = {
    "performingArts": "Seni Persembahan",
    "visualArts": "Seni Visual",
    "sports": "Sukan",
    "languageLiterature": "Bahasa & Sastera",
    "technicalHobbies": "Hobi Teknikal",
    "communitySocial": "Komuniti & Sosial",
}

HOBBY_SUBCATEGORIES = {
    "performingArts": ["musicInstrument", "singing", "traditionalDance", "modernDance", "drama", "choir"],
    "visualArts": ["painting", "digitalArt", "photography", "videography", "sculpture", "crafts"],
    "sports": ["teamSports", "individualSports", "martialArts", "esports", "extremeSports", "fitness"],
    "languageLiterature": ["publicSpeaking", "debate", "poetry", "creativeWriting", "journalism", "foreignLanguage"],
    "technicalHobbies": ["robotics", "programming", "gameDevelopment", "electronics", "threeDPrinting", "diy"],
    "communitySocial": ["volunteering", "environmentalism", "entrepreneurship", "eventOrganizing", "mentoring", "socialActivism"],
}


# ==================== API ENDPOINTS ====================

@router.get("/categories")
async def get_talent_categories():
    """Get all available talent categories"""
    return {
        "soft_skill_categories": SOFT_SKILL_CATEGORIES,
        "soft_skill_display_names": SOFT_SKILL_DISPLAY_NAMES,
        "hobby_categories": HOBBY_CATEGORIES,
        "hobby_display_names": HOBBY_DISPLAY_NAMES,
        "hobby_subcategories": HOBBY_SUBCATEGORIES,
    }


@router.get("/profile/{user_id}", response_model=TalentProfileResponse)
async def get_talent_profile(user_id: str, db: Session = Depends(get_db)):
    """Get complete talent profile for a user"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    return TalentProfileResponse(
        user_id=user_id,
        soft_skills=profile.soft_skills or [],
        hobbies=profile.hobbies or [],
        quiz_results=profile.talent_quiz_results,
        updated_at=profile.updated_at.isoformat() if profile.updated_at else datetime.now().isoformat(),
    )


@router.put("/soft-skills/{user_id}")
async def update_soft_skills(user_id: str, update: SoftSkillUpdate, db: Session = Depends(get_db)):
    """Update soft skills for a user"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Validate categories
    for skill in update.soft_skills:
        if skill.get("category") and skill["category"] not in SOFT_SKILL_CATEGORIES:
            raise HTTPException(
                status_code=400, 
                detail=f"Invalid category: {skill['category']}. Valid: {SOFT_SKILL_CATEGORIES}"
            )
    
    # Add IDs and timestamps to new skills
    processed_skills = []
    for skill in update.soft_skills:
        if not skill.get("id"):
            skill["id"] = str(uuid.uuid4())
        if not skill.get("created_at"):
            skill["created_at"] = datetime.now().isoformat()
        skill["updated_at"] = datetime.now().isoformat()
        processed_skills.append(skill)
    
    profile.soft_skills = processed_skills
    profile.updated_at = datetime.now()
    
    db.commit()
    db.refresh(profile)
    
    return {
        "message": "Soft skills updated successfully",
        "soft_skills": profile.soft_skills,
    }


@router.put("/hobbies/{user_id}")
async def update_hobbies(user_id: str, update: HobbyUpdate, db: Session = Depends(get_db)):
    """Update hobbies for a user"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Validate categories
    for hobby in update.hobbies:
        if hobby.get("category") and hobby["category"] not in HOBBY_CATEGORIES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid category: {hobby['category']}. Valid: {HOBBY_CATEGORIES}"
            )
    
    # Add IDs and timestamps to new hobbies
    processed_hobbies = []
    for hobby in update.hobbies:
        if not hobby.get("id"):
            hobby["id"] = str(uuid.uuid4())
        if not hobby.get("created_at"):
            hobby["created_at"] = datetime.now().isoformat()
        hobby["updated_at"] = datetime.now().isoformat()
        processed_hobbies.append(hobby)
    
    profile.hobbies = processed_hobbies
    profile.updated_at = datetime.now()
    
    db.commit()
    db.refresh(profile)
    
    return {
        "message": "Hobbies updated successfully",
        "hobbies": profile.hobbies,
    }


@router.post("/quiz-results/{user_id}")
async def save_quiz_results(user_id: str, submit: TalentQuizSubmit, db: Session = Depends(get_db)):
    """Save talent quiz results"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Calculate category scores
    category_scores: Dict[str, int] = {}
    answers_dict: Dict[str, Any] = {}
    
    for answer in submit.answers:
        cat = answer.category
        if cat not in category_scores:
            category_scores[cat] = 0
        category_scores[cat] += answer.score
        answers_dict[answer.question_id] = {
            "answer": answer.answer,
            "category": answer.category,
            "score": answer.score,
        }
    
    # Get top 3 talents
    sorted_categories = sorted(category_scores.items(), key=lambda x: x[1], reverse=True)
    top_talents = [cat for cat, _ in sorted_categories[:3]]
    
    quiz_results = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "category_scores": category_scores,
        "top_talents": top_talents,
        "answers": answers_dict,
        "completed_at": datetime.now().isoformat(),
    }
    
    profile.talent_quiz_results = quiz_results
    profile.updated_at = datetime.now()
    
    db.commit()
    db.refresh(profile)
    
    return {
        "message": "Quiz results saved successfully",
        "quiz_results": quiz_results,
    }


@router.get("/quiz-results/{user_id}")
async def get_quiz_results(user_id: str, db: Session = Depends(get_db)):
    """Get talent quiz results for a user"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    if not profile.talent_quiz_results:
        return {"message": "No quiz results found", "quiz_results": None}
    
    return {"quiz_results": profile.talent_quiz_results}


@router.get("/recommendations/{user_id}")
async def get_recommendations(user_id: str, db: Session = Depends(get_db)):
    """Get personalized recommendations based on talent profile"""
    profile = db.query(Profile).filter(Profile.user_id == user_id).first()
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    recommendations = {
        "events": [],
        "clubs": [],
        "similar_students": [],
    }
    
    # Get user's top interest categories
    user_categories = set()
    
    # From hobbies
    if profile.hobbies:
        for hobby in profile.hobbies:
            if isinstance(hobby, dict) and hobby.get("category"):
                user_categories.add(hobby["category"])
    
    # From quiz results
    if profile.talent_quiz_results and profile.talent_quiz_results.get("top_talents"):
        user_categories.update(profile.talent_quiz_results["top_talents"])
    
    # From regular interests
    if profile.interests:
        user_categories.update(profile.interests)
    
    # Find similar students (same categories)
    if user_categories:
        similar_profiles = db.query(Profile).filter(
            Profile.user_id != user_id,
            Profile.hobbies.isnot(None)
        ).limit(10).all()
        
        for p in similar_profiles:
            p_categories = set()
            if p.hobbies:
                for hobby in p.hobbies:
                    if isinstance(hobby, dict) and hobby.get("category"):
                        p_categories.add(hobby["category"])
            
            # Calculate similarity
            common = user_categories.intersection(p_categories)
            if common:
                recommendations["similar_students"].append({
                    "user_id": p.user_id,
                    "full_name": p.full_name,
                    "profile_image_url": p.profile_image_url,
                    "common_interests": list(common),
                    "similarity_score": len(common) / max(len(user_categories), 1),
                })
        
        # Sort by similarity
        recommendations["similar_students"] = sorted(
            recommendations["similar_students"],
            key=lambda x: x["similarity_score"],
            reverse=True
        )[:5]
    
    # TODO: Add event recommendations based on categories
    # This will integrate with the events system
    
    return recommendations
