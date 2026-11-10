/**
 * CONNEKT Google Calendar API v3 Integration Service
 */
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET || '';

/**
 * Generate Google OAuth 2.0 Authorization URL
 */
function getAuthUrl(redirectUri = 'http://localhost:5000/google-callback.html') {
  if (!GOOGLE_CLIENT_ID) {
    return {
      configured: false,
      authUrl: '',
      message: 'GOOGLE_CLIENT_ID not configured in backend .env'
    };
  }

  const scopes = [
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/userinfo.email'
  ].join(' ');

  const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${GOOGLE_CLIENT_ID}&redirect_uri=${encodeURIComponent(
    redirectUri
  )}&response_type=code&scope=${encodeURIComponent(scopes)}&access_type=offline&prompt=consent`;

  return {
    configured: true,
    authUrl,
    redirectUri
  };
}

/**
 * Exchange Authorization Code for Google OAuth Tokens
 */
async function exchangeCode(code, redirectUri = 'http://localhost:5000/google-callback.html') {
  if (!GOOGLE_CLIENT_ID || !GOOGLE_CLIENT_SECRET) {
    // Return simulated tokens for development / sandbox testing
    return {
      accessToken: 'simulated_google_token_' + Date.now(),
      refreshToken: 'simulated_refresh_token_' + Date.now(),
      expiryDate: Date.now() + 3600 * 1000,
      email: 'connected_user@gmail.com',
      simulated: true
    };
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code'
    })
  });

  const tokenData = await tokenRes.json();
  if (!tokenRes.ok) {
    throw new Error(tokenData.error_description || tokenData.error || 'Failed to exchange Google OAuth code.');
  }

  let email = '';
  try {
    const userInfoRes = await fetch('https://www.googleapis.com/oauth2/v2/userinfo', {
      headers: { Authorization: `Bearer ${tokenData.access_token}` }
    });
    if (userInfoRes.ok) {
      const info = await userInfoRes.json();
      email = info.email || '';
    }
  } catch (_) {}

  return {
    accessToken: tokenData.access_token,
    refreshToken: tokenData.refresh_token || '',
    expiryDate: Date.now() + (tokenData.expires_in || 3600) * 1000,
    email,
    simulated: false
  };
}

/**
 * Synchronize a meeting with Google Calendar API v3
 */
async function syncMeetingEvent(googleTokens, meeting, baseUrl = 'http://localhost:5000') {
  if (!googleTokens || !googleTokens.accessToken) {
    throw new Error('Google account is not connected. Please authorize Google Calendar first.');
  }

  const joinUrl = `${baseUrl}/?join=CNK-${meeting.room_code}`;
  const start = meeting.scheduled_at || meeting.start_time || new Date();
  const durationMins = meeting.duration_minutes || 60;
  const end = new Date(new Date(start).getTime() + durationMins * 60000);

  // Simulation mode for local dev without credentials
  if (googleTokens.simulated || !GOOGLE_CLIENT_ID) {
    const eventId = `g_evt_${Date.now()}`;
    const meetLink = `https://meet.google.com/cnk-${meeting.room_code}`;
    return {
      synced: true,
      googleEventId: eventId,
      googleMeetLink: meetLink,
      simulated: true,
      htmlLink: `https://calendar.google.com/calendar/event?eid=${eventId}`
    };
  }

  // Live Google Calendar API v3
  const eventPayload = {
    summary: meeting.title,
    description: `${meeting.description || 'CONNEKT Scheduled Meeting'}\n\nJoin CONNEKT Call: ${joinUrl}`,
    start: { dateTime: new Date(start).toISOString() },
    end: { dateTime: end.toISOString() },
    location: `CONNEKT Room: CNK-${meeting.room_code}`,
    conferenceData: {
      createRequest: {
        requestId: `req-${meeting.room_code}-${Date.now()}`,
        conferenceSolutionKey: { type: 'hangoutsMeet' }
      }
    }
  };

  const calUrl = 'https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1';
  const res = await fetch(calUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${googleTokens.accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(eventPayload)
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.error?.message || 'Failed to create Google Calendar event.');
  }

  const meetLink = data.conferenceData?.entryPoints?.find(ep => ep.entryPointType === 'video')?.uri || '';

  return {
    synced: true,
    googleEventId: data.id,
    googleMeetLink: meetLink,
    htmlLink: data.htmlLink,
    simulated: false
  };
}

module.exports = {
  getAuthUrl,
  exchangeCode,
  syncMeetingEvent
};
