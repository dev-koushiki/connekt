const { verifyToken, hashToken } = require('../services/tokenService');
const UserModel = require('../models/userModel');
const { errorResponse } = require('../utils/responseHandler');

const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return errorResponse(res, 401, 'Authentication required. No token provided.');
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);
    if (!decoded || !decoded.id) {
      return errorResponse(res, 401, 'Invalid or expired authentication token.');
    }

    // Verify active session in DB
    const tokenHash = hashToken(token);
    const session = await UserModel.findSession(tokenHash);

    if (!session) {
      return errorResponse(res, 401, 'Session has expired or was revoked. Please log in again.');
    }

    if (session.user_status === 'suspended' || session.user_status === 'deactivated') {
      return errorResponse(res, 403, `Account is ${session.user_status}. Please contact support.`);
    }

    // Update last activity on session asynchronously
    UserModel.touchSession(session.id).catch(err => console.error('Error updating session activity:', err));

    req.user = {
      id: decoded.id,
      username: decoded.username,
      email: decoded.email,
      role: decoded.role,
      currentMode: decoded.currentMode,
      sessionId: session.id,
      tokenHash
    };

    next();
  } catch (err) {
    console.error('[Auth Middleware Error]:', err);
    return errorResponse(res, 401, 'Authentication failed.');
  }
};

module.exports = {
  requireAuth
};
