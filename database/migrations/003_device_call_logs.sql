-- Device call logs table synced between Android mobile app and web dashboard

CREATE TABLE IF NOT EXISTS user_device_call_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  contact_name VARCHAR(150) NOT NULL,
  phone_number VARCHAR(50) NOT NULL,
  call_type VARCHAR(30) NOT NULL DEFAULT 'unknown',
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  call_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, phone_number, call_timestamp)
);

CREATE INDEX IF NOT EXISTS idx_device_call_logs_user_time
  ON user_device_call_logs(user_id, call_timestamp DESC);
