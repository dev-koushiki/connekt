const db = require('../config/database');

async function migrateEmailDomains() {
  try {
    const rUsers = await db.query(
      `UPDATE users 
       SET email = REPLACE(email, '@connekt.me', '@connekt.net.in') 
       WHERE email LIKE '%@connekt.me' 
       RETURNING id, username, email`
    );
    console.log('Updated users:', rUsers.rows);

    const rMailFrom = await db.query(
      `UPDATE mail_messages 
       SET from_email = REPLACE(from_email, '@connekt.me', '@connekt.net.in') 
       WHERE from_email LIKE '%@connekt.me'`
    );
    console.log('Updated mail_messages from_email count:', rMailFrom.rowCount);

    const rMailTo = await db.query(
      `UPDATE mail_messages 
       SET to_emails = REPLACE(to_emails::text, '@connekt.me', '@connekt.net.in')::jsonb 
       WHERE to_emails::text LIKE '%@connekt.me%'`
    );
    console.log('Updated mail_messages to_emails count:', rMailTo.rowCount);

    const currentUsers = await db.query('SELECT id, username, email FROM users');
    console.log('All current users in DB:', currentUsers.rows);
  } catch (err) {
    console.error('Migration error:', err);
  } finally {
    process.exit(0);
  }
}

migrateEmailDomains();
