const ChatModel = require('../models/chatModel');
const db = require('../config/database');
const { sendSms, normalizePhoneNumber } = require('../services/smsService');
const { successResponse, errorResponse } = require('../utils/responseHandler');

/**
 * Get all conversations for authenticated user
 */
const getConversations = async (req, res) => {
  try {
    const userId = req.user.id;
    const conversations = await ChatModel.getConversationsForUser(userId);
    return successResponse(res, 200, 'Conversations retrieved successfully', conversations);
  } catch (err) {
    console.error('[Get Conversations Error]:', err);
    return errorResponse(res, 500, 'Failed to fetch conversations', err.message);
  }
};

/**
 * Create a new group conversation
 */
const createGroup = async (req, res) => {
  try {
    const creatorId = req.user.id;
    const { title, description, members } = req.body;
    const groupTitle = (title || '').toString().trim() || 'New Group';
    const groupDesc = (description || '').toString().trim();
    const memberList = Array.isArray(members) ? members : [];

    const groupConv = await ChatModel.createGroupConversation({
      creatorId,
      title: groupTitle,
      description: groupDesc,
      memberIdentifiers: memberList
    });

    return successResponse(res, 201, 'Group created successfully', groupConv);
  } catch (err) {
    console.error('[Create Group Error]:', err);
    return errorResponse(res, 500, 'Failed to create group', err.message);
  }
};

/**
 * Respond to a group invitation (accept or decline)
 */
const respondToInvite = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conversationId } = req.params;
    const { accept } = req.body;

    if (!conversationId) {
      return errorResponse(res, 400, 'Conversation ID is required');
    }

    const result = await ChatModel.respondToGroupInvitation({
      conversationId,
      userId,
      accept: accept === true
    });

    return successResponse(res, 200, result.message, result);
  } catch (err) {
    console.error('[Respond To Invite Error]:', err);
    return errorResponse(res, 500, 'Failed to respond to group invitation', err.message);
  }
};

/**
 * Get message history for a conversation or target contact (phone / username / group title)
 */
const getMessages = async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const target = req.params.target;

    if (!target) {
      return errorResponse(res, 400, 'Target contact or conversation ID is required');
    }

    let conversationId = target;
    let peerUser = null;

    // Check if target is UUID
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(target);

    if (!isUuid) {
      // Check if target is a group title the user participates in
      const groupByName = await db.query(
        `SELECT c.id, c.type, c.title
         FROM conversations c
         JOIN conversation_participants cp ON cp.conversation_id = c.id AND cp.user_id = $1
         WHERE c.type = 'group' AND LOWER(c.title) = LOWER($2)
         ORDER BY c.created_at DESC
         LIMIT 1;`,
        [currentUserId, target.trim()]
      );

      if (groupByName.rows.length > 0) {
        conversationId = groupByName.rows[0].id;
      } else {
        // Target is phone number or username
        peerUser = await ChatModel.findUserByIdentifier(target);
        if (!peerUser) {
          // Auto-create contact for new phone number
          peerUser = await ChatModel.findOrCreateContactUser(target);
        }

        if (!peerUser) {
          return errorResponse(res, 404, 'Contact not found');
        }

        const conversation = await ChatModel.findOrCreateDirectConversation(currentUserId, peerUser.id);
        conversationId = conversation.id;
      }
    }

    const result = await ChatModel.getMessages(conversationId, currentUserId);
    const messages = Array.isArray(result) ? result : (result.messages || []);

    return successResponse(res, 200, 'Messages retrieved successfully', {
      conversationId,
      peer: peerUser,
      messages,
      conversation: result.conversation || null,
      participants: result.participants || []
    });
  } catch (err) {
    console.error('[Get Messages Error]:', err);
    return errorResponse(res, 500, 'Failed to fetch message history', err.message);
  }
};

/**
 * Send a chat message and deliver as real SMS if recipient is a phone number
 */
