"""
Event model - matches Firebase events collection
"""
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, JSON, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
import uuid
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Event(Base):
    __tablename__ = "events"
    
    # Primary fields (match database exactly)
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=True, default='general')  # NEW: Event category
    image_url = Column(Text, nullable=True)  # NEW: Event image
    registration_url = Column(Text, nullable=True)  # NEW: Registration link
    max_participants = Column(Integer, nullable=True)  # NEW: Max participants (NULL = unlimited)
    event_date = Column(DateTime(timezone=True), nullable=True)
    location = Column(String, nullable=True)
    organizer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    is_active = Column(Boolean, nullable=True, default=True)
    created_at = Column(DateTime(timezone=True), nullable=True, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), nullable=True, onupdate=func.now())
    
    # Relationships
    organizer = relationship("User", backref="organized_events")
    
    def __repr__(self):
        return f"<Event(id={self.id}, title={self.title}, category={self.category})>"

class EventParticipation(Base):
    """
    Junction table for event participation
    """
    __tablename__ = "event_participations"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    event_id = Column(UUID(as_uuid=True), ForeignKey("events.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Participation details
    registration_date = Column(DateTime(timezone=True), server_default=func.now())
    attendance_status = Column(String, default="registered")  # "registered", "attended", "no_show"
    feedback_rating = Column(Integer, nullable=True)  # 1-5 rating
    feedback_comment = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    event = relationship("Event", backref="participations")
    user = relationship("User", backref="event_participations")
    
    def __repr__(self):
        return f"<EventParticipation(event_id={self.event_id}, user_id={self.user_id})>"