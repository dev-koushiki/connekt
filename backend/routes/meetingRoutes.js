const express = require('express');
const router = express.Router();
const MeetingController = require('../controllers/meetingController');
const { requireAuth } = require('../middleware/authMiddleware');

// All meeting routes require authenticated user
router.use(requireAuth);

// Room lifecycle endpoints
router.post('/rooms/create', MeetingController.createInstantRoom);
router.post('/rooms/:roomCode/join', MeetingController.joinRoom);
router.post('/rooms/:roomCode/leave', MeetingController.leaveRoom);
router.post('/rooms/:roomCode/end', MeetingController.endRoom);
router.get('/rooms/:roomCode', MeetingController.getRoomDetails);

// Signaling & In-Meeting Chat (Phase 2)
router.post('/rooms/:roomCode/signal', MeetingController.sendSignal);
router.get('/rooms/:roomCode/signals', MeetingController.getPendingSignals);
router.get('/rooms/:roomCode/chat', MeetingController.getChatMessages);
router.post('/rooms/:roomCode/chat', MeetingController.sendChatMessage);

// Google OAuth & Calendar Integration Endpoints (Phase 5)
router.get('/google/auth-url', MeetingController.getGoogleAuthUrl);
router.post('/google/callback', MeetingController.handleGoogleCallback);
router.get('/google/status', MeetingController.getGoogleStatus);
router.post('/google/disconnect', MeetingController.disconnectGoogle);

// Meeting scheduling & listing endpoints
router.get('/', MeetingController.listMeetings);
router.post('/', MeetingController.scheduleMeeting);
router.get('/:id', MeetingController.getMeetingDetails);
router.put('/:id', MeetingController.updateMeeting);
router.delete('/:id', MeetingController.cancelMeeting);
router.patch('/:id/lock', MeetingController.toggleLock);

// Meeting Records, Minutes & Action Items (Phase 4)
router.get('/:id/attendance', MeetingController.getMeetingAttendance);
router.get('/:id/minutes', MeetingController.getMeetingMinutes);
router.post('/:id/minutes', MeetingController.saveMeetingMinutes);
router.post('/:id/action-items', MeetingController.addActionItem);
router.put('/:id/action-items/:itemId', MeetingController.updateActionItem);
router.delete('/:id/action-items/:itemId', MeetingController.deleteActionItem);
router.post('/:id/recordings', MeetingController.logMeetingRecording);
router.get('/:id/recordings', MeetingController.getMeetingRecordings);

// Phase 5: Task Conversion, Calendar Sync & Invitations
router.post('/:id/action-items/:itemId/convert', MeetingController.convertActionItemToTask);
router.post('/:id/sync-google', MeetingController.syncGoogleCalendar);
router.get('/:id/icalendar', MeetingController.downloadICalendar);
router.post('/:id/send-invites', MeetingController.sendMeetingInvitations);

module.exports = router;
