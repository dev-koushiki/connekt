const UserModel = require('../models/userModel');
const { successResponse, errorResponse } = require('../utils/responseHandler');

class SessionController {
  /**
   * List all active sessions and devices
   */
  static async getSessions(req, res) {
    try {
      const sessions = await UserModel.getUserSessions(req.user.id, req.user.tokenHash);
      return successResponse(res, 200, 'User sessions retrieved.', { sessions });
    } catch (err) {
      console.error('[Get Sessions Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch active sessions.');
    }
  }

  /**
   * Revoke a specific session
   */
  static async revokeSession(req, res) {
    try {
      const { sessionId } = req.params;
      const revoked = await UserModel.revokeSession(sessionId, req.user.id);
      if (!revoked) {
        return errorResponse(res, 404, 'Session not found or already revoked.');
      }
      return successResponse(res, 200, 'Session terminated successfully.');
    } catch (err) {
      console.error('[Revoke Session Error]:', err);
      return errorResponse(res, 500, 'Failed to revoke session.');
    }
  }

  /**
   * Revoke all other sessions
   */
  static async revokeAllOtherSessions(req, res) {
    try {
      const count = await UserModel.revokeAllOtherSessions(req.user.id, req.user.tokenHash);
      return successResponse(res, 200, `Terminated ${count} other active session(s).`);
    } catch (err) {
      console.error('[Revoke All Other Sessions Error]:', err);
      return errorResponse(res, 500, 'Failed to revoke other sessions.');
    }
  }
}

module.exports = SessionController;
