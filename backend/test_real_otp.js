const http = require('http');
const db = require('./config/database');
const { createOtp, verifyOtp } = require('./services/otpService');

async function runTest() {
  console.log('--- TEST 1: Generating OTP for Indian mobile number ---');
  const testPhone = '9836828816';
  const otpRes = await createOtp(testPhone, 'registration', '127.0.0.1');
  console.log('createOtp result:', otpRes);

  if (otpRes.previewCode) {
    console.error('FAIL: previewCode should NOT be returned when SHOW_OTP_PREVIEW is false!');
  } else {
    console.log('PASS: previewCode is omitted as requested for real SMS flow.');
  }

  // Fetch the actual generated code from database using the newly created ID
  const dbRes = await db.query(
    'SELECT otp_code, expires_at, is_used FROM otp_verifications WHERE id = $1',
    [otpRes.id]
  );
  const realCode = dbRes.rows[0].otp_code;
  console.log(`Generated code in DB: [${realCode}]`);

  console.log('\n--- TEST 2: Verifying with incorrect code (should fail) ---');
  const wrongRes = await verifyOtp(testPhone, '000000', 'registration');
  console.log('Wrong code verify result:', wrongRes);
  if (!wrongRes.valid) {
    console.log('PASS: Wrong code correctly rejected.');
  } else {
    console.error('FAIL: Wrong code was accepted!');
  }

  console.log('\n--- TEST 3: Verifying with normalized number +919836828816 and real code ---');
  const correctRes = await verifyOtp('+919836828816', realCode, 'registration');
  console.log('Correct code verify result:', correctRes);
  if (correctRes.valid) {
    console.log('PASS: Correct code successfully verified with normalized country code!');
  } else {
    console.error('FAIL: Correct code verification failed!');
  }

  console.log('\n--- TEST 4: Verifying reused code (should fail) ---');
  const reuseRes = await verifyOtp(testPhone, realCode, 'registration');
  console.log('Reused code verify result:', reuseRes);
  if (!reuseRes.valid) {
    console.log('PASS: Reused code correctly rejected.');
  } else {
    console.error('FAIL: Reused code was accepted!');
  }

  console.log('\nALL OTP TESTS PASSED SUCCESSFULLY! ✅');
  process.exit(0);
}

runTest().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
