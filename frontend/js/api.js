/**
 * CONNEKT Client API Service
 * Handles all REST API requests, authentication headers, error envelopes
 */
class ApiService {
  constructor() {
    this.baseUrl = '/api';
    this.tokenKey = 'connekt_token';
    this.userKey = 'connekt_user';
  }

  getToken() {
    return localStorage.getItem(this.tokenKey);
  }

  setToken(token) {
    localStorage.setItem(this.tokenKey, token);
  }

  removeToken() {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
  }

  getUser() {
    try {
      const u = localStorage.getItem(this.userKey);
      return u ? JSON.parse(u) : null;
    } catch (e) {
      return null;
    }
  }

  setUser(user) {
    localStorage.setItem(this.userKey, JSON.stringify(user));
  }

  async request(endpoint, options = {}) {
    const {
      skipAuthExpired = false,
      timeoutMs = 0,
      headers: customHeaders = {},
      ...fetchOptions
    } = options;

    const url = `${this.baseUrl}${endpoint}`;
    const headers = {
      ...customHeaders
    };

    const token = this.getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    if (!(fetchOptions.body instanceof FormData) && !headers['Content-Type']) {
      headers['Content-Type'] = 'application/json';
    }

    let controller = null;
    let timeoutId = null;
    if (timeoutMs > 0 && !fetchOptions.signal && typeof AbortController !== 'undefined') {
      controller = new AbortController();
      timeoutId = setTimeout(() => controller.abort(), timeoutMs);
    }

    const config = {
      ...fetchOptions,
      headers,
      ...(controller ? { signal: controller.signal } : {})
    };

    try {
      const response = await fetch(url, config);
      const rawText = await response.text();
      let data = {};
      if (rawText) {
        try {
          data = JSON.parse(rawText);
        } catch (_) {
          data = { message: rawText };
        }
      }

      if (!response.ok) {
        if (response.status === 401 && !skipAuthExpired) {
          // Token expired or session invalid
          this.removeToken();
          window.dispatchEvent(new CustomEvent('auth:expired'));
        }
        throw new Error(data.message || 'Request failed with status ' + response.status);
      }

      return data;
    } catch (err) {
      console.error(`[API Error] ${fetchOptions.method || 'GET'} ${endpoint}:`, err);
      throw err;
    } finally {
      if (timeoutId) clearTimeout(timeoutId);
    }
  }

  // Authentication API endpoints
  auth = {
    checkAvailability: (field, value) => 
      this.request(`/auth/check-availability?field=${encodeURIComponent(field)}&value=${encodeURIComponent(value)}`),

    sendOtp: (identifier, purpose = 'registration') => 
      this.request('/auth/send-otp', {
        method: 'POST',
        body: JSON.stringify({ identifier, purpose })
      }),

    verifyOtp: (identifier, code, purpose = 'registration') =>
      this.request('/auth/verify-otp', {
        method: 'POST',
        body: JSON.stringify({ identifier, code, purpose })
      }),

    register: (payload) =>
      this.request('/auth/register', {
        method: 'POST',
        body: JSON.stringify(payload)
      }),

    login: (payload) =>
      this.request('/auth/login', {
        method: 'POST',
        body: JSON.stringify(payload)
      }),

    resetPassword: (payload) =>
      this.request('/auth/forgot-password', {
        method: 'POST',
        body: JSON.stringify(payload)
      }),

    getMe: () => this.request('/auth/me'),

    logout: () => this.request('/auth/logout', {
      method: 'POST',
      skipAuthExpired: true,
      timeoutMs: 3000
    })
  };

