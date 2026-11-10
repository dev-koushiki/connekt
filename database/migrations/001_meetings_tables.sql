-- Migration: 001_meetings_tables.sql
-- Create and enhance meetings schema for CONNEKT

-- 1. Ensure meetings table has all required fields
CREATE TABLE IF NOT EXISTS meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code VARCHAR(60) UNIQUE NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    agenda TEXT DEFAULT '',
    host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    start_time TIMESTAMPTZ DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    duration_minutes INT DEFAULT 30,
    status VARCHAR(30) NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'ended', 'cancelled')),
    is_locked BOOLEAN NOT NULL DEFAULT false,
    passcode VARCHAR(100),
    meeting_link VARCHAR(255),
    participants TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alter existing columns if table already existed
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'room_code') THEN
        ALTER TABLE meetings ADD COLUMN room_code VARCHAR(60);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'agenda') THEN
        ALTER TABLE meetings ADD COLUMN agenda TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'scheduled_at') THEN
        ALTER TABLE meetings ADD COLUMN scheduled_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'duration_minutes') THEN
        ALTER TABLE meetings ADD COLUMN duration_minutes INT DEFAULT 30;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'is_locked') THEN
        ALTER TABLE meetings ADD COLUMN is_locked BOOLEAN DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'meetings' AND column_name = 'passcode') THEN
        ALTER TABLE meetings ADD COLUMN passcode VARCHAR(100);
    END IF;
END $$;

-- Populate room_code for any legacy rows if null
UPDATE meetings 
SET room_code = LOWER(SUBSTRING(REPLACE(id::text, '-', ''), 1, 3) || '-' || SUBSTRING(REPLACE(id::text, '-', ''), 4, 4) || '-' || SUBSTRING(REPLACE(id::text, '-', ''), 8, 3))
WHERE room_code IS NULL OR room_code = '';

-- Ensure room_code is unique and not null
DO $$ BEGIN
    ALTER TABLE meetings ALTER COLUMN room_code SET NOT NULL;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_meetings_room_code ON meetings(room_code);
CREATE INDEX IF NOT EXISTS idx_meetings_host_id ON meetings(host_id);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);
CREATE INDEX IF NOT EXISTS idx_meetings_scheduled_at ON meetings(scheduled_at);

-- 2. Meeting Participants
CREATE TABLE IF NOT EXISTS meeting_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    email VARCHAR(120) NOT NULL,
    name VARCHAR(120),
    role VARCHAR(30) NOT NULL DEFAULT 'participant' CHECK (role IN ('host', 'co-host', 'participant', 'guest')),
    invitation_status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (invitation_status IN ('pending', 'accepted', 'declined', 'tentative')),
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting_id ON meeting_participants(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_participants_user_id ON meeting_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_meeting_participants_email ON meeting_participants(email);

-- 3. Meeting Attendance
CREATE TABLE IF NOT EXISTS meeting_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    name VARCHAR(120),
    email VARCHAR(120),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_attendance_meeting_id ON meeting_attendance(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_attendance_user_id ON meeting_attendance(user_id);

-- 4. Meeting Signals (for resilient signaling queue)
CREATE TABLE IF NOT EXISTS meeting_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    room_code VARCHAR(60) NOT NULL,
    sender_id VARCHAR(100) NOT NULL,
    recipient_id VARCHAR(100),
    signal_type VARCHAR(60) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_meeting_signals_room_recipient ON meeting_signals(room_code, recipient_id);
CREATE INDEX IF NOT EXISTS idx_meeting_signals_expires_at ON meeting_signals(expires_at);

-- 5. Meeting Messages (persistent meeting chat)
CREATE TABLE IF NOT EXISTS meeting_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    room_code VARCHAR(60) NOT NULL,
    sender_id VARCHAR(100) NOT NULL,
    sender_name VARCHAR(120) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_messages_meeting_id ON meeting_messages(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_messages_room_code ON meeting_messages(room_code);

-- 6. Meeting Minutes
CREATE TABLE IF NOT EXISTS meeting_minutes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by_name VARCHAR(120),
    summary TEXT DEFAULT '',
    discussion_points TEXT[] DEFAULT '{}',
    decisions TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_minutes_meeting_id ON meeting_minutes(meeting_id);

-- 7. Meeting Action Items
CREATE TABLE IF NOT EXISTS meeting_action_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT DEFAULT '',
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    assigned_name VARCHAR(120),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    due_date DATE,
    status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'converted')),
    linked_task_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_action_items_meeting_id ON meeting_action_items(meeting_id);

-- 8. Meeting Recordings (Metadata)
CREATE TABLE IF NOT EXISTS meeting_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    file_name VARCHAR(255) NOT NULL,
    storage_location TEXT NOT NULL,
    duration_seconds INT DEFAULT 0,
    file_size_bytes BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meeting_recordings_meeting_id ON meeting_recordings(meeting_id);
