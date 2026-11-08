const bcrypt = require('bcryptjs');
const UserModel = require('../models/userModel');
const { createOtp, verifyOtp } = require('../services/otpService');
const { generateToken, hashToken } = require('../services/tokenService');
const { successResponse, errorResponse } = require('../utils/responseHandler');

const CONNEKT_DOMAIN = process.env.CONNEKT_DOMAIN || 'connekt.me';
const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_SALT_ROUNDS || '10', 10);

/**
 * Parse client device details from request
 */
const getDeviceInfo = (req) => {
  const ua = req.headers['user-agent'] || 'Unknown Client';
  let device = 'Web Browser';
  if (/mobile/i.test(ua)) device = 'Mobile Browser';
  if (/windows/i.test(ua)) device = 'Windows PC';
  if (/macintosh|mac os/i.test(ua)) device = 'macOS Desktop';
  if (/android/i.test(ua)) device = 'Android Device';
  if (/iphone|ipad/i.test(ua)) device = 'Apple iOS Device';
  if (/linux/i.test(ua)) device = 'Linux Desktop';
  return `${device} (${ua.slice(0, 40)}...)`;
};

/**
 * Controller for Registration, Login, OTP, and Identity Management
 */
class AuthController {
  /**
   * Check real-time availability of username, phone, or email
   */
  static async checkAvailability(req, res) {
    try {
      const { field, value } = req.query;
      if (!field || !value) {
        return errorResponse(res, 400, 'Field and value query parameters are required.');
      }

      let existing = null;
      if (field === 'username') {
        const cleaned = value.trim().toLowerCase().replace(/^@/, '');
        existing = await UserModel.findByUsername(cleaned);
      } else if (field === 'phone') {
        existing = await UserModel.findByPhone(value.trim());
      } else if (field === 'email') {
        existing = await UserModel.findByEmail(value.trim().toLowerCase());
      } else {
        return errorResponse(res, 400, 'Invalid field checked. Allowed: username, phone, email.');
      }

      return successResponse(res, 200, 'Availability status', {
        field,
        value,
        available: !existing
      });
    } catch (err) {
      console.error('[Check Availability Error]:', err);
      return errorResponse(res, 500, 'Failed to check availability.');
    }
  }

  /**
   * Dispatch OTP for registration, login, or recovery
   */
  static async sendOtp(req, res) {
    try {
      const { identifier, purpose = 'registration' } = req.body;
      if (!identifier || !identifier.trim()) {
        return errorResponse(res, 400, 'Identifier (phone or email) is required.');
      }

      const cleanId = identifier.trim();

      // For registration: verify phone is not already in use
      if (purpose === 'registration') {
        const existing = await UserModel.findByPhone(cleanId);
        if (existing) {
          return errorResponse(res, 409, 'This phone number is already registered. Please log in.');
        }
      }

      // For login or forgot_password: check if user exists
      if (purpose === 'login' || purpose === 'forgot_password') {
        const user = await UserModel.findByIdentifier(cleanId);
        if (!user) {
          return errorResponse(res, 404, 'No account found with this phone number or identifier.');
        }
      }

      const otpResult = await createOtp(cleanId, purpose, req.ip);

      return successResponse(res, 200, `Verification code sent to ${cleanId}`, {
        identifier: cleanId,
        purpose,
        expiresAt: otpResult.expiresAt,
        previewCode: otpResult.previewCode // Provided in dev environment for easy testing
      });
    } catch (err) {
      console.error('[Send OTP Error]:', err);
      return errorResponse(res, 500, 'Failed to generate and dispatch verification code.');
    }
  }

  /**
   * Verify an OTP without completing an action yet
   */
  static async verifyOtpChallenge(req, res) {
    try {
      const { identifier, code, purpose = 'registration' } = req.body;
      if (!identifier || !code) {
        return errorResponse(res, 400, 'Identifier and verification code are required.');
      }

      const verification = await verifyOtp(identifier.trim(), code.trim(), purpose);
      if (!verification.valid) {
        return errorResponse(res, 400, verification.message);
      }

      return successResponse(res, 200, 'Code verified successfully.', {
        identifier: identifier.trim(),
        verified: true
      });
    } catch (err) {
      console.error('[Verify OTP Error]:', err);
      return errorResponse(res, 500, 'Failed to verify code.');
    }
  }

