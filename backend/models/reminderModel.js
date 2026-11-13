const db = require('../config/database');

class ReminderModel {
  /**
   * Create a new reminder
   */
  static async create(userId, {
    title,
    description = '',
    dueDate,
    dueTime = '09:00',
    dueDateTime = null,
    repeatFrequency = 'none',
    notificationPreference = 'at_time',
    calendarSync = true,
  }) {
    // Format dueDateTime if not explicitly supplied
    let computedDueDateTime = dueDateTime;
    if (!computedDueDateTime && dueDate) {
      computedDueDateTime = `${dueDate}T${dueTime.length === 5 ? dueTime + ':00' : dueTime}`;
    }

    const query = `
      INSERT INTO reminders (
        user_id, title, description, due_date, due_time, 
        due_datetime, repeat_frequency, notification_preference, 
        calendar_sync, is_completed
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false)
      RETURNING *
    `;

    const values = [
      userId,
      title.trim(),
      (description || '').trim(),
      dueDate,
      dueTime,
      computedDueDateTime,
      repeatFrequency || 'none',
      notificationPreference || 'at_time',
      calendarSync !== false,
    ];

    const result = await db.query(query, values);
    const reminder = result.rows[0];

    // Create a notification for the reminder
    try {
      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'reminder', $2, $3, $4)`,
        [
          userId,
          `Reminder: ${title.trim()}`,
          `Reminder set for ${dueDate} at ${dueTime}${repeatFrequency !== 'none' ? ` (${repeatFrequency})` : ''}`,
          JSON.stringify({
            reminderId: reminder.id,
            dueDate,
            dueTime,
            repeatFrequency,
          }),
        ]
      );
    } catch (notifErr) {
      console.warn('[ReminderModel] Warning creating notification:', notifErr.message);
    }

    return reminder;
  }

  /**
   * Fetch all reminders for a specific user
   */
  static async getByUserId(userId, options = {}) {
    const { status, includeRecurring = true } = options;

    let query = `
      SELECT * FROM reminders
      WHERE user_id = $1
    `;
    const params = [userId];

    if (status === 'completed') {
      query += ` AND is_completed = true`;
    } else if (status === 'pending') {
      query += ` AND is_completed = false`;
    }

    query += ` ORDER BY due_date ASC, due_time ASC, created_at DESC`;

    const result = await db.query(query, params);
    return result.rows;
  }

  /**
   * Fetch a single reminder by ID and user
   */
  static async getById(id, userId) {
    const query = `
      SELECT * FROM reminders
      WHERE id = $1 AND user_id = $2
    `;
    const result = await db.query(query, [id, userId]);
    return result.rows[0] || null;
  }

  /**
   * Update an existing reminder
   */
  static async update(id, userId, fields = {}) {
    const current = await this.getById(id, userId);
    if (!current) return null;

    const updatedTitle = fields.title !== undefined ? fields.title.trim() : current.title;
    const updatedDesc = fields.description !== undefined ? fields.description.trim() : current.description;
    const updatedDueDate = fields.dueDate !== undefined ? fields.dueDate : current.due_date;
    const updatedDueTime = fields.dueTime !== undefined ? fields.dueTime : current.due_time;
    const updatedRepeat = fields.repeatFrequency !== undefined ? fields.repeatFrequency : current.repeat_frequency;
    const updatedNotif = fields.notificationPreference !== undefined ? fields.notificationPreference : current.notification_preference;
    const updatedCompleted = fields.isCompleted !== undefined ? Boolean(fields.isCompleted) : current.is_completed;
    const updatedCalendarSync = fields.calendarSync !== undefined ? Boolean(fields.calendarSync) : current.calendar_sync;

    let computedDueDateTime = fields.dueDateTime || current.due_datetime;
    if (fields.dueDate || fields.dueTime) {
      const dStr = updatedDueDate instanceof Date ? updatedDueDate.toISOString().split('T')[0] : updatedDueDate;
      const tStr = updatedDueTime.length === 5 ? updatedDueTime + ':00' : updatedDueTime;
      computedDueDateTime = `${dStr}T${tStr}`;
    }

    const query = `
      UPDATE reminders
      SET title = $1,
          description = $2,
          due_date = $3,
          due_time = $4,
          due_datetime = $5,
          repeat_frequency = $6,
          notification_preference = $7,
          is_completed = $8,
          calendar_sync = $9,
          updated_at = NOW()
      WHERE id = $10 AND user_id = $11
      RETURNING *
    `;

    const values = [
      updatedTitle,
      updatedDesc,
      updatedDueDate,
      updatedDueTime,
      computedDueDateTime,
      updatedRepeat,
      updatedNotif,
      updatedCompleted,
      updatedCalendarSync,
      id,
      userId,
    ];

    const result = await db.query(query, values);
    return result.rows[0] || null;
  }

  /**
   * Toggle completion status
   */
  static async toggleComplete(id, userId) {
    const query = `
      UPDATE reminders
      SET is_completed = NOT is_completed,
          updated_at = NOW()
      WHERE id = $1 AND user_id = $2
      RETURNING *
    `;
    const result = await db.query(query, [id, userId]);
    return result.rows[0] || null;
  }

  /**
   * Delete a reminder
   */
  static async delete(id, userId) {
    const query = `
      DELETE FROM reminders
      WHERE id = $1 AND user_id = $2
      RETURNING id
    `;
    const result = await db.query(query, [id, userId]);
    return result.rowCount > 0;
  }
}

module.exports = ReminderModel;
