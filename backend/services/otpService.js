const crypto = require('crypto');
const db = require('../config/database');
const nodemailer = require('nodemailer');
const path = require('path');
const { sendOtpSms, normalizePhoneNumber, extractLocalPhone } = require('./smsService');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || '5', 10);
const MAX_OTP_ATTEMPTS = parseInt(process.env.MAX_OTP_ATTEMPTS || '5', 10);

// Setup transporter for email dispatch when applicable
let transporter = null;
if (process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SMTP_PASS !== 'app_password_placeholder') {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });
}

/**
 * Generate cryptographically secure 6-digit code
 */
const generateCode = () => {
  return crypto.randomInt(100000, 999999).toString();
};

/**
 * Create and record an OTP verification challenge
 */
const createOtp = async (identifier, purpose = 'registration', ipAddress = null) => {
  const code = generateCode();
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
  const cleanId = (identifier || '').toString().trim();
  const normalizedId = cleanId.includes('@') ? cleanId.toLowerCase() : normalizePhoneNumber(cleanId);
  const localId = cleanId.includes('@') ? cleanId.toLowerCase() : extractLocalPhone(cleanId);

  // Invalidate any active previous unused OTPs for this identifier and purpose
  await db.query(
    `UPDATE otp_verifications 
     SET is_used = true 
     WHERE (identifier = $1 OR identifier = $2 OR identifier = $3) AND purpose = $4 AND is_used = false`,
    [cleanId, normalizedId, localId, purpose]
  );

  // Insert new OTP record with standard normalized identifier
  const result = await db.query(
    `INSERT INTO otp_verifications (identifier, otp_code, purpose, expires_at, ip_address)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, identifier, purpose, expires_at, created_at`,
    [normalizedId, code, purpose, expiresAt, ipAddress]
  );

  // 1. If identifier is an email: send via email transporter if configured
  if (cleanId.includes('@') && transporter) {
    try {
      await transporter.sendMail({
        from: process.env.SMTP_FROM || 'CONNEKT Identity <noreply@connekt.me>',
        to: cleanId,
        subject: `Your CONNEKT Security Code: ${code}`,
        text: `Your security code for ${purpose} is: ${code}. It expires in ${OTP_EXPIRY_MINUTES} minutes.`,
        html: `
          <div style="font-family: Arial, sans-serif; background: #0b0e14; color: #ffffff; padding: 30px; border-radius: 10px;">
            <h2 style="color: #3b82f6; margin-top: 0;">CONNEKT Identity Verification</h2>
            <p>Your one-time verification code for <strong>${purpose}</strong> is:</p>
            <div style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #60a5fa; padding: 15px; background: #1e293b; border-radius: 8px; text-align: center; margin: 20px 0;">
              ${code}
            </div>
            <p style="color: #94a3b8; font-size: 13px;">This code will expire in ${OTP_EXPIRY_MINUTES} minutes. If you did not request this code, please ignore this message.</p>
          </div>
        `
      });
      console.log(`[OTP Service] Email dispatched to ${cleanId}`);
    } catch (emailErr) {
      console.warn(`[OTP Service] Failed to send email via SMTP:`, emailErr.message);
    }
  }

  let smsDispatched = true;
  let smsError = null;

  // 2. If identifier is a phone number: dispatch real SMS via Main Phone SMS Gateway
  if (!cleanId.includes('@')) {
    console.log(`[OTP Service] 📨 Sending Real SMS OTP to ${normalizedId} for ${purpose}...`);
    try {
      const smsRes = await sendOtpSms(normalizedId, code, purpose);
      if (!smsRes.success) {
        smsDispatched = false;
        smsError = smsRes.error || 'SMS Gateway unreachable';
      }
    } catch (smsErr) {
      smsDispatched = false;
      smsError = smsErr.message;
      console.error(`[OTP Service] SMS Dispatch error:`, smsErr.message);
    }
  }

  console.log(`[OTP Service] Generated code [${code}] for ${cleanId} (${purpose}). SMS dispatched: ${smsDispatched}. Expires in ${OTP_EXPIRY_MINUTES}m.`);

  // If real SMS failed to deliver or in debug preview mode, include code so user is never locked out!
  const showPreview = process.env.SHOW_OTP_PREVIEW === 'true' || !smsDispatched;

  return {
    id: result.rows[0].id,
    identifier: cleanId,
    purpose,
    expiresAt,
    smsDispatched,
    smsError,
    previewCode: showPreview ? code : undefined
  };
};

/**
 * Verify provided OTP code against stored records
 */
const verifyOtp = async (identifier, code, purpose = 'registration') => {
  const cleanCode = (code || '').toString().trim();
  const cleanId = (identifier || '').toString().trim();
  const normalizedId = cleanId.includes('@') ? cleanId.toLowerCase() : normalizePhoneNumber(cleanId);
  const localId = cleanId.includes('@') ? cleanId.toLowerCase() : extractLocalPhone(cleanId);

  const query = `
    SELECT id, otp_code, expires_at, attempts, is_used 
    FROM otp_verifications
    WHERE (identifier = $1 OR identifier = $2 OR identifier = $3) AND purpose = $4 AND is_used = false
    ORDER BY created_at DESC 
    LIMIT 1
  `;
  const result = await db.query(query, [normalizedId, cleanId, localId, purpose]);

  if (result.rows.length === 0) {
    return { valid: false, message: 'No active verification code found for this number. Please request a new OTP.' };
  }

  const record = result.rows[0];

  // Check attempt threshold
  if (record.attempts >= MAX_OTP_ATTEMPTS) {
    await db.query(`UPDATE otp_verifications SET is_used = true WHERE id = $1`, [record.id]);
    return { valid: false, message: 'Maximum verification attempts exceeded. Please request a new code.' };
  }

  // Check expiration
  if (new Date() > new Date(record.expires_at)) {
    await db.query(`UPDATE otp_verifications SET is_used = true WHERE id = $1`, [record.id]);
    return { valid: false, message: 'Verification code has expired. Please request a new code.' };
  }

  // Check code match strictly
  if (record.otp_code.trim() !== cleanCode) {
    await db.query(`UPDATE otp_verifications SET attempts = attempts + 1 WHERE id = $1`, [record.id]);
    const remaining = MAX_OTP_ATTEMPTS - (record.attempts + 1);
    return { 
      valid: false, 
      message: `Invalid verification code. ${remaining > 0 ? remaining + ' attempt(s) remaining.' : 'Code locked.'}` 
    };
  }

  // Code matches! Mark as used
  await db.query(`UPDATE otp_verifications SET is_used = true WHERE id = $1`, [record.id]);

  return { valid: true, message: 'Code verified successfully.' };
};

module.exports = {
  createOtp,
  verifyOtp
};
