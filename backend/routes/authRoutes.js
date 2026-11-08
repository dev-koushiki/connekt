const express = require('express');
const router = express.Router();
const AuthController = require('../controllers/authController');
const { requireAuth } = require('../middleware/authMiddleware');
const { otpRateLimiter, authRateLimiter } = require('../middleware/rateLimiter');

// Public endpoints
router.get('/check-availability', AuthController.checkAvailability);
router.post('/send-otp', otpRateLimiter, AuthController.sendOtp);
router.post('/verify-otp', AuthController.verifyOtpChallenge);
router.post('/register', authRateLimiter, AuthController.register);
router.post('/login', authRateLimiter, AuthController.login);
router.post('/forgot-password', otpRateLimiter, AuthController.resetPassword);

// Authenticated endpoints
router.get('/me', requireAuth, AuthController.getMe);
router.post('/logout', requireAuth, AuthController.logout);

module.exports = router;