const sendMessage = async (req, res) => {
  try {
    const senderId = req.user.id;
    const { recipient, content } = req.body;

    if (!recipient || !recipient.toString().trim()) {
      return errorResponse(res, 400, 'Recipient phone number or username is required');
    }
    if (!content || !content.toString().trim()) {
      return errorResponse(res, 400, 'Message content cannot be empty');
    }

    const cleanRecipient = recipient.toString().trim();
    const cleanContent = content.toString().trim();

    // Check if recipient is an existing conversation UUID
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(cleanRecipient);
    let existingConv = null;

    if (isUuid) {
      const convRes = await db.query(
        `SELECT c.id, c.type, c.title
         FROM conversations c
         JOIN conversation_participants cp ON cp.conversation_id = c.id AND cp.user_id = $1
         WHERE c.id = $2
         LIMIT 1;`,
        [senderId, cleanRecipient]
      );
      if (convRes.rows.length > 0) {
        existingConv = convRes.rows[0];
      }
    } else {
      // Check if recipient matches a group name the user is in
      const groupRes = await db.query(
        `SELECT c.id, c.type, c.title
         FROM conversations c
         JOIN conversation_participants cp ON cp.conversation_id = c.id AND cp.user_id = $1
         WHERE c.type = 'group' AND LOWER(c.title) = LOWER($2)
         ORDER BY c.created_at DESC
         LIMIT 1;`,
        [senderId, cleanRecipient]
      );
      if (groupRes.rows.length > 0) {
        existingConv = groupRes.rows[0];
      }
    }

    if (existingConv) {
      if (existingConv.type === 'group') {
        const partCheck = await db.query(
          `SELECT status FROM conversation_participants WHERE conversation_id = $1 AND user_id = $2`,
          [existingConv.id, senderId]
        );
        if (partCheck.rows.length > 0 && partCheck.rows[0].status === 'pending') {
          return errorResponse(res, 403, 'You must accept the group invitation before sending messages.');
        }
      }

      const savedMsg = await ChatModel.saveMessage({
        conversationId: existingConv.id,
        senderId,
        content: cleanContent
      });

      return successResponse(res, 201, 'Message sent and recorded successfully', {
        ...savedMsg,
        conversationId: existingConv.id,
        isGroup: existingConv.type === 'group',
        smsDispatched: false
      });
    }

    // 1. Identify recipient user for direct chat
    let peerUser = await ChatModel.findUserByIdentifier(cleanRecipient);
    if (!peerUser) {
      peerUser = await ChatModel.findOrCreateContactUser(cleanRecipient);
    }

    if (!peerUser) {
      return errorResponse(res, 404, 'Could not resolve recipient contact');
    }

    // 2. Find or create direct conversation
    const conversation = await ChatModel.findOrCreateDirectConversation(senderId, peerUser.id);

    // 3. Save message into PostgreSQL
    const savedMsg = await ChatModel.saveMessage({
      conversationId: conversation.id,
      senderId,
      content: cleanContent
    });

    // 4. Real Phone SMS Dispatch
    // If recipient has a phone number, dispatch authentic SMS via the main phone gateway
    let smsDispatched = false;
    let smsError = null;
    const recipientPhone = peerUser.phone || (cleanRecipient.replace(/\D/g, '').length >= 10 ? cleanRecipient : null);

    if (recipientPhone) {
      try {
        const formattedPhone = normalizePhoneNumber(recipientPhone);
        const senderLabel = req.user.username ? `@${req.user.username}` : (req.user.phone || 'CONNEKT');

        let smsSummary = cleanContent;
        try {
          if (cleanContent.startsWith('{') && cleanContent.endsWith('}')) {
            const parsed = JSON.parse(cleanContent);
            if (parsed.type === 'image') {
              smsSummary = `📷 [Photo]: ${parsed.name || 'Image attachment'}`;
            } else if (parsed.type === 'voice') {
              smsSummary = `🎤 [Voice Message]: (${parsed.duration || '0:05'})`;
            } else if (parsed.type === 'file') {
              smsSummary = `📄 [Document]: ${parsed.name || 'File attachment'}`;
            }
          }
        } catch (_) {}

        const smsMessage = `[CONNEKT from ${senderLabel}]: ${smsSummary}`;

        console.log(`[Chat SMS Dispatch] Sending real SMS to ${formattedPhone}...`);
        const smsRes = await sendSms({
          to: formattedPhone,
          message: smsMessage,
          purpose: 'direct_chat'
        });

        smsDispatched = smsRes.success === true;
        if (!smsDispatched) {
          smsError = smsRes.error;
        }
      } catch (err) {
        console.warn(`[Chat SMS Warning]: Failed to dispatch SMS to ${recipientPhone}: ${err.message}`);
        smsError = err.message;
      }
    }

    return successResponse(res, 201, 'Message sent and recorded successfully', {
      ...savedMsg,
      conversationId: conversation.id,
      smsDispatched,
      smsError,
      recipientPhone
    });
  } catch (err) {
    console.error('[Send Message Error]:', err);
    return errorResponse(res, 500, 'Failed to send message', err.message);
  }
};

/**
 * Handle media / file upload for chat
 */
const uploadFile = async (req, res) => {
  try {
    if (!req.file) {
      return errorResponse(res, 400, 'No file was uploaded');
    }

    const fileUrl = `/uploads/chats/${req.file.filename}`;
    const fileInfo = {
      url: fileUrl,
      filename: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size
    };

    return successResponse(res, 200, 'File uploaded successfully', fileInfo);
  } catch (err) {
    console.error('[File Upload Error]:', err);
    return errorResponse(res, 500, 'Failed to process file upload', err.message);
  }
};

/**
 * Delete a message (for_me or for_everyone)
 */
const deleteMessage = async (req, res) => {
  try {
    const userId = req.user.id;
    const { messageId } = req.params;
    const { mode } = req.body || {};

    const result = await ChatModel.deleteMessage({
      messageId,
      userId,
      mode: mode === 'for_everyone' ? 'for_everyone' : 'for_me'
    });

    if (!result.success) {
      return errorResponse(res, result.statusCode || 400, result.error || 'Failed to delete message');
    }

    return successResponse(res, 200, 'Message deleted successfully', result);
  } catch (err) {
    console.error('[Delete Message Controller Error]:', err);
    return errorResponse(res, 500, 'Failed to delete message', err.message);
  }
};

module.exports = {
  getConversations,
  getMessages,
  createGroup,
  respondToInvite,
  sendMessage,
  uploadFile,
  deleteMessage
};
