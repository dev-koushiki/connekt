const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const nodemailer = require('nodemailer');

let simpleParser = null;
try {
  ({ simpleParser } = require('mailparser'));
} catch (_) {
  simpleParser = null;
}

let ImapFlow = null;
try {
  ({ ImapFlow } = require('imapflow'));
} catch (_) {
  ImapFlow = null;
}

const CONNEKT_DOMAIN = (process.env.CONNEKT_DOMAIN || 'connekt.net.in').toLowerCase();
const UPLOADS_MAIL_DIR = path.resolve(__dirname, '../uploads/mail');

const BLOCKED_ATTACHMENT_EXTENSIONS = new Set([
  '.exe', '.bat', '.cmd', '.scr', '.vbs', '.vbe', '.js', '.jse',
  '.msi', '.msp', '.ps1', '.sh', '.dll', '.com', '.pif', '.hta', '.jar'
]);

/**
 * Validate attachment filename extension to prevent executable malware uploads/ingestion.
 */
function isSafeAttachmentFilename(filename = '') {
  const ext = path.extname(filename.toString()).toLowerCase();
  return !BLOCKED_ATTACHMENT_EXTENSIONS.has(ext);
}

/**
 * Strip HTML tags into readable plain text.
 */
function htmlToPlainText(html = '') {
  return html
    .toString()
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * Build configured Nodemailer SMTP transporter if real credentials exist.
 */
function createSmtpTransporter() {
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!user || !pass || pass === 'app_password_placeholder') {
    return null;
  }

  return nodemailer.createTransport({
    host: process.env.SMTP_HOST || `mail.${CONNEKT_DOMAIN}`,
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user, pass },
    tls: {
      rejectUnauthorized: process.env.SMTP_TLS_REJECT_UNAUTHORIZED !== 'false'
    }
  });
}

let cachedTransporter = createSmtpTransporter();

function getSmtpStatus() {
  const hasSmtp = Boolean(
    process.env.SMTP_USER &&
      process.env.SMTP_PASS &&
      process.env.SMTP_PASS !== 'app_password_placeholder'
  );
  const hasImap = Boolean(
    ImapFlow &&
      process.env.IMAP_HOST &&
      process.env.IMAP_USER &&
      process.env.IMAP_PASS
  );
  const hasWebhook = Boolean(process.env.MAIL_WEBHOOK_SECRET);

  return {
    domain: CONNEKT_DOMAIN,
    smtpConfigured: hasSmtp,
    smtpHost: process.env.SMTP_HOST || null,
    imapConfigured: hasImap,
    imapHost: process.env.IMAP_HOST || null,
    inboundWebhookConfigured: hasWebhook
  };
}

/**
 * Resolve stored upload URLs safely inside uploads/mail for SMTP attachments.
 */
function resolveMailAttachments(attachments = []) {
  const resolved = [];
  for (const att of attachments) {
    if (!att || typeof att !== 'object') continue;
    const filename = (att.filename || 'attachment').toString();
    if (!isSafeAttachmentFilename(filename)) continue;

    const rawUrl = (att.url || '').toString();
    if (rawUrl.startsWith('/uploads/mail/')) {
      const safeName = path.basename(rawUrl);
      const diskPath = path.join(UPLOADS_MAIL_DIR, safeName);
      if (diskPath.startsWith(UPLOADS_MAIL_DIR) && fs.existsSync(diskPath)) {
        resolved.push({
          filename,
          path: diskPath,
          contentType: att.mimetype || undefined
        });
      }
    }
  }
  return resolved;
}

/**
 * Generate an RFC-5322 compliant Message-ID on the configured CONNEKT domain.
 */
function generateMessageId() {
  const rand = crypto.randomBytes(12).toString('hex');
  return `<${Date.now()}.${rand}@${CONNEKT_DOMAIN}>`;
}

/**
 * Send email to external recipients via configured SMTP server.
 * Never fakes external delivery when SMTP credentials are absent or fail.
 */
