"""
Achievement model - matches Firebase achievements collection
"""
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey, Integer, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Achievement(Base):
    __tablename__ = "achievements"
    
    # Primary fields
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    
    # Achievement details
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String, nullable=True)  # "academic", "technical", "leadership", etc.
    
    # Achievement metadata
    achievement_type = Column(String, nullable=True)  # "certificate", "award", "competition", etc.
    issuing_organization = Column(String, nullable=True)
    date_achieved = Column(DateTime(timezone=True), nullable=True)
    
    # Media and evidence
    image_urls = Column(JSON, nullable=True)  # Array of image URLs
    document_urls = Column(JSON, nullable=True)  # Array of document URLs
    
    # Verification
    is_verified = Column(Boolean, default=False)
    verified_by = Column(String, nullable=True)  # Admin/lecturer who verified
    verified_at = Column(DateTime(timezone=True), nullable=True)
    
    # Skills and tags
    skills_demonstrated = Column(JSON, nullable=True)  # Array of skills
    tags = Column(JSON, nullable=True)  # Array of tags
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    user = relationship("User", backref="achievements")
    
    def __repr__(self):
        return f"<Achievement(id={self.id}, title={self.title}, verified={self.is_verified})>"

class UserAchievement(Base):
    """
    Junction table for awarded achievements (like badges)
    """
    __tablename__ = "user_achievements"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    achievement_id = Column(String, ForeignKey("achievements.id"), nullable=False)
    
    # Award details
    awarded_by = Column(String, nullable=True)  # Admin who awarded
    award_reason = Column(Text, nullable=True)
    points_earned = Column(Integer, default=0)
    
    # Timestamps
    awarded_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", backref="user_achievements")
    achievement = relationship("Achievement", backref="user_achievements")
    
    def __repr__(self):
        return f"<UserAchievement(user_id={self.user_id}, achievement_id={self.achievement_id})>"