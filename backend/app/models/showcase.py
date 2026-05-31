"""
Showcase model - updated to match comprehensive SQL schema
"""
from sqlalchemy import Column, String, Text, DateTime, Boolean, Integer, JSON, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
import uuid
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class ShowcasePost(Base):
    __tablename__ = "showcase_posts"
    
    # Primary identification
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Post content
    title = Column(String(255), default='')
    description = Column(Text)
    content = Column(Text, nullable=False)
    
    # Categorization and privacy
    category = Column(String(50), default='general')
    privacy = Column(String(20), default='public')
    location = Column(String(255))
    
    # Media content (JSON arrays)
    media_urls = Column(JSON, default=list)
    media_types = Column(JSON, default=list)
    media = Column(JSON)
    
    # Tags and skills
    tags = Column(JSON, default=list)
    skills_used = Column(JSON, default=list)
    mentions = Column(JSON, default=list)
    
    # User information (cached for performance)
    user_name = Column(String(255))
    user_profile_image = Column(Text)
    user_role = Column(String(50))
    user_department = Column(String(100))
    user_headline = Column(Text)
    
    # Engagement metrics
    likes_count = Column(Integer, default=0)
    comments_count = Column(Integer, default=0)
    shares_count = Column(Integer, default=0)
    views_count = Column(Integer, default=0)
    
    # Post settings
    is_public = Column(Boolean, default=True)
    is_featured = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False)
    is_archived = Column(Boolean, default=False)
    allow_comments = Column(Boolean, default=True)
    
    # Content moderation
    is_approved = Column(Boolean, default=True)
    moderated_by = Column(String(128))
    moderation_notes = Column(Text)
    
    # Metadata
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    is_edited = Column(Boolean, default=False)
    
    def __repr__(self):
        return f"<ShowcasePost(id={self.id}, content={self.content[:50]}..., user_id={self.user_id})>"

class ShowcaseComment(Base):
    __tablename__ = "showcase_post_comments"
    
    # Primary fields
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id = Column(UUID(as_uuid=True), ForeignKey("showcase_posts.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    parent_comment_id = Column(UUID(as_uuid=True), ForeignKey("showcase_post_comments.id"), nullable=True)  # For replies
    
    # Comment content
    content = Column(Text, nullable=False)
    
    # User information (cached)
    user_name = Column(String(255))
    user_profile_image = Column(Text)
    
    # Engagement
    likes_count = Column(Integer, default=0)
    mentions = Column(JSON, default=list)
    
    # Moderation
    is_approved = Column(Boolean, default=True)
    is_edited = Column(Boolean, default=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    post = relationship("ShowcasePost", backref="comments")
    parent_comment = relationship("ShowcaseComment", remote_side=[id], backref="replies")
    
    def __repr__(self):
        return f"<ShowcaseComment(id={self.id}, post_id={self.post_id}, user_id={self.user_id})>"

class ShowcaseLike(Base):
    __tablename__ = "showcase_post_likes"
    
    # Primary fields
    id = Column(Integer, primary_key=True, autoincrement=True)
    post_id = Column(UUID(as_uuid=True), ForeignKey("showcase_posts.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    post = relationship("ShowcasePost", backref="likes")
    
    def __repr__(self):
        return f"<ShowcaseLike(post_id={self.post_id}, user_id={self.user_id})>"

class ShowcaseShare(Base):
    __tablename__ = "showcase_post_shares"
    
    # Primary fields
    id = Column(Integer, primary_key=True, autoincrement=True)
    post_id = Column(UUID(as_uuid=True), ForeignKey("showcase_posts.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    shared_to = Column(String(50))  # 'timeline', 'external', etc.
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    post = relationship("ShowcasePost", backref="shares")
    
    def __repr__(self):
        return f"<ShowcaseShare(post_id={self.post_id}, user_id={self.user_id}, shared_to={self.shared_to})>"