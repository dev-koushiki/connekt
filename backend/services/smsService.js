const path = require('path');
const { exec } = require('child_process');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

/**
 * Normalize phone numbers to E.164 international format
 * Examples:
 *   9836828816       -> +919836828816 (using DEFAULT_COUNTRY_CODE, default +91)
 *   09836828816      -> +919836828816
 *   +919836828816    -> +919836828816
 *   +1 (555) 234-5678 -> +15552345678
 */
const normalizePhoneNumber = (phone) => {
  if (!phone || typeof phone !== 'string') return '';
  const defaultCountryCode = (process.env.DEFAULT_COUNTRY_CODE || '+91').trim();

  // Strip whitespace, brackets, hyphens
  let cleaned = phone.replace(/[\s\-\(\)\.]/g, '');

  // If already starts with +, return cleaned
  if (cleaned.startsWith('+')) {
    return cleaned;
  }

  // Remove leading 0 if present (common local dialing prefix)
  if (cleaned.startsWith('0')) {
    cleaned = cleaned.substring(1);
  }

  // If 10-digit standard mobile number, prepend default country code
  if (cleaned.length === 10) {
    const prefix = defaultCountryCode.startsWith('+') ? defaultCountryCode : `+${defaultCountryCode}`;
    return `${prefix}${cleaned}`;
  }

  // Otherwise ensure + is prefixed
  return `+${cleaned}`;
};

/**
 * Extract 10-digit local mobile number without international code
 */
const extractLocalPhone = (phone) => {
  if (!phone || typeof phone !== 'string') return '';
  let cleaned = phone.replace(/[\s\-\(\)\.]/g, '');
  cleaned = cleaned.replace(/^\+91/, '').replace(/^91(?=\d{10}$)/, '').replace(/^0/, '');
  return cleaned;
};

/**
 * Dispatch SMS via local Android SMS Gateway app running on user's main phone
 * (e.g. https://github.com/capcom6/android-sms-gateway)
 */
const sendViaAndroidGateway = async ({ to, message }) => {
  const gatewayUrl = process.env.SMS_GATEWAY_URL || 'http://192.168.1.15:8080/message';
  const user = process.env.SMS_GATEWAY_USER || '';
  const pass = process.env.SMS_GATEWAY_PASS || '';

  const headers = {
    'Content-Type': 'application/json'
  };

  if (user || pass) {
    const credentials = Buffer.from(`${user}:${pass}`).toString('base64');
    headers['Authorization'] = `Basic ${credentials}`;
  }

  // capcom6 android-sms-gateway schema
  const payload = {
    textMessage: {
      text: message
    },
    phoneNumbers: [to]
  };

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 8000);

  try {
    const response = await fetch(gatewayUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
      signal: controller.signal
    });
    clearTimeout(timeoutId);

    const bodyText = await response.text();
    let bodyJson = null;
    try {
      bodyJson = JSON.parse(bodyText);
    } catch (_) {}

    if (!response.ok) {
      throw new Error(`Android SMS Gateway returned HTTP ${response.status}: ${bodyText}`);
    }

    console.log(`[SMS Gateway] 📲 Real SMS dispatched via Main Phone to ${to}`);
    return { success: true, provider: 'android_gateway', data: bodyJson || bodyText };
  } catch (err) {
    clearTimeout(timeoutId);
    throw err;
  }
};

/**
 * Dispatch SMS via TextBee Android relay (https://textbee.dev)
 */
const sendViaTextBee = async ({ to, message }) => {
  const apiKey = process.env.TEXTBEE_API_KEY;
  const deviceId = process.env.TEXTBEE_DEVICE_ID;

  if (!apiKey || !deviceId) {
    throw new Error('TEXTBEE_API_KEY and TEXTBEE_DEVICE_ID must be set in .env');
  }

  const endpoint = `https://api.textbee.dev/api/v1/gateway/devices/${deviceId}/sendSMS`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey
    },
    body: JSON.stringify({
      recipients: [to],
      message
    })
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`TextBee API returned HTTP ${response.status}: ${JSON.stringify(data)}`);
  }

  console.log(`[TextBee] 📲 Real SMS dispatched via Main Phone to ${to}`);
  return { success: true, provider: 'textbee', data };
};

/**
 * Dispatch SMS via ADB (Android Debug Bridge) when phone is connected to PC with USB debugging
 */
