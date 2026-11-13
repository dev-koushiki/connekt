const MeetingModel = require('../models/meetingModel');
const UserModel = require('../models/userModel');
const db = require('../config/database');
const { successResponse, errorResponse } = require('../utils/responseHandler');
const meetingEmailService = require('../services/meetingEmailService');
const googleCalendarService = require('../services/googleCalendarService');

class MeetingController {
  /**
   * 1. Create an instant meeting room
   * POST /api/meetings/rooms/create
   */
  static async createInstantRoom(req, res) {
    try {
      const userProfile = await UserModel.findById(req.user.id);
      const hostUser = {
        id: req.user.id,
        email: req.user.email,
        username: req.user.username,
        personalProfile: {
          fullName: userProfile?.full_name || req.user.username
        }
      };

      const title = req.body.title || 'Instant Meeting';
      const meeting = await MeetingModel.createInstantMeeting(hostUser, title);

      return successResponse(res, 201, 'Instant meeting room created successfully.', {
        meeting,
        roomCode: meeting.room_code,
        meetingLink: meeting.meeting_link
      });
    } catch (err) {
      console.error('[Create Instant Room Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to create instant meeting room.');
    }
  }

  /**
   * 2. Validate and join a meeting room
   * POST /api/meetings/rooms/:roomCode/join
   */
  static async joinRoom(req, res) {
    try {
      const { roomCode } = req.params;
      const { passcode } = req.body;

      if (!roomCode) {
        return errorResponse(res, 400, 'Meeting room code is required.');
      }

      const meeting = await MeetingModel.findByRoomCode(roomCode);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found. Please check the code and try again.');
      }

      // Check if meeting has ended or cancelled
      if (meeting.status === 'ended') {
        return errorResponse(res, 410, 'This meeting has ended and is no longer active.');
      }
      if (meeting.status === 'cancelled') {
        return errorResponse(res, 410, 'This meeting was cancelled by the host.');
      }

      const isHost = meeting.host_id === req.user.id;

      // Check if room is locked
      if (meeting.is_locked && !isHost) {
        return errorResponse(res, 423, 'This meeting room has been locked by the host.');
      }

      // Check meeting passcode if configured
      if (meeting.passcode && !isHost) {
        if (!passcode || passcode.trim() !== meeting.passcode.trim()) {
          return errorResponse(res, 403, 'Invalid meeting passcode.');
        }
      }

      // Fetch user profile info
      const userProfile = await UserModel.findById(req.user.id);
      const participantUser = {
        id: req.user.id,
        email: req.user.email,
        username: req.user.username,
        personalProfile: {
          fullName: userProfile?.full_name || req.user.username
        }
      };

      const role = isHost ? 'host' : 'participant';
      const attendance = await MeetingModel.recordParticipantJoin(meeting.id, participantUser, role);
      const participants = await MeetingModel.getParticipants(meeting.id);

      return successResponse(res, 200, 'Joined meeting successfully.', {
        meeting: {
          id: meeting.id,
          roomCode: meeting.room_code,
          title: meeting.title,
          description: meeting.description,
          agenda: meeting.agenda,
          hostId: meeting.host_id,
          hostName: meeting.host_name,
          hostAvatar: meeting.host_avatar,
          status: meeting.status === 'scheduled' ? 'live' : meeting.status,
          isLocked: meeting.is_locked,
          meetingLink: meeting.meeting_link,
          startTime: meeting.start_time
        },
        role,
        isHost,
        attendanceId: attendance?.id,
        participants
      });
    } catch (err) {
      console.error('[Join Room Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to join meeting.');
    }
  }

  /**
   * 3. Leave a meeting room
   * POST /api/meetings/rooms/:roomCode/leave
   */
  static async leaveRoom(req, res) {
    try {
      const { roomCode } = req.params;
      const meeting = await MeetingModel.findByRoomCode(roomCode);

      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found.');
      }

      await MeetingModel.recordParticipantLeave(meeting.id, req.user.id);

      return successResponse(res, 200, 'Left meeting successfully.');
    } catch (err) {
      console.error('[Leave Room Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to record meeting departure.');
    }
  }

  /**
   * 4. End a meeting room for everyone (Host only)
   * POST /api/meetings/rooms/:roomCode/end
   */
  static async endRoom(req, res) {
    try {
      const { roomCode } = req.params;
      const meeting = await MeetingModel.findByRoomCode(roomCode);

      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found.');
      }

      if (meeting.host_id !== req.user.id) {
        return errorResponse(res, 403, 'Only the host has permission to end this meeting.');
      }

      const endedMeeting = await MeetingModel.endMeeting(meeting.id, req.user.id);

      return successResponse(res, 200, 'Meeting ended successfully for all participants.', {
        meeting: endedMeeting
      });
    } catch (err) {
      console.error('[End Room Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to end meeting.');
    }
  }

  /**
   * 5. Get meeting details by room code (Safe view)
   * GET /api/meetings/rooms/:roomCode
   */
  static async getRoomDetails(req, res) {
    try {
      const { roomCode } = req.params;
      const meeting = await MeetingModel.findByRoomCode(roomCode);

      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found.');
      }

      const participants = await MeetingModel.getParticipants(meeting.id);
      const isHost = meeting.host_id === req.user.id;

      return successResponse(res, 200, 'Meeting room details retrieved.', {
        meeting: {
          id: meeting.id,
          roomCode: meeting.room_code,
          title: meeting.title,
          description: meeting.description,
          agenda: meeting.agenda,
          hostId: meeting.host_id,
          hostName: meeting.host_name,
          hostAvatar: meeting.host_avatar,
          status: meeting.status,
          isLocked: meeting.is_locked,
          hasPasscode: !!meeting.passcode,
          scheduledAt: meeting.scheduled_at,
          durationMinutes: meeting.duration_minutes,
          meetingLink: meeting.meeting_link
        },
        isHost,
        participants
      });
    } catch (err) {
      console.error('[Get Room Details Error]:', err);
      return errorResponse(res, 500, 'Failed to retrieve meeting room details.');
    }
  }

  /**
   * 6. List meetings with filters & search
   * GET /api/meetings
   */
  static async listMeetings(req, res) {
    try {
      const { filter = 'all', search = '', limit = 50 } = req.query;
      const meetings = await MeetingModel.listMeetings(req.user.id, req.user.email, {
        filter,
        search,
        limit: parseInt(limit, 10) || 50
      });

      return successResponse(res, 200, 'Meetings retrieved successfully.', {
        meetings,
        total: meetings.length,
        filter
      });
    } catch (err) {
      console.error('[List Meetings Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch meetings.');
    }
  }

  /**
   * 7. Schedule a new meeting
   * POST /api/meetings
   */
  static async scheduleMeeting(req, res) {
    try {
      const {
        title,
        description,
        agenda,
        scheduledAt,
        durationMinutes,
        passcode,
        attendees
      } = req.body;

      if (!title || !title.trim()) {
        return errorResponse(res, 400, 'Meeting title is required.');
      }
      if (!scheduledAt) {
        return errorResponse(res, 400, 'Scheduled date and time is required.');
      }

      const parsedDate = new Date(scheduledAt);
      if (isNaN(parsedDate.getTime())) {
        return errorResponse(res, 400, 'Invalid scheduled date/time format.');
      }

      const userProfile = await UserModel.findById(req.user.id);
      const hostUser = {
        id: req.user.id,
        email: req.user.email,
        username: req.user.username,
        personalProfile: {
          fullName: userProfile?.full_name || req.user.username
        }
      };

      const meeting = await MeetingModel.scheduleMeeting({
        hostUser,
        title: title.trim(),
        description: description?.trim() || '',
        agenda: agenda?.trim() || '',
        scheduledAt: parsedDate,
        durationMinutes: parseInt(durationMinutes, 10) || 45,
        passcode: passcode?.trim() || null,
        attendees: Array.isArray(attendees) ? attendees : []
      });

      // Send in-app notifications to registered attendees
      if (Array.isArray(attendees) && attendees.length > 0) {
        for (const att of attendees) {
          const emailOrUsername = (typeof att === 'string' ? att : att.email || att.username || '').trim().toLowerCase();
          if (!emailOrUsername) continue;

          try {
            const recipient = await UserModel.findByIdentifier(emailOrUsername);
            if (recipient && recipient.id !== req.user.id) {
              await db.query(
                `INSERT INTO notifications (user_id, type, title, body, data, is_read, created_at)
                 VALUES ($1, 'meeting_invite', $2, $3, $4, false, NOW())`,
                [
                  recipient.id,
                  `Meeting Invitation: ${meeting.title}`,
                  `${hostUser.personalProfile.fullName} invited you to a meeting scheduled for ${parsedDate.toLocaleString()}.`,
                  JSON.stringify({
                    meetingId: meeting.id,
                    roomCode: meeting.room_code,
                    meetingLink: meeting.meeting_link,
                    scheduledAt: meeting.scheduled_at
                  })
                ]
              );
            }
          } catch (notifErr) {
            console.error('[Meeting Notification Error]:', notifErr.message);
          }
        }

        // Send email invitations via meetingEmailService
        const emailRecipients = attendees
          .map(att => (typeof att === 'string' ? att : att.email || '').trim())
          .filter(e => e.includes('@'));
        if (emailRecipients.length > 0) {
          const origin = req.headers.origin || 'http://localhost:5000';
          meetingEmailService.sendMeetingInvitation({
            meeting,
            hostUser,
            recipients: emailRecipients,
            baseUrl: origin
          }).catch(err => console.warn('[MeetingEmail] Background dispatch error:', err.message));
        }
      }

      return successResponse(res, 201, 'Meeting scheduled successfully.', {
        meeting
      });
    } catch (err) {
      console.error('[Schedule Meeting Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to schedule meeting.');
    }
  }

  /**
   * 8. Get meeting details by ID
   * GET /api/meetings/:id
   */
  static async getMeetingDetails(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);

      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const participants = await MeetingModel.getParticipants(meeting.id);
      const isHost = meeting.host_id === req.user.id;

      return successResponse(res, 200, 'Meeting details retrieved.', {
        meeting,
        participants,
        isHost
      });
    } catch (err) {
      console.error('[Get Meeting Details Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch meeting details.');
    }
  }

  /**
   * 9. Update meeting details (Host only)
   * PUT /api/meetings/:id
   */
  static async updateMeeting(req, res) {
    try {
      const { id } = req.params;
      const updates = req.body;

      const updated = await MeetingModel.updateMeeting(id, req.user.id, updates);

      return successResponse(res, 200, 'Meeting updated successfully.', {
        meeting: updated
      });
    } catch (err) {
      console.error('[Update Meeting Error]:', err);
      const status = err.message.includes('Only the host') ? 403 : 500;
      return errorResponse(res, status, err.message || 'Failed to update meeting.');
    }
  }

  /**
   * 10. Cancel meeting (Host only)
   * DELETE /api/meetings/:id
   */
  static async cancelMeeting(req, res) {
    try {
      const { id } = req.params;
      const cancelled = await MeetingModel.deleteMeeting(id, req.user.id);

      return successResponse(res, 200, 'Meeting cancelled successfully.', {
        meeting: cancelled
      });
    } catch (err) {
      console.error('[Cancel Meeting Error]:', err);
      const status = err.message.includes('Only the host') ? 403 : 500;
      return errorResponse(res, status, err.message || 'Failed to cancel meeting.');
    }
  }

  /**
   * 11. Lock / Unlock room (Host only)
   * PATCH /api/meetings/:id/lock
   */
  static async toggleLock(req, res) {
    try {
      const { id } = req.params;
      const { isLocked } = req.body;

      const meeting = await MeetingModel.setMeetingLock(id, req.user.id, !!isLocked);

      return successResponse(res, 200, `Meeting room ${isLocked ? 'locked' : 'unlocked'} successfully.`, {
        meeting
      });
    } catch (err) {
      console.error('[Toggle Lock Error]:', err);
      const status = err.message.includes('Only the meeting host') ? 403 : 500;
      return errorResponse(res, status, err.message || 'Failed to update meeting lock status.');
    }
  }

  // ====================================================================
  // WEBRTC SIGNALING & CHAT ENDPOINTS (PHASE 2)
  // ====================================================================

  /**
   * 12. Send a WebRTC signal (SDP or ICE) via REST fallback
   * POST /api/meetings/rooms/:roomCode/signal
   */
  static async sendSignal(req, res) {
    try {
      const { roomCode } = req.params;
      const { recipientId, signalType, payload } = req.body;

      if (!roomCode || !recipientId || !payload) {
        return errorResponse(res, 400, 'roomCode, recipientId, and payload are required.');
      }

      const meeting = await MeetingModel.findByRoomCode(roomCode);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found.');
      }

      const signal = await MeetingModel.saveSignal({
        roomCode,
        meetingId: meeting.id,
        senderId: req.user.id,
        recipientId,
        signalType: signalType || 'webrtc-signal',
        payload
      });

      return successResponse(res, 201, 'Signal queued successfully.', { signal });
    } catch (err) {
      console.error('[Send Signal Error]:', err);
      return errorResponse(res, 500, 'Failed to process signaling message.');
    }
  }

  /**
   * 13. Get pending signals for logged in user
   * GET /api/meetings/rooms/:roomCode/signals
   */
  static async getPendingSignals(req, res) {
    try {
      const { roomCode } = req.params;
      const signals = await MeetingModel.getPendingSignals(roomCode, req.user.id);

      return successResponse(res, 200, 'Pending signals retrieved.', {
        signals,
        count: signals.length
      });
    } catch (err) {
      console.error('[Get Signals Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch pending signals.');
    }
  }

  /**
   * 14. Get meeting chat history
   * GET /api/meetings/rooms/:roomCode/chat
   */
  static async getChatMessages(req, res) {
    try {
      const { roomCode } = req.params;
      const { limit = 100 } = req.query;

      const messages = await MeetingModel.getChatMessages(roomCode, parseInt(limit, 10));

      return successResponse(res, 200, 'Chat history retrieved.', {
        messages,
        count: messages.length
      });
    } catch (err) {
      console.error('[Get Chat Error]:', err);
      return errorResponse(res, 500, 'Failed to retrieve meeting chat messages.');
    }
  }

  /**
   * 15. Post a new in-meeting chat message
   * POST /api/meetings/rooms/:roomCode/chat
   */
  static async sendChatMessage(req, res) {
    try {
      const { roomCode } = req.params;
      const { message } = req.body;

      if (!message || !message.trim()) {
        return errorResponse(res, 400, 'Message cannot be empty.');
      }

      const meeting = await MeetingModel.findByRoomCode(roomCode);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting room not found.');
      }

      const userProfile = await UserModel.findById(req.user.id);
      const senderName = userProfile?.full_name || req.user.username;

      const saved = await MeetingModel.saveChatMessage({
        meetingId: meeting.id,
        roomCode,
        senderId: req.user.id,
        senderName,
        message: message.trim()
      });

      return successResponse(res, 201, 'Chat message saved.', {
        message: saved
      });
    } catch (err) {
      console.error('[Send Chat Error]:', err);
      return errorResponse(res, 500, 'Failed to send chat message.');
    }
  }

  // ====================================================================
  // MEETING RECORDS, MINUTES & ACTION ITEMS (PHASE 4)
  // ====================================================================

  /**
   * 16. Get meeting attendance report
   * GET /api/meetings/:id/attendance
   */
  static async getMeetingAttendance(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const attendance = await MeetingModel.getMeetingAttendance(meeting.id);

      // Calculate attendance statistics
      const totalParticipants = attendance.length;
      const totalDurationSecs = attendance.reduce((acc, row) => acc + (row.duration_seconds || 0), 0);
      const avgDurationSecs = totalParticipants > 0 ? Math.round(totalDurationSecs / totalParticipants) : 0;

      return successResponse(res, 200, 'Attendance report retrieved.', {
        attendance,
        stats: {
          totalParticipants,
          totalDurationSeconds: totalDurationSecs,
          averageDurationSeconds: avgDurationSecs
        }
      });
    } catch (err) {
      console.error('[Get Attendance Error]:', err);
      return errorResponse(res, 500, 'Failed to retrieve attendance records.');
    }
  }

  /**
   * 17. Get meeting minutes & action items
   * GET /api/meetings/:id/minutes
   */
  static async getMeetingMinutes(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const data = await MeetingModel.getMeetingMinutes(meeting.id);

      return successResponse(res, 200, 'Meeting minutes and action items retrieved.', {
        meeting: {
          id: meeting.id,
          title: meeting.title,
          roomCode: meeting.room_code,
          scheduledAt: meeting.scheduled_at,
          status: meeting.status
        },
        minutes: data.minutes,
        actionItems: data.actionItems
      });
    } catch (err) {
      console.error('[Get Minutes Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch meeting minutes.');
    }
  }

  /**
   * 18. Save / update meeting minutes
   * POST /api/meetings/:id/minutes
   */
  static async saveMeetingMinutes(req, res) {
    try {
      const { id } = req.params;
      const { summary, discussionPoints, decisions } = req.body;

      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const userProfile = await UserModel.findById(req.user.id);
      const userName = userProfile?.full_name || req.user.username;

      const saved = await MeetingModel.saveMeetingMinutes(meeting.id, req.user.id, userName, {
        summary,
        discussionPoints,
        decisions
      });

      return successResponse(res, 200, 'Meeting minutes saved successfully.', {
        minutes: saved
      });
    } catch (err) {
      console.error('[Save Minutes Error]:', err);
      return errorResponse(res, 500, 'Failed to save meeting minutes.');
    }
  }

  /**
   * 19. Add an action item
   * POST /api/meetings/:id/action-items
   */
  static async addActionItem(req, res) {
    try {
      const { id } = req.params;
      const { title, description, assignedTo, assignedName, priority, dueDate, status } = req.body;

      if (!title || !title.trim()) {
        return errorResponse(res, 400, 'Action item title is required.');
      }

      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const item = await MeetingModel.addActionItem(meeting.id, {
        title,
        description,
        assignedTo,
        assignedName,
        priority,
        dueDate,
        status
      });

      return successResponse(res, 201, 'Action item created.', {
        actionItem: item
      });
    } catch (err) {
      console.error('[Add Action Item Error]:', err);
      return errorResponse(res, 500, 'Failed to create action item.');
    }
  }

  /**
   * 20. Update an action item
   * PUT /api/meetings/:id/action-items/:itemId
   */
  static async updateActionItem(req, res) {
    try {
      const { itemId } = req.params;
      const updates = req.body;

      const updated = await MeetingModel.updateActionItem(itemId, updates);

      return successResponse(res, 200, 'Action item updated.', {
        actionItem: updated
      });
    } catch (err) {
      console.error('[Update Action Item Error]:', err);
      return errorResponse(res, 500, 'Failed to update action item.');
    }
  }

  /**
   * 21. Delete an action item
   * DELETE /api/meetings/:id/action-items/:itemId
   */
  static async deleteActionItem(req, res) {
    try {
      const { itemId } = req.params;
      const deleted = await MeetingModel.deleteActionItem(itemId);

      return successResponse(res, 200, 'Action item deleted.', {
        actionItem: deleted
      });
    } catch (err) {
      console.error('[Delete Action Item Error]:', err);
      return errorResponse(res, 500, 'Failed to delete action item.');
    }
  }

  /**
   * 22. Log meeting recording metadata
   * POST /api/meetings/:id/recordings
   */
  static async logMeetingRecording(req, res) {
    try {
      const { id } = req.params;
      const { fileName, durationSeconds, fileSizeBytes, storageLocation } = req.body;

      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const rec = await MeetingModel.logMeetingRecording(meeting.id, req.user.id, {
        fileName,
        durationSeconds,
        fileSizeBytes,
        storageLocation
      });

      return successResponse(res, 201, 'Recording metadata logged.', {
        recording: rec
      });
    } catch (err) {
      console.error('[Log Recording Error]:', err);
      return errorResponse(res, 500, 'Failed to log recording metadata.');
    }
  }

  /**
   * 23. Get meeting recordings metadata
   * GET /api/meetings/:id/recordings
   */
  static async getMeetingRecordings(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const recordings = await MeetingModel.getMeetingRecordings(meeting.id);

      return successResponse(res, 200, 'Recordings retrieved.', {
        recordings
      });
    } catch (err) {
      console.error('[Get Recordings Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch recordings metadata.');
    }
  }

  // ====================================================================
  // PHASE 5: ACTION ITEMS TO TASKS & CALENDAR / EMAIL INTEGRATION
  // ====================================================================

  /**
   * 24. Convert a meeting action item to a persistent task
   * POST /api/meetings/:id/action-items/:itemId/convert
   */
  static async convertActionItemToTask(req, res) {
    try {
      const { id, itemId } = req.params;
      const result = await MeetingModel.convertActionItemToTask(id, itemId, req.user.id);

      return successResponse(res, 201, 'Action item converted to task successfully.', result);
    } catch (err) {
      console.error('[Convert Action Item Error]:', err);
      return errorResponse(res, 400, err.message || 'Failed to convert action item to task.');
    }
  }

  /**
   * 25. Get Google OAuth 2.0 Authorization URL
   * GET /api/meetings/google/auth-url
   */
  static async getGoogleAuthUrl(req, res) {
    try {
      const origin = req.headers.origin || 'http://localhost:5000';
      const redirectUri = req.query.redirectUri || `${origin}/google-callback.html`;
      const data = googleCalendarService.getAuthUrl(redirectUri);

      return successResponse(res, 200, 'Google auth URL generated.', data);
    } catch (err) {
      console.error('[Google Auth URL Error]:', err);
      return errorResponse(res, 500, 'Failed to generate Google auth URL.');
    }
  }

  /**
   * 26. Handle Google OAuth code callback exchange
   * POST /api/meetings/google/callback
   */
  static async handleGoogleCallback(req, res) {
    try {
      const { code, redirectUri } = req.body;
      const origin = req.headers.origin || 'http://localhost:5000';
      const actualRedirectUri = redirectUri || `${origin}/google-callback.html`;

      const tokens = await googleCalendarService.exchangeCode(code, actualRedirectUri);
      await MeetingModel.updateUserGoogleTokens(req.user.id, tokens);

      return successResponse(res, 200, 'Google account connected successfully.', {
        connected: true,
        email: tokens.email,
        simulated: tokens.simulated
      });
    } catch (err) {
      console.error('[Google Callback Error]:', err);
      return errorResponse(res, 400, err.message || 'Failed to connect Google account.');
    }
  }

  /**
   * 27. Get user's Google Calendar connection status
   * GET /api/meetings/google/status
   */
  static async getGoogleStatus(req, res) {
    try {
      const tokens = await MeetingModel.getUserGoogleTokens(req.user.id);
      const isConnected = Boolean(tokens && tokens.accessToken);

      return successResponse(res, 200, 'Google status retrieved.', {
        connected: isConnected,
        email: tokens?.email || '',
        simulated: Boolean(tokens?.simulated)
      });
    } catch (err) {
      console.error('[Google Status Error]:', err);
      return errorResponse(res, 500, 'Failed to fetch Google status.');
    }
  }

  /**
   * 28. Disconnect user's Google Calendar account
   * POST /api/meetings/google/disconnect
   */
  static async disconnectGoogle(req, res) {
    try {
      await MeetingModel.updateUserGoogleTokens(req.user.id, null);

      return successResponse(res, 200, 'Google account disconnected successfully.', {
        connected: false
      });
    } catch (err) {
      console.error('[Google Disconnect Error]:', err);
      return errorResponse(res, 500, 'Failed to disconnect Google account.');
    }
  }

  /**
   * 29. Sync a meeting to Google Calendar
   * POST /api/meetings/:id/sync-google
   */
  static async syncGoogleCalendar(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const tokens = await MeetingModel.getUserGoogleTokens(req.user.id);
      if (!tokens || !tokens.accessToken) {
        return errorResponse(res, 400, 'Google Calendar is not connected. Please connect your Google account first.', {
          authRequired: true
        });
      }

      const origin = req.headers.origin || 'http://localhost:5000';
      const syncResult = await googleCalendarService.syncMeetingEvent(tokens, meeting, origin);

      // Save sync status in DB
      const updatedMeeting = await MeetingModel.updateMeetingGoogleSync(meeting.id, {
        googleSynced: true,
        googleEventId: syncResult.googleEventId,
        googleMeetLink: syncResult.googleMeetLink
      });

      return successResponse(res, 200, 'Meeting synchronized with Google Calendar.', {
        meeting: updatedMeeting,
        googleEventId: syncResult.googleEventId,
        googleMeetLink: syncResult.googleMeetLink,
        htmlLink: syncResult.htmlLink
      });
    } catch (err) {
      console.error('[Google Sync Error]:', err);
      return errorResponse(res, 500, err.message || 'Failed to sync meeting to Google Calendar.');
    }
  }

  /**
   * 30. Download .ics iCalendar file for direct 1-click import to any calendar
   * GET /api/meetings/:id/icalendar
   */
  static async downloadICalendar(req, res) {
    try {
      const { id } = req.params;
      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      const userProfile = await UserModel.findById(meeting.host_id);
      const hostName = userProfile?.full_name || 'CONNEKT Host';
      const hostEmail = req.user?.email || 'host@connekt.net.in';
      const origin = req.headers.origin || 'http://localhost:5000';
      const joinUrl = `${origin}/?join=CNK-${meeting.room_code}`;

      const ics = meetingEmailService.generateICalendar(meeting, hostName, hostEmail, joinUrl);

      res.setHeader('Content-Type', 'text/calendar; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="meeting-${meeting.room_code}.ics"`);
      return res.send(ics);
    } catch (err) {
      console.error('[iCalendar Error]:', err);
      return errorResponse(res, 500, 'Failed to generate calendar invitation file.');
    }
  }

  /**
   * 31. Send or resend email invitations for a meeting
   * POST /api/meetings/:id/send-invites
   */
  static async sendMeetingInvitations(req, res) {
    try {
      const { id } = req.params;
      const { recipients } = req.body;

      const meeting = await MeetingModel.findById(id);
      if (!meeting) {
        return errorResponse(res, 404, 'Meeting not found.');
      }

      let emailList = [];
      if (Array.isArray(recipients) && recipients.length > 0) {
        emailList = recipients.filter(e => typeof e === 'string' && e.includes('@'));
      } else {
        const parts = await MeetingModel.getParticipants(meeting.id);
        emailList = parts.map(p => p.email).filter(e => e && e.includes('@'));
      }

      if (emailList.length === 0) {
        return errorResponse(res, 400, 'No valid participant email addresses found for this meeting.');
      }

      const userProfile = await UserModel.findById(req.user.id);
      const hostUser = {
        id: req.user.id,
        email: req.user.email,
        username: req.user.username,
        personalProfile: {
          fullName: userProfile?.full_name || req.user.username
        }
      };

      const origin = req.headers.origin || 'http://localhost:5000';
      const result = await meetingEmailService.sendMeetingInvitation({
        meeting,
        hostUser,
        recipients: emailList,
        baseUrl: origin
      });

      return successResponse(res, 200, `Invitations sent to ${result.count} participant(s).`, result);
    } catch (err) {
      console.error('[Send Invites Error]:', err);
      return errorResponse(res, 500, 'Failed to send meeting invitations.');
    }
  }
}

module.exports = MeetingController;
