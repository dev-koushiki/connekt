const ReminderModel = require('../models/reminderModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

class ReminderController {
  /**
   * GET /api/reminders
   * Fetch all reminders for the authenticated user
   */
  static async listReminders(req, res) {
    try {
      const userId = req.user.id;
      const { status } = req.query;

      const reminders = await ReminderModel.getByUserId(userId, { status });

      return successResponse(res, 200, 'Reminders retrieved successfully', {
        reminders,
        total: reminders.length,
      });
    } catch (err) {
      console.error('[ReminderController.listReminders Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch reminders');
    }
  }

  /**
   * POST /api/reminders
   * Create a new reminder
   */
  static async createReminder(req, res) {
    try {
      const userId = req.user.id;
      const {
        title,
        description,
        dueDate,
        dueTime,
        dueDateTime,
        repeatFrequency,
        notificationPreference,
        calendarSync,
      } = req.body;

      if (!title || !title.trim()) {
        return errorResponse(res, 400, 'Reminder title is required');
      }

      if (!dueDate) {
        return errorResponse(res, 400, 'Due date is required (YYYY-MM-DD)');
      }

      const reminder = await ReminderModel.create(userId, {
        title,
        description,
        dueDate,
        dueTime,
        dueDateTime,
        repeatFrequency,
        notificationPreference,
        calendarSync,
      });

      return successResponse(res, 201, 'Reminder created successfully', reminder);
    } catch (err) {
      console.error('[ReminderController.createReminder Error]:', err);
      return errorResponse(res, 500, 'Failed to create reminder');
    }
  }

  /**
   * GET /api/reminders/:id
   * Fetch a single reminder by ID
   */
  static async getReminder(req, res) {
    try {
      const userId = req.user.id;
      const { id } = req.params;

      const reminder = await ReminderModel.getById(id, userId);
      if (!reminder) {
        return errorResponse(res, 404, 'Reminder not found');
      }

      return successResponse(res, 200, 'Reminder retrieved', reminder);
    } catch (err) {
      console.error('[ReminderController.getReminder Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch reminder');
    }
  }

  /**
   * PUT /api/reminders/:id
   * Update an existing reminder
   */
  static async updateReminder(req, res) {
    try {
      const userId = req.user.id;
      const { id } = req.params;
      const fields = req.body;

      const updated = await ReminderModel.update(id, userId, fields);
      if (!updated) {
        return errorResponse(res, 404, 'Reminder not found or unauthorized');
      }

      return successResponse(res, 200, 'Reminder updated successfully', updated);
    } catch (err) {
      console.error('[ReminderController.updateReminder Error]:', err);
      return errorResponse(res, 500, 'Failed to update reminder');
    }
  }

  /**
   * PATCH /api/reminders/:id/toggle
   * Toggle completion status
   */
  static async toggleComplete(req, res) {
    try {
      const userId = req.user.id;
      const { id } = req.params;

      const updated = await ReminderModel.toggleComplete(id, userId);
      if (!updated) {
        return errorResponse(res, 404, 'Reminder not found or unauthorized');
      }

      return successResponse(res, 200, 'Reminder status updated', updated);
    } catch (err) {
      console.error('[ReminderController.toggleComplete Error]:', err);
      return errorResponse(res, 500, 'Failed to update reminder status');
    }
  }

  /**
   * DELETE /api/reminders/:id
   * Delete a reminder
   */
  static async deleteReminder(req, res) {
    try {
      const userId = req.user.id;
      const { id } = req.params;

      const deleted = await ReminderModel.delete(id, userId);
      if (!deleted) {
        return errorResponse(res, 404, 'Reminder not found or unauthorized');
      }

      return successResponse(res, 200, 'Reminder deleted successfully', { id });
    } catch (err) {
      console.error('[ReminderController.deleteReminder Error]:', err);
      return errorResponse(res, 500, 'Failed to delete reminder');
    }
  }
}

module.exports = ReminderController;
