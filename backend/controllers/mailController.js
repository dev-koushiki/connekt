const MailModel = require('../models/mailModel');
const externalMailService = require('../services/externalMailService');
const { successResponse, errorResponse } = require('../utils/responseHandler');

const getMailOverview = async (req, res) => {
  try {
    const data = await MailModel.listMessages(req.user);
    return successResponse(res, 200, 'Mailbox loaded successfully', data);
  } catch (err) {
    console.error('[Mail Get Error]:', err);
    return errorResponse(res, 500, 'Failed to load mailbox', err.message);
  }
};

const sendOrSaveDraft = async (req, res) => {
  try {
    const result = await MailModel.sendOrSaveDraft(req.user, req.body || {});
    return successResponse(res, 200, 'Mail processed successfully', result);
  } catch (err) {
    console.error('[Mail Send/Draft Error]:', err);
    return errorResponse(res, 500, 'Failed to process email', err.message);
  }
};

const updateMessage = async (req, res) => {
  try {
    const updated = await MailModel.updateMessage(req.user.id, req.params.id, req.body || {});
    if (!updated) {
      return errorResponse(res, 404, 'Email message not found');
    }
    return successResponse(res, 200, 'Email updated successfully', { message: updated });
  } catch (err) {
    console.error('[Mail Update Error]:', err);
    return errorResponse(res, 500, 'Failed to update email', err.message);
  }
};

const bulkAction = async (req, res) => {
  try {
    const { ids, action, ...extra } = req.body || {};
    if (!Array.isArray(ids) || ids.length === 0 || !action) {
      return errorResponse(res, 400, 'ids array and action are required');
    }
    const count = await MailModel.bulkAction(req.user.id, ids, action, extra);
    return successResponse(res, 200, 'Bulk mail action applied', { count });
  } catch (err) {
    console.error('[Mail Bulk Error]:', err);
    return errorResponse(res, 500, 'Failed to apply bulk action', err.message);
  }
};

const deleteMessage = async (req, res) => {
  try {
    const permanent = req.query.permanent === 'true';
    const result = await MailModel.deleteMessage(req.user.id, req.params.id, permanent);
    if (!result.deleted) {
      return errorResponse(res, 404, 'Email message not found');
    }
    return successResponse(res, 200, 'Email deleted successfully', result);
  } catch (err) {
    console.error('[Mail Delete Error]:', err);
    return errorResponse(res, 500, 'Failed to delete email', err.message);
  }
};

const emptyFolder = async (req, res) => {
  try {
    const folder = req.params.folder;
    const count = await MailModel.emptyFolder(req.user.id, folder);
    return successResponse(res, 200, `${folder} emptied`, { count });
  } catch (err) {
    console.error('[Mail Empty Folder Error]:', err);
    return errorResponse(res, 500, 'Failed to empty folder', err.message);
  }
};

const createLabel = async (req, res) => {
  try {
    const { name, color } = req.body || {};
    const label = await MailModel.createLabel(req.user.id, name, color);
    return successResponse(res, 201, 'Label saved', { label });
  } catch (err) {
    console.error('[Mail Create Label Error]:', err);
    return errorResponse(res, 400, err.message || 'Failed to create label');
  }
};

const deleteLabel = async (req, res) => {
  try {
    const deleted = await MailModel.deleteLabel(req.user.id, req.params.id);
    if (!deleted) {
      return errorResponse(res, 404, 'Label not found');
    }
    return successResponse(res, 200, 'Label removed');
  } catch (err) {
    console.error('[Mail Delete Label Error]:', err);
    return errorResponse(res, 500, 'Failed to remove label', err.message);
  }
};

const updateSettings = async (req, res) => {
  try {
    const settings = await MailModel.updateSettings(req.user.id, req.body || {});
    return successResponse(res, 200, 'Mail settings updated', { settings });
  } catch (err) {
    console.error('[Mail Settings Error]:', err);
    return errorResponse(res, 500, 'Failed to update mail settings', err.message);
  }
};

const uploadAttachment = async (req, res) => {
  try {
    if (!req.file) {
      return errorResponse(res, 400, 'No attachment uploaded');
    }
    if (!externalMailService.isSafeAttachmentFilename(req.file.originalname)) {
      return errorResponse(res, 400, 'Executable or unsafe attachment types are blocked');
    }
    return successResponse(res, 200, 'Attachment uploaded', {
      url: `/uploads/mail/${req.file.filename}`,
      filename: req.file.originalname,
      mimetype: req.file.mimetype,
      size: req.file.size
    });
  } catch (err) {
    console.error('[Mail Attachment Error]:', err);
    return errorResponse(res, 500, 'Failed to upload attachment', err.message);
  }
};

const saveTemplate = async (req, res) => {
  try {
    const template = await MailModel.saveTemplate(req.user.id, req.body || {});
    return successResponse(res, 201, 'Template saved', { template });
  } catch (err) {
    console.error('[Mail Save Template Error]:', err);
    return errorResponse(res, 400, err.message || 'Failed to save template');
  }
};