const sendViaAdb = async ({ to, message }) => {
  return new Promise((resolve, reject) => {
    // Escape double quotes in message
    const escapedMsg = message.replace(/"/g, '\\"');
    const cmd = `adb shell cmd phone sms send-sms "${to}" "${escapedMsg}"`;

    exec(cmd, { timeout: 10000 }, (error, stdout, stderr) => {
      if (error) {
        // Fallback to legacy service call isms
        const fallbackCmd = `adb shell service call isms 5 s16 "com.android.mms" s16 "${to}" s16 "null" s16 "${escapedMsg}" s16 "null" s16 "null"`;
        exec(fallbackCmd, { timeout: 10000 }, (err2, stdout2, stderr2) => {
          if (err2) {
            return reject(new Error(`ADB SMS failed: ${error.message}; fallback failed: ${err2.message}`));
          }
          console.log(`[ADB SMS] 📲 Real SMS dispatched via USB-connected Main Phone to ${to}`);
          resolve({ success: true, provider: 'adb', output: stdout2 });
        });
        return;
      }
      console.log(`[ADB SMS] 📲 Real SMS dispatched via USB-connected Main Phone to ${to}`);
      resolve({ success: true, provider: 'adb', output: stdout });
    });
  });
};

/**
 * Dispatch SMS via Fast2SMS (Indian SMS Gateway)
 */
const sendViaFast2Sms = async ({ to, message }) => {
  const apiKey = process.env.FAST2SMS_API_KEY;
  if (!apiKey) {
    throw new Error('FAST2SMS_API_KEY must be set in .env');
  }

  // Fast2SMS accepts 10-digit numbers for domestic India
  const cleanNumber = to.replace(/^\+91/, '').replace(/\D/g, '');

  const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
    method: 'POST',
    headers: {
      'authorization': apiKey,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      route: 'q',
      message,
      language: 'english',
      flash: 0,
      numbers: cleanNumber
    })
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.return === false) {
    throw new Error(`Fast2SMS failed: ${data.message || response.statusText}`);
  }

  console.log(`[Fast2SMS] 📲 Real SMS dispatched to ${to}`);
  return { success: true, provider: 'fast2sms', data };
};

/**
 * Universal SMS Dispatcher
 * Automatically routes to configured provider or falls back gracefully
 */
const sendSms = async ({ to, message, code = null, purpose = 'verification' }) => {
  const formattedPhone = normalizePhoneNumber(to);
  const provider = (process.env.SMS_PROVIDER || 'android_gateway').toLowerCase().trim();

  console.log(`\n======================================================`);
  console.log(`[SMS DISPATCHER] Initiating SMS to ${formattedPhone}`);
  console.log(`[SMS DISPATCHER] Provider: ${provider}`);
  console.log(`[SMS DISPATCHER] Message:  "${message}"`);
  console.log(`======================================================`);

  try {
    if (provider === 'android_gateway' || provider === 'phone_gateway') {
      return await sendViaAndroidGateway({ to: formattedPhone, message });
    } else if (provider === 'textbee') {
      return await sendViaTextBee({ to: formattedPhone, message });
    } else if (provider === 'adb') {
      return await sendViaAdb({ to: formattedPhone, message });
    } else if (provider === 'fast2sms') {
      return await sendViaFast2Sms({ to: formattedPhone, message });
    } else {
      console.log(`[SMS Dispatcher] No active external provider match. Code: [${code}]`);
      return { success: true, provider: 'simulated' };
    }
  } catch (err) {
    console.warn(`\n⚠️  [SMS GATEWAY NOTICE]: Unable to send SMS via ${provider}:`);
    console.warn(`   Reason: ${err.message}`);
    console.warn(`   Target: ${formattedPhone}`);
    if (code) {
      console.warn(`   OTP Security Code: [ ${code} ]`);
    }
    console.warn(`   💡 Tip: Check phone Wi-Fi IP and ensure SMS Gateway app is running.\n`);

    // In non-fatal mode, return status with warning so auth flow continues
    return {
      success: false,
      error: err.message,
      provider,
      fallbackCode: code
    };
  }
};

/**
 * Send an OTP message formatted for CONNEKT authentication
 */
const sendOtpSms = async (phone, code, purpose = 'registration') => {
  const expiryMins = process.env.OTP_EXPIRY_MINUTES || '5';
  let purposeText = 'registration';
  if (purpose === 'login') purposeText = 'Sign In';
  if (purpose === 'forgot_password') purposeText = 'Password Reset';

  const message = `Your CONNEKT security code for ${purposeText} is: ${code}. Valid for ${expiryMins} minutes. Do NOT share this code with anyone.`;
  return await sendSms({ to: phone, message, code, purpose });
};

// If run directly from terminal: node smsService.js <phone> <test message>
if (require.main === module) {
  const testPhone = process.argv[2] || '+919836828816';
  const testCode = '492810';
  console.log(`Testing SMS dispatch to ${testPhone}...`);
  sendOtpSms(testPhone, testCode, 'test')
    .then(res => {
      console.log('Test dispatch complete:', res);
      process.exit(0);
    })
    .catch(err => {
      console.error('Test dispatch error:', err);
      process.exit(1);
    });
}

module.exports = {
  normalizePhoneNumber,
  extractLocalPhone,
  sendSms,
  sendOtpSms
};
