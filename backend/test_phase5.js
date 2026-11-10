/**
 * Automated Verification Script for Phase 5: Task Conversion, Calendar & Email Integrations
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const db = require('./config/database');
const MeetingModel = require('./models/meetingModel');
const UserModel = require('./models/userModel');
const meetingEmailService = require('./services/meetingEmailService');
const googleCalendarService = require('./services/googleCalendarService');

async function runPhase5Tests() {
  console.log('\n============================================================');
  console.log('🚀 RUNNING PHASE 5 TESTS: TASKS, GOOGLE CALENDAR & EMAIL');
  console.log('============================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${message}`);
      failed++;
    }
  }

  try {
    // 1. Get test user
    const userRes = await db.query('SELECT * FROM users LIMIT 1');
    const testUser = userRes.rows[0];
    assert(testUser && testUser.id, 'Test user available for Phase 5 integration testing');

    // 2. Create test meeting
    const meeting = await MeetingModel.createInstantMeeting(testUser, 'Phase 5 Architecture Review');
    assert(meeting && meeting.room_code, `Meeting created: CNK-${meeting.room_code}`);

    // 3. Create an action item
    const actionItem = await MeetingModel.addActionItem(meeting.id, {
      title: 'Deploy real-time WebRTC SFU/TURN cluster',
      description: 'Implement distributed TURN routing for global low-latency meetings',
      assignedTo: testUser.id,
      assignedName: testUser.username,
      priority: 'high',
      dueDate: new Date(Date.now() + 86400000 * 3)
    });
    assert(actionItem && actionItem.id, `Action item created: "${actionItem.title}"`);

    // 4. Test Convert Action Item to Task
    const convertResult = await MeetingModel.convertActionItemToTask(meeting.id, actionItem.id, testUser.id);
    assert(convertResult && convertResult.task && convertResult.task.id, 'Action item converted to persistent task');
    assert(convertResult.task.title === actionItem.title, 'Task title matches action item title');
    assert(convertResult.task.meeting_id === meeting.id, 'Task is foreign-key linked to meeting');
    assert(convertResult.actionItem.status === 'converted', 'Action item status marked as converted');
    assert(convertResult.actionItem.linked_task_id === convertResult.task.id, 'Action item linked_task_id matches task ID');

    // Verify task row directly in database
    const taskDbRes = await db.query('SELECT * FROM tasks WHERE id = $1', [convertResult.task.id]);
    assert(taskDbRes.rowCount === 1, 'Task row verified in PostgreSQL tasks table');

    // Prevent duplicate conversion
    let dupFailed = false;
    try {
      await MeetingModel.convertActionItemToTask(meeting.id, actionItem.id, testUser.id);
    } catch (e) {
      dupFailed = true;
    }
    assert(dupFailed, 'Prevented duplicate conversion of already-converted action item');

    // 5. Test Google OAuth Auth URL Generation
    const authUrlData = googleCalendarService.getAuthUrl('http://localhost:5000/google-callback.html');
    assert(authUrlData !== null, 'Google OAuth URL generator executed without exceptions');

    // 6. Test Google Token Exchange / Dev Mode Simulation
    const tokenData = await googleCalendarService.exchangeCode('test_auth_code', 'http://localhost:5000/google-callback.html');
    assert(tokenData && tokenData.accessToken, 'Google OAuth token exchanged / simulated successfully');

    await MeetingModel.updateUserGoogleTokens(testUser.id, tokenData);
    const retrievedTokens = await MeetingModel.getUserGoogleTokens(testUser.id);
    assert(retrievedTokens && retrievedTokens.accessToken === tokenData.accessToken, 'User Google tokens stored and retrieved from PostgreSQL');

    // 7. Test Google Calendar Meeting Sync
    const syncResult = await googleCalendarService.syncMeetingEvent(tokenData, meeting, 'http://localhost:5000');
    assert(syncResult && syncResult.synced, 'Meeting synchronized with Google Calendar');
    assert(syncResult.googleEventId, `Generated Google Calendar Event ID: ${syncResult.googleEventId}`);

    const updatedMeeting = await MeetingModel.updateMeetingGoogleSync(meeting.id, syncResult);
    assert(updatedMeeting.google_synced === true, 'Meeting table updated with google_synced = true');
    assert(updatedMeeting.google_event_id === syncResult.googleEventId, 'Meeting table updated with google_event_id');

    // 8. Test RFC 5545 iCalendar (.ics) generation
    const icsString = meetingEmailService.generateICalendar(meeting, 'Test Host', 'test@connekt.me', `http://localhost:5000/?join=CNK-${meeting.room_code}`);
    assert(icsString.includes('BEGIN:VCALENDAR'), 'iCalendar contains BEGIN:VCALENDAR header');
    assert(icsString.includes(`CNK-${meeting.room_code}`), 'iCalendar contains room code in description and location');
    assert(icsString.includes('END:VCALENDAR'), 'iCalendar contains valid closing tag');

    // 9. Test Email Invitation Dispatch
    const emailDispatch = await meetingEmailService.sendMeetingInvitation({
      meeting,
      hostUser: testUser,
      recipients: ['invitee1@connekt.me', 'invitee2@connekt.me'],
      baseUrl: 'http://localhost:5000'
    });
    assert(emailDispatch.success === true, 'Meeting email invitation dispatched successfully');
    assert(emailDispatch.count === 2, 'Email dispatched to 2 recipients');

    console.log('\n------------------------------------------------------------');
    console.log(`📊 PHASE 5 RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('------------------------------------------------------------\n');

    process.exit(failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Unexpected error during Phase 5 tests:', err);
    process.exit(1);
  }
}

runPhase5Tests();
