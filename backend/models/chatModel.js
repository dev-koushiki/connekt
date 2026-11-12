const db = require('../config/database');
const { normalizePhoneNumber } = require('../services/smsService');

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
    const placeholderEmail = `${placeholderUsername}@sms.connekt.me`;

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
   * Create a new group conversation with participants
   */
  static async createGroupConversation({ creatorId, title, memberIdentifiers = [] }) {
    const cleanTitle = (title || '').toString().trim() || 'New Group';
    const client = await db.getClient();
    try {
      await client.query('BEGIN');
      const convRes = await client.query(
        `INSERT INTO conversations (type, title, last_message_text, last_message_at, created_at)
         VALUES ('group', $1, 'Group created', NOW(), NOW())
         RETURNING id, type, title, last_message_text, last_message_at, created_at`,
        [cleanTitle]
      );
      const conversation = convRes.rows[0];

      // Add creator as participant
      await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, unread_count, created_at)
         VALUES ($1, $2, 0, NOW())`,
        [conversation.id, creatorId]
      );

      const addedUserIds = new Set([creatorId]);
      const memberNames = [];

      // Resolve and add each member
      for (const identifier of memberIdentifiers) {
        if (!identifier) continue;
        let user = await this.findUserByIdentifier(identifier);
        if (!user) {
          user = await this.findOrCreateContactUser(identifier);
        }
        if (user && !addedUserIds.has(user.id)) {
          addedUserIds.add(user.id);
          const name = user.display_name || user.full_name || user.username || identifier;
          memberNames.push(name);
          await client.query(
            `INSERT INTO conversation_participants (conversation_id, user_id, unread_count, created_at)
             VALUES ($1, $2, 0, NOW())`,
            [conversation.id, user.id]
          );
        }
      }

      // Initial system message
      await client.query(
        `INSERT INTO messages (conversation_id, sender_id, content, is_read, created_at)
         VALUES ($1, $2, $3, true, NOW())`,
        [conversation.id, creatorId, `Group "${cleanTitle}" created`]
      );

      await client.query('COMMIT');
      return {
        id: conversation.id,
        type: 'group',
        title: cleanTitle,
        name: cleanTitle,
        target: conversation.id,
        lastMessage: `Group "${cleanTitle}" created`,
        time: 'Just now',
        unread: 0,
        isOnline: true,
        isGroup: true,
        memberCount: addedUserIds.size,
        members: memberNames
      };
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
        c.last_message_text,
        c.last_message_at,
        c.created_at,
        cp_self.unread_count,
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
        isGroup: isGroup
      };
    });
  }

  /**
   * Get all messages for a specific conversation
   */
  static async getMessages(conversationId, currentUserId) {
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

    // Mark unread incoming messages as read
    await db.query(
      `UPDATE messages SET is_read = true WHERE conversation_id = $1 AND sender_id != $2 AND is_read = false`,
      [conversationId, currentUserId]
    );
    await db.query(
      `UPDATE conversation_participants SET unread_count = 0, last_read_at = NOW() WHERE conversation_id = $1 AND user_id = $2`,
      [conversationId, currentUserId]
    );

    return res.rows.map(row => {
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

      // 3. Increment unread count for other participants
      await client.query(
        `UPDATE conversation_participants
         SET unread_count = unread_count + 1
         WHERE conversation_id = $1 AND user_id != $2`,
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