async function sendExternalEmail({
  fromName,
  fromEmail,
  toList = [],
  ccList = [],
  bccList = [],
  subject,
  body,
  htmlBody = null,
  attachments = [],
  rfcMessageId = null,
  inReplyToRfc = null,
  referencesHeader = null
}) {
  if (!cachedTransporter) {
    cachedTransporter = createSmtpTransporter();
  }
  const messageId = rfcMessageId || generateMessageId();

  if (!cachedTransporter) {
    return {
      sentExternal: false,
      deliveryStatus: 'pending_smtp_config',
      messageId,
      error:
        'External SMTP credentials are not configured yet (set SMTP_HOST, SMTP_USER, and SMTP_PASS on the backend server).'
    };
  }

  const smtpUser = process.env.SMTP_USER;
  const senderDomain = (fromEmail || '').split('@')[1]?.toLowerCase();
  const useDirectFrom =
    process.env.SMTP_SEND_AS_USER === 'true' && senderDomain === CONNEKT_DOMAIN;
  const envelopeFrom = useDirectFrom ? fromEmail : smtpUser;

  const mailOptions = {
    from: `"${fromName || 'CONNEKT User'}" <${envelopeFrom}>`,
    replyTo: fromEmail,
    to: toList.join(', '),
    cc: ccList.length > 0 ? ccList.join(', ') : undefined,
    bcc: bccList.length > 0 ? bccList.join(', ') : undefined,
    subject: subject || '(no subject)',
    text: body || htmlToPlainText(htmlBody || ''),
    html: htmlBody || undefined,
    messageId,
    inReplyTo: inReplyToRfc || undefined,
    references: referencesHeader || undefined,
    attachments: resolveMailAttachments(attachments)
  };

  try {
    const info = await cachedTransporter.sendMail(mailOptions);
    return {
      sentExternal: true,
      deliveryStatus: 'sent_external',
      messageId: info.messageId || messageId,
      accepted: Array.isArray(info.accepted) ? info.accepted : [],
      rejected: Array.isArray(info.rejected) ? info.rejected : [],
      response: info.response || null
    };
  } catch (err) {
    return {
      sentExternal: false,
      deliveryStatus: 'failed',
      messageId,
      error: err.message
    };
  }
}

/**
 * Parse Authentication-Results / Received-SPF headers into normalized security statuses.
 */
function parseAuthHeaders(headersObj = {}) {
  const lowerHeaders = {};
  for (const [k, v] of Object.entries(headersObj || {})) {
    lowerHeaders[k.toLowerCase()] = Array.isArray(v) ? v.join(' ') : String(v || '');
  }

  const authResults = (lowerHeaders['authentication-results'] || '').toLowerCase();
  const receivedSpf = (lowerHeaders['received-spf'] || '').toLowerCase();

  const extractStatus = (token, fallbackText = '') => {
    const regex = new RegExp(`${token}\\s*=\\s*(pass|fail|softfail|neutral|none|temperror|permerror)`, 'i');
    const match = authResults.match(regex) || fallbackText.match(regex);
    if (match) return match[1].toLowerCase();
    if (token === 'spf' && receivedSpf.includes('pass')) return 'pass';
    if (token === 'spf' && receivedSpf.includes('fail')) return 'fail';
    return 'unknown';
  };

  return {
    spfStatus: extractStatus('spf', receivedSpf),
    dkimStatus: extractStatus('dkim'),
    dmarcStatus: extractStatus('dmarc')
  };
}

/**
 * Automatic Gmail-style folder/category & spam scoring based on content and SPF/DKIM/DMARC signals.
 */
function classifyEmail({ fromEmail = '', subject = '', body = '', authResults = {} }) {
  const text = `${fromEmail} ${subject} ${body}`.toLowerCase();
  let spamScore = 0;

  if (authResults.dmarcStatus === 'fail') spamScore += 45;
  if (authResults.spfStatus === 'fail' || authResults.spfStatus === 'softfail') spamScore += 25;

  const spamKeywords = [
    'wire transfer', 'urgent lottery', 'claim your prize', 'bitcoin giveaway',
    'verify your bank immediately', 'viagra', 'act now limited offer', 'nigerian prince'
  ];
  for (const kw of spamKeywords) {
    if (text.includes(kw)) spamScore += 30;
  }

  if (spamScore >= 50) {
    return { folder: 'spam', category: 'primary', spamScore };
  }

  let category = 'primary';
  if (/unsubscribe|promo|discount|sale|% off|deal of the day|newsletter/i.test(text)) {
    category = 'promotions';
  } else if (/commented|mentioned you|liked your|friend request|follower|connection request|social/i.test(text)) {
    category = 'social';
  } else if (/forum|thread reply|mailing list|group digest|community topic|\[list\]/i.test(text)) {
    category = 'forums';
  } else if (/invoice|receipt|statement|order #|shipped|verification code|security alert|alert|update/i.test(text)) {
    category = 'updates';
  }

  return { folder: 'inbox', category, spamScore };
}

/**
 * Verify webhook authenticity via shared secret header or Mailgun HMAC signature.
 */
function verifyInboundWebhookAuth(req) {
  const configuredSecret = process.env.MAIL_WEBHOOK_SECRET;
  const mailgunKey = process.env.MAILGUN_WEBHOOK_SIGNING_KEY;

  if (configuredSecret) {
    const provided = req.headers['x-mail-webhook-secret'] || req.query.secret || '';
    if (provided && provided === configuredSecret) {
      return true;
    }
  }

  const sigObj = req.body?.signature;
  if (mailgunKey && sigObj?.timestamp && sigObj?.token && sigObj?.signature) {
    const hmac = crypto
      .createHmac('sha256', mailgunKey)
      .update(`${sigObj.timestamp}${sigObj.token}`)
      .digest('hex');
    if (hmac === sigObj.signature) {
      return true;
    }
  }

  return false;
}

