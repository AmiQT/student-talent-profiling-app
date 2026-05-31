"""
Profile model - matches Supabase profiles table schema exactly
"""
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, JSON, Boolean, ARRAY, Float, Integer
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Profile(Base):
    __tablename__ = "profiles"
    
    # Primary fields (match database exactly)
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=True)
    
    # Personal information (match database column names exactly)
    full_name = Column(String, nullable=True)  # snake_case
    bio = Column(Text, nullable=True)
    phone_number = Column(String, nullable=True)  # snake_case
    address = Column(Text, nullable=True)
    headline = Column(String, nullable=True)
    profile_image_url = Column(Text, nullable=True)  # snake_case
    
    # Academic fields (direct columns for easier queries)
    student_id = Column(String, nullable=True)
    department = Column(String, nullable=True)
    faculty = Column(String, nullable=True)
    year_of_study = Column(String, nullable=True)
    cgpa = Column(String, nullable=True)  # Stored as string for flexibility
    
    # Social links
    linkedin_url = Column(String, nullable=True)
    github_url = Column(String, nullable=True)
    portfolio_url = Column(String, nullable=True)
    languages = Column(ARRAY(String), nullable=True)
    
    # Academic & experience info (stored as JSONB)
    academic_info = Column(JSON, nullable=True)  # Contains additional student info
    skills = Column(ARRAY(String), nullable=True)  # Array of skills
    interests = Column(ARRAY(String), nullable=True)  # Array of interests
    experiences = Column(JSON, nullable=True)  # JSONB
    projects = Column(JSON, nullable=True)  # JSONB
    
    # Talent system - soft skills, hobbies, and quiz results
    soft_skills = Column(JSON, nullable=True)  # Array of soft skill objects
    hobbies = Column(JSON, nullable=True)  # Array of hobby objects
    talent_quiz_results = Column(JSON, nullable=True)  # Quiz results object
    
    # Personal Advisor (PAK - Penasihat Akademik)
    personal_advisor = Column(String, nullable=True)  # PAK name e.g. "Dr. Muhaini"
    personal_advisor_email = Column(String, nullable=True)  # PAK email
    
    # Kokurikulum metrics
    kokurikulum_score = Column(Float, nullable=True)  # Score from 0-100
    kokurikulum_credits = Column(Integer, nullable=True)  # Credits earned from koku activities
    kokurikulum_activities = Column(ARRAY(String), nullable=True)  # List of koku activities
    
    # Profile completion status
    is_profile_complete = Column(Boolean, nullable=True, default=False)
    
    # Timestamps (snake_case)
    created_at = Column(DateTime(timezone=True), nullable=True, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())
    
    # Relationships
    user = relationship("User", backref="profile")
    
    def __repr__(self):
        return f"<Profile(id={self.id}, user_id={self.user_id}, name={self.full_name})>"
    
    def get_balance_metrics(self):
        """Calculate academic-kokurikulum balance metrics"""
        # Get CGPA from academic_info
        cgpa = 0.0
        if self.academic_info and isinstance(self.academic_info, dict):
            cgpa = float(self.academic_info.get('cgpa', 0) or 0)
        
        academic_score = (cgpa / 4.0) * 100  # Convert CGPA to percentage
        koku_score = self.kokurikulum_score or 0
        
        # Calculate balance score (0-100, where 100 is perfectly balanced)
        diff = abs(academic_score - koku_score)
        balance_score = 100 - diff
        
        if diff <= 10:
            balance_status = 'Seimbang'  # Balanced
        elif academic_score > koku_score:
            balance_status = 'Fokus Akademik'  # Academic focused
        else:
            balance_status = 'Fokus Kokurikulum'  # Koku focused
        
        return {
            'academic_score': round(academic_score, 2),
            'kokurikulum_score': round(koku_score, 2),
            'balance_score': round(balance_score, 2),
            'balance_status': balance_status,
        }