const deleteTemplate = async (req, res) => {
  try {
    const deleted = await MailModel.deleteTemplate(req.user.id, req.params.id);
    if (!deleted) return errorResponse(res, 404, 'Template not found');
    return successResponse(res, 200, 'Template removed');
  } catch (err) {
    console.error('[Mail Delete Template Error]:', err);
    return errorResponse(res, 500, 'Failed to delete template', err.message);
  }
};

const saveContact = async (req, res) => {
  try {
    const contact = await MailModel.saveContact(req.user.id, req.body || {});
    return successResponse(res, 201, 'Contact saved', { contact });
  } catch (err) {
    console.error('[Mail Save Contact Error]:', err);
    return errorResponse(res, 400, err.message || 'Failed to save contact');
  }
};

const deleteContact = async (req, res) => {
  try {
    const deleted = await MailModel.deleteContact(req.user.id, req.params.id);
    if (!deleted) return errorResponse(res, 404, 'Contact not found');
    return successResponse(res, 200, 'Contact removed');
  } catch (err) {
    console.error('[Mail Delete Contact Error]:', err);
    return errorResponse(res, 500, 'Failed to delete contact', err.message);
  }
};

const getExternalMailStatus = async (req, res) => {
  return successResponse(res, 200, 'External mail configuration status', {
    status: externalMailService.getSmtpStatus()
  });
};

const syncImapMailbox = async (req, res) => {
  try {
    const syncRes = await externalMailService.fetchImapUnseenMessages(25);
    if (!syncRes.configured) {
      return successResponse(res, 200, 'IMAP mailbox sync skipped (not configured)', {
        configured: false,
        reason: syncRes.reason,
        ingestedCount: 0
      });
    }

    let ingestedCount = 0;
    const io = req.app.get('io');
    for (const parsed of syncRes.messages) {
      const ingest = await MailModel.ingestInboundEmail(parsed);
      ingestedCount += ingest.deliveredCount;
      if (io) {
        for (const uid of ingest.deliveredToUsers) {
          io.to(`user:${uid}`).emit('mail:new', {
            fromEmail: parsed.fromEmail,
            subject: parsed.subject
          });
        }
      }
    }

    return successResponse(res, 200, 'IMAP sync completed', {
      configured: true,
      fetchedCount: syncRes.messages.length,
      ingestedCount
    });
  } catch (err) {
    console.error('[Mail IMAP Sync Error]:', err);
    return errorResponse(res, 500, 'Failed to sync IMAP mailbox', err.message);
  }
};

const receiveInboundWebhook = async (req, res) => {
  try {
    if (!externalMailService.verifyInboundWebhookAuth(req)) {
      return errorResponse(res, 401, 'Unauthorized inbound mail webhook');
    }

    const body = req.body || {};
    let parsed;
    if (body.rawMime) {
      parsed = await externalMailService.parseRawMimeEmail(body.rawMime);
    } else {
      const splitList = (val) =>
        Array.isArray(val)
          ? val
          : (val || '')
              .toString()
              .split(/[,;\s]+/)
              .map((s) => s.trim().toLowerCase())
              .filter(Boolean);

      parsed = {
        messageId: body['Message-Id'] || body.messageId || externalMailService.generateMessageId(),
        inReplyTo: body['In-Reply-To'] || body.inReplyTo || null,
        references: body.References || body.references || null,
        fromName: body.fromName || body.From || body.sender || 'External Sender',
        fromEmail: (body.sender || body.from || body.fromEmail || '').toString().toLowerCase(),
        to: splitList(body.recipient || body.to),
        cc: splitList(body.cc),
        deliveredTo: body.recipient || body.deliveredTo || null,
        subject: body.subject || '(no subject)',
        body: body['body-plain'] || body.text || body.body || '',
        htmlBody: body['body-html'] || body.html || body.htmlBody || null,
        attachments: [],
        authResults: externalMailService.parseAuthHeaders(body.headers || {})
      };
    }

    const ingest = await MailModel.ingestInboundEmail(parsed);
    const io = req.app.get('io');
    if (io) {
      for (const uid of ingest.deliveredToUsers) {
        io.to(`user:${uid}`).emit('mail:new', {
          fromEmail: parsed.fromEmail,
          subject: parsed.subject
        });
      }
    }

    return successResponse(res, 200, 'Inbound email processed', ingest);
  } catch (err) {
    console.error('[Mail Inbound Webhook Error]:', err);
    return errorResponse(res, 500, 'Failed to process inbound email', err.message);
  }
};

module.exports = {
  getMailOverview,
  sendOrSaveDraft,
  updateMessage,
  bulkAction,
  deleteMessage,
  emptyFolder,
  createLabel,
  deleteLabel,
  updateSettings,
  uploadAttachment,
  saveTemplate,
  deleteTemplate,
  saveContact,
  deleteContact,
  getExternalMailStatus,
  syncImapMailbox,
  receiveInboundWebhook
};
