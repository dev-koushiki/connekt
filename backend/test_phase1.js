const http = require('http');

const BASE_URL = 'http://localhost:5000/api';

async function request(endpoint, method = 'GET', body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE_URL + endpoint);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('====================================================');
  console.log('🧪 RUNNING CONNEKT PHASE 1 INTEGRATION TEST SUITE');
  console.log('====================================================\n');

  const testPhone = `+1${Date.now().toString().slice(-10)}`;
  const testUsername = `user_${Date.now().toString().slice(-6)}`;
  const testPassword = 'Password123!';
  let jwtToken = null;
  let userId = null;
  let otpCode = null;

  // 1. Check Availability
  console.log(`1. Testing Username & Phone Availability for @${testUsername}...`);
  const availRes = await request(`/auth/check-availability?field=username&value=${testUsername}`);
  console.log(`   Status: ${availRes.status}, Available: ${availRes.body.data?.available}`);
  if (!availRes.body.data?.available) throw new Error('Username should be available!');

  // 2. Dispatch OTP
  console.log(`\n2. Requesting Registration OTP for phone: ${testPhone}...`);
  const otpRes = await request('/auth/send-otp', 'POST', { identifier: testPhone, purpose: 'registration' });
  console.log(`   Status: ${otpRes.status}, Message: ${otpRes.body.message}`);
  otpCode = otpRes.body.data?.previewCode;
  console.log(`   Extracted Test OTP: ${otpCode}`);
  if (!otpCode) throw new Error('Preview OTP code not returned in dev mode!');

  // 3. User Registration
  console.log(`\n3. Registering User (@${testUsername}) with OTP...`);
  const regRes = await request('/auth/register', 'POST', {
    phone: testPhone,
    otpCode: otpCode,
    username: testUsername,
    fullName: 'Test Candidate',
    password: testPassword,
    currentMode: 'common'
  });
  console.log(`   Status: ${regRes.status}, Message: ${regRes.body.message}`);
  if (regRes.status !== 201) throw new Error(`Registration failed: ${JSON.stringify(regRes.body)}`);
  
  jwtToken = regRes.body.data.token;
  userId = regRes.body.data.user.id;
  console.log(`   Registered User ID: ${userId}`);
  console.log(`   Connekt Mail ID: ${regRes.body.data.user.email}`);

  // 4. Duplicate Check
  console.log(`\n4. Testing Duplicate Registration Prevention...`);
  const dupRes = await request('/auth/register', 'POST', {
    phone: testPhone,
    otpCode: '123456',
    username: testUsername,
    fullName: 'Test Candidate',
    password: testPassword
  });
  console.log(`   Duplicate rejection status: ${dupRes.status} (Expected 400 or 409)`);
  if (dupRes.status !== 400 && dupRes.status !== 409) throw new Error('Duplicate check failed!');

  // 5. Login
  console.log(`\n5. Testing User Login with Connekt Username & Password...`);
  const loginRes = await request('/auth/login', 'POST', {
    identifier: testUsername,
    password: testPassword,
    loginType: 'password'
  });
  console.log(`   Status: ${loginRes.status}, Welcome: ${loginRes.body.data?.user?.personalProfile?.full_name}`);
  if (loginRes.status !== 200) throw new Error('Login failed!');
  jwtToken = loginRes.body.data.token;

  // 6. Get Profile /me
  console.log(`\n6. Fetching Current Profile via JWT (/auth/me)...`);
  const meRes = await request('/auth/me', 'GET', null, jwtToken);
  console.log(`   Status: ${meRes.status}, User: @${meRes.body.data?.user?.username}`);
  console.log(`   Current Mode: ${meRes.body.data?.user?.current_mode}`);
  if (meRes.status !== 200) throw new Error('Failed to get /auth/me');

  // 7. Mode Switching
  console.log(`\n7. Testing Account Mode Switching (common -> professional -> both)...`);
  const modeRes = await request('/users/mode', 'POST', { mode: 'professional' }, jwtToken);
  console.log(`   Switched to: ${modeRes.body.data?.currentMode}`);
  if (modeRes.body.data?.currentMode !== 'professional') throw new Error('Failed to switch to professional mode');

  const bothRes = await request('/users/mode', 'POST', { mode: 'both' }, jwtToken);
  console.log(`   Switched to: ${bothRes.body.data?.currentMode}`);
  if (bothRes.body.data?.currentMode !== 'both') throw new Error('Failed to switch to both mode');

  // 8. Update Personal Profile
  console.log(`\n8. Updating Personal Profile...`);
  const pRes = await request('/users/profile/personal', 'PUT', {
    fullName: 'Test Candidate Updated',
    displayName: 'CodeMaster',
    bio: 'Architecting scalable cloud systems.',
    location: 'Bangalore, India'
  }, jwtToken);
  console.log(`   Status: ${pRes.status}, Updated Display Name: ${pRes.body.data?.personalProfile?.display_name}`);
  if (pRes.status !== 200) throw new Error('Failed to update personal profile');

  // 9. Update Professional Profile
  console.log(`\n9. Updating Professional Profile...`);
  const profRes = await request('/users/profile/professional', 'PUT', {
    headline: 'Principal Distributed Systems Architect',
    currentCompany: 'CONNEKT Labs',
    industry: 'Cloud & AI Infrastructure',
    yearsOfExperience: 8,
    isOpenToWork: true
  }, jwtToken);
  console.log(`   Status: ${profRes.status}, Headline: ${profRes.body.data?.professionalProfile?.headline}`);
  if (profRes.status !== 200) throw new Error('Failed to update professional profile');

  // 10. Skills Management
  console.log(`\n10. Adding and Deleting Skills...`);
  const skillRes = await request('/users/skills', 'POST', { skillName: 'PostgreSQL Architecture', proficiency: 'Expert' }, jwtToken);
  console.log(`    Added Skill: ${skillRes.body.data?.skill?.skill_name} (${skillRes.body.data?.skill?.proficiency})`);
  const skillId = skillRes.body.data?.skill?.id;

  const delSkillRes = await request(`/users/skills/${skillId}`, 'DELETE', null, jwtToken);
  console.log(`    Delete Skill Status: ${delSkillRes.status}`);
  if (delSkillRes.status !== 200) throw new Error('Failed to delete skill');

  // 11. Work Experience & Education
  console.log(`\n11. Adding Education and Experience...`);
  const eduRes = await request('/users/education', 'POST', {
    institution: 'IIT Kharagpur',
    degree: 'B.Tech & M.Tech Dual Degree',
    fieldOfStudy: 'Computer Science & Engineering',
    startYear: 2018,
    endYear: 2023
  }, jwtToken);
  console.log(`    Added Education: ${eduRes.body.data?.education?.institution}`);

  const expRes = await request('/users/experience', 'POST', {
    companyName: 'Tech Innovations Inc',
    title: 'Senior Full Stack Architect',
    location: 'Bangalore',
    isCurrent: true,
    description: 'Designed unified messaging and distributed microservices.'
  }, jwtToken);
  console.log(`    Added Experience: ${expRes.body.data?.experience?.company_name}`);

  // 12. Privacy Settings
  console.log(`\n12. Updating Privacy Settings...`);
  const privRes = await request('/users/privacy', 'PUT', {
    profileVisibility: 'contacts_only',
    readReceipts: true,
    onlineStatus: true,
    groupInvitationApproval: true
  }, jwtToken);
  console.log(`    Status: ${privRes.status}, Group Approval: ${privRes.body.data?.privacySettings?.group_invitation_approval}`);

  // 13. Sessions & Devices
  console.log(`\n13. Inspecting Active Sessions & Devices...`);
  const sessRes = await request('/sessions', 'GET', null, jwtToken);
  console.log(`    Active Sessions Count: ${sessRes.body.data?.sessions?.length}`);
  console.log(`    Current Session Device: ${sessRes.body.data?.sessions[0]?.device_info}`);

  // 14. Logout
  console.log(`\n14. Testing User Logout...`);
  const logoutRes = await request('/auth/logout', 'POST', null, jwtToken);
  console.log(`    Logout Status: ${logoutRes.status}, Message: ${logoutRes.body.message}`);

  console.log('\n====================================================');
  console.log('✅ ALL PHASE 1 INTEGRATION TESTS PASSED 100%!');
  console.log('====================================================');
}

runTests().catch(err => {
  console.error('\n❌ Test Suite Failed:', err);
  process.exit(1);
});
