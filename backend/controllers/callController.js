const CallModel = require('../models/callModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

class CallController {
  /**
   * Upload device call logs from user's phone contacts
   * POST /api/calls/device-logs
   */
  static async uploadDeviceLogs(req, res) {
    try {
      const logs = req.body.logs;
      if (!logs || !Array.isArray(logs)) {
        return errorResponse(res, 400, 'Invalid request: "logs" array is required.');
      }

      const result = await CallModel.saveDeviceCallLogs(req.user.id, logs);

      // Emit live socket event so the website automatically updates
      const io = req.app.get('io');
      if (io) {
        io.to(`user:${req.user.id}`).emit('call-logs:synced', {
          count: result.insertedCount,
          total: result.total,
          syncedAt: new Date().toISOString()
        });
      }

      return successResponse(res, 200, `Successfully synced ${result.insertedCount} call logs from phone contacts.`, result);
    } catch (err) {
      console.error('[CallController.uploadDeviceLogs Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to upload device call logs.');
    }
  }

  /**
   * Get synced call logs for the logged-in user
   * GET /api/calls/device-logs
   */
  static async getDeviceLogs(req, res) {
    try {
      const type = req.query.type || 'all';
      const limit = parseInt(req.query.limit, 10) || 50;
      const offset = parseInt(req.query.offset, 10) || 0;

      const result = await CallModel.getDeviceCallLogs(req.user.id, { type, limit, offset });
      return successResponse(res, 200, 'Device call logs retrieved successfully.', result);
    } catch (err) {
      console.error('[CallController.getDeviceLogs Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to retrieve call logs.');
    }
  }

  /**
   * Trigger sync request to connected mobile app (called when user logs in to website)
   * POST /api/calls/request-sync
   */
  static async requestSync(req, res) {
    try {
      CallModel.requestSync(req.user.id);

      // Notify mobile app via WebSocket
      const io = req.app.get('io');
      if (io) {
        io.to(`user:${req.user.id}`).emit('call-logs:sync-request', {
          requestedAt: new Date().toISOString()
        });
      }

      return successResponse(res, 200, 'Call logs sync request dispatched to connected phone.', {
        syncRequested: true
      });
    } catch (err) {
      console.error('[CallController.requestSync Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to request call logs sync.');
    }
  }

  /**
   * Check sync status
   * GET /api/calls/sync-status
   */
  static async getSyncStatus(req, res) {
    try {
      const status = await CallModel.getSyncStatus(req.user.id);
      return successResponse(res, 200, 'Sync status retrieved.', status);
    } catch (err) {
      return errorResponse(res, 500, err.message || 'Failed to fetch sync status.');
    }
  }
}

module.exports = CallController;
