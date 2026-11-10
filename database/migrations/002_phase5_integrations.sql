-- Phase 5 Integrations: Tasks, Google Calendar & Extensibility

-- 1. Tasks Table for Action Item conversions
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_name VARCHAR(100),
  created_by UUID REFERENCES users(id) ON DELETE CASCADE,
  due_date DATE,
  priority VARCHAR(20) DEFAULT 'medium',
  status VARCHAR(30) DEFAULT 'not-started',
  meeting_id UUID REFERENCES meetings(id) ON DELETE SET NULL,
  linked_action_item_id UUID REFERENCES meeting_action_items(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_meeting ON tasks(meeting_id);

-- 2. Google Calendar OAuth Tokens on users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_tokens JSONB DEFAULT NULL;

-- 3. Google Calendar synchronization metadata on meetings table
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS google_synced BOOLEAN DEFAULT FALSE;
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS google_event_id VARCHAR(255) DEFAULT NULL;
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS google_meet_link VARCHAR(255) DEFAULT NULL;
