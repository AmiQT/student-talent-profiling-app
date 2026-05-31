"""
Events API endpoints - Full CRUD with Supabase
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
import uuid
import os
# Firebase auth removed - using Supabase auth
from app.database import get_db
from app.auth import verify_supabase_token, verify_admin_user
from app.models.event import Event
from supabase import create_client, Client
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/events", tags=["Events"])

# Pydantic models for request validation
class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: Optional[str] = "general"
    image_url: Optional[str] = None
    registration_url: Optional[str] = None
    max_participants: Optional[int] = None  # NULL = unlimited, number = limit
    event_date: Optional[datetime] = None
    location: Optional[str] = None

class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    image_url: Optional[str] = None
    registration_url: Optional[str] = None
    max_participants: Optional[int] = None  # NULL = unlimited, number = limit
    event_date: Optional[datetime] = None
    location: Optional[str] = None
    is_active: Optional[bool] = None

@router.get("/")
async def get_all_events(
    limit: int = Query(100, le=200),
    category: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_supabase_token),
):
    """Get all events from Supabase database"""
    try:
        from supabase import create_client
        
        # Initialize Supabase client
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        logger.info(f"🔑 Supabase URL loaded: {bool(supabase_url)}, Key loaded: {bool(supabase_key)}")
        
        if not supabase_url or not supabase_key:
            logger.error(f"Supabase credentials not configured - URL: {bool(supabase_url)}, Key: {bool(supabase_key)}")
            raise HTTPException(
                status_code=500, 
                detail=f"Database configuration error - Missing: {'URL' if not supabase_url else ''} {'KEY' if not supabase_key else ''}"
            )
        
        supabase = create_client(supabase_url, supabase_key)
        
        # Build query
        query = supabase.table('events').select('*').order('created_at', desc=True)
        
        # Apply filters
        if category:
            query = query.eq('category', category)
        
        query = query.limit(limit)
        
        # Execute query
        response = query.execute()
        
        events = response.data if response.data else []
        
        logger.info(f"Retrieved {len(events)} events from database")
        
        return {
            "events": events,
            "total": len(events),
            "message": "Events retrieved successfully"
        }
        
    except Exception as e:
        logger.error(f"Error getting events: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get events: {str(e)}")

@router.get("/{event_id}")
async def get_event_by_id(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_supabase_token),
):
    """Get event by ID from Supabase database"""
    try:
        from supabase import create_client
        
        # Initialize Supabase client
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_KEY")
        
        if not supabase_url or not supabase_key:
            logger.error("Supabase credentials not configured")
            raise HTTPException(status_code=500, detail="Database configuration error")
        
        supabase = create_client(supabase_url, supabase_key)
        
        # Query event
        response = supabase.table('events').select('*').eq('id', event_id).execute()
        
        if not response.data or len(response.data) == 0:
            raise HTTPException(status_code=404, detail="Event not found")
        
        return response.data[0]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting event: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get event: {str(e)}")

@router.post("/")
async def create_event(
    event_data: EventCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_admin_user),
):
    """Create new event - Admin only"""
    try:
        logger.info(f"Creating event: {event_data.title}")
        
        # Create new event using SQLAlchemy (bypasses RLS)
        new_event = Event(
            id=str(uuid.uuid4()),
            title=event_data.title,
            description=event_data.description,
            category=event_data.category or "general",
            image_url=event_data.image_url,
            registration_url=event_data.registration_url,
            max_participants=event_data.max_participants,  # NULL = unlimited
            event_date=event_data.event_date,
            location=event_data.location,
            organizer_id=current_user.get('uid'),  # Use uid from JWT
            is_active=True,
            created_at=datetime.utcnow()
        )
        
        db.add(new_event)
        db.commit()
        db.refresh(new_event)
        
        logger.info(f"✅ Event created successfully: {event_data.title}")
        
        return {
            "message": "Event created successfully",
            "event": {
                "id": new_event.id,
                "title": new_event.title,
                "description": new_event.description,
                "category": new_event.category,
                "image_url": new_event.image_url,
                "registration_url": new_event.registration_url,
                "max_participants": new_event.max_participants,
                "event_date": new_event.event_date.isoformat() if new_event.event_date else None,
                "location": new_event.location,
                "is_active": new_event.is_active,
                "created_at": new_event.created_at.isoformat() if new_event.created_at else None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating event: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to create event: {str(e)}")

@router.put("/{event_id}")
async def update_event(
    event_id: str,
    event_data: EventUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_admin_user),
):
    """Update event - Admin only"""
    try:
        from supabase import create_client
        
        logger.info(f"Updating event: {event_id}")
        
        # Check if event exists using SQLAlchemy (bypasses RLS)
        event = db.query(Event).filter(Event.id == event_id).first()
        
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")
        
        # Update fields (only update fields that are set)
        if event_data.title is not None:
            event.title = event_data.title
        if event_data.description is not None:
            event.description = event_data.description
        if event_data.category is not None:
            event.category = event_data.category
        if event_data.image_url is not None:
            event.image_url = event_data.image_url
        if event_data.registration_url is not None:
            event.registration_url = event_data.registration_url
        if event_data.max_participants is not None:
            event.max_participants = event_data.max_participants
        if event_data.event_date is not None:
            event.event_date = event_data.event_date
        if event_data.location is not None:
            event.location = event_data.location
        if event_data.is_active is not None:
            event.is_active = event_data.is_active
        
        event.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(event)
        
        logger.info(f"✅ Event updated successfully: {event_id}")
        
        return {
            "message": "Event updated successfully",
            "event": {
                "id": event.id,
                "title": event.title,
                "description": event.description,
                "category": event.category,
                "image_url": event.image_url,
                "registration_url": event.registration_url,
                "max_participants": event.max_participants,
                "event_date": event.event_date.isoformat() if event.event_date else None,
                "location": event.location,
                "is_active": event.is_active,
                "updated_at": event.updated_at.isoformat() if event.updated_at else None
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating event: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to update event: {str(e)}")

@router.delete("/{event_id}")
async def delete_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(verify_admin_user),
):
    """Delete event - Admin only"""
    try:
        from app.models.event import EventParticipation
        
        logger.info(f"Deleting event: {event_id}")
        
        # Check if event exists using SQLAlchemy (bypasses RLS)
        event = db.query(Event).filter(Event.id == event_id).first()
        
        if not event:
            raise HTTPException(status_code=404, detail="Event not found")
        
        event_title = event.title
        
        # Delete related event participations first (foreign key constraint)
        db.query(EventParticipation).filter(EventParticipation.event_id == event_id).delete()
        
        # Delete the event
        db.delete(event)
        db.commit()
        
        logger.info(f"✅ Event deleted successfully: {event_title}")
        
        return {
            "message": "Event deleted successfully",
            "event_id": event_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting event: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to delete event: {str(e)}")
