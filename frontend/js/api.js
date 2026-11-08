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
    const url = `${this.baseUrl}${endpoint}`;
    const headers = {
      ...(options.headers || {})
    };

    const token = this.getToken();
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }

    if (!(options.body instanceof FormData) && !headers['Content-Type']) {
      headers['Content-Type'] = 'application/json';
    }

    const config = {
      ...options,
      headers
    };

    try {
      const response = await fetch(url, config);
      const data = await response.json();

      if (!response.ok) {
        if (response.status === 401) {
          // Token expired or session invalid
          this.removeToken();
          window.dispatchEvent(new CustomEvent('auth:expired'));
        }
        throw new Error(data.message || 'Request failed with status ' + response.status);
      }

      return data;
    } catch (err) {
      console.error(`[API Error] ${options.method || 'GET'} ${endpoint}:`, err);
      throw err;
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

    logout: () => this.request('/auth/logout', { method: 'POST' })
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
}

// Global API instance
window.api = new ApiService();
