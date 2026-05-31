-- Migration: Add Event Registration Fields
-- Date: 2025-01-XX
-- Description: Adds fields to events table to support in-app registration and updates event_participations table

-- ======================================
-- PART 1: Update events table
-- ======================================

-- Add registration-related columns to events table
ALTER TABLE events
ADD COLUMN IF NOT EXISTS event_date TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS venue TEXT,
ADD COLUMN IF NOT EXISTS max_participants INTEGER,
ADD COLUMN IF NOT EXISTS current_participants INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS registration_deadline TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS registration_open BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS requirements TEXT[],
ADD COLUMN IF NOT EXISTS skills_gained TEXT[],
ADD COLUMN IF NOT EXISTS target_audience TEXT[];

-- Add indexes for query performance
CREATE INDEX IF NOT EXISTS idx_events_event_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_registration_open ON events(registration_open);
CREATE INDEX IF NOT EXISTS idx_events_registration_deadline ON events(registration_deadline);

-- Add check constraint for participant count
ALTER TABLE events
ADD CONSTRAINT chk_participants_positive 
CHECK (current_participants >= 0);

ALTER TABLE events
ADD CONSTRAINT chk_max_participants_positive 
CHECK (max_participants IS NULL OR max_participants > 0);

ALTER TABLE events
ADD CONSTRAINT chk_current_not_exceed_max 
CHECK (max_participants IS NULL OR current_participants <= max_participants);

-- ======================================
-- PART 2: Update event_participations table
-- ======================================

-- Add participant_data JSONB column to store auto-filled profile data
ALTER TABLE event_participations
ADD COLUMN IF NOT EXISTS participant_data JSONB;

-- Add index for participant_data JSONB queries
CREATE INDEX IF NOT EXISTS idx_event_participations_participant_data 
ON event_participations USING GIN (participant_data);

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_event_participations_event_user 
ON event_participations(event_id, user_id);

CREATE INDEX IF NOT EXISTS idx_event_participations_user_id 
ON event_participations(user_id);

CREATE INDEX IF NOT EXISTS idx_event_participations_attendance_status 
ON event_participations(attendance_status);

-- ======================================
-- PART 3: Create helper functions
-- ======================================

-- Function: Get participant count for an event
CREATE OR REPLACE FUNCTION get_event_participant_count(p_event_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM event_participations
    WHERE event_id = p_event_id
      AND attendance_status != 'cancelled'
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Check if event is full
CREATE OR REPLACE FUNCTION is_event_full(p_event_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_max_participants INTEGER;
  v_current_participants INTEGER;
BEGIN
  SELECT max_participants, current_participants
  INTO v_max_participants, v_current_participants
  FROM events
  WHERE id = p_event_id;

  -- If no max limit, event is never full
  IF v_max_participants IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN v_current_participants >= v_max_participants;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Check if registration is open
CREATE OR REPLACE FUNCTION is_registration_open(p_event_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_registration_open BOOLEAN;
  v_registration_deadline TIMESTAMP WITH TIME ZONE;
  v_is_full BOOLEAN;
BEGIN
  SELECT registration_open, registration_deadline
  INTO v_registration_open, v_registration_deadline
  FROM events
  WHERE id = p_event_id;

  -- Check basic registration_open flag
  IF v_registration_open = FALSE THEN
    RETURN FALSE;
  END IF;

  -- Check deadline
  IF v_registration_deadline IS NOT NULL AND NOW() > v_registration_deadline THEN
    RETURN FALSE;
  END IF;

  -- Check if full
  v_is_full := is_event_full(p_event_id);
  IF v_is_full THEN
    RETURN FALSE;
  END IF;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- ======================================
-- PART 4: Create triggers
-- ======================================

-- Trigger: Auto-update current_participants on insert
CREATE OR REPLACE FUNCTION update_current_participants_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE events
  SET current_participants = COALESCE(current_participants, 0) + 1
  WHERE id = NEW.event_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_participants_insert ON event_participations;
CREATE TRIGGER trg_update_participants_insert
AFTER INSERT ON event_participations
FOR EACH ROW
WHEN (NEW.attendance_status != 'cancelled')
EXECUTE FUNCTION update_current_participants_on_insert();

-- Trigger: Auto-update current_participants on delete
CREATE OR REPLACE FUNCTION update_current_participants_on_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE events
  SET current_participants = GREATEST(COALESCE(current_participants, 1) - 1, 0)
  WHERE id = OLD.event_id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_participants_delete ON event_participations;
CREATE TRIGGER trg_update_participants_delete
AFTER DELETE ON event_participations
FOR EACH ROW
WHEN (OLD.attendance_status != 'cancelled')
EXECUTE FUNCTION update_current_participants_on_delete();

-- Trigger: Auto-update current_participants on status change
CREATE OR REPLACE FUNCTION update_current_participants_on_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If changing from non-cancelled to cancelled
  IF OLD.attendance_status != 'cancelled' AND NEW.attendance_status = 'cancelled' THEN
    UPDATE events
    SET current_participants = GREATEST(COALESCE(current_participants, 1) - 1, 0)
    WHERE id = NEW.event_id;
  END IF;

  -- If changing from cancelled to non-cancelled
  IF OLD.attendance_status = 'cancelled' AND NEW.attendance_status != 'cancelled' THEN
    UPDATE events
    SET current_participants = COALESCE(current_participants, 0) + 1
    WHERE id = NEW.event_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_participants_status ON event_participations;
CREATE TRIGGER trg_update_participants_status
AFTER UPDATE OF attendance_status ON event_participations
FOR EACH ROW
EXECUTE FUNCTION update_current_participants_on_status_change();

-- ======================================
-- PART 5: Data migration (optional)
-- ======================================

-- Sync current_participants with actual count from event_participations
UPDATE events e
SET current_participants = (
  SELECT COUNT(*)::INTEGER
  FROM event_participations ep
  WHERE ep.event_id = e.id
    AND ep.attendance_status != 'cancelled'
);

-- ======================================
-- PART 6: Grant permissions
-- ======================================

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION get_event_participant_count(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_event_full(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_registration_open(UUID) TO authenticated;

-- ======================================
-- VERIFICATION QUERIES
-- ======================================

-- To verify the migration:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'events';
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'event_participations';
-- SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name LIKE '%event%';
