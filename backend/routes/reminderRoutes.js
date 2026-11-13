const express = require('express');
const router = express.Router();
const ReminderController = require('../controllers/reminderController');
const { requireAuth } = require('../middleware/authMiddleware');

// All reminder endpoints require authentication
router.use(requireAuth);

router.get('/', ReminderController.listReminders);
router.post('/', ReminderController.createReminder);
router.get('/:id', ReminderController.getReminder);
router.put('/:id', ReminderController.updateReminder);
router.patch('/:id/toggle', ReminderController.toggleComplete);
router.delete('/:id', ReminderController.deleteReminder);

module.exports = router;
