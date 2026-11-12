const crypto = require('crypto');
const db = require('../config/database');
const externalMailService = require('../services/externalMailService');

let tableInitPromise = null;

function makeSnippet(body) {
  const clean = (body || '').toString().replace(/\s+/g, ' ').trim();
  if (clean.length <= 140) return clean;
  return `${clean.slice(0, 137)}...`;
}

function parseAddressList(input) {
  if (!input) return [];
  if (Array.isArray(input)) {
    return input
      .map((item) => item.toString().trim().toLowerCase())
      .filter(Boolean);
  }
  return input
    .toString()
    .split(/[,;\s]+/)
    .map((item) => item.trim().toLowerCase())
    .filter((item) => item.includes('@') || item.length > 0);
}

function formatMessageRow(row) {
  return {
    id: row.id,
    ownerUserId: row.owner_user_id,
    threadId: row.thread_id,
    inReplyTo: row.in_reply_to,
    senderName: row.from_name || row.from_email,
    senderEmail: row.from_email,
    to: Array.isArray(row.to_emails) ? row.to_emails : [],
    cc: Array.isArray(row.cc_emails) ? row.cc_emails : [],
    bcc: Array.isArray(row.bcc_emails) ? row.bcc_emails : [],
    subject: row.subject || '(no subject)',
    body: row.body || '',
    htmlBody: row.html_body || null,
    snippet: row.snippet || makeSnippet(row.body),
    folder: row.folder || 'inbox',
    originalFolder: row.original_folder || 'inbox',
    category: row.category || 'primary',
    labels: Array.isArray(row.labels) ? row.labels : [],
    attachments: Array.isArray(row.attachments) ? row.attachments : [],
    rfcMessageId: row.rfc_message_id || null,
    inReplyToRfc: row.in_reply_to_rfc || null,
    deliveryStatus: row.delivery_status || 'delivered_internal',
    deliveryError: row.delivery_error || null,
    spamScore: typeof row.spam_score === 'number' ? row.spam_score : 0,
    spfStatus: row.spf_status || null,
    dkimStatus: row.dkim_status || null,
    dmarcStatus: row.dmarc_status || null,
    isUnread: row.is_unread === true,
    isStarred: row.is_starred === true,
    isImportant: row.is_important === true,
    isMuted: row.is_muted === true,
    isConfidential: row.is_confidential === true,
    confidentialExpiresAt: row.confidential_expires_at ? new Date(row.confidential_expires_at).toISOString() : null,
    snoozedUntil: row.snoozed_until ? new Date(row.snoozed_until).toISOString() : null,
    scheduledAt: row.scheduled_at ? new Date(row.scheduled_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : new Date().toISOString(),
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : new Date().toISOString()
  };
}

class MailModel {
  /**
   * Ensure mail tables and indexes exist in PostgreSQL.
   */
  static async ensureTable() {
    if (!tableInitPromise) {
      tableInitPromise = db
        .query(`
          CREATE TABLE IF NOT EXISTS mail_messages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            thread_id VARCHAR(120) NOT NULL,
            in_reply_to UUID,
            from_name VARCHAR(160) NOT NULL DEFAULT '',
            from_email VARCHAR(255) NOT NULL DEFAULT '',
            to_emails JSONB NOT NULL DEFAULT '[]'::jsonb,
            cc_emails JSONB NOT NULL DEFAULT '[]'::jsonb,
            bcc_emails JSONB NOT NULL DEFAULT '[]'::jsonb,
            subject VARCHAR(500) NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            snippet VARCHAR(300) NOT NULL DEFAULT '',
            folder VARCHAR(30) NOT NULL DEFAULT 'inbox',
            original_folder VARCHAR(30) NOT NULL DEFAULT 'inbox',
            category VARCHAR(30) NOT NULL DEFAULT 'primary',
            labels JSONB NOT NULL DEFAULT '[]'::jsonb,
            attachments JSONB NOT NULL DEFAULT '[]'::jsonb,
            is_unread BOOLEAN NOT NULL DEFAULT false,
            is_starred BOOLEAN NOT NULL DEFAULT false,
            is_important BOOLEAN NOT NULL DEFAULT false,
            is_muted BOOLEAN NOT NULL DEFAULT false,
            is_confidential BOOLEAN NOT NULL DEFAULT false,
            confidential_expires_at TIMESTAMPTZ,
            snoozed_until TIMESTAMPTZ,
            scheduled_at TIMESTAMPTZ,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
          );
          CREATE INDEX IF NOT EXISTS idx_mail_owner_folder_time
            ON mail_messages(owner_user_id, folder, created_at DESC);
          CREATE INDEX IF NOT EXISTS idx_mail_owner_thread
            ON mail_messages(owner_user_id, thread_id, created_at ASC);

          CREATE TABLE IF NOT EXISTS mail_labels (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(80) NOT NULL,
            color VARCHAR(20) NOT NULL DEFAULT '#1D4ED8',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, name)
          );

          CREATE TABLE IF NOT EXISTS mail_settings (
            user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
            signature TEXT NOT NULL DEFAULT '',
            signature_enabled BOOLEAN NOT NULL DEFAULT false,
            vacation_enabled BOOLEAN NOT NULL DEFAULT false,
            vacation_subject VARCHAR(255) NOT NULL DEFAULT 'Out of Office',
            vacation_body TEXT NOT NULL DEFAULT 'I am currently away and will respond when I return.',
            conversation_view BOOLEAN NOT NULL DEFAULT true,
            right_swipe_action VARCHAR(30) NOT NULL DEFAULT 'archive',
            left_swipe_action VARCHAR(30) NOT NULL DEFAULT 'delete',
            compact_density BOOLEAN NOT NULL DEFAULT false,
            has_seeded_welcome BOOLEAN NOT NULL DEFAULT false,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
          );

          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS html_body TEXT;
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS rfc_message_id VARCHAR(255);
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS in_reply_to_rfc VARCHAR(255);
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS references_header TEXT;
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS delivery_status VARCHAR(40) NOT NULL DEFAULT 'delivered_internal';
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS delivery_error TEXT;
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS spam_score INTEGER NOT NULL DEFAULT 0;
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS spf_status VARCHAR(30);
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS dkim_status VARCHAR(30);
          ALTER TABLE mail_messages ADD COLUMN IF NOT EXISTS dmarc_status VARCHAR(30);

          CREATE INDEX IF NOT EXISTS idx_mail_owner_rfc_id
            ON mail_messages(owner_user_id, rfc_message_id);

          CREATE TABLE IF NOT EXISTS mail_templates (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(120) NOT NULL,
            subject VARCHAR(500) NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            html_body TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
          );

          CREATE TABLE IF NOT EXISTS mail_contacts (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(160) NOT NULL DEFAULT '',
            email VARCHAR(255) NOT NULL,
            phone VARCHAR(60) NOT NULL DEFAULT '',
            company VARCHAR(160) NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, email)
          );
        `)
        .catch((err) => {
          tableInitPromise = null;
          throw err;
        });
    }
    return tableInitPromise;
  }

  /**
   * Ensure settings row and one-time welcome mail exist for a user.
   */
  static async ensureUserInitialized(user) {
    await this.ensureTable();
    const userId = user.id;
    const settingsRes = await db.query(
      'SELECT * FROM mail_settings WHERE user_id = $1',
      [userId]
    );

    if (settingsRes.rows.length > 0 && settingsRes.rows[0].has_seeded_welcome) {
      return settingsRes.rows[0];
    }

    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO mail_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
        [userId]
      );

      const defaultLabels = [
        { name: 'Work', color: '#1D4ED8' },
        { name: 'Personal', color: '#059669' },
        { name: 'Finance', color: '#D97706' },
        { name: 'Travel', color: '#7C3AED' }
      ];
      for (const lbl of defaultLabels) {
        await client.query(
          `INSERT INTO mail_labels (user_id, name, color)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, name) DO NOTHING`,
          [userId, lbl.name, lbl.color]
        );
      }

      const existingCountRes = await client.query(
        'SELECT COUNT(*)::int AS cnt FROM mail_messages WHERE owner_user_id = $1',
        [userId]
      );
      if (existingCountRes.rows[0].cnt === 0) {
        const userMail = (user.email || `${user.username || 'user'}@connekt.me`).toLowerCase();
        const welcomeThread = `thr_welcome_${userId.slice(0, 8)}`;
        await client.query(
          `INSERT INTO mail_messages (
            owner_user_id, thread_id, from_name, from_email, to_emails,
            subject, body, snippet, folder, original_folder, category, labels,
            is_unread, is_starred, is_important
          ) VALUES
          (
            $1, $2, 'CONNEKT Mail Team', 'mail-team@connekt.me', $3::jsonb,
            'Welcome to your new Connekt Mail inbox',
            'Hi there,\n\nYour Connekt Mail workspace now supports full Google Mail workflows including Primary/Social/Promotions tabs, conversation threads, custom labels, scheduled send, snooze, confidential mode, attachments, and vacation auto-replies.\n\nReply directly to any message or tap Compose to get started.',
            'Your Connekt Mail workspace now supports full Google Mail workflows including Primary/Social/Promotions tabs, threads, labels, snooze, and more.',
            'inbox', 'inbox', 'primary', '["Work"]'::jsonb, true, true, true
          ),
          (
            $1, $4, 'CONNEKT Community', 'community@connekt.me', $3::jsonb,
            'Connect with colleagues across Meetings & Chats',
            'Discover how teammates collaborate in CONNEKT across HD meetings, SMS-bridged chats, and real-time mail.',
            'Discover how teammates collaborate in CONNEKT across HD meetings, SMS-bridged chats, and real-time mail.',
            'inbox', 'inbox', 'social', '["Personal"]'::jsonb, true, false, false
          ),
          (
            $1, $5, 'CONNEKT Cloud Workspace', 'updates@connekt.me', $3::jsonb,
            'Smart Workspace Tips: Keyboard & Swipe Productivity',
            'Tip: Swipe emails right to archive or left to delete. Customize swipe actions, signatures, and Out-of-Office auto-replies inside Mail Settings.',
            'Tip: Swipe emails right to archive or left to delete. Customize swipe actions and signatures inside Mail Settings.',
            'inbox', 'inbox', 'promotions', '[]'::jsonb, false, false, false
          )`,
          [
            userId,
            welcomeThread,
            JSON.stringify([userMail]),
            `thr_social_${userId.slice(0, 8)}`,
            `thr_promo_${userId.slice(0, 8)}`
          ]
        );
      }

      const updatedSettings = await client.query(
        `UPDATE mail_settings SET has_seeded_welcome = true, updated_at = NOW()
         WHERE user_id = $1 RETURNING *`,
        [userId]
      );
      await client.query('COMMIT');
      return updatedSettings.rows[0];
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Deliver scheduled emails that have reached scheduled_at and wake expired snoozes.
   */
  static async processDueMessages(userId) {
    await this.ensureTable();

    // 1. Wake up snoozed messages
    await db.query(
      `UPDATE mail_messages
       SET folder = 'inbox',
           original_folder = 'inbox',
           snoozed_until = NULL,
           is_unread = true,
           updated_at = NOW()
       WHERE owner_user_id = $1
         AND folder = 'snoozed'
         AND snoozed_until IS NOT NULL
         AND snoozed_until <= NOW()`,
      [userId]
    );

    // 2. Dispatch scheduled messages that are now due
    const dueScheduled = await db.query(
      `SELECT * FROM mail_messages
       WHERE owner_user_id = $1
         AND folder = 'scheduled'
         AND scheduled_at IS NOT NULL
         AND scheduled_at <= NOW()`,
      [userId]
    );

    for (const row of dueScheduled.rows) {
      await db.query(
        `UPDATE mail_messages
         SET folder = 'sent',
             original_folder = 'sent',
             scheduled_at = NULL,
             updated_at = NOW()
         WHERE id = $1`,
        [row.id]
      );
      await this._deliverToRecipients({
        senderUserId: userId,
        fromName: row.from_name,
        fromEmail: row.from_email,
        threadId: row.thread_id,
        toList: row.to_emails || [],
        ccList: row.cc_emails || [],
        bccList: row.bcc_emails || [],
        subject: row.subject,
        body: row.body,
        attachments: row.attachments || [],
        isConfidential: row.is_confidential,
        confidentialExpiresAt: row.confidential_expires_at
      });
    }
  }

  /**
   * Resolve registered recipient users and deliver copies internally or via real SMTP externally.
   */
  static async _deliverToRecipients({
    senderUserId,
    senderMessageId = null,
    fromName,
    fromEmail,
    threadId,
    toList = [],
    ccList = [],
    bccList = [],
    subject,
    body,
    htmlBody = null,
    attachments = [],
    isConfidential = false,
    confidentialExpiresAt = null,
    rfcMessageId = null,
    inReplyToRfc = null,
    referencesHeader = null
  }) {
    const allRecipients = Array.from(new Set([...toList, ...ccList, ...bccList]))
      .map((e) => e.toString().trim().toLowerCase())
      .filter(Boolean);

    if (allRecipients.length === 0) {
      return { deliveredInternal: 0, sentExternal: false, deliveryStatus: 'delivered_internal' };
    }

    const finalRfcId = rfcMessageId || externalMailService.generateMessageId();
    let deliveredInternal = 0;
    const externalRecipients = [];

    for (const recipientEmail of allRecipients) {
      // Auto-add recipients to sender's mail contacts if missing
      if (senderUserId) {
        await db.query(
          `INSERT INTO mail_contacts (user_id, name, email)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, email) DO NOTHING`,
          [senderUserId, recipientEmail.split('@')[0], recipientEmail]
        );
      }

      const localUserRes = await db.query(
        `SELECT u.id, u.email, u.username, p.full_name
         FROM users u
         LEFT JOIN user_profiles p ON p.user_id = u.id
         WHERE LOWER(u.email) = LOWER($1)
            OR LOWER(u.username || '@connekt.me') = LOWER($1)
         LIMIT 1`,
        [recipientEmail]
      );

      if (localUserRes.rows.length > 0) {
        const recipient = localUserRes.rows[0];
        if (recipient.id !== senderUserId) {
          await this.ensureUserInitialized(recipient);
          const { category } = externalMailService.classifyEmail({
            fromEmail,
            subject,
            body
          });
          await db.query(
            `INSERT INTO mail_messages (
              owner_user_id, thread_id, rfc_message_id, in_reply_to_rfc, references_header,
              from_name, from_email, to_emails, cc_emails,
              subject, body, html_body, snippet, folder, original_folder, category, labels, attachments,
              is_unread, is_confidential, confidential_expires_at, delivery_status, spf_status, dkim_status, dmarc_status
            ) VALUES (
              $1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9::jsonb,
              $10, $11, $12, $13, 'inbox', 'inbox', $14, '[]'::jsonb, $15::jsonb,
              true, $16, $17, 'delivered_internal', 'pass', 'pass', 'pass'
            )`,
            [
              recipient.id,
              threadId,
              finalRfcId,
              inReplyToRfc,
              referencesHeader,
              fromName,
              fromEmail,
              JSON.stringify(toList),
              JSON.stringify(ccList),
              subject,
              body,
              htmlBody,
              makeSnippet(body),
              category,
              JSON.stringify(attachments),
              isConfidential === true,
              confidentialExpiresAt
            ]
          );
          deliveredInternal++;

          // Real-time notification row
          await db.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'new_mail', $2, $3, $4::jsonb)`,
            [
              recipient.id,
              `New mail from ${fromName || fromEmail}`,
              subject || '(no subject)',
              JSON.stringify({ threadId, fromEmail })
            ]
          ).catch(() => {});

          // Vacation auto-responder check
          const vacRes = await db.query(
            'SELECT vacation_enabled, vacation_subject, vacation_body FROM mail_settings WHERE user_id = $1',
            [recipient.id]
          );
          if (vacRes.rows[0]?.vacation_enabled && fromEmail && senderUserId) {
            const vacSubj = vacRes.rows[0].vacation_subject || `Re: ${subject}`;
            const vacBody = vacRes.rows[0].vacation_body || 'I am currently out of office.';
            await db.query(
              `INSERT INTO mail_messages (
                owner_user_id, thread_id, from_name, from_email, to_emails,
                subject, body, snippet, folder, original_folder, category, is_unread
              ) VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8, 'inbox', 'inbox', 'primary', true)`,
              [
                senderUserId,
                threadId,
                recipient.full_name || recipient.username || recipient.email,
                recipient.email,
                JSON.stringify([fromEmail]),
                vacSubj,
                vacBody,
                makeSnippet(vacBody)
              ]
            );
          }
        }
      } else {
        externalRecipients.push(recipientEmail);
      }
    }

    let sentExternal = false;
    let deliveryStatus = deliveredInternal > 0 ? 'delivered_internal' : 'pending_smtp_config';
    let deliveryError = null;

    if (externalRecipients.length > 0) {
      const extResult = await externalMailService.sendExternalEmail({
        fromName,
        fromEmail,
        toList: toList.filter((e) => externalRecipients.includes(e.toLowerCase())),
        ccList: ccList.filter((e) => externalRecipients.includes(e.toLowerCase())),
        bccList: bccList.filter((e) => externalRecipients.includes(e.toLowerCase())),
        subject,
        body,
        htmlBody,
        attachments,
        rfcMessageId: finalRfcId,
        inReplyToRfc,
        referencesHeader
      });
      sentExternal = extResult.sentExternal;
      deliveryStatus = extResult.deliveryStatus;
      deliveryError = extResult.error || null;
    }

    if (senderMessageId) {
      await db.query(
        `UPDATE mail_messages
         SET rfc_message_id = COALESCE(rfc_message_id, $1),
             delivery_status = $2,
             delivery_error = $3,
             updated_at = NOW()
         WHERE id = $4`,
        [finalRfcId, deliveryStatus, deliveryError, senderMessageId]
      );
    }

    return {
      deliveredInternal,
      sentExternal,
      externalRecipientCount: externalRecipients.length,
      deliveryStatus,
      deliveryError,
      rfcMessageId: finalRfcId
    };
  }

  /**
   * Fetch all messages, labels, templates, contacts, and settings for a user.
   */
  static async listMessages(user) {
    await this.ensureUserInitialized(user);
    await this.processDueMessages(user.id);

    const res = await db.query(
      `SELECT * FROM mail_messages
       WHERE owner_user_id = $1
       ORDER BY created_at DESC`,
      [user.id]
    );

    const settingsRes = await db.query(
      'SELECT * FROM mail_settings WHERE user_id = $1',
      [user.id]
    );
    const labelsRes = await db.query(
      'SELECT id, name, color FROM mail_labels WHERE user_id = $1 ORDER BY name ASC',
      [user.id]
    );
    const templatesRes = await db.query(
      'SELECT id, name, subject, body, html_body, created_at FROM mail_templates WHERE user_id = $1 ORDER BY updated_at DESC',
      [user.id]
    );
    const contactsRes = await db.query(
      'SELECT id, name, email, phone, company, notes FROM mail_contacts WHERE user_id = $1 ORDER BY name ASC, email ASC',
      [user.id]
    );

    return {
      messages: res.rows.map(formatMessageRow),
      labels: labelsRes.rows,
      templates: templatesRes.rows.map((t) => ({
        id: t.id,
        name: t.name,
        subject: t.subject,
        body: t.body,
        htmlBody: t.html_body
      })),
      contacts: contactsRes.rows,
      settings: this.formatSettings(settingsRes.rows[0]),
      externalStatus: externalMailService.getSmtpStatus()
    };
  }

  /**
   * Send mail, schedule send, or save/update a draft (supports HTML rich-text body).
   */
  static async sendOrSaveDraft(senderUser, payload = {}) {
    await this.ensureUserInitialized(senderUser);

    const userId = senderUser.id;
    const draftId = payload.draftId || null;
    const isDraft = payload.isDraft === true;
    const fromName =
      senderUser.personalProfile?.fullName ||
      senderUser.full_name ||
      senderUser.username ||
      'CONNEKT User';
    const fromEmail = (
      senderUser.email ||
      `${senderUser.username || 'user'}@connekt.me`
    ).toLowerCase();

    const toList = parseAddressList(payload.to);
    const ccList = parseAddressList(payload.cc);
    const bccList = parseAddressList(payload.bcc);
    const subject = (payload.subject || '').toString().trim();
    let htmlBody = payload.htmlBody ? payload.htmlBody.toString() : null;
    let body = (payload.body || (htmlBody ? externalMailService.htmlToPlainText(htmlBody) : '')).toString();
    const attachments = Array.isArray(payload.attachments) ? payload.attachments : [];
    const labels = Array.isArray(payload.labels) ? payload.labels : [];
    const isConfidential = payload.isConfidential === true;
    const confidentialExpiresAt = payload.confidentialExpiresAt
      ? new Date(payload.confidentialExpiresAt)
      : null;
    const scheduledAt = payload.scheduledAt ? new Date(payload.scheduledAt) : null;
    const isScheduled = !isDraft && scheduledAt && !isNaN(scheduledAt.getTime()) && scheduledAt > new Date();
    const threadId = (payload.threadId || `thr_${crypto.randomBytes(6).toString('hex')}`).toString();
    const inReplyTo = payload.inReplyTo || null;
    const inReplyToRfc = payload.inReplyToRfc || null;
    const referencesHeader = payload.referencesHeader || null;
    const rfcMessageId = isDraft ? null : externalMailService.generateMessageId();

    // Append signature when sending
    if (!isDraft) {
      const settingsRes = await db.query(
        'SELECT signature, signature_enabled FROM mail_settings WHERE user_id = $1',
        [userId]
      );
      const settingsRow = settingsRes.rows[0];
      if (settingsRow?.signature_enabled && settingsRow.signature?.trim()) {
        const sig = settingsRow.signature.trim();
        if (!body.includes(sig)) {
          body = `${body.trimEnd()}\n\n--\n${sig}`;
          if (htmlBody) {
            htmlBody = `${htmlBody}<br><br><p>--<br>${sig.replace(/\n/g, '<br>')}</p>`;
          }
        }
      }
    }

    const folder = isDraft ? 'drafts' : isScheduled ? 'scheduled' : 'sent';
    const initialStatus = isDraft ? 'draft' : isScheduled ? 'scheduled' : 'delivered_internal';
    let savedRow;

    if (draftId) {
      const updateRes = await db.query(
        `UPDATE mail_messages
         SET to_emails = $1::jsonb,
             cc_emails = $2::jsonb,
             bcc_emails = $3::jsonb,
             subject = $4,
             body = $5,
             html_body = $6,
             snippet = $7,
             folder = $8,
             original_folder = $8,
             labels = $9::jsonb,
             attachments = $10::jsonb,
             is_confidential = $11,
             confidential_expires_at = $12,
             scheduled_at = $13,
             rfc_message_id = COALESCE($14, rfc_message_id),
             delivery_status = $15,
             updated_at = NOW()
         WHERE id = $16 AND owner_user_id = $17
         RETURNING *`,
        [
          JSON.stringify(toList),
          JSON.stringify(ccList),
          JSON.stringify(bccList),
          subject,
          body,
          htmlBody,
          makeSnippet(body),
          folder,
          JSON.stringify(labels),
          JSON.stringify(attachments),
          isConfidential,
          confidentialExpiresAt,
          isScheduled ? scheduledAt : null,
          rfcMessageId,
          initialStatus,
          draftId,
          userId
        ]
      );
      savedRow = updateRes.rows[0];
    }

    if (!savedRow) {
      const insertRes = await db.query(
        `INSERT INTO mail_messages (
          owner_user_id, thread_id, in_reply_to, rfc_message_id, in_reply_to_rfc, references_header,
          from_name, from_email, to_emails, cc_emails, bcc_emails,
          subject, body, html_body, snippet, folder, original_folder, category,
          labels, attachments, is_unread, is_confidential, confidential_expires_at,
          scheduled_at, delivery_status
        ) VALUES (
          $1, $2, $3, $4, $5, $6,
          $7, $8, $9::jsonb, $10::jsonb, $11::jsonb,
          $12, $13, $14, $15, $16, $16, 'primary',
          $17::jsonb, $18::jsonb, false, $19, $20, $21, $22
        ) RETURNING *`,
        [
          userId,
          threadId,
          inReplyTo,
          rfcMessageId,
          inReplyToRfc,
          referencesHeader,
          fromName,
          fromEmail,
          JSON.stringify(toList),
          JSON.stringify(ccList),
          JSON.stringify(bccList),
          subject,
          body,
          htmlBody,
          makeSnippet(body),
          folder,
          JSON.stringify(labels),
          JSON.stringify(attachments),
          isConfidential,
          confidentialExpiresAt,
          isScheduled ? scheduledAt : null,
          initialStatus
        ]
      );
      savedRow = insertRes.rows[0];
    }

    let deliveryInfo = {
      deliveredInternal: 0,
      sentExternal: false,
      deliveryStatus: initialStatus
    };
    if (!isDraft && !isScheduled) {
      deliveryInfo = await this._deliverToRecipients({
        senderUserId: userId,
        senderMessageId: savedRow.id,
        fromName,
        fromEmail,
        threadId,
        toList,
        ccList,
        bccList,
        subject: subject || '(no subject)',
        body,
        htmlBody,
        attachments,
        isConfidential,
        confidentialExpiresAt,
        rfcMessageId: savedRow.rfc_message_id || rfcMessageId,
        inReplyToRfc,
        referencesHeader
      });

      const refreshedRes = await db.query('SELECT * FROM mail_messages WHERE id = $1', [savedRow.id]);
      if (refreshedRes.rows[0]) {
        savedRow = refreshedRes.rows[0];
      }
    }

    return {
      message: formatMessageRow(savedRow),
      delivery: deliveryInfo
    };
  }

  /**
   * Update flags/folder/labels/snooze on a single message.
   */
  static async updateMessage(userId, messageId, patch = {}) {
    await this.ensureTable();
    const existingRes = await db.query(
      'SELECT * FROM mail_messages WHERE id = $1 AND owner_user_id = $2',
      [messageId, userId]
    );
    if (existingRes.rows.length === 0) return null;
    const current = existingRes.rows[0];

    const nextFolder = patch.folder ?? current.folder;
    const nextOriginalFolder =
      patch.folder && ['inbox', 'sent', 'drafts'].includes(patch.folder)
        ? patch.folder
        : current.original_folder;

    const res = await db.query(
      `UPDATE mail_messages
       SET is_unread = $1,
           is_starred = $2,
           is_important = $3,
           is_muted = $4,
           folder = $5,
           original_folder = $6,
           category = $7,
           labels = $8::jsonb,
           snoozed_until = $9,
           updated_at = NOW()
       WHERE id = $10 AND owner_user_id = $11
       RETURNING *`,
      [
        patch.isUnread !== undefined ? patch.isUnread === true : current.is_unread,
        patch.isStarred !== undefined ? patch.isStarred === true : current.is_starred,
        patch.isImportant !== undefined ? patch.isImportant === true : current.is_important,
        patch.isMuted !== undefined ? patch.isMuted === true : current.is_muted,
        nextFolder,
        nextOriginalFolder,
        patch.category ?? current.category,
        JSON.stringify(Array.isArray(patch.labels) ? patch.labels : current.labels || []),
        patch.snoozedUntil !== undefined
          ? (patch.snoozedUntil ? new Date(patch.snoozedUntil) : null)
          : current.snoozed_until,
        messageId,
        userId
      ]
    );
    return res.rows.length > 0 ? formatMessageRow(res.rows[0]) : null;
  }

  /**
   * Apply a bulk Gmail action across one or more message IDs.
   */
  static async bulkAction(userId, ids = [], action, extra = {}) {
    await this.ensureTable();
    if (!Array.isArray(ids) || ids.length === 0) return 0;

    switch (action) {
      case 'mark_read':
        await db.query(
          'UPDATE mail_messages SET is_unread = false, updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'mark_unread':
        await db.query(
          'UPDATE mail_messages SET is_unread = true, updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'star':
        await db.query(
          'UPDATE mail_messages SET is_starred = true, updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'unstar':
        await db.query(
          'UPDATE mail_messages SET is_starred = false, updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'important':
        await db.query(
          'UPDATE mail_messages SET is_important = true, updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'archive':
        await db.query(
          `UPDATE mail_messages SET folder = 'archive', updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids]
        );
        break;
      case 'trash':
      case 'delete':
        await db.query(
          `UPDATE mail_messages SET folder = 'trash', updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids]
        );
        break;
      case 'spam':
        await db.query(
          `UPDATE mail_messages SET folder = 'spam', updated_at = NOW() WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids]
        );
        break;
      case 'restore':
      case 'not_spam':
        await db.query(
          `UPDATE mail_messages SET folder = COALESCE(NULLIF(original_folder, ''), 'inbox'), snoozed_until = NULL, updated_at = NOW()
           WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids]
        );
        break;
      case 'snooze': {
        const until = extra.snoozedUntil ? new Date(extra.snoozedUntil) : new Date(Date.now() + 3600000 * 4);
        await db.query(
          `UPDATE mail_messages SET folder = 'snoozed', snoozed_until = $3, updated_at = NOW()
           WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids, until]
        );
        break;
      }
      case 'delete_forever':
        await db.query(
          'DELETE FROM mail_messages WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
          [userId, ids]
        );
        break;
      case 'move': {
        const targetFolder = extra.folder || 'inbox';
        const targetCategory = extra.category;
        await db.query(
          `UPDATE mail_messages
           SET folder = $3,
               original_folder = CASE WHEN $3 IN ('inbox', 'sent', 'drafts') THEN $3 ELSE original_folder END,
               category = COALESCE($4, category),
               updated_at = NOW()
           WHERE owner_user_id = $1 AND id = ANY($2::uuid[])`,
          [userId, ids, targetFolder, targetCategory || null]
        );
        break;
      }
      case 'apply_label': {
        const labelName = (extra.label || '').toString().trim();
        if (labelName) {
          const rowsRes = await db.query(
            'SELECT id, labels FROM mail_messages WHERE owner_user_id = $1 AND id = ANY($2::uuid[])',
            [userId, ids]
          );
          for (const row of rowsRes.rows) {
            const existing = Array.isArray(row.labels) ? row.labels : [];
            if (!existing.includes(labelName)) {
              await db.query(
                'UPDATE mail_messages SET labels = $1::jsonb, updated_at = NOW() WHERE id = $2',
                [JSON.stringify([...existing, labelName]), row.id]
              );
            }
          }
        }
        break;
      }
      default:
        break;
    }
    return ids.length;
  }

  static async deleteMessage(userId, messageId, permanent = false) {
    await this.ensureTable();
    const res = await db.query(
      'SELECT folder FROM mail_messages WHERE id = $1 AND owner_user_id = $2',
      [messageId, userId]
    );
    if (res.rows.length === 0) return { deleted: false };

    if (permanent || res.rows[0].folder === 'trash' || res.rows[0].folder === 'drafts') {
      await db.query('DELETE FROM mail_messages WHERE id = $1 AND owner_user_id = $2', [messageId, userId]);
      return { deleted: true, permanent: true };
    }

    await db.query(
      `UPDATE mail_messages SET folder = 'trash', updated_at = NOW() WHERE id = $1 AND owner_user_id = $2`,
      [messageId, userId]
    );
    return { deleted: true, permanent: false };
  }

  static async emptyFolder(userId, folder) {
    await this.ensureTable();
    if (!['trash', 'spam'].includes(folder)) return 0;
    const res = await db.query(
      'DELETE FROM mail_messages WHERE owner_user_id = $1 AND folder = $2 RETURNING id',
      [userId, folder]
    );
    return res.rowCount || 0;
  }

  static async createLabel(userId, name, color = '#1D4ED8') {
    await this.ensureTable();
    const cleanName = (name || '').toString().trim();
    if (!cleanName) throw new Error('Label name is required');
    const res = await db.query(
      `INSERT INTO mail_labels (user_id, name, color)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id, name) DO UPDATE SET color = EXCLUDED.color
       RETURNING id, name, color`,
      [userId, cleanName, color]
    );
    return res.rows[0];
  }

  static async deleteLabel(userId, labelId) {
    await this.ensureTable();
    const lblRes = await db.query(
      'SELECT name FROM mail_labels WHERE id = $1 AND user_id = $2',
      [labelId, userId]
    );
    if (lblRes.rows.length === 0) return false;
    const labelName = lblRes.rows[0].name;

    await db.query('DELETE FROM mail_labels WHERE id = $1 AND user_id = $2', [labelId, userId]);
    await db.query(
      `UPDATE mail_messages
       SET labels = COALESCE((
         SELECT jsonb_agg(elem)
         FROM jsonb_array_elements_text(labels) AS elem
         WHERE elem <> $2
       ), '[]'::jsonb)
       WHERE owner_user_id = $1`,
      [userId, labelName]
    );
    return true;
  }

  static formatSettings(row) {
    if (!row) {
      return {
        signature: '',
        signatureEnabled: false,
        vacationEnabled: false,
        vacationSubject: 'Out of Office',
        vacationBody: 'I am currently away and will respond when I return.',
        conversationView: true,
        rightSwipeAction: 'archive',
        leftSwipeAction: 'delete',
        compactDensity: false
      };
    }
    return {
      signature: row.signature || '',
      signatureEnabled: row.signature_enabled === true,
      vacationEnabled: row.vacation_enabled === true,
      vacationSubject: row.vacation_subject || 'Out of Office',
      vacationBody: row.vacation_body || 'I am currently away and will respond when I return.',
      conversationView: row.conversation_view !== false,
      rightSwipeAction: row.right_swipe_action || 'archive',
      leftSwipeAction: row.left_swipe_action || 'delete',
      compactDensity: row.compact_density === true
    };
  }

  static async updateSettings(userId, patch = {}) {
    await this.ensureTable();
    await db.query(
      `INSERT INTO mail_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING`,
      [userId]
    );
    const res = await db.query(
      `UPDATE mail_settings
       SET signature = COALESCE($2, signature),
           signature_enabled = COALESCE($3, signature_enabled),
           vacation_enabled = COALESCE($4, vacation_enabled),
           vacation_subject = COALESCE($5, vacation_subject),
           vacation_body = COALESCE($6, vacation_body),
           conversation_view = COALESCE($7, conversation_view),
           right_swipe_action = COALESCE($8, right_swipe_action),
           left_swipe_action = COALESCE($9, left_swipe_action),
           compact_density = COALESCE($10, compact_density),
           updated_at = NOW()
       WHERE user_id = $1
       RETURNING *`,
      [
        userId,
        patch.signature !== undefined ? patch.signature.toString() : null,
        patch.signatureEnabled !== undefined ? patch.signatureEnabled === true : null,
        patch.vacationEnabled !== undefined ? patch.vacationEnabled === true : null,
        patch.vacationSubject !== undefined ? patch.vacationSubject.toString() : null,
        patch.vacationBody !== undefined ? patch.vacationBody.toString() : null,
        patch.conversationView !== undefined ? patch.conversationView === true : null,
        patch.rightSwipeAction !== undefined ? patch.rightSwipeAction.toString() : null,
        patch.leftSwipeAction !== undefined ? patch.leftSwipeAction.toString() : null,
        patch.compactDensity !== undefined ? patch.compactDensity === true : null
      ]
    );
    return this.formatSettings(res.rows[0]);
  }

  /**
   * Ingest an external inbound email (via webhook or IMAP sync) into the matching CONNEKT user's mailbox.
   */
  static async ingestInboundEmail(parsed) {
    await this.ensureTable();
    const targetAddresses = Array.from(
      new Set([...(parsed.to || []), ...(parsed.cc || []), ...(parsed.deliveredTo ? [parsed.deliveredTo] : [])])
    )
      .map((e) => e.toString().trim().toLowerCase())
      .filter(Boolean);

    let deliveredCount = 0;
    const deliveredToUsers = [];

    for (const addr of targetAddresses) {
      const userRes = await db.query(
        `SELECT id, username, email FROM users
         WHERE LOWER(email) = LOWER($1)
            OR LOWER(username || '@connekt.me') = LOWER($1)
         LIMIT 1`,
        [addr]
      );
      if (userRes.rows.length === 0) continue;
      const recipient = userRes.rows[0];
      await this.ensureUserInitialized(recipient);

      // Deduplicate per recipient user by RFC Message-ID
      if (parsed.messageId) {
        const dupRes = await db.query(
          'SELECT id FROM mail_messages WHERE owner_user_id = $1 AND rfc_message_id = $2 LIMIT 1',
          [recipient.id, parsed.messageId]
        );
        if (dupRes.rows.length > 0) continue;
      }

      // Thread correlation strictly within recipient's own mailbox
      let threadId = null;
      if (parsed.inReplyTo) {
        const thrRes = await db.query(
          'SELECT thread_id FROM mail_messages WHERE owner_user_id = $1 AND rfc_message_id = $2 LIMIT 1',
          [recipient.id, parsed.inReplyTo]
        );
        threadId = thrRes.rows[0]?.thread_id || null;
      }
      if (!threadId) {
        threadId = `thr_${crypto.randomBytes(6).toString('hex')}`;
      }

      const authResults = parsed.authResults || {};
      const classification = externalMailService.classifyEmail({
        fromEmail: parsed.fromEmail,
        subject: parsed.subject,
        body: parsed.body,
        authResults
      });

      const insertRes = await db.query(
        `INSERT INTO mail_messages (
          owner_user_id, thread_id, rfc_message_id, in_reply_to_rfc, references_header,
          from_name, from_email, to_emails, cc_emails,
          subject, body, html_body, snippet, folder, original_folder, category,
          attachments, is_unread, delivery_status, spam_score,
          spf_status, dkim_status, dmarc_status
        ) VALUES (
          $1, $2, $3, $4, $5,
          $6, $7, $8::jsonb, $9::jsonb,
          $10, $11, $12, $13, $14, $14, $15,
          $16::jsonb, true, 'received_external', $17,
          $18, $19, $20
        ) RETURNING id`,
        [
          recipient.id,
          threadId,
          parsed.messageId || externalMailService.generateMessageId(),
          parsed.inReplyTo || null,
          parsed.references || null,
          parsed.fromName || parsed.fromEmail || 'External Sender',
          parsed.fromEmail || '',
          JSON.stringify(parsed.to || [addr]),
          JSON.stringify(parsed.cc || []),
          parsed.subject || '(no subject)',
          parsed.body || '',
          parsed.htmlBody || null,
          makeSnippet(parsed.body),
          classification.folder,
          classification.category,
          JSON.stringify(parsed.attachments || []),
          classification.spamScore,
          authResults.spfStatus || 'unknown',
          authResults.dkimStatus || 'unknown',
          authResults.dmarcStatus || 'unknown'
        ]
      );

      await db.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'new_mail', $2, $3, $4::jsonb)`,
        [
          recipient.id,
          `New email from ${parsed.fromName || parsed.fromEmail}`,
          parsed.subject || '(no subject)',
          JSON.stringify({ messageId: insertRes.rows[0].id, threadId })
        ]
      ).catch(() => {});

      deliveredCount++;
      deliveredToUsers.push(recipient.id);
    }

    return { deliveredCount, deliveredToUsers };
  }

  static async saveTemplate(userId, payload = {}) {
    await this.ensureTable();
    const name = (payload.name || '').toString().trim();
    if (!name) throw new Error('Template name is required');
    const subject = (payload.subject || '').toString();
    const body = (payload.body || '').toString();
    const htmlBody = payload.htmlBody ? payload.htmlBody.toString() : null;

    if (payload.id) {
      const res = await db.query(
        `UPDATE mail_templates
         SET name = $1, subject = $2, body = $3, html_body = $4, updated_at = NOW()
         WHERE id = $5 AND user_id = $6
         RETURNING id, name, subject, body, html_body`,
        [name, subject, body, htmlBody, payload.id, userId]
      );
      if (res.rows[0]) {
        return {
          id: res.rows[0].id,
          name: res.rows[0].name,
          subject: res.rows[0].subject,
          body: res.rows[0].body,
          htmlBody: res.rows[0].html_body
        };
      }
    }

    const res = await db.query(
      `INSERT INTO mail_templates (user_id, name, subject, body, html_body)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, name, subject, body, html_body`,
      [userId, name, subject, body, htmlBody]
    );
    return {
      id: res.rows[0].id,
      name: res.rows[0].name,
      subject: res.rows[0].subject,
      body: res.rows[0].body,
      htmlBody: res.rows[0].html_body
    };
  }

  static async deleteTemplate(userId, templateId) {
    await this.ensureTable();
    const res = await db.query(
      'DELETE FROM mail_templates WHERE id = $1 AND user_id = $2 RETURNING id',
      [templateId, userId]
    );
    return res.rowCount > 0;
  }

  static async saveContact(userId, payload = {}) {
    await this.ensureTable();
    const email = (payload.email || '').toString().trim().toLowerCase();
    if (!email || !email.includes('@')) throw new Error('Valid contact email is required');
    const name = (payload.name || email.split('@')[0]).toString().trim();
    const phone = (payload.phone || '').toString().trim();
    const company = (payload.company || '').toString().trim();
    const notes = (payload.notes || '').toString().trim();

    const res = await db.query(
      `INSERT INTO mail_contacts (user_id, name, email, phone, company, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (user_id, email) DO UPDATE SET
         name = EXCLUDED.name,
         phone = EXCLUDED.phone,
         company = EXCLUDED.company,
         notes = EXCLUDED.notes,
         updated_at = NOW()
       RETURNING id, name, email, phone, company, notes`,
      [userId, name, email, phone, company, notes]
    );
    return res.rows[0];
  }

  static async deleteContact(userId, contactId) {
    await this.ensureTable();
    const res = await db.query(
      'DELETE FROM mail_contacts WHERE id = $1 AND user_id = $2 RETURNING id',
      [contactId, userId]
    );
    return res.rowCount > 0;
  }
}

module.exports = MailModel;
