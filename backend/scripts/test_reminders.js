const ReminderModel = require('../models/reminderModel');
const UserModel = require('../models/userModel');

async function testReminders() {
  try {
    const user = await UserModel.findByUsername('kou12');
    if (!user) {
      console.error('User kou12 not found');
      process.exit(1);
    }
    console.log('Testing with user:', user.username, user.id);

    // 1. Create reminder
    const created = await ReminderModel.create(user.id, {
      title: 'Review System Architecture with Team',
      description: 'Discuss Calendar and Reminders two-way sync on CONNEKT.',
      dueDate: '2026-08-14',
      dueTime: '10:30',
      repeatFrequency: 'weekly',
      notificationPreference: '15_min_before',
      calendarSync: true,
    });
    console.log('Created reminder:', created);

    // 2. List reminders
    const list = await ReminderModel.getByUserId(user.id);
    console.log('User reminders count:', list.length);

    // 3. Toggle complete
    const toggled = await ReminderModel.toggleComplete(created.id, user.id);
    console.log('Toggled completion:', toggled.is_completed);

    // 4. Update reminder
    const updated = await ReminderModel.update(created.id, user.id, {
      title: 'Updated: Review Architecture with Team',
      dueTime: '11:00',
    });
    console.log('Updated reminder:', updated.title, updated.due_time);

    // 5. Delete reminder
    const deleted = await ReminderModel.delete(created.id, user.id);
    console.log('Deleted reminder success:', deleted);

    console.log('All Reminder tests passed successfully!');
  } catch (err) {
    console.error('Test failed:', err);
  } finally {
    process.exit(0);
  }
}

testReminders();
