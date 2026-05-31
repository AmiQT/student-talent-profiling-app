"""
User model - matches Supabase public.users table schema exactly
"""
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID
import uuid
from sqlalchemy.sql import func
from app.database import Base
import enum

class UserRole(enum.Enum):
    student = "student"
    lecturer = "lecturer" 
    admin = "admin"

class User(Base):
    __tablename__ = "users"
    
    # Primary fields (match database exactly)
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)  # UUID from Supabase
    email = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)  
    role = Column(String, nullable=False, default='student')  # Use String instead of Enum for compatibility
    department = Column(String, nullable=True)
    
    # Optional identifier fields  
    student_id = Column(String, nullable=True)
    staff_id = Column(String, nullable=True)
    
    # Status fields
    is_active = Column(Boolean, nullable=True, default=True)
    profile_completed = Column(Boolean, nullable=True, default=False)
    
    # Timestamps (match database exactly)
    created_at = Column(DateTime(timezone=True), nullable=True, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    
    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"