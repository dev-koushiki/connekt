const db = require('../config/database');
const crypto = require('crypto');

class MeetingModel {
  /**
   * Generate readable, unique room code in format abc-defg-hij
   */
  static generateRoomCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randPart = (len) => {
      let res = '';
      const bytes = crypto.randomBytes(len);
      for (let i = 0; i < len; i++) {
        res += chars[bytes[i] % chars.length];
      }
      return res;
    };
    return `${randPart(3)}-${randPart(4)}-${randPart(3)}`;
  }

  /**
   * Create an instant meeting room
   */
  static async createInstantMeeting(hostUser, title = 'Instant Meeting') {
    let roomCode = this.generateRoomCode();
    // Verify room code uniqueness
    let exists = await this.findByRoomCode(roomCode);
    while (exists) {
      roomCode = this.generateRoomCode();
      exists = await this.findByRoomCode(roomCode);
    }

    const meetingLink = `/meet/${roomCode}`;
    const now = new Date();
    const hostId = hostUser?.id || hostUser;

    const result = await db.query(
      `INSERT INTO meetings (
        room_code, title, description, agenda, host_id,
        scheduled_at, start_time, duration_minutes, status, is_locked, meeting_link
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *`,
      [
        roomCode,
        title,
        'Quick instant meeting room',
        'Real-time audio & video conferencing',
        hostId,
        now,
        now,
        60,
        'live',
        false,
        meetingLink
      ]
    );

    const meeting = result.rows[0];

    // Add host to meeting_participants
    await db.query(
      `INSERT INTO meeting_participants (
        meeting_id, user_id, email, name, role, invitation_status, joined_at
      ) VALUES ($1, $2, $3, $4, 'host', 'accepted', NOW())`,
      [meeting.id, hostUser.id, hostUser.email, hostUser.personalProfile?.fullName || hostUser.username]
    );

    return meeting;
  }

  /**
   * Schedule a future meeting
   */
  static async scheduleMeeting({
    hostUser,
    title,
    description = '',
    agenda = '',
    scheduledAt,
    durationMinutes = 30,
    passcode = null,
    attendees = []
  }) {
    let roomCode = this.generateRoomCode();
    let exists = await this.findByRoomCode(roomCode);
    while (exists) {
      roomCode = this.generateRoomCode();
      exists = await this.findByRoomCode(roomCode);
    }

    const meetingLink = `/meet/${roomCode}`;

    const client = await db.getClient ? await db.getClient() : null;
    const runner = client || db;

    try {
      if (client) await client.query('BEGIN');

      const meetingRes = await runner.query(
        `INSERT INTO meetings (
          room_code, title, description, agenda, host_id,
          scheduled_at, start_time, duration_minutes, status, is_locked, passcode, meeting_link
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'scheduled', false, $9, $10)
        RETURNING *`,
        [
          roomCode,
          title,
          description,
          agenda,
          hostUser.id,
          scheduledAt,
          scheduledAt,
          parseInt(durationMinutes, 10) || 30,
          passcode,
          meetingLink
        ]
      );

      const meeting = meetingRes.rows[0];

      // Add host as participant
      await runner.query(
        `INSERT INTO meeting_participants (
          meeting_id, user_id, email, name, role, invitation_status
        ) VALUES ($1, $2, $3, $4, 'host', 'accepted')`,
        [meeting.id, hostUser.id, hostUser.email, hostUser.personalProfile?.fullName || hostUser.username]
      );

      // Add attendees
      for (const att of attendees) {
        const emailOrIdentifier = typeof att === 'string' ? att.trim() : (att.email || att.username || '').trim();
        if (!emailOrIdentifier) continue;

        // Lookup registered user by email or username if available
        const userRes = await runner.query(
          `SELECT u.id, u.email, u.username, COALESCE(p.full_name, u.username) AS name
           FROM users u
           LEFT JOIN user_profiles p ON u.id = p.user_id
           WHERE LOWER(u.email) = $1 OR LOWER(u.username) = $1 LIMIT 1`,
          [emailOrIdentifier.toLowerCase()]
        );

        const targetUser = userRes.rows[0];
        const attUserId = targetUser ? targetUser.id : null;
        const attEmail = targetUser ? targetUser.email : emailOrIdentifier;
        const attName = targetUser ? targetUser.name : emailOrIdentifier.split('@')[0];

        await runner.query(
          `INSERT INTO meeting_participants (
            meeting_id, user_id, email, name, role, invitation_status
          ) VALUES ($1, $2, $3, $4, 'participant', 'pending')`,
          [meeting.id, attUserId, attEmail, attName]
        );

        // If target user exists in CONNEKT, send notification
        if (targetUser) {
          await runner.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'meeting_invite', $2, $3, $4)`,
            [
              targetUser.id,
              `Meeting Invitation: ${title}`,
              `You have been invited to "${title}" scheduled for ${new Date(scheduledAt).toLocaleString()}. Room Code: ${roomCode}`,
              JSON.stringify({ meetingId: meeting.id, roomCode })
            ]
          );
        }
      }

      if (client) await client.query('COMMIT');
      return meeting;
    } catch (err) {
      if (client) await client.query('ROLLBACK');
      throw err;
    } finally {
      if (client) client.release();
    }
  }

  /**
   * Find meeting by Room Code or UUID
   */
  static async findByRoomCode(code) {
    if (!code) return null;
    const clean = code.trim().toLowerCase();
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(code);

    const query = isUuid
      ? `SELECT m.*, u.username AS host_username, COALESCE(p.full_name, u.username) AS host_name, p.avatar_url AS host_avatar
         FROM meetings m
         JOIN users u ON m.host_id = u.id
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE m.id = $1 OR LOWER(m.room_code) = $2`
      : `SELECT m.*, u.username AS host_username, COALESCE(p.full_name, u.username) AS host_name, p.avatar_url AS host_avatar
         FROM meetings m
         JOIN users u ON m.host_id = u.id
         LEFT JOIN user_profiles p ON u.id = p.user_id
         WHERE LOWER(m.room_code) = $1`;

    const params = isUuid ? [code, clean] : [clean];
    const res = await db.query(query, params);
    return res.rows[0] || null;
  }

  /**
   * List meetings for a user with filters
   */
  static async listMeetings(userId, userEmail, { filter = 'all', search = '', limit = 50 }) {
    let whereClauses = [];
    let params = [userId, userEmail.toLowerCase()];
    let paramIndex = 3;

    // Base condition: User is host OR participant
    whereClauses.push(`(
      m.host_id = $1 OR 
      EXISTS (
        SELECT 1 FROM meeting_participants mp 
        WHERE mp.meeting_id = m.id AND (mp.user_id = $1 OR LOWER(mp.email) = $2)
      )
    )`);

    // Status / Time Filters
    if (filter === 'today') {
      whereClauses.push(`DATE(m.scheduled_at) = CURRENT_DATE`);
    } else if (filter === 'upcoming') {
      whereClauses.push(`(m.scheduled_at >= NOW() OR m.status = 'live') AND m.status != 'cancelled' AND m.status != 'ended'`);
    } else if (filter === 'past') {
      whereClauses.push(`(m.scheduled_at < NOW() OR m.status = 'ended')`);
    } else if (filter === 'created_by_me') {
      whereClauses.push(`m.host_id = $1`);
    } else if (filter === 'invited_to') {
      whereClauses.push(`m.host_id != $1`);
    }

    // Search query filter
    if (search && search.trim()) {
      params.push(`%${search.trim().toLowerCase()}%`);
      whereClauses.push(`(
        LOWER(m.title) LIKE $${paramIndex} OR 
        LOWER(m.description) LIKE $${paramIndex} OR 
        LOWER(m.agenda) LIKE $${paramIndex} OR 
        LOWER(m.room_code) LIKE $${paramIndex}
      )`);
      paramIndex++;
    }

    params.push(limit);

    const query = `
      SELECT m.*,
             u.username AS host_username,
             COALESCE(p.full_name, u.username) AS host_name,
             COALESCE(p.avatar_url, '') AS host_avatar,
             (SELECT COUNT(*) FROM meeting_participants mp WHERE mp.meeting_id = m.id) AS participant_count,
             CASE WHEN m.host_id = $1 THEN 'host' ELSE 'participant' END AS user_role
      FROM meetings m
      JOIN users u ON m.host_id = u.id
      LEFT JOIN user_profiles p ON u.id = p.user_id
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY 
        CASE WHEN m.status = 'live' THEN 0 ELSE 1 END,
        m.scheduled_at DESC
      LIMIT $${paramIndex}`;

    const res = await db.query(query, params);
    return res.rows;
  }

  /**
   * Register participant join & attendance
   */
  static async recordParticipantJoin(meetingId, user, role = 'participant') {
    const userId = user?.id || user;
    const userEmail = user?.email || '';
    const name = user?.personalProfile?.fullName || user?.username || user?.name || 'Participant';

    // 1. Check or insert in meeting_participants
    const existing = await db.query(
      `SELECT * FROM meeting_participants WHERE meeting_id = $1 AND (user_id = $2 OR (email != '' AND LOWER(email) = $3))`,
      [meetingId, userId, userEmail.toLowerCase()]
    );

    if (existing.rowCount === 0) {
      await db.query(
        `INSERT INTO meeting_participants (meeting_id, user_id, email, name, role, invitation_status, joined_at)
         VALUES ($1, $2, $3, $4, $5, 'accepted', NOW())`,
        [meetingId, userId, userEmail, name, role]
      );
    } else {
      await db.query(
        `UPDATE meeting_participants 
         SET joined_at = NOW(), invitation_status = 'accepted'
         WHERE id = $1`,
        [existing.rows[0].id]
      );
    }

    // 2. Open an attendance session
    const attendanceRes = await db.query(
      `INSERT INTO meeting_attendance (meeting_id, user_id, name, email, joined_at)
       VALUES ($1, $2, $3, $4, NOW())
       RETURNING *`,
      [meetingId, userId, name, userEmail]
    );

    // Update meeting status to 'live' if not already
    await db.query(
      `UPDATE meetings SET status = 'live', start_time = COALESCE(start_time, NOW()), updated_at = NOW() 
       WHERE id = $1 AND status = 'scheduled'`,
      [meetingId]
    );

    return attendanceRes.rows[0];
  }

  /**
   * Record participant leave & calculate duration
   */
  static async recordParticipantLeave(meetingId, userId) {
    // Find latest open attendance session for this participant
    const openSession = await db.query(
      `SELECT * FROM meeting_attendance 
       WHERE meeting_id = $1 AND user_id = $2 AND left_at IS NULL 
       ORDER BY joined_at DESC LIMIT 1`,
      [meetingId, userId]
    );

    if (openSession.rowCount > 0) {
      const session = openSession.rows[0];
      const joinedAt = new Date(session.joined_at);
      const now = new Date();
      const durationSeconds = Math.max(0, Math.floor((now.getTime() - joinedAt.getTime()) / 1000));

      await db.query(
        `UPDATE meeting_attendance 
         SET left_at = NOW(), duration_seconds = $1 
         WHERE id = $2`,
        [durationSeconds, session.id]
      );

      await db.query(
        `UPDATE meeting_participants 
         SET left_at = NOW() 
         WHERE meeting_id = $1 AND user_id = $2`,
        [meetingId, userId]
      );

      return { duration_seconds: durationSeconds, durationSeconds };
    }

    return null;

    return { durationSeconds: 0 };
  }

  /**
   * End meeting (Host only)
   */
  static async endMeeting(meetingId, hostId) {
    const meeting = await db.query(`SELECT * FROM meetings WHERE id = $1`, [meetingId]);
    if (meeting.rowCount === 0) throw new Error('Meeting not found');

    if (meeting.rows[0].host_id !== hostId) {
      throw new Error('Only the meeting host can end the meeting for everyone.');
    }

    // Close all open attendance records
    await db.query(
      `UPDATE meeting_attendance 
       SET left_at = NOW(),
           duration_seconds = GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (NOW() - joined_at))))
       WHERE meeting_id = $1 AND left_at IS NULL`,
      [meetingId]
    );

    // Mark meeting as ended
    const result = await db.query(
      `UPDATE meetings 
       SET status = 'ended', end_time = NOW(), updated_at = NOW() 
       WHERE id = $1 
       RETURNING *`,
      [meetingId]
    );

    return result.rows[0];
  }

  /**
   * Lock / Unlock meeting room (Host only)
   */
  static async setMeetingLock(meetingId, hostId, isLocked) {
    const meeting = await db.query(`SELECT * FROM meetings WHERE id = $1`, [meetingId]);
    if (meeting.rowCount === 0) throw new Error('Meeting not found');

    if (meeting.rows[0].host_id !== hostId) {
      throw new Error('Only the meeting host can lock or unlock the meeting.');
    }

    const result = await db.query(
      `UPDATE meetings SET is_locked = $1, updated_at = NOW() WHERE id = $2 RETURNING *`,
      [isLocked, meetingId]
    );

    return result.rows[0];
  }

  /**
   * Find meeting by database UUID
   */
  static async findById(id) {
    if (!id) return null;
    const res = await db.query(
      `SELECT m.*, u.username AS host_username, COALESCE(p.full_name, u.username) AS host_name, p.avatar_url AS host_avatar
       FROM meetings m
       JOIN users u ON m.host_id = u.id
       LEFT JOIN user_profiles p ON u.id = p.user_id
       WHERE m.id = $1`,
      [id]
    );
    return res.rows[0] || null;
  }

  /**
   * Update meeting details (Host only)
   */
  static async updateMeeting(id, hostId, updates = {}) {
    const meeting = await this.findById(id);
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.host_id !== hostId) throw new Error('Only the host can modify this meeting');

    const allowed = ['title', 'description', 'agenda', 'scheduled_at', 'duration_minutes', 'passcode'];
    const setClauses = [];
    const values = [];
    let pIdx = 1;

    for (const key of allowed) {
      if (updates[key] !== undefined) {
        setClauses.push(`${key} = $${pIdx}`);
        values.push(updates[key]);
        pIdx++;
      }
    }

    if (setClauses.length === 0) return meeting;

    setClauses.push(`updated_at = NOW()`);
    values.push(id);

    const query = `UPDATE meetings SET ${setClauses.join(', ')} WHERE id = $${pIdx} RETURNING *`;
    const res = await db.query(query, values);
    return res.rows[0];
  }

  /**
   * Cancel or delete meeting (Host only)
   */
  static async deleteMeeting(id, hostId) {
    const meeting = await this.findById(id);
    if (!meeting) throw new Error('Meeting not found');
    if (meeting.host_id !== hostId) throw new Error('Only the host can cancel this meeting');

    const res = await db.query(
      `UPDATE meetings SET status = 'cancelled', updated_at = NOW() WHERE id = $1 RETURNING *`,
      [id]
    );
    return res.rows[0];
  }

  /**
   * Get meeting participants list
   */
  static async getParticipants(meetingId) {
    const res = await db.query(
      `SELECT mp.*, COALESCE(p.avatar_url, '') AS avatar_url
       FROM meeting_participants mp
       LEFT JOIN user_profiles p ON mp.user_id = p.user_id
       WHERE mp.meeting_id = $1
       ORDER BY 
         CASE WHEN mp.role = 'host' THEN 0 WHEN mp.role = 'co-host' THEN 1 ELSE 2 END,
         mp.joined_at ASC NULLS LAST`,
      [meetingId]
    );
    return res.rows;
  }

  // ====================================================================
  // SIGNALING & REAL-TIME COLLABORATION METHODS (PHASE 2)
  // ====================================================================

  /**
   * Save signaling message (SDP offer/answer or ICE candidate) for persistent/fallback relay
   */
  static async saveSignal({ roomCode, meetingId = null, senderId, recipientId, signalType, payload }) {
    let mId = meetingId;
    if (!mId) {
      const m = await this.findByRoomCode(roomCode);
      mId = m?.id;
    }
    if (!mId) return null;

    const expiresAt = new Date(Date.now() + 60 * 1000); // 60s TTL
    const res = await db.query(
      `INSERT INTO meeting_signals (
        room_code, meeting_id, sender_id, recipient_id, signal_type, payload, expires_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        roomCode.toLowerCase(),
        mId,
        String(senderId),
        String(recipientId),
        signalType,
        JSON.stringify(payload),
        expiresAt
      ]
    );
    return res.rows[0];
  }

  /**
   * Retrieve pending signals for recipient and mark them processed
   */
  static async getPendingSignals(roomCode, recipientId) {
    const res = await db.query(
      `SELECT * FROM meeting_signals
       WHERE room_code = $1 
         AND recipient_id = $2 
         AND processed_at IS NULL 
         AND expires_at > NOW()
       ORDER BY created_at ASC`,
      [roomCode.toLowerCase(), String(recipientId)]
    );

    if (res.rows.length > 0) {
      const ids = res.rows.map(r => r.id);
      await db.query(
        `UPDATE meeting_signals SET processed_at = NOW() WHERE id = ANY($1::uuid[])`,
        [ids]
      );
    }

    return res.rows;
  }

  /**
   * Save an in-meeting chat message
   */
  static async saveChatMessage({ meetingId = null, roomCode, senderId, senderName, message }) {
    let mId = meetingId;
    if (!mId) {
      const m = await this.findByRoomCode(roomCode);
      mId = m?.id;
    }
    if (!mId) return null;

    const res = await db.query(
      `INSERT INTO meeting_messages (
        meeting_id, room_code, sender_id, sender_name, message, created_at
      ) VALUES ($1, $2, $3, $4, $5, NOW())
      RETURNING *`,
      [mId, roomCode.toLowerCase(), String(senderId), senderName, message]
    );
    return res.rows[0];
  }

  /**
   * Retrieve meeting chat history
   */
  static async getChatMessages(roomCode, limit = 100) {
    const res = await db.query(
      `SELECT * FROM meeting_messages
       WHERE room_code = $1
       ORDER BY created_at ASC
       LIMIT $2`,
      [roomCode.toLowerCase(), limit]
    );
    return res.rows;
  }

  // ====================================================================
  // MEETING RECORDS, MINUTES & ACTION ITEMS (PHASE 4)
  // ====================================================================

  /**
   * Get complete attendance records with duration calculations
   */
  static async getMeetingAttendance(meetingId) {
    const res = await db.query(
      `SELECT a.*, COALESCE(p.avatar_url, '') AS avatar_url
       FROM meeting_attendance a
       LEFT JOIN user_profiles p ON a.user_id = p.user_id
       WHERE a.meeting_id = $1
       ORDER BY a.joined_at ASC`,
      [meetingId]
    );
    return res.rows;
  }

  /**
   * Get meeting minutes and attached action items
   */
  static async getMeetingMinutes(meetingId) {
    const minutesRes = await db.query(
      `SELECT * FROM meeting_minutes WHERE meeting_id = $1 ORDER BY updated_at DESC LIMIT 1`,
      [meetingId]
    );

    const actionItemsRes = await db.query(
      `SELECT ai.*, COALESCE(p.avatar_url, '') AS assigned_avatar, COALESCE(u.username, '') AS user_username
       FROM meeting_action_items ai
       LEFT JOIN users u ON ai.assigned_to = u.id
       LEFT JOIN user_profiles p ON u.id = p.user_id
       WHERE ai.meeting_id = $1
       ORDER BY 
         CASE WHEN ai.status = 'completed' THEN 1 ELSE 0 END,
         ai.created_at ASC`,
      [meetingId]
    );

    const minutesRow = minutesRes.rows[0] || null;
    if (minutesRow) {
      minutesRow.discussion_points_text = Array.isArray(minutesRow.discussion_points)
        ? minutesRow.discussion_points.join('\n')
        : (minutesRow.discussion_points || '');
      minutesRow.decisions_text = Array.isArray(minutesRow.decisions)
        ? minutesRow.decisions.join('\n')
        : (minutesRow.decisions || '');
    }

    return {
      minutes: minutesRow,
      actionItems: actionItemsRes.rows
    };
  }

  /**
   * Create or update meeting minutes (Upsert)
   */
  static async saveMeetingMinutes(meetingId, userId, userName, { summary, discussionPoints, decisions }) {
    const normalizeArray = (val) => {
      if (!val) return [];
      if (Array.isArray(val)) return val.map(s => String(s).trim()).filter(Boolean);
      if (typeof val === 'string') {
        return val.split('\n').map(s => s.trim()).filter(Boolean);
      }
      return [String(val)];
    };

    const discArr = normalizeArray(discussionPoints);
    const decArr = normalizeArray(decisions);

    const existing = await db.query(`SELECT id FROM meeting_minutes WHERE meeting_id = $1`, [meetingId]);

    if (existing.rowCount > 0) {
      const res = await db.query(
        `UPDATE meeting_minutes 
         SET summary = $1, discussion_points = $2, decisions = $3, updated_at = NOW()
         WHERE id = $4
         RETURNING *`,
        [summary || '', discArr, decArr, existing.rows[0].id]
      );
      const row = res.rows[0];
      if (row) {
        row.discussion_points_text = Array.isArray(row.discussion_points) ? row.discussion_points.join('\n') : '';
        row.decisions_text = Array.isArray(row.decisions) ? row.decisions.join('\n') : '';
      }
      return row;
    } else {
      const res = await db.query(
        `INSERT INTO meeting_minutes (
          meeting_id, summary, discussion_points, decisions, created_by, created_by_name, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
        RETURNING *`,
        [meetingId, summary || '', discArr, decArr, userId, userName]
      );
      const row = res.rows[0];
      if (row) {
        row.discussion_points_text = Array.isArray(row.discussion_points) ? row.discussion_points.join('\n') : '';
        row.decisions_text = Array.isArray(row.decisions) ? row.decisions.join('\n') : '';
      }
      return row;
    }
  }

  /**
   * Add a new action item to a meeting
   */
  static async addActionItem(meetingId, { title, description = '', assignedTo = null, assignedName = '', priority = 'medium', dueDate = null, status = 'pending' }) {
    let assignedUserId = null;
    let resolvedName = assignedName ? assignedName.trim() : '';

    if (assignedTo && typeof assignedTo === 'string') {
      const cleanAssigned = assignedTo.trim();
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(cleanAssigned);
      if (isUuid) {
        assignedUserId = cleanAssigned;
      } else {
        // Search by email or username
        const u = await db.query(
          `SELECT id, username, email FROM users WHERE LOWER(email) = LOWER($1) OR LOWER(username) = LOWER($1) LIMIT 1`,
          [cleanAssigned]
        );
        if (u.rowCount > 0) {
          assignedUserId = u.rows[0].id;
          if (!resolvedName) resolvedName = u.rows[0].username;
        } else {
          if (!resolvedName) resolvedName = cleanAssigned;
        }
      }
    }

    const res = await db.query(
      `INSERT INTO meeting_action_items (
        meeting_id, title, description, assigned_to, assigned_name, priority, due_date, status, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      RETURNING *`,
      [meetingId, title.trim(), (description || '').trim(), assignedUserId, resolvedName, priority, dueDate, status]
    );
    return res.rows[0];
  }

  /**
   * Update an action item (e.g. status, assignee, title, priority)
   */
  static async updateActionItem(itemId, updates = {}) {
    const allowed = ['title', 'description', 'assigned_to', 'assigned_name', 'priority', 'due_date', 'status'];
    const setClauses = [];
    const values = [];
    let pIdx = 1;

    for (const key of allowed) {
      if (updates[key] !== undefined) {
        setClauses.push(`${key} = $${pIdx}`);
        values.push(updates[key]);
        pIdx++;
      }
    }

    if (setClauses.length === 0) {
      const res = await db.query(`SELECT * FROM meeting_action_items WHERE id = $1`, [itemId]);
      return res.rows[0];
    }

    values.push(itemId);
    const query = `UPDATE meeting_action_items SET ${setClauses.join(', ')} WHERE id = $${pIdx} RETURNING *`;
    const res = await db.query(query, values);
    return res.rows[0];
  }

  /**
   * Delete an action item
   */
  static async deleteActionItem(itemId) {
    const res = await db.query(
      `DELETE FROM meeting_action_items WHERE id = $1 RETURNING *`,
      [itemId]
    );
    return res.rows[0];
  }

  /**
   * Log a completed browser meeting recording metadata
   */
  static async logMeetingRecording(meetingId, userId, { fileName, durationSeconds, fileSizeBytes, storageLocation = 'local_browser' }) {
    const res = await db.query(
      `INSERT INTO meeting_recordings (
        meeting_id, user_id, file_name, duration_seconds, file_size_bytes, storage_location, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
      RETURNING *`,
      [meetingId, userId, fileName, durationSeconds || 0, fileSizeBytes || 0, storageLocation]
    );
    return res.rows[0];
  }

  /**
   * Get recordings metadata for a meeting
   */
  static async getMeetingRecordings(meetingId) {
    const res = await db.query(
      `SELECT r.*, u.username, COALESCE(p.full_name, u.username) AS recorder_name
       FROM meeting_recordings r
       JOIN users u ON r.user_id = u.id
       LEFT JOIN user_profiles p ON u.id = p.user_id
       WHERE r.meeting_id = $1
       ORDER BY r.created_at DESC`,
      [meetingId]
    );
    return res.rows;
  }

  // ====================================================================
  // PHASE 5: TASKS CONVERSION & GOOGLE CALENDAR SYNC
  // ====================================================================

  /**
   * Convert an action item into a Task in tasks table
   */
  static async convertActionItemToTask(meetingId, actionItemId, createdByUserId) {
    const itemRes = await db.query(
      `SELECT ai.*, m.title AS meeting_title 
       FROM meeting_action_items ai
       JOIN meetings m ON ai.meeting_id = m.id
       WHERE ai.id = $1 AND ai.meeting_id = $2`,
      [actionItemId, meetingId]
    );

    if (itemRes.rowCount === 0) {
      throw new Error('Action item not found in this meeting.');
    }

    const item = itemRes.rows[0];
    if (item.status === 'converted' && item.linked_task_id) {
      throw new Error('Action item is already converted to a task.');
    }

    // Insert into tasks table
    const taskRes = await db.query(
      `INSERT INTO tasks (
        title, description, assigned_to, assigned_name, created_by,
        due_date, priority, status, meeting_id, linked_action_item_id, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'not-started', $8, $9, NOW(), NOW())
      RETURNING *`,
      [
        item.title,
        item.description || `Deliverable generated from meeting: "${item.meeting_title}"`,
        item.assigned_to,
        item.assigned_name,
        createdByUserId,
        item.due_date,
        item.priority || 'medium',
        meetingId,
        item.id
      ]
    );

    const createdTask = taskRes.rows[0];

    // Update meeting_action_items
    const updatedActionRes = await db.query(
      `UPDATE meeting_action_items 
       SET status = 'converted', linked_task_id = $1 
       WHERE id = $2 
       RETURNING *`,
      [createdTask.id, item.id]
    );

    return {
      task: createdTask,
      actionItem: updatedActionRes.rows[0]
    };
  }

  /**
   * Update meeting Google synchronization details
   */
  static async updateMeetingGoogleSync(meetingId, { googleSynced, synced, googleEventId, googleMeetLink }) {
    const isSynced = googleSynced !== undefined ? Boolean(googleSynced) : Boolean(synced);
    const res = await db.query(
      `UPDATE meetings 
       SET google_synced = $1, google_event_id = $2, google_meet_link = $3, updated_at = NOW()
       WHERE id = $4
       RETURNING *`,
      [isSynced, googleEventId || null, googleMeetLink || null, meetingId]
    );
    return res.rows[0];
  }

  /**
   * Save user's Google OAuth tokens
   */
  static async updateUserGoogleTokens(userId, googleTokens) {
    const res = await db.query(
      `UPDATE users SET google_tokens = $1 WHERE id = $2 RETURNING id, email, google_tokens`,
      [googleTokens ? JSON.stringify(googleTokens) : null, userId]
    );
    return res.rows[0];
  }

  /**
   * Retrieve user's Google OAuth tokens
   */
  static async getUserGoogleTokens(userId) {
    const res = await db.query(`SELECT google_tokens FROM users WHERE id = $1`, [userId]);
    const row = res.rows[0];
    if (!row || !row.google_tokens) return null;
    return typeof row.google_tokens === 'string' ? JSON.parse(row.google_tokens) : row.google_tokens;
  }
}

module.exports = MeetingModel;
