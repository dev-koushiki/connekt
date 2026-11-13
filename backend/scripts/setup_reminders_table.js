const db = require('../config/database');

async function setupRemindersTable() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS reminders (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        description TEXT DEFAULT '',
        due_date DATE NOT NULL,
        due_time VARCHAR(20) DEFAULT '09:00',
        due_datetime TIMESTAMPTZ,
        repeat_frequency VARCHAR(50) DEFAULT 'none',
        notification_preference VARCHAR(50) DEFAULT 'at_time',
        is_completed BOOLEAN DEFAULT FALSE,
        calendar_sync BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_reminders_user_date ON reminders(user_id, due_date);
      CREATE INDEX IF NOT EXISTS idx_reminders_user_completed ON reminders(user_id, is_completed);
    `);
    console.log('Reminders table and indexes successfully initialized.');
  } catch (err) {
    console.error('Error creating reminders table:', err);
  } finally {
    process.exit(0);
  }
}

setupRemindersTable();