  /**
   * Register a new user
   */
  static async register(req, res) {
    try {
      const {
        phone,
        otpCode,
        username,
        customEmail,
        password,
        fullName,
        displayName,
        currentMode = 'common',
        recoveryEmail
      } = req.body;

      // Validation
      if (!phone || !phone.trim()) {
        return errorResponse(res, 400, 'Phone number is required.');
      }
      if (!otpCode || !otpCode.trim()) {
        return errorResponse(res, 400, 'Verification code is required.');
      }
      if (!username || !username.trim()) {
        return errorResponse(res, 400, 'Username is required.');
      }
      if (!password || password.length < 6) {
        return errorResponse(res, 400, 'Password must be at least 6 characters long.');
      }
      if (!fullName || !fullName.trim()) {
        return errorResponse(res, 400, 'Full name is required.');
      }

      const cleanPhone = phone.trim();
      const cleanUsername = username.trim().toLowerCase().replace(/^@/, '');

      // Verify OTP for registration
      const otpCheck = await verifyOtp(cleanPhone, otpCode.trim(), 'registration');
      if (!otpCheck.valid) {
        return errorResponse(res, 400, otpCheck.message);
      }

      // Check duplicate phone
      const phoneExists = await UserModel.findByPhone(cleanPhone);
      if (phoneExists) {
        return errorResponse(res, 409, 'This phone number is already registered.');
      }

      // Check duplicate username
      const usernameExists = await UserModel.findByUsername(cleanUsername);
      if (usernameExists) {
        return errorResponse(res, 409, 'This username is already taken. Please choose another.');
      }

      // Generate or validate Connekt Mail ID
      let connektEmail = `${cleanUsername}@${CONNEKT_DOMAIN}`;
      if (customEmail && customEmail.trim()) {
        connektEmail = customEmail.trim().toLowerCase();
        if (!connektEmail.endsWith(`@${CONNEKT_DOMAIN}`)) {
          connektEmail = `${connektEmail.split('@')[0]}@${CONNEKT_DOMAIN}`;
        }
      }

      const emailExists = await UserModel.findByEmail(connektEmail);
      if (emailExists) {
        return errorResponse(res, 409, 'This Connekt Mail ID is already in use.');
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

      // Create user with transactional integrity
      const user = await UserModel.createUser({
        phone: cleanPhone,
        username: cleanUsername,
        email: connektEmail,
        passwordHash,
        fullName: fullName.trim(),
        displayName: displayName || fullName.trim(),
        currentMode: ['common', 'professional', 'both'].includes(currentMode) ? currentMode : 'common',
        recoveryEmail: recoveryEmail ? recoveryEmail.trim() : null
      });

      // Generate JWT Access Token
      const token = generateToken({
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        currentMode: user.current_mode
      });

      // Register session
      const tokenHash = hashToken(token);
      const deviceInfo = getDeviceInfo(req);
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      const session = await UserModel.createSession({
        userId: user.id,
        tokenHash,
        deviceInfo,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
        expiresAt
      });

      return successResponse(res, 201, 'Account registered successfully! Welcome to CONNEKT.', {
        user,
        token,
        session
      });
    } catch (err) {
      console.error('[Registration Error]:', err);
      if (err.code === '23505') {
        return errorResponse(res, 409, 'A duplicate record already exists (phone, username, or email).');
      }
      return errorResponse(res, 500, 'Registration failed due to server error.');
    }
  }

  /**
   * Log in with (Phone/Username/Connekt Mail + Password) OR (Phone + OTP)
   */
  static async login(req, res) {
    try {
      const { identifier, password, otpCode, loginType = 'password' } = req.body;

      if (!identifier || !identifier.trim()) {
        return errorResponse(res, 400, 'Identifier (Phone, Username, or Connekt Mail ID) is required.');
      }

      const cleanId = identifier.trim().toLowerCase().replace(/^@/, '');
      const user = await UserModel.findByIdentifier(cleanId);

      if (!user) {
        return errorResponse(res, 401, 'Invalid credentials. User not found.');
      }

      if (user.status === 'suspended' || user.status === 'deactivated') {
        return errorResponse(res, 403, `This account is ${user.status}. Please contact support.`);
      }

      // Password Authentication
      if (loginType === 'password') {
        if (!password) {
          return errorResponse(res, 400, 'Password is required for password login.');
        }

        const isMatch = await bcrypt.compare(password, user.password_hash);
        if (!isMatch) {
          return errorResponse(res, 401, 'Invalid credentials. Incorrect password.');
        }
      } 
      // OTP Authentication
      else if (loginType === 'otp') {
        if (!otpCode) {
          return errorResponse(res, 400, 'Verification code is required for OTP login.');
        }

        const otpCheck = await verifyOtp(user.phone, otpCode.trim(), 'login');
        if (!otpCheck.valid) {
          return errorResponse(res, 400, otpCheck.message);
        }
      } else {
        return errorResponse(res, 400, 'Invalid login type specified.');
      }

      // Update last login
      await UserModel.updateLastLogin(user.id);

      // Generate JWT
      const token = generateToken({
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        currentMode: user.current_mode
      });

      // Record device session
      const tokenHash = hashToken(token);
      const deviceInfo = getDeviceInfo(req);
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

      const session = await UserModel.createSession({
        userId: user.id,
        tokenHash,
        deviceInfo,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'],
        expiresAt
      });

      // Fetch full profile package
      const fullUser = await UserModel.findById(user.id);

      return successResponse(res, 200, 'Login successful. Welcome back!', {
        user: fullUser,
        token,
        session
      });
    } catch (err) {
      console.error('[Login Error]:', err);
      return errorResponse(res, 500, 'Authentication error.');
    }
  }

  /**
   * Reset password using verified OTP
   */
  static async resetPassword(req, res) {
    try {
      const { identifier, otpCode, newPassword } = req.body;

      if (!identifier || !otpCode || !newPassword) {
        return errorResponse(res, 400, 'Identifier, verification code, and new password are required.');
      }

      if (newPassword.length < 6) {
        return errorResponse(res, 400, 'New password must be at least 6 characters long.');
      }

      const cleanId = identifier.trim().toLowerCase().replace(/^@/, '');
      const user = await UserModel.findByIdentifier(cleanId);

      if (!user) {
        return errorResponse(res, 404, 'Account not found.');
      }

      const otpCheck = await verifyOtp(user.phone, otpCode.trim(), 'forgot_password');
      if (!otpCheck.valid) {
        return errorResponse(res, 400, otpCheck.message);
      }

      // Hash new password
      const newHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
      await UserModel.updatePassword(user.id, newHash);

      // Revoke all existing sessions for security
      await UserModel.revokeAllOtherSessions(user.id, 'all');

      return successResponse(res, 200, 'Password has been reset successfully. Please log in with your new password.');
    } catch (err) {
      console.error('[Reset Password Error]:', err);
      return errorResponse(res, 500, 'Failed to reset password.');
    }
  }

  /**
   * Get current authenticated user profile and details
   */
  static async getMe(req, res) {
    try {
      const user = await UserModel.findById(req.user.id);
      if (!user) {
        return errorResponse(res, 404, 'User profile not found.');
      }
      return successResponse(res, 200, 'User profile retrieved', { user });
    } catch (err) {
      console.error('[GetMe Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch user profile.');
    }
  }

  /**
   * Log out active session
   */
  static async logout(req, res) {
    try {
      if (req.user && req.user.sessionId) {
        await UserModel.revokeSession(req.user.sessionId, req.user.id);
      }
      return successResponse(res, 200, 'Logged out successfully.');
    } catch (err) {
      console.error('[Logout Error]:', err);
      return errorResponse(res, 500, 'Logout failed.');
    }
  }
}

module.exports = AuthController;
