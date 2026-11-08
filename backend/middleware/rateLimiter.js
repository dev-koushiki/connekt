const rateLimit = require('express-rate-limit');
const { errorResponse } = require('../utils/responseHandler');

const otpRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // limit each IP to 15 OTP requests per window
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    return errorResponse(res, 429, 'Too many verification code requests from this device. Please wait a few minutes before trying again.');
  }
});

const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30, // limit login attempts
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    return errorResponse(res, 429, 'Too many authentication attempts. Please try again after 15 minutes.');
  }
});

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    return errorResponse(res, 429, 'Too many requests. Please slow down.');
  }
});

module.exports = {
  otpRateLimiter,
  authRateLimiter,
  apiLimiter
};
