/**
 * CONNEKT Meeting Email & iCalendar Notification Service
 */
const nodemailer = require('nodemailer');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

let transporter = null;
if (process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SMTP_PASS !== 'app_password_placeholder') {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });
}

/**
 * Format Date to iCalendar UTC format (e.g. 20261109T180000Z)
 */
function toICalDate(d) {
  const date = new Date(d);
  return date.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
}

/**
 * Generate standard RFC 5545 iCalendar (.ics) content
 */
function generateICalendar(meeting, hostName = 'Host', hostEmail = 'host@connekt.me', joinUrl = '') {
  const start = meeting.scheduled_at || meeting.start_time || new Date();
  const durationMins = meeting.duration_minutes || 60;
  const end = new Date(new Date(start).getTime() + durationMins * 60000);

  const dtStart = toICalDate(start);
  const dtEnd = toICalDate(end);
  const dtStamp = toICalDate(new Date());
  const uid = `cnk-${meeting.room_code || meeting.id}@connekt.me`;

  const icsLines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//CONNEKT//Meetings Collaboration//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:REQUEST',
    'BEGIN:VEVENT',
    `UID:${uid}`,
    `DTSTAMP:${dtStamp}`,
    `DTSTART:${dtStart}`,
    `DTEND:${dtEnd}`,
    `SUMMARY:${meeting.title || 'CONNEKT Meeting'}`,
    `DESCRIPTION:${(meeting.description || 'CONNEKT Video Conference')}\\n\\nRoom Code: CNK-${meeting.room_code}\\nJoin Meeting: ${joinUrl}`,
    `LOCATION:CONNEKT Room CNK-${meeting.room_code} (${joinUrl})`,
    `ORGANIZER;CN=${hostName}:mailto:${hostEmail}`,
    'STATUS:CONFIRMED',
    'BEGIN:VALARM',
    'TRIGGER:-PT15M',
    'ACTION:DISPLAY',
    'DESCRIPTION:Reminder: Upcoming CONNEKT Meeting in 15 minutes',
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR'
  ];

  return icsLines.join('\r\n');
}

/**
 * Send meeting invitation email to a participant or list of participants
 */
async function sendMeetingInvitation({ meeting, hostUser, recipients = [], baseUrl = 'http://localhost:5000' }) {
  if (!recipients || recipients.length === 0) return { success: true, count: 0 };

  const hostName = hostUser?.personalProfile?.fullName || hostUser?.username || 'CONNEKT Host';
  const hostEmail = hostUser?.email || 'noreply@connekt.me';
  const joinUrl = `${baseUrl}/?join=CNK-${meeting.room_code}`;
  const icsContent = generateICalendar(meeting, hostName, hostEmail, joinUrl);

  const scheduledDate = meeting.scheduled_at ? new Date(meeting.scheduled_at) : new Date();
  const formattedDate = scheduledDate.toLocaleString('en-US', {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  });

  const htmlBody = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0b0f19; color: #f1f5f9; padding: 24px; margin: 0; }
        .card { background-color: #12192c; border: 1px solid #1e293b; border-radius: 12px; padding: 32px; max-width: 580px; margin: 0 auto; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        .logo { font-size: 24px; font-weight: 800; color: #38bdf8; margin-bottom: 20px; letter-spacing: 1px; }
        .logo span { color: #f43f5e; }
        h2 { margin: 0 0 12px 0; color: #ffffff; font-size: 20px; }
        .badge { display: inline-block; background: rgba(56, 189, 248, 0.15); color: #38bdf8; padding: 4px 10px; border-radius: 6px; font-size: 13px; font-weight: 600; margin-bottom: 20px; }
        .details-box { background: rgba(0,0,0,0.25); border: 1px solid #1e293b; border-radius: 8px; padding: 18px; margin: 20px 0; }
        .detail-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 14px; }
        .detail-row:last-child { border-bottom: none; }
        .label { color: #94a3b8; }
        .val { color: #f8fafc; font-weight: 600; }
        .btn { display: inline-block; background-color: #2563eb; color: #ffffff !important; padding: 12px 28px; border-radius: 8px; text-decoration: none; font-weight: 700; font-size: 15px; margin: 24px 0 16px 0; text-align: center; }
        .footer { font-size: 12px; color: #64748b; margin-top: 24px; text-align: center; line-height: 1.5; }
      </style>
    </head>
    <body>
      <div class="card">
        <div class="logo">CONNEKT<span>.</span></div>
        <div class="badge">MEETING INVITATION</div>
        <h2>${meeting.title}</h2>
        <p style="color: #cbd5e1; font-size: 14.5px; line-height: 1.5; margin-bottom: 20px;">
          <strong>${hostName}</strong> has invited you to join a real-time CONNEKT meeting.
        </p>

        <div class="details-box">
          <div class="detail-row">
            <span class="label">Date & Time:</span>
            <span class="val">${formattedDate}</span>
          </div>
          <div class="detail-row">
            <span class="label">Duration:</span>
            <span class="val">${meeting.duration_minutes || 60} Minutes</span>
          </div>
          <div class="detail-row">
            <span class="label">Room Code:</span>
            <span class="val" style="font-family: monospace; color: #38bdf8;">CNK-${meeting.room_code}</span>
          </div>
          ${meeting.agenda ? `
          <div class="detail-row">
            <span class="label">Agenda:</span>
            <span class="val">${meeting.agenda}</span>
          </div>` : ''}
          ${meeting.passcode ? `
          <div class="detail-row">
            <span class="label">Passcode:</span>
            <span class="val" style="color: #fbbf24;">${meeting.passcode}</span>
          </div>` : ''}
        </div>

        <div style="text-align: center;">
          <a href="${joinUrl}" class="btn">Join Meeting Now 📹</a>
        </div>

        <p style="color: #94a3b8; font-size: 13px; text-align: center;">
          Or copy and paste this direct link into your browser:<br/>
          <span style="color: #38bdf8; word-break: break-all;">${joinUrl}</span>
        </p>

        <div class="footer">
          A calendar invitation (.ics) is attached to this email.<br/>
          CONNEKT Real-Time Unified Collaboration Suite.
        </div>
      </div>
    </body>
    </html>
  `;

  // Dispatch via Nodemailer if configured
  if (transporter) {
    try {
      await transporter.sendMail({
        from: `"${hostName} via CONNEKT" <${process.env.SMTP_USER}>`,
        to: recipients.join(', '),
        subject: `Invitation: ${meeting.title} @ ${formattedDate}`,
        html: htmlBody,
        icalEvent: {
          filename: `invitation-${meeting.room_code}.ics`,
          method: 'REQUEST',
          content: icsContent
        }
      });
      console.log(`[MeetingEmail] Sent invitation email to ${recipients.length} recipients`);
      return { success: true, count: recipients.length, simulated: false };
    } catch (err) {
      console.warn(`[MeetingEmail] SMTP dispatch failed, fallback to simulated:`, err.message);
    }
  }

  // Simulated email dispatch (Development / No SMTP configured)
  console.log(`[MeetingEmail Simulation] Email invitation logged for ${recipients.length} recipients (${recipients.join(', ')}) for room CNK-${meeting.room_code}`);
  return { success: true, count: recipients.length, simulated: true };
}

module.exports = {
  generateICalendar,
  sendMeetingInvitation
};