  // User & Mode Management API endpoints
  user = {
    switchMode: (mode) =>
      this.request('/users/mode', {
        method: 'POST',
        body: JSON.stringify({ mode })
      }),

    updatePersonalProfile: (data) =>
      this.request('/users/profile/personal', {
        method: 'PUT',
        body: JSON.stringify(data)
      }),

    updateProfessionalProfile: (data) =>
      this.request('/users/profile/professional', {
        method: 'PUT',
        body: JSON.stringify(data)
      }),

    uploadAvatar: (formData) =>
      this.request('/users/profile/avatar', {
        method: 'POST',
        body: formData
      }),

    addSkill: (data) =>
      this.request('/users/skills', {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    deleteSkill: (skillId) =>
      this.request(`/users/skills/${skillId}`, {
        method: 'DELETE'
      }),

    addEducation: (data) =>
      this.request('/users/education', {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    deleteEducation: (eduId) =>
      this.request(`/users/education/${eduId}`, {
        method: 'DELETE'
      }),

    addExperience: (data) =>
      this.request('/users/experience', {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    deleteExperience: (expId) =>
      this.request(`/users/experience/${expId}`, {
        method: 'DELETE'
      }),

    getPrivacy: () => this.request('/users/privacy'),

    updatePrivacy: (data) =>
      this.request('/users/privacy', {
        method: 'PUT',
        body: JSON.stringify(data)
      })
  };

  // Sessions and Devices API endpoints
  sessions = {
    getSessions: () => this.request('/sessions'),

    revokeSession: (sessionId) =>
      this.request(`/sessions/${sessionId}`, {
        method: 'DELETE'
      }),

    revokeAllOther: () =>
      this.request('/sessions', {
        method: 'DELETE'
      })
  };

  // Meetings & Collaboration API endpoints (Phase 1)
  meetings = {
    createInstantRoom: (title) =>
      this.request('/meetings/rooms/create', {
        method: 'POST',
        body: JSON.stringify({ title: title || 'Instant Meeting' })
      }),

    getRoom: (roomCode) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}`),

    joinRoom: (roomCode, passcode = '') =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/join`, {
        method: 'POST',
        body: JSON.stringify({ passcode })
      }),

    leaveRoom: (roomCode) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/leave`, {
        method: 'POST'
      }),

    endRoom: (roomCode) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/end`, {
        method: 'POST'
      }),

    listMeetings: (params = {}) => {
      const q = new URLSearchParams(params).toString();
      return this.request(`/meetings${q ? '?' + q : ''}`);
    },

    scheduleMeeting: (data) =>
      this.request('/meetings', {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    getMeeting: (id) =>
      this.request(`/meetings/${id}`),

    updateMeeting: (id, data) =>
      this.request(`/meetings/${id}`, {
        method: 'PUT',
        body: JSON.stringify(data)
      }),

    cancelMeeting: (id) =>
      this.request(`/meetings/${id}`, {
        method: 'DELETE'
      }),

    toggleLock: (id, isLocked) =>
      this.request(`/meetings/${id}/lock`, {
        method: 'PATCH',
        body: JSON.stringify({ isLocked })
      }),

    // Signaling & Chat (Phase 2)
    sendSignal: (roomCode, data) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/signal`, {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    getPendingSignals: (roomCode) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/signals`),

    getChatMessages: (roomCode) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/chat`),

    sendChatMessage: (roomCode, message) =>
      this.request(`/meetings/rooms/${encodeURIComponent(roomCode)}/chat`, {
        method: 'POST',
        body: JSON.stringify({ message })
      }),

    // Meeting Records, Minutes & Action Items (Phase 4)
    getAttendance: (id) =>
      this.request(`/meetings/${id}/attendance`),

    getMinutes: (id) =>
      this.request(`/meetings/${id}/minutes`),

    saveMinutes: (id, data) =>
      this.request(`/meetings/${id}/minutes`, {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    addActionItem: (id, data) =>
      this.request(`/meetings/${id}/action-items`, {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    updateActionItem: (id, itemId, data) =>
      this.request(`/meetings/${id}/action-items/${itemId}`, {
        method: 'PUT',
        body: JSON.stringify(data)
      }),

    deleteActionItem: (id, itemId) =>
      this.request(`/meetings/${id}/action-items/${itemId}`, {
        method: 'DELETE'
      }),

    logRecording: (id, data) =>
      this.request(`/meetings/${id}/recordings`, {
        method: 'POST',
        body: JSON.stringify(data)
      }),

    getRecordings: (id) =>
      this.request(`/meetings/${id}/recordings`),

    // Phase 5: Action Items to Tasks, Google Calendar & Email Integrations
    convertActionItemToTask: (id, itemId) =>
      this.request(`/meetings/${id}/action-items/${itemId}/convert`, {
        method: 'POST'
      }),

    getGoogleAuthUrl: (redirectUri) =>
      this.request(`/meetings/google/auth-url${redirectUri ? '?redirectUri=' + encodeURIComponent(redirectUri) : ''}`),

    handleGoogleCallback: (code, redirectUri) =>
      this.request('/meetings/google/callback', {
        method: 'POST',
        body: JSON.stringify({ code, redirectUri })
      }),

    getGoogleStatus: () =>
      this.request('/meetings/google/status'),

    disconnectGoogle: () =>
      this.request('/meetings/google/disconnect', {
        method: 'POST'
      }),

    syncGoogleCalendar: (id) =>
      this.request(`/meetings/${id}/sync-google`, {
        method: 'POST'
      }),

    sendMeetingInvitations: (id, recipients = []) =>
      this.request(`/meetings/${id}/send-invites`, {
        method: 'POST',
        body: JSON.stringify({ recipients })
      })
  };

  // Phone Contacts & Device Call Logs API endpoints (Synced with Mobile App)
  calls = {
    getDeviceLogs: (params = {}) => {
      const q = new URLSearchParams(params).toString();
      return this.request(`/calls/device-logs${q ? '?' + q : ''}`);
    },

    requestSync: () =>
      this.request('/calls/request-sync', {
        method: 'POST'
      }),

    getSyncStatus: () =>
      this.request('/calls/sync-status')
  };

  // Reminders API (Synced with Mobile App & PostgreSQL Database)
  reminders = {
    getAll: () => this.request('/reminders'),
    create: (data) => this.request('/reminders', {
      method: 'POST',
      body: JSON.stringify(data)
    }),
    update: (id, data) => this.request(`/reminders/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),
    toggleComplete: (id) => this.request(`/reminders/${id}/toggle`, {
      method: 'PATCH'
    }),
    delete: (id) => this.request(`/reminders/${id}`, {
      method: 'DELETE'
    })
  };

  // Dynamic Translation API
  translate = {
    translateText: (text, targetLang, sourceLang = 'auto') => this.request('/translate', {
      method: 'POST',
      body: JSON.stringify({ text, targetLang, sourceLang })
    })
  };
}

// Global API instance
window.api = new ApiService();