/**
 * Persist an uploaded/parsed raw attachment buffer safely under uploads/mail.
 */
function saveParsedAttachment(att) {
  const filename = (att.filename || `attachment_${Date.now()}.bin`).toString();
  if (!isSafeAttachmentFilename(filename)) {
    return null;
  }
  if (!fs.existsSync(UPLOADS_MAIL_DIR)) {
    fs.mkdirSync(UPLOADS_MAIL_DIR, { recursive: true });
  }
  const uniqueName = `inb_${Date.now()}_${Math.round(Math.random() * 1e9)}${path.extname(filename)}`;
  const targetPath = path.join(UPLOADS_MAIL_DIR, uniqueName);
  const contentBuf = Buffer.isBuffer(att.content)
    ? att.content
    : Buffer.from(att.content || '', 'utf8');
  fs.writeFileSync(targetPath, contentBuf);

  return {
    url: `/uploads/mail/${uniqueName}`,
    filename,
    mimetype: att.contentType || 'application/octet-stream',
    size: contentBuf.length
  };
}

/**
 * Parse an RFC-822 raw email buffer (used by IMAP sync and raw inbound webhooks).
 */
async function parseRawMimeEmail(rawSource) {
  if (!simpleParser) {
    throw new Error('mailparser package is not installed');
  }
  const parsed = await simpleParser(rawSource);
  const extractAddresses = (field) =>
    (field?.value || [])
      .map((entry) => (entry.address || '').toLowerCase())
      .filter(Boolean);

  const fromEntry = parsed.from?.value?.[0] || {};
  const headersObj = {};
  if (parsed.headers && typeof parsed.headers.forEach === 'function') {
    parsed.headers.forEach((value, key) => {
      headersObj[key] = typeof value === 'string' ? value : JSON.stringify(value);
    });
  }

  const attachments = [];
  for (const att of parsed.attachments || []) {
    const saved = saveParsedAttachment(att);
    if (saved) attachments.push(saved);
  }

  return {
    messageId: parsed.messageId || generateMessageId(),
    inReplyTo: parsed.inReplyTo || null,
    references: Array.isArray(parsed.references)
      ? parsed.references.join(' ')
      : parsed.references || null,
    fromName: fromEntry.name || fromEntry.address || 'External Sender',
    fromEmail: (fromEntry.address || '').toLowerCase(),
    to: extractAddresses(parsed.to),
    cc: extractAddresses(parsed.cc),
    subject: parsed.subject || '(no subject)',
    body: parsed.text || htmlToPlainText(parsed.html || ''),
    htmlBody: typeof parsed.html === 'string' ? parsed.html : null,
    attachments,
    authResults: parseAuthHeaders(headersObj)
  };
}

/**
 * Sync unread emails from configured IMAP mailbox via imapflow.
 */
async function fetchImapUnseenMessages(limit = 25) {
  if (!ImapFlow) {
    return { configured: false, messages: [], reason: 'imapflow package unavailable' };
  }
  if (!process.env.IMAP_HOST || !process.env.IMAP_USER || !process.env.IMAP_PASS) {
    return {
      configured: false,
      messages: [],
      reason: 'IMAP_HOST, IMAP_USER, or IMAP_PASS not configured'
    };
  }

  const client = new ImapFlow({
    host: process.env.IMAP_HOST,
    port: parseInt(process.env.IMAP_PORT || '993', 10),
    secure: process.env.IMAP_SECURE !== 'false',
    auth: {
      user: process.env.IMAP_USER,
      pass: process.env.IMAP_PASS
    },
    logger: false
  });

  const parsedMessages = [];
  await client.connect();
  const lock = await client.getMailboxLock('INBOX');
  try {
    const uids = await client.search({ seen: false }, { uid: true });
    const slice = uids.slice(-limit);
    for (const uid of slice) {
      const msg = await client.fetchOne(uid, { source: true, uid: true }, { uid: true });
      if (msg?.source) {
        const parsed = await parseRawMimeEmail(msg.source);
        parsedMessages.push(parsed);
        await client.messageFlagsAdd(uid, ['\\Seen'], { uid: true });
      }
    }
  } finally {
    lock.release();
    await client.logout();
  }

  return { configured: true, messages: parsedMessages };
}

module.exports = {
  CONNEKT_DOMAIN,
  isSafeAttachmentFilename,
  htmlToPlainText,
  getSmtpStatus,
  generateMessageId,
  sendExternalEmail,
  parseAuthHeaders,
  classifyEmail,
  verifyInboundWebhookAuth,
  saveParsedAttachment,
  parseRawMimeEmail,
  fetchImapUnseenMessages
};
