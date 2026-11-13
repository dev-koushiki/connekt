const db = require('../config/database');
const { sendSms, normalizePhoneNumber } = require('../services/smsService');

class ChatModel {
  /**
   * Find a user by phone, username, or UUID
   */
  static async findUserByIdentifier(identifier) {
    if (!identifier) return null;
    const clean = identifier.toString().trim();
    const cleanDigits = clean.replace(/\D/g, '');
    const normalizedPhone = normalizePhoneNumber(clean);

    const query = `
      SELECT u.id, u.phone, u.username, u.email, u.role, u.status,
             p.full_name, p.display_name, p.avatar_url
      FROM users u
      LEFT JOIN user_profiles p ON p.user_id = u.id
      WHERE u.id::text = $1
         OR LOWER(u.username) = LOWER($2)
         OR u.phone = $3
         OR u.phone = $4
         OR (LENGTH($5) >= 10 AND u.phone LIKE '%' || $5)
      LIMIT 1;
    `;
    const res = await db.query(query, [
      clean,
      clean.replace(/^@/, ''),
      clean,
      normalizedPhone,
      cleanDigits.length >= 10 ? cleanDigits.slice(-10) : cleanDigits
    ]);
    return res.rows[0] || null;
  }

  /**
   * Auto-create a lightweight contact entry for an unregistered recipient phone number
   */
  static async findOrCreateContactUser(phone) {
    const existing = await this.findUserByIdentifier(phone);
    if (existing) return existing;

    const cleanDigits = phone.toString().replace(/\D/g, '');
    const standardPhone = cleanDigits.length === 10 ? cleanDigits : (phone.startsWith('+') ? phone : `+${phone}`);
    const placeholderUsername = `user_${cleanDigits.slice(-6) || Math.floor(100000 + Math.random() * 900000)}`;
    const placeholderEmail = `${placeholderUsername}@sms.connekt.net.in`;

    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const userRes = await client.query(
        `INSERT INTO users (phone, username, email, password_hash, role, status, is_verified, current_mode)
         VALUES ($1, $2, $3, 'NOPASSWORD_SMS_CONTACT', 'contact', 'active', false, 'common')
         RETURNING id, phone, username, email, role, status, is_verified, current_mode`,
        [standardPhone, placeholderUsername, placeholderEmail]
      );
      const user = userRes.rows[0];

      const profRes = await client.query(
        `INSERT INTO user_profiles (user_id, full_name, display_name)
         VALUES ($1, $2, $2)
         RETURNING id, full_name, display_name, avatar_url`,
        [user.id, standardPhone]
      );
      await client.query('COMMIT');

      return {
        ...user,
        full_name: profRes.rows[0].full_name,
        display_name: profRes.rows[0].display_name,
        avatar_url: profRes.rows[0].avatar_url
      };
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[Create Contact User Error]:', err.message);
      // If concurrent insertion collided, retry find
      return await this.findUserByIdentifier(phone);
    } finally {
      client.release();
    }
  }

  /**
   * Find existing direct 1-to-1 conversation or create a new one
   */
  static async findOrCreateDirectConversation(user1Id, user2Id) {
    // 1. Look for existing direct conversation between both users
    const findQuery = `
      SELECT c.id, c.type, c.title, c.last_message_text, c.last_message_at, c.created_at
      FROM conversations c
      JOIN conversation_participants cp1 ON cp1.conversation_id = c.id AND cp1.user_id = $1
      JOIN conversation_participants cp2 ON cp2.conversation_id = c.id AND cp2.user_id = $2
      WHERE c.type = 'direct'
      LIMIT 1;
    `;
    const findRes = await db.query(findQuery, [user1Id, user2Id]);
    if (findRes.rows.length > 0) {
      return findRes.rows[0];
    }

    // 2. Create new direct conversation
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const convRes = await client.query(
        `INSERT INTO conversations (type, title, created_at)
         VALUES ('direct', null, NOW())
         RETURNING id, type, title, last_message_text, last_message_at, created_at`
      );
      const conversation = convRes.rows[0];

      // Add participants
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, unread_count, created_at)
         VALUES ($1, $2, 0, NOW()), ($1, $3, 0, NOW())`,
        [conversation.id, user1Id, user2Id]
      );

      await client.query('COMMIT');
      return conversation;
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Create a new group conversation with title, description, and invite pending members
   */
  static async createGroupConversation({ creatorId, title, description = '', memberIdentifiers = [] }) {
    const cleanTitle = (title || '').toString().trim() || 'New Group';
    const cleanDesc = (description || '').toString().trim();
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const convRes = await client.query(
        `INSERT INTO conversations (type, title, description, creator_id, last_message_text, last_message_at, created_at)
         VALUES ('group', $1, $2, $3, 'Group created', NOW(), NOW())
         RETURNING id, type, title, description, creator_id, last_message_text, last_message_at, created_at`,
        [cleanTitle, cleanDesc, creatorId]
      );
      const conversation = convRes.rows[0];

      // Add creator as accepted admin
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, status, role, unread_count, created_at)
         VALUES ($1, $2, 'accepted', 'admin', 0, NOW())`,
        [conversation.id, creatorId]
      );

      const creator = await this.findUserByIdentifier(creatorId);
      const creatorName = creator?.display_name || creator?.full_name || creator?.username || 'Admin';

      const addedUserIds = new Set([creatorId]);
      const membersInfo = [];

      // Resolve and add each member as 'pending'
      for (const identifier of memberIdentifiers) {
        if (!identifier) continue;
        let user = await this.findUserByIdentifier(identifier);
        if (!user) {
          user = await this.findOrCreateContactUser(identifier);
        }
        if (user && !addedUserIds.has(user.id)) {
          addedUserIds.add(user.id);
          const name = user.display_name || user.full_name || user.username || identifier;
          membersInfo.push({
            id: user.id,
            name,
            phone: user.phone,
            status: 'pending',
            role: 'member'
          });

          await client.query(
            `INSERT INTO conversation_participants (conversation_id, user_id, status, role, unread_count, created_at)
             VALUES ($1, $2, 'pending', 'member', 0, NOW())`,
            [conversation.id, user.id]
          );

          // Dispatch invitation message ("allowed msg") via SMS if member has phone
          const phone = user.phone || (identifier.replace(/\D/g, '').length >= 10 ? identifier : null);
          if (phone) {
            try {
              const formattedPhone = normalizePhoneNumber(phone);
              const inviteMsg = `[CONNEKT Group Invitation]: ${creatorName} invited you to join "${cleanTitle}"${cleanDesc ? `: "${cleanDesc}"` : ''}. Open CONNEKT to accept the invitation and start chatting! https://connekt.net.in`;
              await sendSms({
                to: formattedPhone,
                message: inviteMsg,
                purpose: 'group_invite'
              });
            } catch (smsErr) {
              console.warn(`[Group Invite SMS Warning]: ${smsErr.message}`);
            }
          }
        }
      }

      // Initial system announcement
      const inviteSummary = membersInfo.length > 0
        ? `Invitations sent to ${membersInfo.map(m => m.name).join(', ')}. Members can join once they accept.`
        : 'Group ready.';
      await client.query(
        `INSERT INTO messages (conversation_id, sender_id, content, is_read, created_at)
         VALUES ($1, $2, $3, true, NOW())`,
        [conversation.id, creatorId, `Group "${cleanTitle}" created by ${creatorName}.${cleanDesc ? ` Description: ${cleanDesc}.` : ''} ${inviteSummary}`]
      );

      await client.query('COMMIT');
      return {
        id: conversation.id,
        type: 'group',
        title: cleanTitle,
        description: cleanDesc,
        name: cleanTitle,
        target: conversation.id,
        lastMessage: `Group "${cleanTitle}" created`,
        time: 'Just now',
        unread: 0,
        isOnline: true,
        isGroup: true,
        memberCount: addedUserIds.size,
        members: membersInfo
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Respond to group invitation (accept or decline)
   */
  static async respondToGroupInvitation({ conversationId, userId, accept }) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const user = await this.findUserByIdentifier(userId);
      const userName = user?.display_name || user?.full_name || user?.username || 'Member';

      if (accept) {
        const updateRes = await client.query(
          `UPDATE conversation_participants
           SET status = 'accepted'
           WHERE conversation_id = $1 AND user_id = $2
           RETURNING id, conversation_id, user_id, status`,
          [conversationId, userId]
        );

        if (updateRes.rows.length === 0) {
          await client.query(
            `INSERT INTO conversation_participants (conversation_id, user_id, status, role, unread_count, created_at)
             VALUES ($1, $2, 'accepted', 'member', 0, NOW())`,
            [conversationId, userId]
          );
        }

        // Post announcement into group
        await client.query(
          `INSERT INTO messages (conversation_id, sender_id, content, is_read, created_at)
           VALUES ($1, $2, $3, true, NOW())`,
          [conversationId, userId, `${userName} accepted the invitation and joined the group.`]
        );

        await client.query(
          `UPDATE conversations SET last_message_text = $1, last_message_at = NOW() WHERE id = $2`,
          [`${userName} joined the group`, conversationId]
        );

        await client.query('COMMIT');
        return { success: true, status: 'accepted', message: 'You have joined the group' };
      } else {
        await client.query(
          `DELETE FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2`,
          [conversationId, userId]
        );
        await client.query('COMMIT');
        return { success: true, status: 'declined', message: 'Invitation declined' };
      }
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * List all conversations for a user with participant profiles & unread counters
   */
  static async getConversationsForUser(userId) {
    const query = `
      SELECT
        c.id,
        c.type,
        c.title,
        c.description,
        c.last_message_text,
        c.last_message_at,
        c.created_at,
        cp_self.unread_count,
        cp_self.status AS participant_status,
        cp_self.role AS participant_role,
        -- Peer identity info for direct chats
        u_peer.id AS peer_id,
        u_peer.phone AS peer_phone,
        u_peer.username AS peer_username,
        COALESCE(p_peer.display_name, p_peer.full_name, u_peer.phone, u_peer.username, 'Chat') AS peer_name,
        p_peer.avatar_url AS peer_avatar
      FROM conversations c
      JOIN conversation_participants cp_self ON cp_self.conversation_id = c.id AND cp_self.user_id = $1
      LEFT JOIN LATERAL (
        SELECT cp.user_id
        FROM conversation_participants cp
        WHERE cp.conversation_id = c.id AND cp.user_id != $1
        LIMIT 1
      ) single_peer ON c.type = 'direct'
      LEFT JOIN users u_peer ON u_peer.id = single_peer.user_id
      LEFT JOIN user_profiles p_peer ON p_peer.user_id = u_peer.id
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC;
    `;
    const res = await db.query(query, [userId]);

    return res.rows.map(row => {
      let formattedTime = 'Just now';
      const timestamp = row.last_message_at || row.created_at;
      if (timestamp) {
        const d = new Date(timestamp);
        const now = new Date();
        if (d.toDateString() === now.toDateString()) {
          formattedTime = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        } else {
          formattedTime = d.toLocaleDateString([], { month: 'short', day: 'numeric' });
        }
      }

      const rawLastMsg = (row.last_message_text || '').trim();
      const sanitizedLastMsg =
        rawLastMsg === 'This message was deleted' ||
        rawLastMsg === 'You deleted this message' ||
        rawLastMsg === 'Conversation started'
          ? ''
          : rawLastMsg;

      const isGroup = row.type === 'group';
      const displayName = isGroup ? (row.title || 'Group') : row.peer_name;

      return {
        id: row.id,
        name: displayName,
        target: isGroup ? row.id : (row.peer_phone || row.peer_username || displayName),
        phone: isGroup ? null : row.peer_phone,
        username: isGroup ? null : row.peer_username,
        avatar: isGroup ? '' : (row.peer_avatar || ''),
        lastMessage: sanitizedLastMsg,
        time: formattedTime,
        unread: row.unread_count || 0,
        isOnline: true,
        type: row.type || 'direct',
        isGroup: isGroup,
        description: row.description || '',
        participantStatus: row.participant_status || 'accepted',
        participantRole: row.participant_role || 'member',
        isPendingInvite: isGroup && row.participant_status === 'pending'
      };
    });
  }

  /**
   * Get all messages for a specific conversation
   */
  static async getMessages(conversationId, currentUserId) {
    // 1. Fetch conversation metadata
    const convMetaRes = await db.query(
      `SELECT c.id, c.title, c.description, c.type, c.creator_id,
              cp_self.status AS participant_status, cp_self.role AS participant_role
       FROM conversations c
       LEFT JOIN conversation_participants cp_self ON cp_self.conversation_id = c.id AND cp_self.user_id = $2
       WHERE c.id = $1
       LIMIT 1;`,
      [conversationId, currentUserId]
    );
    const meta = convMetaRes.rows[0] || null;

    // 2. Fetch participants with their invitation statuses
    const partRes = await db.query(
      `SELECT u.id, u.username, u.phone,
              COALESCE(p.display_name, p.full_name, u.phone, u.username) AS name,
              p.avatar_url,
              cp.status, cp.role
       FROM conversation_participants cp
       JOIN users u ON u.id = cp.user_id
       LEFT JOIN user_profiles p ON p.user_id = u.id
       WHERE cp.conversation_id = $1
       ORDER BY (cp.role = 'admin') DESC, cp.created_at ASC;`,
      [conversationId]
    );

    // 3. Query message history
    const query = `
      SELECT
        m.id,
        m.conversation_id,
        m.sender_id,
        m.content AS text,
        m.is_read,
        m.created_at,
        u.phone AS sender_phone,
        u.username AS sender_username,
        p.full_name AS sender_name
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      LEFT JOIN user_profiles p ON p.user_id = u.id
      WHERE m.conversation_id = $1
        AND m.content NOT IN ('This message was deleted', 'You deleted this message')
      ORDER BY m.created_at ASC
      LIMIT 200;
    `;
    const res = await db.query(query, [conversationId]);

    // Mark unread incoming messages as read if active
    if (!meta || meta.participant_status === 'accepted') {
      await db.query(
        `UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id != $2 AND is_read = false`,
        [conversationId, currentUserId]
      );
      await db.query(
        `UPDATE conversation_participants SET unread_count = 0, last_read_at = NOW() WHERE conversation_id = $1 AND user_id = $2`,
        [conversationId, currentUserId]
      );
    }

    const messages = res.rows.map(row => {
      const d = new Date(row.created_at);
      const timeStr = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

      return {
        id: row.id,
        text: row.text,
        time: timeStr,
        isMe: row.sender_id === currentUserId,
        isRead: row.is_read,
        senderName: row.sender_name || row.sender_username || row.sender_phone || 'Member',
        createdAt: row.created_at
      };
    });

    return {
      messages,
      conversation: meta,
      participants: partRes.rows
    };
  }

  /**
   * Save a new message in conversation
   */
  static async saveMessage({ conversationId, senderId, content }) {
    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      // 1. Insert message
      const msgRes = await client.query(
        `INSERT INTO messages (conversation_id, sender_id, content, is_read, created_at)
         VALUES ($1, $2, $3, false, NOW())
         RETURNING id, conversation_id, sender_id, content AS text, is_read, created_at`,
        [conversationId, senderId, content.trim()]
      );
      const msg = msgRes.rows[0];

      // 2. Update conversation last message
      await client.query(
        `UPDATE conversations
         SET last_message_text = $1, last_message_at = NOW()
         WHERE id = $2`,
        [content.trim(), conversationId]
      );

      // 3. Increment unread count for accepted participants only
      await client.query(
        `UPDATE conversation_participants
         SET unread_count = unread_count + 1
         WHERE conversation_id = $1 AND user_id != $2 AND COALESCE(status, 'accepted') = 'accepted'`,
        [conversationId, senderId]
      );

      await client.query('COMMIT');

      const d = new Date(msg.created_at);
      return {
        id: msg.id,
        text: msg.text,
        time: d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        isMe: true,
        isRead: false,
        createdAt: msg.created_at
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Delete a message completely (for_me or for_everyone) so no placeholder remains,
   * and recalculate the conversation's last message preview and unread counts.
   */
  static async deleteMessage({ messageId, userId, mode }) {
    if (!messageId) return { success: false, error: 'Message ID is required' };

    const client = await db.getClient();
    try {
      await client.query('BEGIN');

      const msgRes = await client.query(
        `SELECT id, conversation_id, sender_id
         FROM messages
         WHERE id::text = $1
         LIMIT 1`,
        [messageId.toString()]
      );

      if (msgRes.rows.length === 0) {
        await client.query('COMMIT');
        return { success: true, mode, messageId };
      }

      const targetMsg = msgRes.rows[0];
      if (mode === 'for_everyone' && targetMsg.sender_id?.toString() !== userId?.toString()) {
        await client.query('ROLLBACK');
        return { success: false, statusCode: 403, error: 'You can only delete your own messages for everyone' };
      }

      // Remove the message row completely so nothing shows (as if nothing was sent)
      await client.query(`DELETE FROM messages WHERE id = $1`, [targetMsg.id]);

      // Update conversation preview to the latest remaining non-deleted message (or clear it)
      const prevRes = await client.query(
        `SELECT content, created_at
         FROM messages
         WHERE conversation_id = $1
           AND content NOT IN ('This message was deleted', 'You deleted this message')
         ORDER BY created_at DESC
         LIMIT 1`,
        [targetMsg.conversation_id]
      );

      if (prevRes.rows.length > 0) {
        const prev = prevRes.rows[0];
        await client.query(
          `UPDATE conversations
           SET last_message_text = $1, last_message_at = $2
           WHERE id = $3`,
          [prev.content, prev.created_at, targetMsg.conversation_id]
        );
      } else {
        await client.query(
          `UPDATE conversations
           SET last_message_text = NULL, last_message_at = created_at
           WHERE id = $1`,
          [targetMsg.conversation_id]
        );
      }

      // Recompute participant unread counts after removing the message
      await client.query(
        `UPDATE conversation_participants cp
         SET unread_count = (
           SELECT COUNT(*)::int
           FROM messages m
           WHERE m.conversation_id = cp.conversation_id
             AND m.sender_id != cp.user_id
             AND m.is_read = false
             AND m.content NOT IN ('This message was deleted', 'You deleted this message')
         )
         WHERE cp.conversation_id = $1`,
        [targetMsg.conversation_id]
      );

      await client.query('COMMIT');
      return { success: true, mode, messageId, conversationId: targetMsg.conversation_id };
    } catch (err) {
      await client.query('ROLLBACK');
      console.warn('[Delete Message Warning]:', err.message);
      return { success: false, error: err.message };
    } finally {
      client.release();
    }
  }
}

module.exports = ChatModel;
