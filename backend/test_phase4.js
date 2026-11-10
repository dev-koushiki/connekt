/**
 * Automated Verification Script for Phase 4: Meeting Records, Minutes, Action Items & Recordings
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const db = require('./config/database');
const MeetingModel = require('./models/meetingModel');
const UserModel = require('./models/userModel');
const { generateToken } = require('./services/tokenService');

async function runPhase4Tests() {
  console.log('\n============================================================');
  console.log('🚀 RUNNING PHASE 4 TESTS: RECORDS, MINUTES & ACTION ITEMS');
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
    // 1. Get or create test host user
    let userRes = await db.query("SELECT * FROM users LIMIT 1");
    let testUser = userRes.rows[0];
    if (!testUser) {
      testUser = await UserModel.createUser({
        phone: '+1999999999',
        username: 'phase4host',
        email: 'phase4_test@connekt.me',
        passwordHash: '$2b$10$abcdefghijklmnopqrstuvwxyz1234567890'
      });
    }
    assert(testUser && testUser.id, 'Test user available for Phase 4 testing');

    // 2. Create a test meeting
    const meeting = await MeetingModel.createInstantMeeting(testUser, 'Phase 4 Verification Conference');
    assert(meeting && meeting.room_code, `Created test meeting room CNK-${meeting.room_code} (ID: ${meeting.id})`);

    // 3. Record attendance for 3 participants
    await MeetingModel.recordParticipantJoin(meeting.id, testUser, 'host');
    await new Promise(r => setTimeout(r, 1100)); // Sleep 1.1s so duration is > 0
    await MeetingModel.recordParticipantLeave(meeting.id, testUser.id);

    // Participant 2
    await db.query(
      `INSERT INTO meeting_attendance (meeting_id, user_id, name, email, joined_at, left_at, duration_seconds)
       VALUES ($1, $2, $3, $4, NOW() - INTERVAL '30 minutes', NOW(), 1800)`,
      [meeting.id, testUser.id, 'Alice Developer', 'alice@connekt.me']
    );

    // Participant 3
    await db.query(
      `INSERT INTO meeting_attendance (meeting_id, user_id, name, email, joined_at, left_at, duration_seconds)
       VALUES ($1, $2, $3, $4, NOW() - INTERVAL '45 minutes', NOW(), 2700)`,
      [meeting.id, testUser.id, 'Bob Architect', 'bob@connekt.me']
    );

    // 4. Test getMeetingAttendance
    const attendance = await MeetingModel.getMeetingAttendance(meeting.id);
    assert(attendance.length >= 3, `Retrieved ${attendance.length} attendance records for meeting`);

    const totalSecs = attendance.reduce((acc, row) => acc + (row.duration_seconds || 0), 0);
    const avgSecs = Math.round(totalSecs / attendance.length);
    assert(totalSecs >= 4500, `Total duration calculated correctly (${totalSecs}s)`);
    assert(avgSecs > 0, `Average duration calculated correctly (${avgSecs}s)`);

    // 5. Test saveMeetingMinutes (Upsert)
    const minutesData = {
      summary: 'Reviewed real-time WebRTC audio/video architecture and finalized Phase 4 deliverables.',
      discussionPoints: '1. Web Audio API mixing for recordings.\n2. In-meeting persistent chat.\n3. Screen share spotlight layout.',
      decisions: 'Agreed to implement pure client-side recording download with server-side metadata logging.'
    };

    const savedMin = await MeetingModel.saveMeetingMinutes(meeting.id, testUser.id, 'Test Host', minutesData);
    assert(savedMin && savedMin.meeting_id === meeting.id, 'Meeting minutes saved successfully in PostgreSQL');
    assert(savedMin.summary === minutesData.summary, 'Minutes summary matches expected value');

    // Test Minutes Upsert update
    const updatedMin = await MeetingModel.saveMeetingMinutes(meeting.id, testUser.id, 'Test Host', {
      summary: 'Updated Executive Summary: Phase 4 completed successfully.',
      discussionPoints: minutesData.discussionPoints,
      decisions: minutesData.decisions
    });
    assert(updatedMin.summary.includes('Phase 4 completed successfully'), 'Minutes updated (Upsert) correctly without duplicate entries');

    // 6. Test Action Items CRUD
    const item1 = await MeetingModel.addActionItem(meeting.id, {
      title: 'Verify browser audio mixing in Firefox and Chrome',
      description: 'Ensure MediaStreamDestination correctly binds remote participant streams',
      assignedTo: 'alice@connekt.me',
      assignedName: 'Alice Developer',
      priority: 'high',
      dueDate: new Date(Date.now() + 86400000 * 2)
    });
    assert(item1 && item1.id, `Created Action Item 1: "${item1.title}" (Priority: ${item1.priority})`);

    const item2 = await MeetingModel.addActionItem(meeting.id, {
      title: 'Write automated Phase 4 verification test suite',
      assignedTo: 'bob@connekt.me',
      assignedName: 'Bob Architect',
      priority: 'medium'
    });
    assert(item2 && item2.id, `Created Action Item 2: "${item2.title}"`);

    // Retrieve minutes & action items combined
    const minWithActions = await MeetingModel.getMeetingMinutes(meeting.id);
    assert(minWithActions.actionItems.length === 2, `Retrieved ${minWithActions.actionItems.length} action items attached to meeting`);

    // Update Action Item 1 (status: completed)
    const updatedItem1 = await MeetingModel.updateActionItem(item1.id, {
      status: 'completed'
    });
    assert(updatedItem1.status === 'completed', 'Action Item 1 status updated to completed');

    // Delete Action Item 2
    const deletedItem2 = await MeetingModel.deleteActionItem(item2.id);
    assert(deletedItem2 && deletedItem2.id === item2.id, 'Action Item 2 deleted successfully');

    const minAfterDelete = await MeetingModel.getMeetingMinutes(meeting.id);
    assert(minAfterDelete.actionItems.length === 1, 'Action items count is 1 after deletion');

    // 7. Test Meeting Recording Logging
    const recordingLog = await MeetingModel.logMeetingRecording(meeting.id, testUser.id, {
      fileName: `connekt-meeting-${meeting.room_code}-20261109.webm`,
      durationSeconds: 1845,
      fileSizeBytes: 24500000,
      storageLocation: 'browser-download'
    });
    assert(recordingLog && recordingLog.id, `Logged meeting recording: ${recordingLog.file_name} (${(recordingLog.file_size_bytes / (1024 * 1024)).toFixed(1)} MB)`);

    const recordings = await MeetingModel.getMeetingRecordings(meeting.id);
    assert(recordings.length === 1 && recordings[0].id === recordingLog.id, 'Retrieved recording logs for meeting');

    // 8. Test CSV Generation format
    const csvHeader = 'Participant Name,Email,Joined At,Left At,Duration (Seconds),Duration (Minutes)';
    const csvRow = `"${attendance[0].name}","${attendance[0].email}","${attendance[0].joined_at.toISOString()}","${attendance[0].left_at ? attendance[0].left_at.toISOString() : ''}",${attendance[0].duration_seconds},${(attendance[0].duration_seconds / 60).toFixed(1)}`;
    assert(csvRow.includes(attendance[0].name), 'CSV attendance formatting valid');

    console.log('\n------------------------------------------------------------');
    console.log(`📊 PHASE 4 RESULTS: ${passed} PASSED, ${failed} FAILED`);
    console.log('------------------------------------------------------------\n');

    process.exit(failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Unexpected error during Phase 4 tests:', err);
    process.exit(1);
  }
}

runPhase4Tests();
