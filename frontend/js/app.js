/**
 * CONNEKT Main Application Orchestrator
 * Pure Vanilla JavaScript ES6+ Architecture
 */

class AppController {
  constructor() {
    this.currentUser = null;
    this.activeModule = 'home';
    this.activeMode = 'common'; // 'common' | 'professional' | 'both'
    this.globalSocket = null;
    this._isLoggingOut = false;
    this.reminders = [];
    this.calendarDate = new Date();
    this.pinSecurityActive = localStorage.getItem('connekt_pin_enabled') === 'true';
  }

  async init() {
    this.initTheme();
    this.setupGlobalListeners();
    window.authManager.init();

    // Support URL Hash Navigation (e.g. #meetings, #call_logs, #home, #profile)
    const initialHash = window.location.hash.replace('#', '');
    if (initialHash && ['home', 'meetings', 'call_logs', 'profile', 'settings', 'messages', 'communities', 'mail'].includes(initialHash)) {
      this.activeModule = initialHash;
    } else if (initialHash.startsWith('meet/')) {
      this.activeModule = 'meetings';
      const codeFromHash = initialHash.replace('meet/', '').trim();
      setTimeout(() => this.handleDirectJoinRoom(codeFromHash), 600);
    }

    // Direct pathname navigation (e.g. /meet/abc-defg-hij)
    if (window.location.pathname.startsWith('/meet/')) {
      const codeFromPath = window.location.pathname.replace('/meet/', '').split('/')[0].trim();
      if (codeFromPath) {
        this.activeModule = 'meetings';
        setTimeout(() => this.handleDirectJoinRoom(codeFromPath), 600);
      }
    }

    window.addEventListener('hashchange', () => {
      const h = window.location.hash.replace('#', '');
      if (h && h !== this.activeModule) {
        this.navigateTo(h, false);
      }
    });

    // Check if user is logged in
    const token = window.api.getToken();
    if (token) {
      await this.loadUserProfile();
      this.initGlobalSocket();
      this.triggerCallLogsSync();
    } else {
      this.showAuthModal(true);
    }
  }

  setupGlobalListeners() {
    // Auth login/register success event
    window.addEventListener('auth:login_success', (e) => {
      this.currentUser = e.detail;
      this.showAuthModal(false);
      this.applyUserSession();
      this.renderCurrentView();
      this.initGlobalSocket();
      this.triggerCallLogsSync();
    });

    // Auth expired event
    window.addEventListener('auth:expired', () => {
      if (this._isLoggingOut) return;
      this._resetClientSessionUI();
      this.showToast('Your session has expired. Please sign in again.', 'warning');
    });

    // Mobile menu toggle
    const burger = document.getElementById('mobileMenuToggle');
    const sidebar = document.getElementById('appSidebar');
    const overlay = document.getElementById('mobileOverlay');

    if (burger && sidebar && overlay) {
      burger.addEventListener('click', () => {
        sidebar.classList.toggle('mobile-open');
        overlay.classList.toggle('active');
      });

      overlay.addEventListener('click', () => {
        sidebar.classList.remove('mobile-open');
        overlay.classList.remove('active');
      });
    }

    // Navigation items
    document.querySelectorAll('.nav-item[data-module]').forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const mod = e.currentTarget.dataset.module;
        this.navigateTo(mod);

        // Close mobile drawer if open
        sidebar?.classList.remove('mobile-open');
        overlay?.classList.remove('active');
      });
    });

    // Mode Switcher Pills in Topbar
    document.querySelectorAll('.mode-pill-btn').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const mode = e.currentTarget.dataset.mode;
        await this.switchMode(mode);
      });
    });

    // Logout button
    const logoutBtn = document.getElementById('btnLogout');
    if (logoutBtn) {
      logoutBtn.addEventListener('click', () => this.handleLogout());
    }

    // Avatar file input change listener
    const avatarInput = document.getElementById('avatarFileInput');
    if (avatarInput) {
      avatarInput.addEventListener('change', (e) => this.handleAvatarUpload(e));
    }
  }

  initTheme() {
    const savedTheme = localStorage.getItem('connekt-theme') || 'dark';
    this.setTheme(savedTheme, false);
  }

  setTheme(theme, notify = true) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('connekt-theme', theme);
    const icon = document.getElementById('themeToggleIcon');
    if (icon) {
      icon.textContent = theme === 'light' ? '☀️' : '🌙';
    }
    const btn = document.getElementById('btnThemeToggle');
    if (btn) {
      btn.title = theme === 'light' ? 'Switch to Dark Mood' : 'Switch to Light Mood';
    }
    if (notify) {
      this.showToast(`Switched to ${theme === 'light' ? 'Light Mood ☀️' : 'Dark Mood 🌙'}`, 'info');
    }
  }

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'dark';
    const next = current === 'dark' ? 'light' : 'dark';
    this.setTheme(next, true);
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    let icon = 'ℹ️';
    if (type === 'success') icon = '✅';
    if (type === 'error') icon = '❌';
    if (type === 'warning') icon = '⚠️';

    toast.innerHTML = `
      <div style="display: flex; align-items: center; gap: 8px;">
        <span>${icon}</span>
        <span>${message}</span>
      </div>
      <button style="background: none; border: none; color: inherit; cursor: pointer; font-size: 1.1rem;" onclick="this.parentElement.remove()">×</button>
    `;

    container.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(50px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 4500);
  }

  showLoading(isLoading) {
    const loader = document.getElementById('globalLoader');
    if (loader) {
      loader.style.display = isLoading ? 'flex' : 'none';
    }
  }

  showAuthModal(show) {
    const modal = document.getElementById('authModal');
    if (modal) {
      if (show) modal.classList.add('active');
      else modal.classList.remove('active');
    }
  }

  async loadUserProfile() {
    try {
      this.showLoading(true);
      const res = await window.api.auth.getMe();
      this.currentUser = res.data.user;
      this.applyUserSession();
      this.renderCurrentView();
    } catch (err) {
      console.error('Failed to load user profile:', err);
      this.showAuthModal(true);
    } finally {
      this.showLoading(false);
    }
  }

  applyUserSession() {
    if (!this.currentUser) return;

    const user = this.currentUser;
    this.activeMode = user.current_mode || 'common';

    // Update Mode Switcher Active Pill
    document.querySelectorAll('.mode-pill-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mode === this.activeMode);
    });

    // Update Sidebar User Card
    const avatar = document.getElementById('sidebarAvatar');
    const name = document.getElementById('sidebarName');
    const handle = document.getElementById('sidebarHandle');
    const topAvatar = document.getElementById('topbarAvatar');
    const modeBadge = document.getElementById('activeModeBadge');

    const displayName = user.personalProfile?.display_name || user.personalProfile?.full_name || user.username;
    const fallbackAvatar = '/assets/images/default-avatar.png';
    const avatarUrl = user.personalProfile?.avatar_url || fallbackAvatar;

    this._setImgWithFallback(avatar, avatarUrl, fallbackAvatar);
    this._setImgWithFallback(topAvatar, avatarUrl, fallbackAvatar);
    if (name) name.textContent = displayName;
    if (handle) handle.textContent = `@${user.username}`;
    if (modeBadge) {
      modeBadge.textContent = `${this.activeMode.toUpperCase()} MODE`;
      modeBadge.className = `badge badge-mode ${this.activeMode === 'professional' ? 'badge-primary' : 'badge-success'}`;
    }

    // Hide auth modal if open
    this.showAuthModal(false);
  }

  async switchMode(mode) {
    if (mode === this.activeMode) return;

    try {
      this.showLoading(true);
      const res = await window.api.user.switchMode(mode);
      this.activeMode = res.data.currentMode;
      this.currentUser.current_mode = this.activeMode;
      this.showToast(`Switched to ${this.activeMode.toUpperCase()} Mode!`, 'success');
      this.applyUserSession();
      this.renderCurrentView();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  navigateTo(moduleName, updateHash = true) {
    this.activeModule = moduleName;
    if (updateHash && window.location.hash !== `#${moduleName}`) {
      window.location.hash = moduleName;
    }

    document.querySelectorAll('.nav-item[data-module]').forEach(item => {
      item.classList.toggle('active', item.dataset.module === moduleName);
    });

    this.renderCurrentView();
  }

  renderCurrentView() {
    const mainContent = document.getElementById('mainContentArea');
    if (!mainContent) return;

    switch (this.activeModule) {
      case 'home':
        this.renderHomeView(mainContent);
        break;
      case 'meetings':
        this.meetingsMainTab = 'meetings';
        this.renderMeetingsDashboard(mainContent);
        break;
      case 'call_logs':
        this.meetingsMainTab = 'call_logs';
        this.renderMeetingsDashboard(mainContent);
        break;
      case 'profile':
        this.renderProfileView(mainContent);
        break;
      case 'settings':
        this.renderSettingsView(mainContent);
        break;
      case 'schedule':
      case 'reminders':
        this.renderScheduleView(mainContent);
        break;
      case 'messages':
      case 'communities':
      case 'mail':
      case 'network':
      case 'ai':
      case 'shield':
        this.renderPhaseModulePlaceholder(mainContent, this.activeModule);
        break;
      default:
        this.renderHomeView(mainContent);
    }
  }

  async renderHomeView(container) {
    const user = this.currentUser;
    const email = user.email ? (user.email.includes('@connekt.net.in') ? user.email : user.username + '@connekt.net.in') : (user.username + '@connekt.net.in');
    
    // Load reminders in background if needed
    if (!this.reminders || this.reminders.length === 0) {
      try {
        const res = await window.api.reminders.getAll();
        this.reminders = res.data || [];
      } catch (_) {}
    }

    const pendingRemindersCount = (this.reminders || []).filter(r => !r.is_completed).length;

    // Mini calendar calculations for current month
    const now = new Date();
    const curYear = now.getFullYear();
    const curMonth = now.getMonth();
    const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const monthStr = monthNames[curMonth] + " " + curYear;

    const firstDay = new Date(curYear, curMonth, 1).getDay();
    const daysInMonth = new Date(curYear, curMonth + 1, 0).getDate();

    let calCellsHtml = '';
    for (let i = 0; i < firstDay; i++) {
      calCellsHtml += '<div class="mini-cal-cell empty"></div>';
    }

    for (let d = 1; d <= daysInMonth; d++) {
      const cellDate = new Date(curYear, curMonth, d);
      const isToday = d === now.getDate();
      const hasReminder = (this.reminders || []).some(r => this._matchesReminderDate(r, cellDate));
      
      let classes = 'mini-cal-cell';
      let dot = '';
      if (isToday) classes += ' today';
      if (hasReminder) {
        classes += ' has-reminder';
        dot = '<div class="mini-cal-dot red"></div>';
      }

      calCellsHtml += `<div class="${classes}">${d}${dot}</div>`;
    }

    const isProf = this.activeMode === 'professional';

    container.innerHTML = `
      <!-- Cyber Top Header Banner with CONNEKT Logo & Tagline -->
      <div class="app-cyber-header">
        <div class="brand-title-box">
          <h1>CONNEKT</h1>
          <p>CONNECTING THE UNCONNECTED</p>
        </div>
        <button class="btn btn-secondary btn-sm" onclick="window.i18n.showLanguageSelector()" style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.2); border-radius: 8px; color: #ffffff; display: flex; align-items: center; gap: 6px; padding: 6px 12px; cursor: pointer; font-weight: 700;">
          <span style="font-size: 1.1rem;">A/文</span>
          <span style="font-size: 0.82rem;">${window.i18n ? window.i18n.getCurrentLanguage().name : 'English'}</span>
        </button>
      </div>

      <!-- Top Dashboard Grid (Schedule, World Clock, Reminder, Quick Notes) -->
      <div class="home-top-grid">
        <!-- Schedule Mini Calendar Card -->
        <div class="schedule-mini-card" onclick="window.app.navigateTo('schedule')" title="Click to open Full Schedule & Calendar">
          <div class="mini-cal-header">
            <span class="mini-cal-title">Schedule</span>
            <span class="mini-cal-month">${monthStr}</span>
          </div>
          <div class="mini-cal-days-row">
            <span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span>
          </div>
          <div class="mini-cal-grid">
            ${calCellsHtml}
          </div>
        </div>

        <!-- Right Widgets Column -->
        <div class="home-widgets-col">
          <!-- World Clock Widget -->
          <div class="widget-pill-card" onclick="window.app.showWorldClockModal()">
            <div class="widget-pill-left">
              <div class="widget-pill-icon">🕒</div>
              <span class="widget-pill-title">World Clock</span>
            </div>
            <span id="homeClockDisplay" style="font-size: 0.85rem; font-weight: 700; color: var(--accent-cyan);">
              ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          </div>

          <!-- Reminder Widget with Live Counter Badge -->
          <div class="widget-pill-card" onclick="window.app.showRemindersModal()">
            <div class="widget-pill-left">
              <div class="widget-pill-icon">☑️</div>
              <span class="widget-pill-title">Reminder</span>
            </div>
            <span class="widget-counter-badge">${pendingRemindersCount}</span>
          </div>

          <!-- Quick Notes Sticky Card -->
          <div class="quick-notes-sticky-card" onclick="window.app.showQuickNotesModal()" title="Open Quick Notes">
            <h3>Quick Notes</h3>
          </div>
        </div>
      </div>

      <!-- CONNEKT Identity Banner Card -->
      <div class="identity-banner-card">
        <div class="id-left-brand">
          <div class="id-logo-row">
            <div class="brand-logo" style="width: 32px; height: 32px; font-size: 1.1rem; border-radius: 8px;">C</div>
            <div>
              <div style="font-weight: 800; font-size: 1.1rem; letter-spacing: 0.05em;">CONNEKT</div>
              <div style="font-size: 0.68rem; color: var(--text-muted); font-weight: 600; letter-spacing: 0.08em;">CONNECTING THE UNCONNECTED</div>
            </div>
          </div>
          <div class="id-email-text">${email}</div>
          <div class="pro-toggle-row">
            <label class="switch" style="position: relative; display: inline-block; width: 44px; height: 24px; margin-right: 6px;">
              <input type="checkbox" ${isProf ? 'checked' : ''} onchange="window.app.switchMode(this.checked ? 'professional' : 'common')" style="opacity: 0; width: 0; height: 0;" />
              <span class="slider round" style="position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: ${isProf ? '#2563eb' : '#475569'}; transition: .3s; border-radius: 24px;"></span>
            </label>
            <span>Switch to ${isProf ? 'Personal' : 'Professional'}</span>
          </div>
        </div>

        <div class="id-actions-col">
          <button class="btn-profile-coral" onclick="window.app.navigateTo('profile')">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span>👤</span>
              <span>Your Profile</span>
            </div>
            <span style="width: 8px; height: 8px; border-radius: 50%; background: #22c55e;"></span>
          </button>
          <button class="btn-invite-blue" onclick="window.app.showInviteFriendsModal()">
            <span>👥</span>
            <span>Invite Friends</span>
          </button>
        </div>
      </div>

      <!-- Quick Action Cards: Chat, Mail, Meeting -->
      <div class="action-card-row">
        <!-- Chat Card -->
        <div class="action-row-card" onclick="window.app.navigateTo('messages')">
          <div class="action-row-left">
            <span class="action-row-icon" style="color: #3b82f6;">💬</span>
            <span class="action-row-title">Chat</span>
          </div>
          <span class="action-badge-red">2</span>
        </div>

        <!-- Mail Card -->
        <div class="action-row-card" onclick="window.app.navigateTo('mail')">
          <div class="action-row-left">
            <span class="action-row-icon" style="color: #8b5cf6;">✉️</span>
            <span class="action-row-title">Mail</span>
          </div>
          <span class="action-badge-red">4</span>
        </div>

        <!-- Meeting Card -->
        <div class="action-row-card" onclick="window.app.navigateTo('meetings')">
          <div class="action-row-left">
            <span class="action-row-icon" style="color: #06b6d4;">📹</span>
            <span class="action-row-title">Meeting</span>
          </div>
          <span style="font-size: 1.2rem; color: var(--text-muted);">→</span>
        </div>
      </div>

      <!-- Vibe Banner matching mobile app -->
      <div class="vibe-banner-container" onclick="window.app.showToast('Vibe Social Feed active!', 'info')">
        <img src="/assets/images/vibe_banner.png" alt="Vibe" onerror="this.parentElement.style.display='none'" />
      </div>
    `;
  }

  renderProfileView(container) {
    const user = this.currentUser;
    const personal = user.personalProfile || {};
    const prof = user.professionalProfile || {};
    const email = user.email ? (user.email.includes('@connekt.net.in') ? user.email : user.username + '@connekt.net.in') : (user.username + '@connekt.net.in');
    const displayName = personal.full_name || personal.display_name || user.username;
    const avatarUrl = personal.avatar_url || '/assets/images/default-avatar.png';
    const isPinActive = localStorage.getItem('connekt_pin_enabled') === 'true';

    container.innerHTML = `
      <!-- Top Title Bar -->
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <button class="icon-btn" onclick="window.app.navigateTo('home')" style="font-size: 1.2rem;">←</button>
          <h2 style="margin: 0; font-size: 1.4rem; font-weight: 800;">My Profile & Security</h2>
        </div>
        <button class="icon-btn" onclick="window.app.handleLogout()" title="Sign Out" style="color: #ef4444; font-size: 1.2rem;">🚪</button>
      </div>

      <!-- Profile Header Card -->
      <div class="card" style="text-align: center; padding: 24px 20px; margin-bottom: 20px; border-radius: var(--radius-lg);">
        <div style="position: relative; display: inline-block; margin-bottom: 14px;">
          <img src="${avatarUrl}" onerror="this.src='/assets/images/default-avatar.png'" style="width: 90px; height: 90px; border-radius: 50%; object-fit: cover; border: 3px solid #2563eb;" />
          <button onclick="document.getElementById('avatarFileInput')?.click()" style="position: absolute; bottom: 0; right: 0; background: #2563eb; color: white; border: none; border-radius: 50%; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; font-size: 0.85rem; cursor: pointer; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
            📷
          </button>
          <input type="file" id="avatarFileInput" accept="image/*" style="display: none;" onchange="window.app.handleAvatarUpload(event)" />
        </div>

        <h3 style="font-size: 1.35rem; font-weight: 800; margin-bottom: 4px; display: flex; align-items: center; justify-content: center; gap: 6px;">
          <span>${displayName}</span>
          <span style="color: #3b82f6; font-size: 1.1rem;" title="Verified User">✓</span>
        </h3>
        <div style="color: var(--accent-cyan); font-weight: 600; font-size: 0.9rem; margin-bottom: 8px;">@${user.username}</div>

        <!-- Standardized Email Pill with Copy Button -->
        <div class="profile-pill-email">
          <span>@</span>
          <span>${email}</span>
          <button class="icon-btn" onclick="window.app.copyToClipboard('${email}', 'Email copied to clipboard!')" style="padding: 2px 4px; font-size: 0.9rem; color: var(--text-secondary);" title="Copy email">
            📋
          </button>
        </div>

        <div style="margin-top: 14px;">
          <button class="btn btn-primary" onclick="window.app.switchProfileTab('personal')" style="padding: 8px 24px; border-radius: var(--radius-full); font-weight: 700;">
            ✏️ Edit Profile
          </button>
        </div>

        <!-- Mode Pills: Personal | Professional | Both Modes -->
        <div style="display: flex; justify-content: center; gap: 8px; margin-top: 20px;">
          <button class="btn btn-sm ${this.activeMode === 'common' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('common')" style="border-radius: var(--radius-full); padding: 6px 16px;">
            Personal
          </button>
          <button class="btn btn-sm ${this.activeMode === 'professional' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('professional')" style="border-radius: var(--radius-full); padding: 6px 16px;">
            Professional
          </button>
          <button class="btn btn-sm ${this.activeMode === 'both' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('both')" style="border-radius: var(--radius-full); padding: 6px 16px;">
            Both Modes
          </button>
        </div>
      </div>

      <!-- Navigation Tabs -->
      <div class="tabs-container" style="margin-bottom: 20px;">
        <button class="tab-btn active" onclick="window.app.switchProfileTab('personal')">Personal</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('skills')">Career & Skills</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('security')">Security & Privacy</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('settings')">Settings</button>
      </div>

      <!-- Security & Privacy Tab Content -->
      <div id="tab-security" class="profile-tab-content" style="display: none;">
        <!-- App Protection Banner -->
        <div class="security-active-banner">
          <span style="font-size: 1.8rem;">🛡️</span>
          <div>
            <div style="font-weight: 800; font-size: 1.05rem;">App Protection: ${isPinActive ? 'Active' : 'Standby'}</div>
            <div style="font-size: 0.82rem; opacity: 0.9;">${isPinActive ? 'Secured with 4-Digit PIN & Biometrics' : 'Set up a 4-Digit Security PIN to protect your account'}</div>
          </div>
        </div>

        <!-- App Lock & PIN Security Card -->
        <div class="security-card-box">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.3rem;">🔢</span>
              <div>
                <div style="font-weight: 700; font-size: 0.95rem;">4-Digit Security PIN</div>
                <div style="font-size: 0.78rem; color: ${isPinActive ? '#22c55e' : 'var(--text-muted)'};">${isPinActive ? 'PIN is set and active' : 'Not activated'}</div>
              </div>
            </div>
            <label class="switch" style="position: relative; display: inline-block; width: 44px; height: 24px;">
              <input type="checkbox" ${isPinActive ? 'checked' : ''} onchange="window.app.togglePinSecurity(this.checked)" style="opacity: 0; width: 0; height: 0;" />
              <span class="slider round" style="position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: ${isPinActive ? '#2563eb' : '#475569'}; transition: .3s; border-radius: 24px;"></span>
            </label>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.88rem;">
            <span style="color: var(--text-secondary);">Saved PIN: ${isPinActive ? '••••' : 'None'}</span>
            <button class="btn btn-secondary btn-sm" onclick="window.app.showPinSecurityModal()">
              🔄 Change PIN
            </button>
          </div>
        </div>
      </div>

      <!-- Tab 1: Personal Profile Form -->
      <div id="tab-personal" class="profile-tab-content">
        <div class="card">
          <h4 style="margin-bottom: 16px; font-size: 1.1rem; font-weight: 700;">Personal Information</h4>
          <form id="personalProfileForm" onsubmit="window.app.handleSavePersonalProfile(event)">
            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Full Legal Name</label>
                <input type="text" class="form-control" id="pFullName" value="${personal.full_name || ''}" required />
              </div>
              <div class="form-group">
                <label class="form-label">Display Name</label>
                <input type="text" class="form-control" id="pDisplayName" value="${personal.display_name || ''}" />
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Personal Bio</label>
              <textarea class="form-control" id="pBio" rows="3" placeholder="No personal bio added yet.">${personal.bio || ''}</textarea>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Location / City</label>
                <input type="text" class="form-control" id="pLocation" value="${personal.location || ''}" placeholder="Location not set" />
              </div>
              <div class="form-group">
                <label class="form-label">Personal Website</label>
                <input type="url" class="form-control" id="pWebsite" value="${personal.website_url || ''}" placeholder="No website" />
              </div>
            </div>

            <div style="text-align: right; margin-top: 10px;">
              <button type="submit" class="btn btn-primary">Save Changes</button>
            </div>
          </form>
        </div>
      </div>

      <!-- Tab 2: Career & Skills Content -->
      <div id="tab-skills" class="profile-tab-content" style="display: none;">
        <div class="card">
          <h4 style="margin-bottom: 16px; font-size: 1.1rem; font-weight: 700;">Professional Career & Skills</h4>
          <div class="form-group">
            <label class="form-label">Professional Headline</label>
            <input type="text" class="form-control" id="profHeadline" value="${prof.headline || ''}" placeholder="e.g. Senior Software Architect" />
          </div>
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label">Current Organization / Company</label>
              <input type="text" class="form-control" id="profCompany" value="${prof.current_company || ''}" placeholder="e.g. Google / DeepMind" />
            </div>
            <div class="form-group">
              <label class="form-label">Industry</label>
              <input type="text" class="form-control" id="profIndustry" value="${prof.industry || ''}" placeholder="e.g. Software & AI" />
            </div>
          </div>
          <div style="margin-top: 16px;">
            <label class="form-label">Listed Skills</label>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              ${(user.skills || []).map(s => `<span class="badge badge-primary">${s.skill_name} (${s.proficiency})</span>`).join('') || '<span style="color: var(--text-muted); font-size: 0.85rem;">No skills listed yet.</span>'}
            </div>
          </div>
        </div>
      </div>

      <!-- Tab 3: Settings Content -->
      <div id="tab-settings" class="profile-tab-content" style="display: none;">
        <div class="card">
          <h4 style="margin-bottom: 16px; font-size: 1.1rem; font-weight: 700;">Application & Security Settings</h4>
          <div style="display: flex; flex-direction: column; gap: 14px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
              <div>
                <div style="font-weight: 700;">Interface Language</div>
                <div style="font-size: 0.8rem; color: var(--text-muted);">22 Indian & International languages</div>
              </div>
              <button class="btn btn-secondary btn-sm" onclick="window.i18n.showLanguageSelector()">Change Language</button>
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 12px; border-top: 1px solid var(--border-subtle);">
              <div>
                <div style="font-weight: 700;">Theme Mood</div>
                <div style="font-size: 0.8rem; color: var(--text-muted);">Dark Mode / Light Mode</div>
              </div>
              <button class="btn btn-secondary btn-sm" onclick="window.app.toggleTheme()">Toggle Theme</button>
            </div>
          </div>
        </div>
      </div>
    `;
  }

  switchProfileTab(tabName) {
    document.querySelectorAll('.profile-tab-content').forEach(c => c.style.display = 'none');
    document.querySelectorAll('.tabs-container .tab-btn').forEach(b => b.classList.remove('active'));

    const tab = document.getElementById(`tab-${tabName}`);
    if (tab) tab.style.display = 'block';

    const btns = document.querySelectorAll('.tabs-container .tab-btn');
    const tabMap = { personal: 0, professional: 1, skills: 2, experience: 3, education: 4 };
    if (btns[tabMap[tabName]]) {
      btns[tabMap[tabName]].classList.add('active');
    }
  }

  async handleSavePersonalProfile(e) {
    e.preventDefault();
    try {
      this.showLoading(true);
      const data = {
        fullName: document.getElementById('pFullName').value.trim(),
        displayName: document.getElementById('pDisplayName').value.trim(),
        bio: document.getElementById('pBio').value.trim(),
        location: document.getElementById('pLocation').value.trim(),
        website: document.getElementById('pWebsite').value.trim(),
        birthdate: document.getElementById('pBirthdate').value || undefined,
        gender: document.getElementById('pGender').value || undefined
      };

      const res = await window.api.user.updatePersonalProfile(data);
      this.currentUser.personalProfile = res.data.personalProfile;
      this.showToast('Personal profile saved successfully!', 'success');
      this.applyUserSession();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleSaveProfessionalProfile(e) {
    e.preventDefault();
    try {
      this.showLoading(true);
      const data = {
        headline: document.getElementById('profHeadline').value.trim(),
        currentCompany: document.getElementById('profCompany').value.trim(),
        industry: document.getElementById('profIndustry').value.trim(),
        yearsOfExperience: document.getElementById('profExperienceYears').value,
        summary: document.getElementById('profSummary').value.trim(),
        portfolioUrl: document.getElementById('profPortfolio').value.trim(),
        githubUrl: document.getElementById('profGithub').value.trim(),
        linkedinUrl: document.getElementById('profLinkedin').value.trim(),
        isOpenToWork: document.getElementById('profOpenToWork').checked,
        isHiring: document.getElementById('profHiring').checked
      };

      const res = await window.api.user.updateProfessionalProfile(data);
      this.currentUser.professionalProfile = res.data.professionalProfile;
      this.showToast('Professional profile saved successfully!', 'success');
      this.applyUserSession();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  _setImgWithFallback(imgEl, url, fallback = '/assets/images/default-avatar.png') {
    if (!imgEl) return;
    imgEl.onerror = () => {
      imgEl.onerror = null;
      imgEl.src = fallback;
    };
    imgEl.src = url || fallback;
  }

  async handleAvatarUpload(e) {
    const input = e.target;
    const file = input?.files?.[0];
    if (!file) return;

    const maxBytes = 5 * 1024 * 1024;
    if (file.size > maxBytes) {
      this.showToast('Profile photo must be 5MB or smaller.', 'error');
      input.value = '';
      return;
    }

    const allowedExt = /\.(jpe?g|png|webp|gif|heic|heif)$/i;
    if (file.type && !file.type.startsWith('image/') && !allowedExt.test(file.name)) {
      this.showToast('Please select a valid image file (JPG, PNG, WEBP, or GIF).', 'error');
      input.value = '';
      return;
    }

    const formData = new FormData();
    formData.append('avatar', file);

    try {
      this.showLoading(true);
      const res = await window.api.user.uploadAvatar(formData);
      const newAvatarUrl = res?.data?.avatarUrl;
      if (this.currentUser) {
        if (res?.data?.user) {
          this.currentUser = res.data.user;
        } else {
          this.currentUser.personalProfile = {
            ...(this.currentUser.personalProfile || {}),
            avatar_url: newAvatarUrl
          };
        }
        window.api.setUser(this.currentUser);
      }
      this.showToast('Avatar updated successfully!', 'success');
      this.applyUserSession();
      this._setImgWithFallback(document.getElementById('profileAvatarPreview'), newAvatarUrl);
    } catch (err) {
      this.showToast(err.message || 'Failed to upload avatar.', 'error');
    } finally {
      if (input) input.value = '';
      this.showLoading(false);
    }
  }

  async handleAddSkill(e) {
    e.preventDefault();
    const nameInput = document.getElementById('newSkillName');
    const profInput = document.getElementById('newSkillProficiency');
    const skillName = nameInput.value.trim();
    const proficiency = profInput.value;

    try {
      this.showLoading(true);
      await window.api.user.addSkill({ skillName, proficiency });
      this.showToast(`Skill '${skillName}' added!`, 'success');
      await this.loadUserProfile();
      this.switchProfileTab('skills');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleDeleteSkill(skillId) {
    try {
      this.showLoading(true);
      await window.api.user.deleteSkill(skillId);
      this.showToast('Skill removed.', 'info');
      await this.loadUserProfile();
      this.switchProfileTab('skills');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleAddExperience(e) {
    e.preventDefault();
    const companyName = document.getElementById('expCompany').value.trim();
    const title = document.getElementById('expTitle').value.trim();
    const startDate = document.getElementById('expStartDate').value || undefined;
    const endDate = document.getElementById('expEndDate').value || undefined;
    const description = document.getElementById('expDescription').value.trim();

    try {
      this.showLoading(true);
      await window.api.user.addExperience({ companyName, title, startDate, endDate, description });
      this.showToast('Work experience added!', 'success');
      await this.loadUserProfile();
      this.switchProfileTab('experience');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleDeleteExperience(id) {
    try {
      this.showLoading(true);
      await window.api.user.deleteExperience(id);
      this.showToast('Experience record removed.', 'info');
      await this.loadUserProfile();
      this.switchProfileTab('experience');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleAddEducation(e) {
    e.preventDefault();
    const institution = document.getElementById('eduInstitution').value.trim();
    const degree = document.getElementById('eduDegree').value.trim();
    const fieldOfStudy = document.getElementById('eduField').value.trim();
    const startYear = document.getElementById('eduStartYear').value || undefined;
    const endYear = document.getElementById('eduEndYear').value || undefined;

    try {
      this.showLoading(true);
      await window.api.user.addEducation({ institution, degree, fieldOfStudy, startYear, endYear });
      this.showToast('Education record added!', 'success');
      await this.loadUserProfile();
      this.switchProfileTab('education');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleDeleteEducation(id) {
    try {
      this.showLoading(true);
      await window.api.user.deleteEducation(id);
      this.showToast('Education record removed.', 'info');
      await this.loadUserProfile();
      this.switchProfileTab('education');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async renderSettingsView(container) {
    container.innerHTML = `
      <div style="margin-bottom: 24px;">
        <h2>Security & Privacy Controls</h2>
        <p style="color: var(--text-muted);">Manage active sessions, devices, privacy visibility, and communication permissions.</p>
      </div>

      <div class="grid-2">
        <!-- Privacy Settings -->
        <div class="card">
          <h3 style="margin-bottom: 20px;">Privacy & Permissions</h3>
          <form onsubmit="window.app.handleSavePrivacy(event)">
            <div class="form-group">
              <label class="form-label">Profile Visibility</label>
              <select id="settingProfileVisibility" class="form-control">
                <option value="public">Public (Everyone can see your profile)</option>
                <option value="friends_only">Contacts & Friends Only</option>
                <option value="private">Private (Restricted)</option>
              </select>
            </div>

            <div class="form-group" style="display: flex; align-items: center; justify-content: space-between; padding: 8px 0;">
              <div>
                <div style="font-weight: 600;">Read Receipts</div>
                <div style="font-size: 0.8rem; color: var(--text-muted);">Allow others to see when you have read their messages</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="settingReadReceipts" />
                <span class="slider"></span>
              </label>
            </div>

            <div class="form-group" style="display: flex; align-items: center; justify-content: space-between; padding: 8px 0;">
              <div>
                <div style="font-weight: 600;">Online Presence Status</div>
                <div style="font-size: 0.8rem; color: var(--text-muted);">Show green online indicator when actively connected</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="settingOnlineStatus" />
                <span class="slider"></span>
              </label>
            </div>

            <div class="form-group" style="display: flex; align-items: center; justify-content: space-between; padding: 8px 0;">
              <div>
                <div style="font-weight: 600;">Group Invitation Approval</div>
                <div style="font-size: 0.8rem; color: var(--text-muted);">Require your explicit approval before adding to any group</div>
              </div>
              <label class="switch">
                <input type="checkbox" id="settingGroupApproval" />
                <span class="slider"></span>
              </label>
            </div>

            <div class="form-group">
              <label class="form-label">Message Requests Filter</label>
              <select id="settingMessageRequests" class="form-control">
                <option value="everyone">Allow from Everyone</option>
                <option value="contacts_only">Contacts Only</option>
                <option value="nobody">Strict (Nobody)</option>
              </select>
            </div>

            <button type="submit" class="btn btn-primary" style="margin-top: 10px;">Save Privacy Settings</button>
          </form>
        </div>

        <!-- Active Devices & Sessions -->
        <div class="card">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
            <h3>Active Device Sessions</h3>
            <button class="btn btn-danger btn-sm" onclick="window.app.handleRevokeAllOtherSessions()">Revoke Other Devices</button>
          </div>
          <div id="sessionsListContainer">
            <p style="color: var(--text-muted);">Loading active sessions...</p>
          </div>
        </div>
      </div>
    `;

    // Populate privacy settings values
    const priv = this.currentUser.privacySettings || {};
    const vis = document.getElementById('settingProfileVisibility');
    const read = document.getElementById('settingReadReceipts');
    const online = document.getElementById('settingOnlineStatus');
    const group = document.getElementById('settingGroupApproval');
    const reqs = document.getElementById('settingMessageRequests');

    if (vis) vis.value = priv.profile_visibility || 'public';
    if (read) read.checked = priv.read_receipts !== false;
    if (online) online.checked = priv.online_status !== false;
    if (group) group.checked = priv.group_invitation_approval !== false;
    if (reqs) reqs.value = priv.message_requests || 'everyone';

    // Load active sessions
    await this.loadSessionsList();
  }

  async loadSessionsList() {
    const container = document.getElementById('sessionsListContainer');
    if (!container) return;

    try {
      const res = await window.api.sessions.getSessions();
      const sessions = res.data.sessions;

      if (!sessions || sessions.length === 0) {
        container.innerHTML = `<p style="color: var(--text-muted);">No active sessions found.</p>`;
        return;
      }

      container.innerHTML = sessions.map(s => `
        <div style="border-bottom: 1px solid var(--border-subtle); padding: 12px 0; display: flex; align-items: center; justify-content: space-between;">
          <div>
            <div style="font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>💻 ${s.device_info}</span>
              ${s.is_current ? '<span class="badge badge-success">Current Session</span>' : ''}
            </div>
            <div style="color: var(--text-muted); font-size: 0.8rem; margin-top: 2px;">
              IP: ${s.ip_address || '127.0.0.1'} • Last active: ${new Date(s.last_active_at).toLocaleString()}
            </div>
          </div>
          ${!s.is_current ? `
            <button class="btn btn-secondary btn-sm" style="color: var(--color-danger);" onclick="window.app.handleRevokeSession('${s.id}')">Revoke</button>
          ` : ''}
        </div>
      `).join('');
    } catch (err) {
      container.innerHTML = `<p style="color: var(--color-danger);">Failed to load sessions: ${err.message}</p>`;
    }
  }

  async handleSavePrivacy(e) {
    e.preventDefault();
    try {
      this.showLoading(true);
      const data = {
        profileVisibility: document.getElementById('settingProfileVisibility').value,
        readReceipts: document.getElementById('settingReadReceipts').checked,
        onlineStatus: document.getElementById('settingOnlineStatus').checked,
        groupInvitationApproval: document.getElementById('settingGroupApproval').checked,
        messageRequests: document.getElementById('settingMessageRequests').value
      };

      const res = await window.api.user.updatePrivacy(data);
      this.currentUser.privacySettings = res.data.privacySettings;
      this.showToast('Privacy settings updated successfully!', 'success');
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleRevokeSession(sessionId) {
    try {
      this.showLoading(true);
      await window.api.sessions.revokeSession(sessionId);
      this.showToast('Device session terminated.', 'info');
      await this.loadSessionsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleRevokeAllOtherSessions() {
    if (!confirm('Are you sure you want to sign out all other devices?')) return;
    try {
      this.showLoading(true);
      const res = await window.api.sessions.revokeAllOther();
      this.showToast(res.message, 'success');
      await this.loadSessionsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  _resetClientSessionUI() {
    window.api.removeToken();
    this.currentUser = null;
    this.activeModule = 'home';
    this.activeMode = 'common';

    try {
      const overlayEl = document.getElementById('meetingRoomOverlay');
      if (window.meetingRoom && typeof window.meetingRoom.leaveRoom === 'function' && overlayEl && overlayEl.style.display !== 'none') {
        window.meetingRoom.leaveRoom(false);
      }
      if (overlayEl) overlayEl.style.display = 'none';
    } catch (_) {}

    try {
      if (this.globalSocket) {
        this.globalSocket.disconnect();
        this.globalSocket = null;
      }
    } catch (_) {}

    try {
      if (window.chatManager && typeof window.chatManager.disconnect === 'function') {
        window.chatManager.disconnect();
      }
    } catch (_) {}

    ['instantMeetingModal', 'joinedMeetingModal', 'scheduleMeetingModal', 'meetingRecordsModal'].forEach((id) => {
      document.getElementById(id)?.remove();
    });
    document.getElementById('appSidebar')?.classList.remove('mobile-open');
    document.getElementById('mobileOverlay')?.classList.remove('active');

    const mainContent = document.getElementById('mainContentArea');
    if (mainContent) mainContent.innerHTML = '';

    const defaultAvatar = '/assets/images/default-avatar.png';
    this._setImgWithFallback(document.getElementById('sidebarAvatar'), defaultAvatar, defaultAvatar);
    this._setImgWithFallback(document.getElementById('topbarAvatar'), defaultAvatar, defaultAvatar);

    const sidebarName = document.getElementById('sidebarName');
    const sidebarHandle = document.getElementById('sidebarHandle');
    const modeBadge = document.getElementById('activeModeBadge');
    if (sidebarName) sidebarName.textContent = 'Guest User';
    if (sidebarHandle) sidebarHandle.textContent = '@connekt';
    if (modeBadge) {
      modeBadge.textContent = 'COMMON MODE';
      modeBadge.className = 'badge badge-mode badge-success';
    }

    document.querySelectorAll('.nav-item[data-module]').forEach((item) => {
      item.classList.toggle('active', item.dataset.module === 'home');
    });

    if (window.location.hash) {
      try {
        history.replaceState(null, '', window.location.pathname + window.location.search);
      } catch (_) {
        window.location.hash = '';
      }
    }

    window.authManager?.resetForms?.();
    this.showAuthModal(true);
  }

  async handleLogout() {
    if (this._isLoggingOut) return;
    this._isLoggingOut = true;
    const logoutBtn = document.getElementById('btnLogout');
    if (logoutBtn) logoutBtn.disabled = true;

    try {
      this.showLoading(true);
      if (window.api.getToken()) {
        await window.api.auth.logout();
      }
    } catch (_) {
      // Proceed with local sign-out even if server revoke fails or times out
    } finally {
      this._resetClientSessionUI();
      this.showLoading(false);
      if (logoutBtn) logoutBtn.disabled = false;
      this._isLoggingOut = false;
      this.showToast('Logged out safely.', 'info');
    }
  }

  // ====================================================================
  // MEETINGS & COLLABORATION MODULE (PHASE 1 FOUNDATION)
  // ====================================================================

  async renderMeetingsDashboard(container) {
    this.meetingsFilter = 'all';
    this.meetingsSearch = '';
    this.meetingsMainTab = this.meetingsMainTab || 'meetings';
    this.callLogsFilter = 'all';
    this.callLogsSearch = '';

    container.innerHTML = `
      <!-- Meetings Top Header -->
      <div class="meetings-header">
        <div>
          <button class="btn btn-secondary btn-sm" style="margin-bottom: 8px; display: inline-flex; align-items: center; gap: 6px;" onclick="window.app.navigateTo('home')">
            ← Back to Dashboard
          </button>
          <h2>CONNEKT Meetings & Calls</h2>
          <p style="color: var(--text-muted); font-size: 0.9rem;">
            Instant video conference rooms, calendar schedules, and live phone contacts call history.
          </p>
        </div>

        <div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">
          <button class="btn btn-primary btn-sm" onclick="window.app.openScheduleMeetingModal()">+ Schedule Meeting</button>
          <button class="btn btn-secondary btn-sm" onclick="window.app.meetingsMainTab === 'call_logs' ? window.app.loadCallLogsList() : window.app.loadMeetingsList()">↻ Refresh</button>
        </div>
      </div>

      <!-- Main Navigation Tabs: Video Meetings vs Phone Call Logs -->
      <div class="tabs-container" style="margin-bottom: 24px; border-bottom: 1px solid var(--border-subtle);">
        <button class="tab-btn ${this.meetingsMainTab === 'meetings' ? 'active' : ''}" data-main-meetings-tab="meetings" onclick="window.app.switchMeetingsMainTab('meetings')">
          📹 Video Meetings & Conferences
        </button>
        <button class="tab-btn ${this.meetingsMainTab === 'call_logs' ? 'active' : ''}" data-main-meetings-tab="call_logs" onclick="window.app.switchMeetingsMainTab('call_logs')">
          📱 Phone Contacts & Call History (Synced with Phone)
        </button>
      </div>

      <!-- SECTION 1: VIDEO CONFERENCES & ROOMS -->
      <div id="meetingsSectionContainer" style="${this.meetingsMainTab === 'meetings' ? 'display: block;' : 'display: none;'}">
        <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
          <div class="meetings-search-bar" style="flex: 1; max-width: 450px;">
            <span>🔍</span>
            <input type="text" id="meetingsSearchInput" class="meetings-search-input" placeholder="Search meetings by title, room code, or agenda..." />
          </div>
        </div>

        <!-- Main Action Section (3 Primary Cards) -->
        <div class="meeting-actions-grid">
          <!-- Card 1: Start Instant Meeting -->
          <div class="meeting-action-card primary">
            <div>
              <div class="meeting-action-card-icon">⚡</div>
              <h3 style="margin-bottom: 8px;">Start Instant Meeting</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4; margin-bottom: 20px;">
                Create an instant meeting room immediately. Generates a unique room code (<code style="color: var(--accent-cyan);">abc-defg-hij</code>) and assigns you as host.
              </p>
            </div>
            <button class="btn btn-primary" style="width: 100%; display: flex; align-items: center; justify-content: center; gap: 8px;" onclick="window.app.handleCreateInstantMeeting()">
              <span>Start Meeting Now</span>
              <span>📹</span>
            </button>
          </div>

          <!-- Card 2: Join a Meeting -->
          <div class="meeting-action-card accent">
            <div>
              <div class="meeting-action-card-icon">🔗</div>
              <h3 style="margin-bottom: 8px;">Join a Meeting</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4; margin-bottom: 14px;">
                Enter a meeting room code or link to enter an active session.
              </p>
              <div style="display: flex; flex-direction: column; gap: 8px; margin-bottom: 16px;">
                <input type="text" id="joinRoomCodeInput" class="form-control" placeholder="Room code (e.g. abc-defg-hij)" style="font-family: monospace; font-size: 0.95rem; text-transform: lowercase;" />
                <input type="password" id="joinRoomPasscodeInput" class="form-control" placeholder="Passcode (optional if requested)" style="font-size: 0.88rem;" />
              </div>
            </div>
            <button class="btn btn-secondary" style="width: 100%; border-color: var(--accent-cyan); color: var(--accent-cyan);" onclick="window.app.handleJoinMeetingFromInput()">
              Join Meeting Room →
            </button>
          </div>

          <!-- Card 3: Schedule a Meeting -->
          <div class="meeting-action-card purple">
            <div>
              <div class="meeting-action-card-icon">📅</div>
              <h3 style="margin-bottom: 8px;">Schedule a Meeting</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4; margin-bottom: 20px;">
                Plan a future video conference with custom date, time, duration, agenda, and invite registered CONNEKT contacts.
              </p>
            </div>
            <button class="btn btn-secondary" style="width: 100%;" onclick="window.app.openScheduleMeetingModal()">
              Schedule New Meeting 📅
            </button>
          </div>
        </div>

        <!-- Meeting Overview Section -->
        <div style="margin-top: 12px;">
          <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
            <h3 style="display: flex; align-items: center; gap: 10px;">
              <span>Meeting Overview</span>
              <span id="meetingsTotalCountBadge" class="badge badge-primary">0 Total</span>
            </h3>

            <!-- Filter Tabs -->
            <div class="tabs-container" style="margin-bottom: 0;">
              <button class="tab-btn active" data-meetings-tab="all" onclick="window.app.switchMeetingsFilter('all')">All Meetings</button>
              <button class="tab-btn" data-meetings-tab="upcoming" onclick="window.app.switchMeetingsFilter('upcoming')">Upcoming</button>
              <button class="tab-btn" data-meetings-tab="today" onclick="window.app.switchMeetingsFilter('today')">Today</button>
              <button class="tab-btn" data-meetings-tab="created_by_me" onclick="window.app.switchMeetingsFilter('created_by_me')">Created by Me</button>
              <button class="tab-btn" data-meetings-tab="invited_to" onclick="window.app.switchMeetingsFilter('invited_to')">Invited to</button>
              <button class="tab-btn" data-meetings-tab="past" onclick="window.app.switchMeetingsFilter('past')">Past History</button>
            </div>
          </div>

          <!-- Dynamic Meeting Records Container -->
          <div id="meetingsListContainer">
            <div style="text-align: center; padding: 36px; color: var(--text-muted);">
              <div style="width: 32px; height: 32px; border: 3px solid rgba(255,255,255,0.1); border-top-color: var(--accent-cyan); border-radius: 50%; animation: spin 0.8s linear infinite; margin: 0 auto 12px;"></div>
              Loading meetings from database...
            </div>
          </div>
        </div>
      </div>

      <!-- SECTION 2: PHONE CONTACTS & CALL HISTORY (SYNCED WITH ANDROID PHONE) -->
      <div id="callsSectionContainer" style="${this.meetingsMainTab === 'call_logs' ? 'display: block;' : 'display: none;'}">
        <!-- Live Sync Status Banner -->
        <div style="background: var(--bg-card); border-radius: var(--radius-md); padding: 18px; border: 1px solid var(--border-subtle); margin-bottom: 20px;">
          <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 14px;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(16, 185, 129, 0.15); color: #10b981; display: flex; align-items: center; justify-content: center; font-size: 1.4rem;">
                📱
              </div>
              <div>
                <h3 style="margin-bottom: 2px;">Phone Contacts & Call Logs</h3>
                <p style="color: var(--text-muted); font-size: 0.85rem; margin: 0;">
                  Automatically fetched from your Android phone contacts and call logs upon website login.
                </p>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 10px;">
              <span id="callSyncStatusBadge" class="badge badge-success" style="padding: 6px 12px; font-size: 0.8rem;">
                🟢 Phone Connected & Synced
              </span>
              <button id="btnManualCallSync" class="btn btn-secondary btn-sm" onclick="window.app.triggerCallLogsSync(true)">
                🔄 Sync from Phone
              </button>
            </div>
          </div>
        </div>

        <!-- Filter & Search Toolbar -->
        <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-bottom: 16px;">
          <div class="tabs-container" style="margin-bottom: 0;">
            <button class="tab-btn active" data-call-tab="all" onclick="window.app.switchCallLogsFilter('all')">All Calls</button>
            <button class="tab-btn" data-call-tab="incoming" onclick="window.app.switchCallLogsFilter('incoming')">Incoming ↙️</button>
            <button class="tab-btn" data-call-tab="outgoing" onclick="window.app.switchCallLogsFilter('outgoing')">Outgoing ↗️</button>
            <button class="tab-btn" data-call-tab="missed" onclick="window.app.switchCallLogsFilter('missed')">Missed ❌</button>
            <button class="tab-btn" data-call-tab="rejected" onclick="window.app.switchCallLogsFilter('rejected')">Rejected 🚫</button>
          </div>
          <div class="meetings-search-bar" style="max-width: 320px;">
            <span>🔍</span>
            <input type="text" id="callLogsSearchInput" class="meetings-search-input" placeholder="Search contact name or number..." />
          </div>
        </div>

        <!-- Dynamic Call Logs Container -->
        <div id="callLogsListContainer">
          <div style="text-align: center; padding: 36px; color: var(--text-muted);">
            <div style="width: 32px; height: 32px; border: 3px solid rgba(255,255,255,0.1); border-top-color: var(--accent-cyan); border-radius: 50%; animation: spin 0.8s linear infinite; margin: 0 auto 12px;"></div>
            Loading phone call logs...
          </div>
        </div>
      </div>

      <!-- Modal Container for Schedule & Instant Meeting Result -->
      <div id="meetingsModalContainer"></div>
    `;

    // Hook meetings search input with debounce
    let searchTimeout = null;
    const searchInput = document.getElementById('meetingsSearchInput');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        clearTimeout(searchTimeout);
        searchTimeout = setTimeout(() => {
          this.meetingsSearch = e.target.value.trim();
          this.loadMeetingsList();
        }, 300);
      });
    }

    // Hook call logs search input with debounce
    let callSearchTimeout = null;
    const callSearchInput = document.getElementById('callLogsSearchInput');
    if (callSearchInput) {
      callSearchInput.addEventListener('input', (e) => {
        clearTimeout(callSearchTimeout);
        callSearchTimeout = setTimeout(() => {
          this.callLogsSearch = e.target.value.trim();
          this.loadCallLogsList();
        }, 300);
      });
    }

    // Load initial data based on active tab
    if (this.meetingsMainTab === 'call_logs') {
      await this.loadCallLogsList();
    } else {
      await this.loadMeetingsList();
    }
  }

  switchMeetingsMainTab(tab) {
    this.meetingsMainTab = tab;
    document.querySelectorAll('[data-main-meetings-tab]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.mainMeetingsTab === tab);
    });
    const meetingsSection = document.getElementById('meetingsSectionContainer');
    const callsSection = document.getElementById('callsSectionContainer');
    if (tab === 'meetings') {
      if (meetingsSection) meetingsSection.style.display = 'block';
      if (callsSection) callsSection.style.display = 'none';
      this.loadMeetingsList();
    } else {
      if (meetingsSection) meetingsSection.style.display = 'none';
      if (callsSection) callsSection.style.display = 'block';
      this.loadCallLogsList();
    }
  }

  switchCallLogsFilter(filter) {
    this.callLogsFilter = filter;
    document.querySelectorAll('[data-call-tab]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.callTab === filter);
    });
    this.loadCallLogsList();
  }

  initGlobalSocket() {
    const token = window.api.getToken();
    if (!token || typeof io === 'undefined') return;
    if (this.globalSocket && this.globalSocket.connected) return;

    try {
      this.globalSocket = io({
        auth: { token },
        query: { token }
      });

      this.globalSocket.on('call-logs:synced', (data) => {
        this.showToast(`✅ Synced ${data.count} call logs from your phone contacts!`, 'success');
        if (this.activeModule === 'meetings' && this.meetingsMainTab === 'call_logs') {
          this.loadCallLogsList();
        }
      });
    } catch (_) {}
  }

  async triggerCallLogsSync(isManual = false) {
    try {
      if (isManual) this.showToast('📱 Requesting fresh call logs from connected phone...', 'info');
      await window.api.calls.requestSync();
      if (this.meetingsMainTab === 'call_logs') {
        setTimeout(() => this.loadCallLogsList(), 1200);
      }
    } catch (err) {
      if (isManual) this.showToast('Could not reach phone: ' + err.message, 'warning');
    }
  }

  async loadCallLogsList() {
    const container = document.getElementById('callLogsListContainer');
    if (!container) return;

    try {
      const filter = this.callLogsFilter || 'all';
      const search = (this.callLogsSearch || '').toLowerCase();
      const res = await window.api.calls.getDeviceLogs({ type: filter, limit: 100 });
      let logs = res.data?.logs || [];
      const totalSynced = res.data?.total ?? logs.length;

      const statusBadge = document.getElementById('callSyncStatusBadge');
      if (statusBadge) {
        if (totalSynced > 0) {
          statusBadge.className = 'badge badge-success';
          statusBadge.textContent = `🟢 ${totalSynced} Call Log${totalSynced === 1 ? '' : 's'} Synced`;
        } else {
          statusBadge.className = 'badge badge-warning';
          statusBadge.textContent = '🟡 Waiting for Phone Sync';
        }
      }

      if (search) {
        logs = logs.filter(l =>
          (l.name && l.name.toLowerCase().includes(search)) ||
          (l.number && l.number.includes(search))
        );
      }

      if (logs.length === 0) {
        container.innerHTML = `
          <div class="card" style="text-align: center; padding: 48px 20px;">
            <div style="font-size: 2.8rem; margin-bottom: 12px;">📱</div>
            <h4 style="margin-bottom: 6px; color: var(--text-primary);">No call logs found</h4>
            <p style="color: var(--text-muted); font-size: 0.88rem; max-width: 440px; margin: 0 auto 16px;">
              ${search ? `No call records match "${search}".` : `When you log in to the website, your phone's call logs are synced automatically from your phone contacts. Ensure the CONNEKT app is open on your phone.`}
            </p>
            <button class="btn btn-primary btn-sm" onclick="window.app.triggerCallLogsSync(true)">🔄 Sync Call Logs Now</button>
          </div>
        `;
        return;
      }

      container.innerHTML = logs.map(l => {
        const type = (l.type || 'unknown').toLowerCase();
        let icon = '📞';
        let badgeClass = 'badge-primary';
        let typeLabel = 'Call';

        if (type === 'incoming') {
          icon = '↙️';
          badgeClass = 'badge-success';
          typeLabel = 'Incoming';
        } else if (type === 'outgoing') {
          icon = '↗️';
          badgeClass = 'badge-primary';
          typeLabel = 'Outgoing';
        } else if (type === 'missed') {
          icon = '❌';
          badgeClass = 'badge-danger';
          typeLabel = 'Missed';
        } else if (type === 'rejected') {
          icon = '🚫';
          badgeClass = 'badge-warning';
          typeLabel = 'Rejected';
        }

        const mins = Math.floor((l.duration || 0) / 60);
        const secs = (l.duration || 0) % 60;
        const durationStr = l.duration > 0 ? (mins > 0 ? `${mins}m ${secs}s` : `${secs}s`) : (type === 'missed' ? '0s (Missed)' : '0s');

        const date = l.timestamp ? new Date(l.timestamp) : new Date();
        const formattedDate = date.toLocaleString('en-US', {
          month: 'short',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit',
          hour12: true
        });

        const initial = (l.name || l.number || 'C').trim().charAt(0).toUpperCase();

        return `
          <div class="meeting-card" style="display: flex; align-items: center; justify-content: space-between; gap: 14px; padding: 14px 18px; margin-bottom: 10px;">
            <div style="display: flex; align-items: center; gap: 14px; min-width: 0;">
              <div style="width: 42px; height: 42px; border-radius: 50%; background: rgba(37, 99, 235, 0.15); color: #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 1.1rem; font-weight: 700; flex-shrink: 0;">
                ${initial}
              </div>
              <div style="min-width: 0;">
                <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                  <h4 style="margin: 0; font-size: 0.98rem; font-weight: 600; color: var(--text-primary); text-overflow: ellipsis; overflow: hidden; white-space: nowrap;">
                    ${l.name || l.number}
                  </h4>
                  <span class="badge ${badgeClass}" style="font-size: 0.72rem; padding: 2px 7px;">
                    ${icon} ${typeLabel}
                  </span>
                </div>
                <div style="color: var(--text-muted); font-size: 0.82rem; margin-top: 2px; font-family: monospace;">
                  ${l.number}
                </div>
              </div>
            </div>

            <div style="text-align: right; flex-shrink: 0;">
              <div style="font-size: 0.85rem; font-weight: 600; color: var(--text-primary);">
                ${formattedDate}
              </div>
              <div style="font-size: 0.78rem; color: var(--text-muted); margin-top: 2px;">
                ⏱️ ${durationStr}
              </div>
            </div>
          </div>
        `;
      }).join('');
    } catch (err) {
      console.error('Failed to load call logs:', err);
      container.innerHTML = `
        <div class="card" style="text-align: center; color: var(--color-danger); padding: 24px;">
          Failed to load call logs: ${err.message}
        </div>
      `;
    }
  }

  async switchMeetingsFilter(filter) {
    this.meetingsFilter = filter;
    document.querySelectorAll('[data-meetings-tab]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.meetingsTab === filter);
    });
    await this.loadMeetingsList();
  }

  async loadMeetingsList() {
    const container = document.getElementById('meetingsListContainer');
    if (!container) return;

    try {
      const res = await window.api.meetings.listMeetings({
        filter: this.meetingsFilter,
        search: this.meetingsSearch
      });

      const meetings = res.data.meetings || [];
      const countBadge = document.getElementById('meetingsTotalCountBadge');
      if (countBadge) countBadge.textContent = `${meetings.length} Meeting${meetings.length === 1 ? '' : 's'}`;

      if (meetings.length === 0) {
        container.innerHTML = `
          <div class="card meeting-empty-state">
            <div style="font-size: 2.5rem; margin-bottom: 12px;">📹</div>
            <h4 style="margin-bottom: 6px; color: var(--text-primary);">No meetings found</h4>
            <p style="color: var(--text-muted); font-size: 0.9rem; max-width: 420px; margin: 0 auto 16px;">
              ${this.meetingsSearch ? `No meetings match "${this.meetingsSearch}". Try another keyword.` : `There are no meetings in this category yet. Start an instant meeting or schedule a conference above.`}
            </p>
            <button class="btn btn-primary btn-sm" onclick="window.app.handleCreateInstantMeeting()">Start Instant Meeting</button>
          </div>
        `;
        return;
      }

      const currentUserId = this.currentUser?.id;

      container.innerHTML = meetings.map(m => {
        const isHost = m.host_id === currentUserId;
        const isLive = m.status === 'live';
        const isEnded = m.status === 'ended';
        const isCancelled = m.status === 'cancelled';
        const isScheduled = m.status === 'scheduled';

        let statusHtml = '';
        if (isLive) {
          statusHtml = `<span class="status-beacon live"><span class="beacon-dot"></span>HAPPENING NOW</span>`;
        } else if (isScheduled) {
          statusHtml = `<span class="badge badge-primary">UPCOMING</span>`;
        } else if (isEnded) {
          statusHtml = `<span class="badge" style="background: rgba(255,255,255,0.08); color: var(--text-muted);">ENDED</span>`;
        } else if (isCancelled) {
          statusHtml = `<span class="badge badge-danger">CANCELLED</span>`;
        }

        const scheduledDate = m.scheduled_at ? new Date(m.scheduled_at) : null;
        const formattedDate = scheduledDate ? scheduledDate.toLocaleString('en-US', {
          weekday: 'short',
          month: 'short',
          day: 'numeric',
          hour: 'numeric',
          minute: '2-digit'
        }) : 'Instant / Live';

        return `
          <div class="meeting-card">
            <div style="display: flex; align-items: flex-start; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
              <div>
                <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 6px; flex-wrap: wrap;">
                  ${statusHtml}
                  <span class="meeting-code-chip" title="Click to copy room code" onclick="window.app.handleCopyText('${m.room_code}', 'Room code copied!')">
                    <span>CNK-${m.room_code}</span>
                    <span style="opacity: 0.7;">📋</span>
                  </span>
                  ${m.is_locked ? '<span class="badge badge-warning">🔒 Locked Room</span>' : ''}
                  ${m.passcode ? '<span class="badge badge-mode">🔑 Passcode Protected</span>' : ''}
                </div>
                <h3 style="font-size: 1.15rem; margin-bottom: 4px; color: var(--text-primary);">${m.title}</h3>
                ${m.description ? `<p style="color: var(--text-secondary); font-size: 0.88rem; margin-bottom: 6px;">${m.description}</p>` : ''}
                ${m.agenda ? `<div style="font-size: 0.82rem; color: var(--accent-cyan); margin-bottom: 6px;">📌 Agenda: ${m.agenda}</div>` : ''}
              </div>

              <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                ${(!isEnded && !isCancelled) ? `
                  <button class="btn btn-primary btn-sm" style="display: flex; align-items: center; gap: 6px;" onclick="window.app.handleDirectJoinRoom('${m.room_code}')">
                    <span>📹</span>
                    <span>Join Call</span>
                  </button>
                ` : ''}
                <button class="btn btn-secondary btn-sm" onclick="window.app.handleCopyMeetingLink('${m.room_code}', '${m.title}')">
                  Copy Invite
                </button>
                <button class="btn btn-secondary btn-sm" style="color: var(--accent-cyan); border-color: rgba(6, 182, 212, 0.4);" onclick="window.app.openMeetingRecordsModal('${m.id}')" title="View Attendance, Minutes & Action Items">
                  📋 Records
                </button>
                ${isHost && !isEnded && !isCancelled ? `
                  <button class="btn btn-secondary btn-sm" style="color: ${m.is_locked ? 'var(--color-success)' : 'var(--color-warning)'};" onclick="window.app.handleToggleMeetingLock('${m.id}', ${!!m.is_locked})">
                    ${m.is_locked ? '🔓 Unlock' : '🔒 Lock'}
                  </button>
                  <button class="btn btn-secondary btn-sm" style="color: var(--color-danger);" onclick="window.app.handleCancelMeeting('${m.id}')">
                    Cancel
                  </button>
                ` : ''}
              </div>
            </div>

            <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px; margin-top: 6px; padding-top: 10px; border-top: 1px solid var(--border-subtle); font-size: 0.82rem; color: var(--text-muted);">
              <div style="display: flex; align-items: center; gap: 8px;">
                <img src="${m.host_avatar || '/assets/images/default-avatar.png'}" style="width: 22px; height: 22px; border-radius: 50%; object-fit: cover;" />
                <span>Host: <strong style="color: var(--text-primary);">${m.host_name || m.host_username}</strong></span>
                ${isHost ? '<span class="badge badge-success" style="font-size: 0.7rem; padding: 1px 6px;">You</span>' : ''}
              </div>
              <div style="display: flex; align-items: center; gap: 16px;">
                <span>🕒 ${formattedDate}</span>
                <span>⏱️ ${m.duration_minutes || 60} mins</span>
                <span>👥 ${m.participant_count || 1} Participant${m.participant_count == 1 ? '' : 's'}</span>
              </div>
            </div>
          </div>
        `;
      }).join('');
    } catch (err) {
      console.error('Failed to load meetings list:', err);
      container.innerHTML = `
        <div class="card" style="text-align: center; color: var(--color-danger); padding: 24px;">
          Failed to load meetings: ${err.message}
        </div>
      `;
    }
  }

  async handleCreateInstantMeeting() {
    try {
      this.showLoading(true);
      const res = await window.api.meetings.createInstantRoom('Instant Meeting');
      const meeting = res.data.meeting;
      const roomCode = res.data.roomCode;
      const directUrl = `${window.location.origin}/meet/${roomCode}`;

      this.showToast('Instant meeting room created!', 'success');
      this.showInstantMeetingModal(roomCode, directUrl, meeting);
      await this.loadMeetingsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  showInstantMeetingModal(roomCode, directUrl, meeting) {
    const modalContainer = document.getElementById('meetingsModalContainer') || document.body;
    const modalId = 'instantMeetingModal';
    const existing = document.getElementById(modalId);
    if (existing) existing.remove();

    const div = document.createElement('div');
    div.id = modalId;
    div.className = 'modal-overlay active';
    div.innerHTML = `
      <div class="modal-content" style="max-width: 500px;">
        <div class="modal-header">
          <div style="display: flex; align-items: center; gap: 10px;">
            <div style="width: 32px; height: 32px; border-radius: 8px; background: rgba(37, 99, 235, 0.2); color: #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">⚡</div>
            <h3 class="modal-title">Instant Meeting Created</h3>
          </div>
          <button class="modal-close-btn" onclick="document.getElementById('${modalId}').remove()">&times;</button>
        </div>
        <div class="modal-body">
          <p style="color: var(--text-secondary); font-size: 0.9rem; margin-bottom: 16px;">
            Your instant room is ready. Share this readable meeting code or invite link with participants.
          </p>

          <div style="background: var(--bg-input); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 16px; text-align: center; margin-bottom: 16px;">
            <div style="font-size: 0.75rem; color: var(--text-muted); font-weight: 600; text-transform: uppercase; margin-bottom: 6px;">Room Code</div>
            <div style="font-family: monospace; font-size: 1.8rem; font-weight: 800; color: var(--accent-cyan); letter-spacing: 0.1em; user-select: all;">
              ${roomCode}
            </div>
            <button class="btn btn-secondary btn-sm" style="margin-top: 10px;" onclick="window.app.handleCopyText('${roomCode}', 'Room code copied!')">
              📋 Copy Room Code
            </button>
          </div>

          <div class="form-group">
            <label class="form-label">Direct Meeting Link</label>
            <div style="display: flex; gap: 8px;">
              <input type="text" readonly value="${directUrl}" class="form-control" style="font-size: 0.85rem;" />
              <button class="btn btn-secondary" onclick="window.app.handleCopyMeetingLink('${roomCode}', 'Instant Meeting')">Copy</button>
            </div>
          </div>
        </div>
        <div class="modal-footer" style="display: flex; justify-content: space-between;">
          <button class="btn btn-secondary" onclick="document.getElementById('${modalId}').remove()">Close</button>
          <button class="btn btn-primary" onclick="window.app.handleDirectJoinRoom('${roomCode}'); document.getElementById('${modalId}').remove();">
            Enter Meeting Room Now 📹
          </button>
        </div>
      </div>
    `;
    modalContainer.appendChild(div);
  }

  async handleJoinMeetingFromInput() {
    const input = document.getElementById('joinRoomCodeInput');
    const passInput = document.getElementById('joinRoomPasscodeInput');
    if (!input) return;

    let code = input.value.trim();
    if (!code) {
      this.showToast('Please enter a meeting room code or link.', 'warning');
      input.focus();
      return;
    }

    // Extract code if user pasted a full link (e.g. http://localhost:5000/meet/abc-defg-hij)
    if (code.includes('/meet/')) {
      code = code.split('/meet/').pop().split('?')[0].split('#')[0];
    } else if (code.includes('CNK-')) {
      code = code.replace('CNK-', '');
    }

    const passcode = passInput ? passInput.value.trim() : '';
    await this.handleDirectJoinRoom(code, passcode);
  }

  async handleDirectJoinRoom(roomCode, passcode = '') {
    try {
      this.showLoading(true);
      const res = await window.api.meetings.joinRoom(roomCode, passcode);
      const meeting = res.data.meeting;
      const role = res.data.role;

      this.showToast(`Joined meeting room "${meeting.title}" as ${role}!`, 'success');

      // Launch full WebRTC live calling interface
      if (window.meetingRoom) {
        await window.meetingRoom.enterRoom(meeting, role, this.currentUser);
      } else {
        this.showJoinedMeetingSummaryModal(meeting, role, res.data.participants);
      }

      await this.loadMeetingsList();
    } catch (err) {
      console.error('Failed to join room:', err);
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  showJoinedMeetingSummaryModal(meeting, role, participants) {
    const modalContainer = document.getElementById('meetingsModalContainer') || document.body;
    const modalId = 'joinedMeetingModal';
    const existing = document.getElementById(modalId);
    if (existing) existing.remove();

    const div = document.createElement('div');
    div.id = modalId;
    div.className = 'modal-overlay active';
    div.innerHTML = `
      <div class="modal-content" style="max-width: 520px;">
        <div class="modal-header">
          <div style="display: flex; align-items: center; gap: 10px;">
            <div style="width: 32px; height: 32px; border-radius: 8px; background: rgba(16, 185, 129, 0.2); color: #10b981; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">✓</div>
            <h3 class="modal-title">Connected to Meeting Room</h3>
          </div>
          <button class="modal-close-btn" onclick="document.getElementById('${modalId}').remove()">&times;</button>
        </div>
        <div class="modal-body">
          <div style="margin-bottom: 16px;">
            <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase;">Meeting Title</div>
            <h3 style="color: var(--text-primary); margin-top: 2px;">${meeting.title}</h3>
            ${meeting.description ? `<p style="color: var(--text-secondary); font-size: 0.88rem; margin-top: 4px;">${meeting.description}</p>` : ''}
          </div>

          <div class="grid-2" style="margin-bottom: 16px;">
            <div class="card" style="padding: 12px;">
              <div style="font-size: 0.75rem; color: var(--text-muted);">ROOM CODE</div>
              <div style="font-family: monospace; font-weight: 700; color: var(--accent-cyan); font-size: 1.05rem;">CNK-${meeting.roomCode}</div>
            </div>
            <div class="card" style="padding: 12px;">
              <div style="font-size: 0.75rem; color: var(--text-muted);">YOUR ROLE</div>
              <div style="font-weight: 700; color: #10b981; font-size: 1.05rem; text-transform: capitalize;">${role}</div>
            </div>
          </div>

          <div style="margin-bottom: 16px;">
            <div style="font-size: 0.8rem; color: var(--text-muted); margin-bottom: 8px; font-weight: 600;">ACTIVE PARTICIPANTS (${participants?.length || 1})</div>
            <div style="display: flex; flex-direction: column; gap: 8px; max-height: 140px; overflow-y: auto;">
              ${(participants || []).map(p => `
                <div style="display: flex; align-items: center; justify-content: space-between; padding: 6px 10px; background: var(--bg-input); border-radius: var(--radius-sm);">
                  <div style="display: flex; align-items: center; gap: 8px;">
                    <img src="${p.avatar_url || '/assets/images/default-avatar.png'}" style="width: 24px; height: 24px; border-radius: 50%; object-fit: cover;" />
                    <span style="font-size: 0.88rem; font-weight: 600;">${p.name || p.email}</span>
                  </div>
                  <span class="badge ${p.role === 'host' ? 'badge-primary' : 'badge-mode'}" style="font-size: 0.7rem; text-transform: capitalize;">${p.role}</span>
                </div>
              `).join('')}
            </div>
          </div>

          <div style="padding: 12px; background: rgba(37, 99, 235, 0.1); border: 1px solid rgba(37, 99, 235, 0.25); border-radius: var(--radius-md); font-size: 0.82rem; color: #93c5fd;">
            ℹ️ Phase 1 Attendance session has been initiated in PostgreSQL. Real-time WebRTC media streams & audio/video calling are part of Phase 2.
          </div>
        </div>
        <div class="modal-footer" style="display: flex; justify-content: space-between;">
          <button class="btn btn-secondary" onclick="window.app.handleLeaveRoom('${meeting.roomCode}'); document.getElementById('${modalId}').remove();">Leave Room</button>
          <button class="btn btn-primary" onclick="document.getElementById('${modalId}').remove()">Stay in Room</button>
        </div>
      </div>
    `;
    modalContainer.appendChild(div);
  }

  async handleLeaveRoom(roomCode) {
    try {
      this.showLoading(true);
      await window.api.meetings.leaveRoom(roomCode);
      this.showToast('You left the meeting room.', 'info');
      await this.loadMeetingsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  openScheduleMeetingModal() {
    const modalContainer = document.getElementById('meetingsModalContainer') || document.body;
    const modalId = 'scheduleMeetingModal';
    const existing = document.getElementById(modalId);
    if (existing) existing.remove();

    // Default scheduled time: 15 minutes in future
    const now = new Date();
    now.setMinutes(now.getMinutes() + 15);
    const localIso = new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 16);

    const div = document.createElement('div');
    div.id = modalId;
    div.className = 'modal-overlay active';
    div.innerHTML = `
      <div class="modal-content" style="max-width: 560px;">
        <div class="modal-header">
          <div style="display: flex; align-items: center; gap: 10px;">
            <div style="width: 32px; height: 32px; border-radius: 8px; background: rgba(168, 85, 247, 0.2); color: #c084fc; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">📅</div>
            <h3 class="modal-title">Schedule a Meeting</h3>
          </div>
          <button class="modal-close-btn" onclick="document.getElementById('${modalId}').remove()">&times;</button>
        </div>
        <form onsubmit="window.app.handleScheduleMeetingSubmit(event)">
          <div class="modal-body">
            <div class="form-group">
              <label class="form-label">Meeting Title *</label>
              <input type="text" id="schTitle" class="form-control" placeholder="e.g. CONNEKT Engineering Sprint Review" required />
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Date & Start Time *</label>
                <input type="datetime-local" id="schDate" class="form-control" value="${localIso}" required />
              </div>
              <div class="form-group">
                <label class="form-label">Expected Duration</label>
                <select id="schDuration" class="form-control">
                  <option value="15">15 Minutes</option>
                  <option value="30">30 Minutes</option>
                  <option value="45" selected>45 Minutes</option>
                  <option value="60">1 Hour</option>
                  <option value="90">1.5 Hours</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Meeting Description</label>
              <textarea id="schDescription" class="form-control" rows="2" placeholder="Brief context about this meeting..."></textarea>
            </div>

            <div class="form-group">
              <label class="form-label">Agenda</label>
              <textarea id="schAgenda" class="form-control" rows="2" placeholder="Topics to cover, goals, action items..."></textarea>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Attendees (Emails or Usernames)</label>
                <input type="text" id="schAttendees" class="form-control" placeholder="sarah@connekt.net.in, alex" />
                <span style="font-size: 0.75rem; color: var(--text-muted);">Separate with commas.</span>
              </div>
              <div class="form-group">
                <label class="form-label">Optional Passcode</label>
                <input type="text" id="schPasscode" class="form-control" placeholder="Leave empty for public" />
              </div>
            </div>

            <div style="display: flex; gap: 20px; align-items: center; margin-top: 10px; padding: 10px; background: rgba(255,255,255,0.02); border-radius: 8px; border: 1px solid var(--border-subtle);">
              <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer; color: var(--text-primary);">
                <input type="checkbox" id="schSendInvites" checked />
                <span>✉️ Send Email Invitations</span>
              </label>
              <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; cursor: pointer; color: var(--text-primary);">
                <input type="checkbox" id="schSyncGoogle" />
                <span>📅 Sync to Google Calendar</span>
              </label>
            </div>
          </div>
          <div class="modal-footer" style="display: flex; justify-content: space-between;">
            <button type="button" class="btn btn-secondary" onclick="document.getElementById('${modalId}').remove()">Cancel</button>
            <button type="submit" class="btn btn-primary">Schedule Meeting 📅</button>
          </div>
        </form>
      </div>
    `;
    modalContainer.appendChild(div);
  }

  async handleScheduleMeetingSubmit(e) {
    e.preventDefault();
    try {
      this.showLoading(true);
      const title = document.getElementById('schTitle').value.trim();
      const scheduledAt = document.getElementById('schDate').value;
      const durationMinutes = parseInt(document.getElementById('schDuration').value, 10);
      const description = document.getElementById('schDescription').value.trim();
      const agenda = document.getElementById('schAgenda').value.trim();
      const rawAttendees = document.getElementById('schAttendees').value;
      const passcode = document.getElementById('schPasscode').value.trim();

      const attendees = rawAttendees ? rawAttendees.split(',').map(s => s.trim()).filter(Boolean) : [];

      const payload = {
        title,
        scheduledAt,
        durationMinutes,
        description,
        agenda,
        attendees,
        passcode: passcode || undefined
      };

      const res = await window.api.meetings.scheduleMeeting(payload);
      const meeting = res.data.meeting;

      // If Google Sync selected, trigger calendar sync
      const shouldSyncGoogle = document.getElementById('schSyncGoogle')?.checked;
      if (shouldSyncGoogle && meeting?.id) {
        try {
          await window.api.meetings.syncGoogleCalendar(meeting.id);
        } catch (_) {}
      }

      // Close modal
      const modal = document.getElementById('scheduleMeetingModal');
      if (modal) modal.remove();

      this.showToast('Meeting scheduled successfully!', 'success');
      await this.loadMeetingsList();
    } catch (err) {
      console.error('Failed to schedule meeting:', err);
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleCopyMeetingLink(roomCode, title = 'CONNEKT Meeting') {
    const link = `${window.location.origin}/meet/${roomCode}`;
    const text = `Join my CONNEKT Meeting: "${title}"\nRoom Code: ${roomCode}\nDirect Link: ${link}`;
    await this.handleCopyText(text, 'Meeting invitation copied to clipboard!');
  }

  async handleCopyText(text, successMsg = 'Copied to clipboard!') {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const t = document.createElement('textarea');
        t.value = text;
        document.body.appendChild(t);
        t.select();
        document.execCommand('copy');
        document.body.removeChild(t);
      }
      this.showToast(successMsg, 'success');
    } catch (err) {
      this.showToast('Failed to copy to clipboard', 'warning');
    }
  }

  async handleCancelMeeting(meetingId) {
    if (!confirm('Are you sure you want to cancel this meeting?')) return;
    try {
      this.showLoading(true);
      await window.api.meetings.cancelMeeting(meetingId);
      this.showToast('Meeting cancelled.', 'info');
      await this.loadMeetingsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async handleToggleMeetingLock(meetingId, currentLock) {
    try {
      this.showLoading(true);
      const nextLock = !currentLock;
      const res = await window.api.meetings.toggleLock(meetingId, nextLock);
      this.showToast(res.message, 'success');
      await this.loadMeetingsList();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  // ====================================================================
  // MEETING RECORDS, MINUTES & ACTION ITEMS MODAL (PHASE 4)
  // ====================================================================

  async openMeetingRecordsModal(meetingId) {
    try {
      this.showLoading(true);

      const [attRes, minRes, recRes] = await Promise.all([
        window.api.meetings.getAttendance(meetingId).catch(() => ({ data: { attendance: [], stats: {} } })),
        window.api.meetings.getMinutes(meetingId).catch(() => ({ data: { meeting: {}, minutes: null, actionItems: [] } })),
        window.api.meetings.getRecordings(meetingId).catch(() => ({ data: { recordings: [] } }))
      ]);

      const attendance = attRes.data?.attendance || [];
      const stats = attRes.data?.stats || { totalParticipants: 0, totalDurationSeconds: 0, averageDurationSeconds: 0 };
      const minutes = minRes.data?.minutes || { summary: '', discussion_points: '', decisions: '' };
      const actionItems = minRes.data?.actionItems || [];
      const recordings = recRes.data?.recordings || [];
      const meeting = minRes.data?.meeting || {};

      const modalContainer = document.getElementById('meetingsModalContainer') || document.body;
      const modalId = 'meetingRecordsModal';
      const existing = document.getElementById(modalId);
      if (existing) existing.remove();

      const formatDuration = (secs) => {
        if (!secs || secs < 0) return '0m';
        const mins = Math.floor(secs / 60);
        const remSecs = secs % 60;
        return `${mins}m ${remSecs}s`;
      };

      const div = document.createElement('div');
      div.id = modalId;
      div.className = 'modal-overlay active';
      div.innerHTML = `
        <div class="modal-content" style="max-width: 760px; max-height: 90vh; overflow-y: auto;">
          <div class="modal-header">
            <div>
              <div style="font-size: 0.75rem; color: var(--accent-cyan); text-transform: uppercase; font-weight: 700;">Meeting Records & Minutes</div>
              <h3 class="modal-title" style="margin: 2px 0 0 0;">${meeting.title || 'Meeting Details'}</h3>
            </div>
            <button class="modal-close-btn" onclick="document.getElementById('${modalId}').remove()">&times;</button>
          </div>

          <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; padding: 10px 14px; background: rgba(255,255,255,0.02); border-radius: 8px; border: 1px solid var(--border-subtle);">
            <div style="font-size: 0.82rem; color: var(--text-muted); display: flex; align-items: center; gap: 8px;">
              <span>Room: <strong style="color: var(--accent-cyan);">CNK-${meeting.roomCode || meeting.room_code || ''}</strong></span>
              ${meeting.google_synced ? '<span class="badge badge-success" style="font-size: 0.68rem;">📅 Google Synced</span>' : ''}
            </div>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              <button class="btn btn-secondary btn-sm" style="font-size: 0.78rem;" onclick="window.app.syncGoogleCalendarHandler('${meetingId}')">
                📅 Sync Google Calendar
              </button>
              <button class="btn btn-secondary btn-sm" style="font-size: 0.78rem;" onclick="window.app.downloadICalendarHandler('${meetingId}')">
                📥 Download .ics
              </button>
              <button class="btn btn-secondary btn-sm" style="font-size: 0.78rem;" onclick="window.app.sendMeetingInvitesHandler('${meetingId}')">
                ✉️ Send Invites
              </button>
            </div>
          </div>

          <div class="records-modal-tabs">
            <button class="records-tab-btn active" data-rec-tab="attendance" onclick="window.app.switchRecordsTab('attendance')">👥 Attendance (${attendance.length})</button>
            <button class="records-tab-btn" data-rec-tab="minutes" onclick="window.app.switchRecordsTab('minutes')">📝 Minutes & Notes</button>
            <button class="records-tab-btn" data-rec-tab="actions" onclick="window.app.switchRecordsTab('actions')">✅ Action Items (${actionItems.length})</button>
            <button class="records-tab-btn" data-rec-tab="recordings" onclick="window.app.switchRecordsTab('recordings')">🎥 Recordings (${recordings.length})</button>
          </div>

          <!-- Tab 1: Attendance Log -->
          <div id="pane-attendance" class="records-tab-pane active">
            <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 16px;">
              <div class="card" style="padding: 12px; text-align: center; background: rgba(255,255,255,0.02);">
                <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase;">Total Attendees</div>
                <div style="font-size: 1.4rem; font-weight: 700; color: var(--accent-cyan);">${stats.totalParticipants}</div>
              </div>
              <div class="card" style="padding: 12px; text-align: center; background: rgba(255,255,255,0.02);">
                <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase;">Total Time Logged</div>
                <div style="font-size: 1.4rem; font-weight: 700; color: var(--text-primary);">${formatDuration(stats.totalDurationSeconds)}</div>
              </div>
              <div class="card" style="padding: 12px; text-align: center; background: rgba(255,255,255,0.02);">
                <div style="font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase;">Avg Participant Duration</div>
                <div style="font-size: 1.4rem; font-weight: 700; color: var(--color-success);">${formatDuration(stats.averageDurationSeconds)}</div>
              </div>
            </div>

            <div style="display: flex; justify-content: flex-end; margin-bottom: 12px;">
              <button class="btn btn-secondary btn-sm" id="btnExportAttendanceCsv">
                📥 Download Attendance CSV
              </button>
            </div>

            ${attendance.length === 0 ? `
              <div style="text-align: center; padding: 24px; color: var(--text-muted);">
                No attendance logs found for this meeting yet.
              </div>
            ` : `
              <div style="overflow-x: auto; border: 1px solid var(--border-subtle); border-radius: 8px;">
                <table class="attendance-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>Email</th>
                      <th>Joined At</th>
                      <th>Left At</th>
                      <th>Duration</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${attendance.map(a => `
                      <tr>
                        <td style="font-weight: 600;">${a.name || 'Anonymous'}</td>
                        <td style="color: var(--text-muted); font-size: 0.8rem;">${a.email || '-'}</td>
                        <td style="font-size: 0.8rem; color: var(--text-secondary);">${new Date(a.joined_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</td>
                        <td style="font-size: 0.8rem; color: var(--text-secondary);">${a.left_at ? new Date(a.left_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '<span class="status-beacon live" style="font-size: 0.65rem;">Active</span>'}</td>
                        <td><span class="badge badge-primary">${formatDuration(a.duration_seconds)}</span></td>
                      </tr>
                    `).join('')}
                  </tbody>
                </table>
              </div>
            `}
          </div>

          <!-- Tab 2: Meeting Minutes & Notes -->
          <div id="pane-minutes" class="records-tab-pane">
            <form id="meetingMinutesForm" onsubmit="event.preventDefault(); window.app.saveMinutesHandler('${meetingId}')">
              <div class="form-group" style="margin-bottom: 14px;">
                <label class="form-label" style="font-weight: 600;">Meeting Executive Summary</label>
                <textarea id="minutesSummary" class="form-control" rows="3" placeholder="Overview of the meeting agenda, key highlights, and primary discussions...">${minutes.summary || ''}</textarea>
              </div>

              <div class="form-group" style="margin-bottom: 14px;">
                <label class="form-label" style="font-weight: 600;">Discussion Points</label>
                <textarea id="minutesDiscussion" class="form-control" rows="4" placeholder="Detailed topics discussed, arguments presented, technical evaluations...">${minutes.discussion_points_text || (Array.isArray(minutes.discussion_points) ? minutes.discussion_points.join('\n') : minutes.discussion_points) || ''}</textarea>
              </div>

              <div class="form-group" style="margin-bottom: 16px;">
                <label class="form-label" style="font-weight: 600;">Key Decisions Made</label>
                <textarea id="minutesDecisions" class="form-control" rows="3" placeholder="Final conclusions reached, agreed architectures, policies, or alignments...">${minutes.decisions_text || (Array.isArray(minutes.decisions) ? minutes.decisions.join('\n') : minutes.decisions) || ''}</textarea>
              </div>

              <div style="display: flex; justify-content: flex-end; gap: 10px;">
                <button type="submit" class="btn btn-primary">Save Meeting Minutes 💾</button>
              </div>
            </form>
          </div>

          <!-- Tab 3: Action Items & Tasks -->
          <div id="pane-actions" class="records-tab-pane">
            <!-- Add New Action Item Form -->
            <form id="addActionItemForm" style="background: rgba(255,255,255,0.02); border: 1px solid var(--border-subtle); border-radius: 8px; padding: 14px; margin-bottom: 16px;" onsubmit="event.preventDefault(); window.app.addActionItemHandler('${meetingId}')">
              <div style="font-weight: 600; font-size: 0.88rem; margin-bottom: 10px; color: var(--accent-cyan);">+ Add Action Item</div>
              <div style="display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 10px; margin-bottom: 10px;">
                <input type="text" id="actionItemTitle" class="form-control" placeholder="Action item title *" required />
                <input type="text" id="actionItemAssigned" class="form-control" placeholder="Assignee (email/name)" />
                <select id="actionItemPriority" class="form-control">
                  <option value="medium">Medium Priority</option>
                  <option value="high">High Priority</option>
                  <option value="low">Low Priority</option>
                </select>
              </div>
              <div style="display: flex; gap: 10px; align-items: center;">
                <input type="date" id="actionItemDueDate" class="form-control" style="max-width: 180px;" />
                <input type="text" id="actionItemDesc" class="form-control" placeholder="Optional details or context..." />
                <button type="submit" class="btn btn-primary btn-sm" style="white-space: nowrap;">Add Item</button>
              </div>
            </form>

            <!-- Action Items List -->
            <div id="actionItemsListContainer">
              ${actionItems.length === 0 ? `
                <div style="text-align: center; padding: 24px; color: var(--text-muted);">
                  No action items created yet. Add deliverables above!
                </div>
              ` : actionItems.map(item => `
                <div class="action-item-card ${item.status === 'completed' ? 'completed' : ''}">
                  <input type="checkbox" ${item.status === 'completed' ? 'checked' : ''} style="margin-top: 4px; cursor: pointer;" onchange="window.app.toggleActionItemHandler('${meetingId}', '${item.id}', '${item.status}')" />
                  <div style="flex: 1;">
                    <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px; flex-wrap: wrap;">
                      <span class="action-title" style="font-weight: 600; color: var(--text-primary); font-size: 0.95rem;">${item.title}</span>
                      <span class="action-priority-badge ${item.priority || 'medium'}">${item.priority || 'medium'}</span>
                      <span class="badge ${item.status === 'completed' ? 'badge-success' : 'badge-warning'}" style="font-size: 0.7rem;">${item.status}</span>
                    </div>
                    ${item.description ? `<p style="font-size: 0.82rem; color: var(--text-secondary); margin: 0 0 4px 0;">${item.description}</p>` : ''}
                    <div style="font-size: 0.75rem; color: var(--text-muted); display: flex; gap: 14px;">
                      <span>👤 Assigned: <strong>${item.assigned_name || item.assigned_to || 'Unassigned'}</strong></span>
                      ${item.due_date ? `<span>📅 Due: <strong>${new Date(item.due_date).toLocaleDateString()}</strong></span>` : ''}
                    </div>
                  </div>
                  <div style="display: flex; align-items: center; gap: 6px;">
                    ${item.status !== 'converted' ? `
                      <button class="btn btn-secondary btn-sm" style="color: var(--accent-cyan); font-size: 0.78rem; padding: 3px 8px;" onclick="window.app.convertActionItemHandler('${meetingId}', '${item.id}')" title="Convert to Task">
                        🚀 Convert to Task
                      </button>
                    ` : `
                      <span class="badge badge-success" style="font-size: 0.72rem;">✓ Task Created</span>
                    `}
                    <button class="btn btn-secondary btn-sm" style="color: var(--color-danger); padding: 2px 6px; font-size: 0.8rem;" onclick="window.app.deleteActionItemHandler('${meetingId}', '${item.id}')" title="Delete action item">
                      🗑️
                    </button>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- Tab 4: Meeting Recordings -->
          <div id="pane-recordings" class="records-tab-pane">
            ${recordings.length === 0 ? `
              <div style="text-align: center; padding: 32px; color: var(--text-muted);">
                <div style="font-size: 2rem; margin-bottom: 8px;">🎥</div>
                <div style="font-weight: 600; margin-bottom: 4px;">No recordings logged for this meeting</div>
                <p style="font-size: 0.85rem; max-width: 380px; margin: 0 auto;">
                  During an active call, click the ⏺️ record button to capture the video stream, audio, and screen share.
                </p>
              </div>
            ` : `
              <div style="display: flex; flex-direction: column; gap: 10px;">
                ${recordings.map(rec => `
                  <div class="card" style="display: flex; align-items: center; justify-content: space-between; padding: 14px; background: rgba(255,255,255,0.02);">
                    <div style="display: flex; align-items: center; gap: 12px;">
                      <div style="width: 36px; height: 36px; border-radius: 8px; background: rgba(239, 68, 68, 0.15); color: #f87171; display: flex; align-items: center; justify-content: center; font-size: 1.2rem;">🎥</div>
                      <div>
                        <div style="font-weight: 600; color: var(--text-primary); font-size: 0.9rem;">${rec.file_name}</div>
                        <div style="font-size: 0.75rem; color: var(--text-muted); display: flex; gap: 12px;">
                          <span>⏱️ ${formatDuration(rec.duration_seconds)}</span>
                          <span>💾 ${(rec.file_size_bytes / (1024 * 1024)).toFixed(1)} MB</span>
                          <span>🕒 ${new Date(rec.created_at).toLocaleString()}</span>
                        </div>
                      </div>
                    </div>
                    <span class="badge badge-success" style="font-size: 0.72rem;">Saved to Browser</span>
                  </div>
                `).join('')}
              </div>
            `}
          </div>
        </div>
      `;

      modalContainer.appendChild(div);

      // Attach CSV Export Listener
      const btnCsv = document.getElementById('btnExportAttendanceCsv');
      if (btnCsv) {
        btnCsv.onclick = () => {
          this.downloadAttendanceCsv(meeting.title || 'Meeting', meeting.room_code || 'CNK', attendance);
        };
      }
    } catch (err) {
      console.error('Error opening meeting records modal:', err);
      this.showToast('Failed to open meeting records: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  switchRecordsTab(tabName) {
    document.querySelectorAll('.records-tab-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.recTab === tabName);
    });
    document.querySelectorAll('.records-tab-pane').forEach(pane => {
      pane.classList.remove('active');
    });
    const activePane = document.getElementById(`pane-${tabName}`);
    if (activePane) activePane.classList.add('active');
  }

  async saveMinutesHandler(meetingId) {
    try {
      this.showLoading(true);
      const summary = document.getElementById('minutesSummary')?.value || '';
      const discussionPoints = document.getElementById('minutesDiscussion')?.value || '';
      const decisions = document.getElementById('minutesDecisions')?.value || '';

      await window.api.meetings.saveMinutes(meetingId, {
        summary,
        discussionPoints,
        decisions
      });

      this.showToast('Meeting minutes saved successfully!', 'success');
    } catch (err) {
      this.showToast('Failed to save minutes: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async addActionItemHandler(meetingId) {
    try {
      const title = document.getElementById('actionItemTitle')?.value;
      const assignedTo = document.getElementById('actionItemAssigned')?.value;
      const priority = document.getElementById('actionItemPriority')?.value;
      const dueDate = document.getElementById('actionItemDueDate')?.value;
      const description = document.getElementById('actionItemDesc')?.value;

      if (!title || !title.trim()) {
        this.showToast('Please provide an action item title.', 'warning');
        return;
      }

      this.showLoading(true);
      await window.api.meetings.addActionItem(meetingId, {
        title: title.trim(),
        assignedTo: assignedTo ? assignedTo.trim() : null,
        priority: priority || 'medium',
        dueDate: dueDate || null,
        description: description ? description.trim() : null
      });

      this.showToast('Action item added!', 'success');
      // Reopen modal to refresh list
      await this.openMeetingRecordsModal(meetingId);
      this.switchRecordsTab('actions');
    } catch (err) {
      this.showToast('Failed to add action item: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async toggleActionItemHandler(meetingId, itemId, currentStatus) {
    try {
      const nextStatus = currentStatus === 'completed' ? 'pending' : 'completed';
      await window.api.meetings.updateActionItem(meetingId, itemId, { status: nextStatus });
      this.showToast(`Action item marked ${nextStatus}.`, 'success');
      await this.openMeetingRecordsModal(meetingId);
      this.switchRecordsTab('actions');
    } catch (err) {
      this.showToast('Failed to update action item: ' + err.message, 'error');
    }
  }

  async deleteActionItemHandler(meetingId, itemId) {
    if (!confirm('Are you sure you want to delete this action item?')) return;
    try {
      this.showLoading(true);
      await window.api.meetings.deleteActionItem(meetingId, itemId);
      this.showToast('Action item deleted.', 'info');
      await this.openMeetingRecordsModal(meetingId);
      this.switchRecordsTab('actions');
    } catch (err) {
      this.showToast('Failed to delete action item: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  downloadAttendanceCsv(meetingTitle, roomCode, attendanceList) {
    try {
      const headers = ['Participant Name', 'Email', 'Joined At', 'Left At', 'Duration (Seconds)', 'Duration (Minutes)'];
      const rows = attendanceList.map(a => [
        `"${(a.name || 'Anonymous').replace(/"/g, '""')}"`,
        `"${(a.email || '').replace(/"/g, '""')}"`,
        `"${a.joined_at ? new Date(a.joined_at).toISOString() : ''}"`,
        `"${a.left_at ? new Date(a.left_at).toISOString() : ''}"`,
        a.duration_seconds || 0,
        ((a.duration_seconds || 0) / 60).toFixed(1)
      ]);

      const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `attendance-${roomCode}-${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(url), 5000);

      this.showToast('Attendance report CSV downloaded!', 'success');
    } catch (e) {
      this.showToast('Failed to export CSV: ' + e.message, 'error');
    }
  }

  // ====================================================================
  // PHASE 5 INTEGRATION HANDLERS (TASKS, CALENDAR & EMAIL)
  // ====================================================================

  async convertActionItemHandler(meetingId, itemId) {
    try {
      this.showLoading(true);
      const res = await window.api.meetings.convertActionItemToTask(meetingId, itemId);
      this.showToast(`Action item converted into task "${res.data.task.title}"!`, 'success');
      await this.openMeetingRecordsModal(meetingId);
      this.switchRecordsTab('actions');
    } catch (err) {
      this.showToast('Failed to convert action item: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  async syncGoogleCalendarHandler(meetingId) {
    try {
      this.showLoading(true);
      const res = await window.api.meetings.syncGoogleCalendar(meetingId);
      this.showToast('Meeting synchronized to Google Calendar!', 'success');
      await this.openMeetingRecordsModal(meetingId);
    } catch (err) {
      if (err.data?.authRequired) {
        // Open Google OAuth flow or simulation
        try {
          const authRes = await window.api.meetings.getGoogleAuthUrl();
          if (authRes.data?.configured && authRes.data?.authUrl) {
            window.open(authRes.data.authUrl, '_blank');
          } else {
            // Auto connect via simulated dev mode
            await window.api.meetings.handleGoogleCallback('dev-simulated-code');
            await window.api.meetings.syncGoogleCalendar(meetingId);
            this.showToast('Google Calendar connected (Dev Mode) and meeting synced!', 'success');
            await this.openMeetingRecordsModal(meetingId);
          }
        } catch (authErr) {
          this.showToast(authErr.message, 'error');
        }
      } else {
        this.showToast(err.message, 'error');
      }
    } finally {
      this.showLoading(false);
    }
  }

  downloadICalendarHandler(meetingId) {
    try {
      const token = localStorage.getItem('accessToken');
      const url = `/api/meetings/${meetingId}/icalendar`;
      fetch(url, { headers: { Authorization: `Bearer ${token}` } })
        .then(res => {
          if (!res.ok) throw new Error('Failed to generate iCalendar file');
          return res.blob();
        })
        .then(blob => {
          const dlUrl = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = dlUrl;
          a.download = `meeting-${meetingId}.ics`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          setTimeout(() => URL.revokeObjectURL(dlUrl), 5000);
          this.showToast('iCalendar (.ics) file downloaded! Open to add to calendar.', 'success');
        })
        .catch(err => this.showToast(err.message, 'error'));
    } catch (e) {
      this.showToast('Failed to download calendar file: ' + e.message, 'error');
    }
  }

  async sendMeetingInvitesHandler(meetingId) {
    try {
      this.showLoading(true);
      const res = await window.api.meetings.sendMeetingInvitations(meetingId);
      this.showToast(res.message || 'Meeting email invitations sent!', 'success');
    } catch (err) {
      this.showToast('Failed to send email invites: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  renderPhaseModulePlaceholder(container, moduleName) {
    const modules = {
      messages: { title: 'Direct & Group Messaging', phase: 'Phase 2', desc: 'Real-time WebSocket chat, read receipts, voice notes, and group invitation approval.' },
      communities: { title: 'Communities & Live Streaming', phase: 'Phase 3', desc: 'Public & private communities, interactive live streams, comments, and member roles.' },
      mail: { title: 'Connekt Mail Client', phase: 'Phase 4', desc: 'Dedicated email interface with your unique ID ' + (this.currentUser?.email || 'user@connekt.net.in') + ', SMTP delivery, and attachments.' },
      meetings: { title: 'Meetings & Audio/Video Calls', phase: 'Phase 4', desc: 'P2P WebRTC voice/video calls, screen sharing, and multi-user conference rooms.' },
      reminders: { title: 'Centralized Reminder Box', phase: 'Phase 5', desc: 'Smart reminders, cross-module clip saving, notifications, and scheduled tasks.' },
      network: { title: 'Professional Career Network', phase: 'Phase 6', desc: 'Job postings, internship boards, enterprise networking, and talent discovery.' },
      ai: { title: 'AI Assistant (Gemini Ecosystem)', phase: 'Phase 5', desc: 'Conversational assistant for message writing, meeting summaries, and multilingual translations.' },
      shield: { title: 'Connekt Shield Intelligent Security', phase: 'Phase 5', desc: 'Spam scoring, malicious link filtering, phishing protection, and fraud defense.' }
    };

    const mod = modules[moduleName] || { title: moduleName, phase: 'Upcoming Phase', desc: 'Module roadmap in progress.' };

    container.innerHTML = `
      <div class="card phase-preview-card">
        <span class="phase-tag">${mod.phase} ROADMAP</span>
        <h2 style="margin-bottom: 8px;">${mod.title}</h2>
        <p style="color: var(--text-secondary); max-width: 600px; margin: 0 auto 24px;">${mod.desc}</p>
        <div style="display: flex; justify-content: center; gap: 12px;">
          <button class="btn btn-secondary" onclick="window.app.navigateTo('home')">Return to Dashboard</button>
          <button class="btn btn-primary" onclick="window.app.navigateTo('profile')">Complete Profile</button>
        </div>
      </div>
    `;
  }
}

// Instantiate and export app controller
window.app = new AppController();
document.addEventListener('DOMContentLoaded', () => {
  window.app.init();

  // ====================================================================
  // SCHEDULE & CALENDAR MODULE (WITH TWO-WAY REMINDER INTEGRATION)
  // ====================================================================

  async renderScheduleView(container) {
    this.showLoading(true);
    try {
      const [remindersRes, meetingsRes] = await Promise.all([
        window.api.reminders.getAll().catch(() => ({ data: [] })),
        window.api.meetings.listMeetings().catch(() => ({ data: [] }))
      ]);

      this.reminders = remindersRes.data || [];
      const meetings = meetingsRes.data || [];

      const selDate = this.calendarDate || new Date();
      const selYear = selDate.getFullYear();
      const selMonth = selDate.getMonth();
      const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
      const monthStr = monthNames[selMonth] + " " + selYear;

      const firstDay = new Date(selYear, selMonth, 1).getDay();
      const daysInMonth = new Date(selYear, selMonth + 1, 0).getDate();

      let calCellsHtml = '';
      for (let i = 0; i < firstDay; i++) {
        calCellsHtml += '<div class="mini-cal-cell empty"></div>';
      }

      for (let d = 1; d <= daysInMonth; d++) {
        const cellDate = new Date(selYear, selMonth, d);
        const isSelected = d === selDate.getDate();
        const hasReminder = this.reminders.some(r => this._matchesReminderDate(r, cellDate));
        const hasMeeting = meetings.some(m => {
          if (!m.scheduled_start_time) return false;
          const md = new Date(m.scheduled_start_time);
          return md.getFullYear() === selYear && md.getMonth() === selMonth && md.getDate() === d;
        });

        let classes = 'mini-cal-cell';
        let dots = '';
        if (isSelected) classes += ' today';
        if (hasReminder) {
          classes += ' has-reminder';
          dots += '<div class="mini-cal-dot red"></div>';
        }
        if (hasMeeting) {
          dots += '<div class="mini-cal-dot green"></div>';
        }

        calCellsHtml += `<div class="${classes}" style="cursor: pointer;" onclick="window.app.selectCalendarDay(${d})">${d}${dots}</div>`;
      }

      // Filter day items
      const dayReminders = this.reminders.filter(r => this._matchesReminderDate(r, selDate));
      const dayMeetings = meetings.filter(m => {
        if (!m.scheduled_start_time) return false;
        const md = new Date(m.scheduled_start_time);
        return md.getFullYear() === selDate.getFullYear() && md.getMonth() === selDate.getMonth() && md.getDate() === selDate.getDate();
      });

      const dayTitle = selDate.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

      container.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 12px;">
            <button class="icon-btn" onclick="window.app.navigateTo('home')" style="font-size: 1.2rem;">←</button>
            <div>
              <h2 style="margin: 0; font-size: 1.4rem; font-weight: 800;">Schedule & Calendar</h2>
              <span style="font-size: 0.8rem; color: var(--text-muted);">Unified Schedule, Meetings & Two-Way Reminders</span>
            </div>
          </div>
          <div style="display: flex; gap: 10px;">
            <button class="btn btn-primary" onclick="window.app.showAddReminderModal()">+ New Reminder</button>
            <button class="btn btn-secondary" onclick="window.app.navigateTo('meetings')">+ Schedule Meeting</button>
          </div>
        </div>

        <div class="grid-2" style="margin-bottom: 24px;">
          <!-- Monthly Calendar Card -->
          <div class="card" style="border-radius: var(--radius-lg); padding: 20px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
              <button class="icon-btn" onclick="window.app.changeCalendarMonth(-1)" style="font-size: 1.2rem;">‹</button>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">${monthStr}</h3>
              <button class="icon-btn" onclick="window.app.changeCalendarMonth(1)" style="font-size: 1.2rem;">›</button>
            </div>
            <div class="mini-cal-days-row" style="margin-bottom: 10px;">
              <span>Sun</span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span>
            </div>
            <div class="mini-cal-grid" style="gap: 8px;">
              ${calCellsHtml}
            </div>
            <div style="display: flex; justify-content: center; gap: 16px; margin-top: 18px; font-size: 0.78rem; color: var(--text-secondary);">
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="width: 8px; height: 8px; border-radius: 50%; background: #ef4444;"></span>
                <span>Reminder</span>
              </div>
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="width: 8px; height: 8px; border-radius: 50%; background: #10b981;"></span>
                <span>Meeting</span>
              </div>
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="width: 8px; height: 8px; border-radius: 50%; background: #3b82f6;"></span>
                <span>Selected</span>
              </div>
            </div>
          </div>

          <!-- Day Schedule Card -->
          <div class="card" style="border-radius: var(--radius-lg); padding: 20px; display: flex; flex-direction: column;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--border-subtle); padding-bottom: 10px;">
              <div>
                <span style="font-size: 0.75rem; text-transform: uppercase; color: var(--accent-cyan); font-weight: 700;">Day Schedule</span>
                <h4 style="margin: 2px 0 0; font-size: 1.05rem; font-weight: 800;">${dayTitle}</h4>
              </div>
              <button class="btn btn-secondary btn-sm" onclick="window.app.showAddReminderModal()">+ Reminder</button>
            </div>

            <!-- Reminders List -->
            <div style="flex: 1; overflow-y: auto;">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--text-secondary); margin-bottom: 8px; text-transform: uppercase;">Reminders (${dayReminders.length})</div>
              ${dayReminders.length === 0 ? `
                <div style="padding: 16px; text-align: center; color: var(--text-muted); font-size: 0.88rem; background: rgba(255,255,255,0.02); border-radius: 8px;">
                  No reminders for this date.
                </div>
              ` : dayReminders.map(r => `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: var(--bg-card-hover); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
                  <div style="display: flex; align-items: center; gap: 10px;">
                    <input type="checkbox" ${r.is_completed ? 'checked' : ''} onchange="window.app.handleToggleReminder('${r.id}')" style="cursor: pointer; width: 18px; height: 18px;" />
                    <div>
                      <div style="font-weight: 700; font-size: 0.92rem; text-decoration: ${r.is_completed ? 'line-through' : 'none'}; color: ${r.is_completed ? 'var(--text-muted)' : 'var(--text-primary)'};">${r.title}</div>
                      <div style="font-size: 0.76rem; color: var(--text-secondary);">${r.due_time || '10:00 AM'} ${r.repeat_frequency && r.repeat_frequency !== 'none' ? '• 🔁 ' + r.repeat_frequency : ''}</div>
                    </div>
                  </div>
                  <div style="display: flex; gap: 6px;">
                    <button class="icon-btn" onclick="window.app.handleDeleteReminder('${r.id}')" title="Delete" style="color: #ef4444; font-size: 0.9rem;">🗑️</button>
                  </div>
                </div>
              `).join('')}

              <div style="font-size: 0.8rem; font-weight: 700; color: var(--text-secondary); margin: 16px 0 8px; text-transform: uppercase;">Meetings (${dayMeetings.length})</div>
              ${dayMeetings.length === 0 ? `
                <div style="padding: 16px; text-align: center; color: var(--text-muted); font-size: 0.88rem; background: rgba(255,255,255,0.02); border-radius: 8px;">
                  No scheduled meetings for this date.
                </div>
              ` : dayMeetings.map(m => `
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: rgba(37,99,235,0.08); border: 1px solid rgba(37,99,235,0.25); border-radius: 8px; margin-bottom: 8px;">
                  <div>
                    <div style="font-weight: 700; font-size: 0.92rem; color: #60a5fa;">${m.title}</div>
                    <div style="font-size: 0.76rem; color: var(--text-secondary);">${new Date(m.scheduled_start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                  </div>
                  <button class="btn btn-primary btn-sm" onclick="window.app.handleJoinMeetingFromCard('${m.meeting_code}')">Join</button>
                </div>
              `).join('')}
            </div>
          </div>
        </div>
      `;
    } catch (err) {
      this.showToast('Failed to load schedule: ' + err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  changeCalendarMonth(delta) {
    const cur = this.calendarDate || new Date();
    this.calendarDate = new Date(cur.getFullYear(), cur.getMonth() + delta, 1);
    this.renderCurrentView();
  }

  selectCalendarDay(day) {
    const cur = this.calendarDate || new Date();
    this.calendarDate = new Date(cur.getFullYear(), cur.getMonth(), day);
    this.renderCurrentView();
  }

  _matchesReminderDate(reminder, date) {
    if (!reminder || !reminder.due_date) return false;
    const rDate = new Date(reminder.due_date);
    const rDateStr = rDate.toISOString().split('T')[0];
    const targetDateStr = date.toISOString().split('T')[0];

    if (rDateStr === targetDateStr) return true;

    // Recurring support
    const freq = reminder.repeat_frequency;
    if (!freq || freq === 'none') return false;

    if (date < rDate) return false;

    if (freq === 'daily') return true;
    if (freq === 'weekly') return date.getDay() === rDate.getDay();
    if (freq === 'monthly') return date.getDate() === rDate.getDate();

    return false;
  }

  // ====================================================================
  // REMINDERS ACTIONS & MODALS
  // ====================================================================

  async handleToggleReminder(id) {
    try {
      const res = await window.api.reminders.toggleComplete(id);
      const updated = res.data;
      if (this.reminders) {
        const item = this.reminders.find(r => r.id === id);
        if (item) item.is_completed = updated.is_completed;
      }
      this.showToast(updated.is_completed ? 'Reminder completed!' : 'Reminder reopened', 'success');
      this.renderCurrentView();
    } catch (err) {
      this.showToast(err.message, 'error');
    }
  }

  async handleDeleteReminder(id) {
    if (!confirm('Are you sure you want to delete this reminder?')) return;
    try {
      await window.api.reminders.delete(id);
      if (this.reminders) {
        this.reminders = this.reminders.filter(r => r.id !== id);
      }
      this.showToast('Reminder deleted successfully', 'success');
      this.renderCurrentView();
    } catch (err) {
      this.showToast(err.message, 'error');
    }
  }

  showRemindersModal() {
    let modal = document.getElementById('remindersSheetModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'remindersSheetModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3100';
      document.body.appendChild(modal);
    }

    const items = this.reminders || [];

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 500px; max-height: 85vh; display: flex; flex-direction: column;">
        <div class="modal-header" style="padding: 16px 20px; border-bottom: 1px solid var(--border-subtle); display: flex; justify-content: space-between; align-items: center;">
          <div style="display: flex; align-items: center; gap: 10px;">
            <span style="font-size: 1.3rem;">☑️</span>
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">My Reminders</h3>
              <span style="font-size: 0.78rem; color: var(--text-muted);">Synced with Calendar & Notifications</span>
            </div>
          </div>
          <button class="icon-btn" onclick="document.getElementById('remindersSheetModal').style.display='none'" style="font-size: 1.2rem;">&times;</button>
        </div>
        <div style="padding: 16px 20px; overflow-y: auto; flex: 1;">
          ${items.length === 0 ? `
            <div style="text-align: center; padding: 24px 0; color: var(--text-muted);">
              No reminders yet! Tap below to add your first reminder.
            </div>
          ` : items.map(r => `
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
              <div style="display: flex; align-items: center; gap: 10px;">
                <input type="checkbox" ${r.is_completed ? 'checked' : ''} onchange="window.app.handleToggleReminder('${r.id}')" style="cursor: pointer; width: 18px; height: 18px;" />
                <div>
                  <div style="font-weight: 700; font-size: 0.92rem; text-decoration: ${r.is_completed ? 'line-through' : 'none'}; color: ${r.is_completed ? 'var(--text-muted)' : 'var(--text-primary)'};">${r.title}</div>
                  <div style="font-size: 0.76rem; color: var(--text-secondary);">📅 ${new Date(r.due_date).toLocaleDateString()} at ${r.due_time || '10:00 AM'}</div>
                </div>
              </div>
              <button class="icon-btn" onclick="window.app.handleDeleteReminder('${r.id}')" style="color: #ef4444;">🗑️</button>
            </div>
          `).join('')}
        </div>
        <div style="padding: 14px 20px; border-top: 1px solid var(--border-subtle); display: flex; gap: 10px;">
          <button class="btn btn-primary" onclick="document.getElementById('remindersSheetModal').style.display='none'; window.app.showAddReminderModal();" style="flex: 1;">+ Add New Reminder</button>
          <button class="btn btn-secondary" onclick="document.getElementById('remindersSheetModal').style.display='none'; window.app.navigateTo('schedule');">Open Calendar</button>
        </div>
      </div>
    `;
    modal.style.display = 'flex';
  }

  showAddReminderModal() {
    let modal = document.getElementById('addReminderModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'addReminderModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3200';
      document.body.appendChild(modal);
    }

    const todayStr = new Date().toISOString().split('T')[0];

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 480px;">
        <div class="modal-header" style="padding: 16px 20px; border-bottom: 1px solid var(--border-subtle); display: flex; justify-content: space-between; align-items: center;">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">Create Reminder</h3>
          <button class="icon-btn" onclick="document.getElementById('addReminderModal').style.display='none'" style="font-size: 1.2rem;">&times;</button>
        </div>
        <form onsubmit="window.app.handleSaveReminder(event)" style="padding: 18px 20px;">
          <div class="form-group">
            <label class="form-label">Reminder Title *</label>
            <input type="text" id="remTitle" class="form-control" placeholder="e.g. Product Review Meeting" required />
          </div>
          <div class="form-group">
            <label class="form-label">Description / Notes</label>
            <textarea id="remDesc" class="form-control" rows="2" placeholder="Optional details..."></textarea>
          </div>
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label">Date *</label>
              <input type="date" id="remDate" class="form-control" value="${todayStr}" required />
            </div>
            <div class="form-group">
              <label class="form-label">Time</label>
              <input type="time" id="remTime" class="form-control" value="10:30" />
            </div>
          </div>
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label">Repeat Frequency</label>
              <select id="remRepeat" class="form-control">
                <option value="none">None (One-time)</option>
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="monthly">Monthly</option>
              </select>
            </div>
            <div class="form-group">
              <label class="form-label">Notification</label>
              <select id="remNotify" class="form-control">
                <option value="at_time">At exact time</option>
                <option value="15_min_before">15 minutes before</option>
                <option value="1_hour_before">1 hour before</option>
                <option value="1_day_before">1 day before</option>
              </select>
            </div>
          </div>
          <div style="text-align: right; margin-top: 14px; display: flex; gap: 10px; justify-content: flex-end;">
            <button type="button" class="btn btn-secondary" onclick="document.getElementById('addReminderModal').style.display='none'">Cancel</button>
            <button type="submit" class="btn btn-primary">Save Reminder</button>
          </div>
        </form>
      </div>
    `;
    modal.style.display = 'flex';
  }

  async handleSaveReminder(e) {
    e.preventDefault();
    const title = document.getElementById('remTitle').value.trim();
    const description = document.getElementById('remDesc').value.trim();
    const dueDate = document.getElementById('remDate').value;
    const dueTime = document.getElementById('remTime').value;
    const repeatFrequency = document.getElementById('remRepeat').value;
    const notificationPreference = document.getElementById('remNotify').value;

    try {
      this.showLoading(true);
      const res = await window.api.reminders.create({
        title,
        description,
        dueDate,
        dueTime,
        repeatFrequency,
        notificationPreference
      });

      if (!this.reminders) this.reminders = [];
      this.reminders.unshift(res.data);
      document.getElementById('addReminderModal').style.display = 'none';
      this.showToast('Reminder saved & synced to Calendar!', 'success');
      this.renderCurrentView();
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
      this.showLoading(false);
    }
  }

  // ====================================================================
  // QUICK NOTES MODAL
  // ====================================================================

  showQuickNotesModal() {
    let modal = document.getElementById('quickNotesModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'quickNotesModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3100';
      document.body.appendChild(modal);
    }

    let notes = [];
    try {
      notes = JSON.parse(localStorage.getItem('connekt_home_quick_notes_v2') || '[]');
    } catch (_) {}

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 520px; background: #fffbeb; color: #713f12; border: 1px solid #fef08a;">
        <div class="modal-header" style="padding: 16px 20px; border-bottom: 1px solid #fde047; display: flex; justify-content: space-between; align-items: center;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 1.3rem;">📝</span>
            <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; font-style: italic; color: #713f12;">Quick Notes</h3>
          </div>
          <button class="icon-btn" onclick="document.getElementById('quickNotesModal').style.display='none'" style="color: #713f12; font-size: 1.2rem;">&times;</button>
        </div>
        <div style="padding: 18px 20px;">
          <textarea id="quickNoteInput" class="form-control" rows="3" placeholder="Write a note here..." style="background: #ffffff; color: #1e293b; border: 1px solid #fde047; margin-bottom: 10px;"></textarea>
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <span style="font-size: 0.76rem; color: #854d0e;">Saved locally on this device</span>
            <button class="btn btn-sm" onclick="window.app.saveQuickNote()" style="background: #713f12; color: #ffffff; font-weight: 700;">✓ Save Note</button>
          </div>

          <div style="margin-top: 18px;">
            <div style="font-size: 0.8rem; font-weight: 800; color: #854d0e; text-transform: uppercase; margin-bottom: 8px;">Saved Notes (${notes.length})</div>
            <div style="max-height: 220px; overflow-y: auto;">
              ${notes.length === 0 ? `
                <div style="font-size: 0.85rem; color: #a16207; text-align: center; padding: 12px 0;">No notes saved yet.</div>
              ` : notes.map((n, idx) => `
                <div style="background: #ffffff; border: 1px solid #fef08a; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: flex-start;">
                  <div style="flex: 1; font-size: 0.9rem; color: #1e293b; white-space: pre-wrap;">${n.text}</div>
                  <button class="icon-btn" onclick="window.app.deleteQuickNote(${idx})" style="color: #ef4444; font-size: 0.85rem; margin-left: 8px;">&times;</button>
                </div>
              `).join('')}
            </div>
          </div>
        </div>
      </div>
    `;
    modal.style.display = 'flex';
  }

  saveQuickNote() {
    const input = document.getElementById('quickNoteInput');
    const val = input.value.trim();
    if (!val) return;

    let notes = [];
    try {
      notes = JSON.parse(localStorage.getItem('connekt_home_quick_notes_v2') || '[]');
    } catch (_) {}

    notes.unshift({ text: val, createdAt: new Date().toISOString() });
    localStorage.setItem('connekt_home_quick_notes_v2', JSON.stringify(notes));
    input.value = '';
    this.showToast('Note saved!', 'success');
    this.showQuickNotesModal();
  }

  deleteQuickNote(idx) {
    let notes = [];
    try {
      notes = JSON.parse(localStorage.getItem('connekt_home_quick_notes_v2') || '[]');
    } catch (_) {}

    notes.splice(idx, 1);
    localStorage.setItem('connekt_home_quick_notes_v2', JSON.stringify(notes));
    this.showQuickNotesModal();
  }

  // ====================================================================
  // INVITE FRIENDS MODAL
  // ====================================================================

  showInviteFriendsModal() {
    let modal = document.getElementById('inviteFriendsModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'inviteFriendsModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3100';
      document.body.appendChild(modal);
    }

    const username = this.currentUser?.username || 'welcome';
    const inviteLink = `https://connekt.net.in/join?ref=${username}`;

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 440px; text-align: center; border-radius: var(--radius-lg); padding: 24px;">
        <div style="width: 56px; height: 56px; border-radius: 50%; background: #2563eb; color: white; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; margin: 0 auto 14px;">
          👥
        </div>
        <h3 style="font-size: 1.25rem; font-weight: 800; margin-bottom: 6px;">Invite Friends to CONNEKT</h3>
        <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 20px; line-height: 1.4;">
          Connect the unconnected. Share your personal invite link with friends and colleagues.
        </p>

        <div style="background: var(--bg-input); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 18px;">
          <span style="font-size: 0.88rem; font-weight: 600; color: var(--accent-cyan); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">${inviteLink}</span>
          <button class="icon-btn" onclick="window.app.copyToClipboard('${inviteLink}', 'Invite link copied!')" title="Copy Link" style="font-size: 1.1rem; color: var(--text-primary); margin-left: 8px;">
            📋
          </button>
        </div>

        <button class="btn btn-primary" onclick="window.app.shareInviteLink('${inviteLink}')" style="width: 100%; padding: 12px; font-weight: 700; border-radius: var(--radius-md); display: flex; align-items: center; justify-content: center; gap: 8px;">
          <span>🔗</span>
          <span>Share Link</span>
        </button>
      </div>
    `;
    modal.style.display = 'flex';
  }

  async shareInviteLink(link) {
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Join me on CONNEKT',
          text: 'Connect with me on CONNEKT – Connecting the Unconnected!',
          url: link
        });
        return;
      } catch (_) {}
    }
    this.copyToClipboard(link, 'Invite link copied to clipboard!');
  }

  // ====================================================================
  // PIN & SECURITY MODALS
  // ====================================================================

  togglePinSecurity(enable) {
    if (enable) {
      this.showPinSecurityModal();
    } else {
      localStorage.setItem('connekt_pin_enabled', 'false');
      this.showToast('Security PIN disabled', 'info');
      this.renderCurrentView();
    }
  }

  showPinSecurityModal() {
    let modal = document.getElementById('pinSecurityModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'pinSecurityModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3200';
      document.body.appendChild(modal);
    }

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 380px; text-align: center; border-radius: var(--radius-lg); padding: 24px;">
        <span style="font-size: 2rem;">🔒</span>
        <h3 style="font-size: 1.25rem; font-weight: 800; margin: 10px 0 4px;">4-Digit Security PIN</h3>
        <p style="font-size: 0.82rem; color: var(--text-secondary); margin-bottom: 20px;">
          Enter a 4-digit numeric PIN to protect your CONNEKT profile and account data.
        </p>

        <div style="display: flex; justify-content: center; gap: 10px; margin-bottom: 20px;">
          <input type="password" maxlength="1" class="pin-digit form-control" style="width: 44px; height: 50px; text-align: center; font-size: 1.4rem; font-weight: 800;" />
          <input type="password" maxlength="1" class="pin-digit form-control" style="width: 44px; height: 50px; text-align: center; font-size: 1.4rem; font-weight: 800;" />
          <input type="password" maxlength="1" class="pin-digit form-control" style="width: 44px; height: 50px; text-align: center; font-size: 1.4rem; font-weight: 800;" />
          <input type="password" maxlength="1" class="pin-digit form-control" style="width: 44px; height: 50px; text-align: center; font-size: 1.4rem; font-weight: 800;" />
        </div>

        <div style="display: flex; gap: 10px;">
          <button class="btn btn-secondary" onclick="document.getElementById('pinSecurityModal').style.display='none'" style="flex: 1;">Cancel</button>
          <button class="btn btn-primary" onclick="window.app.savePinSecurity()" style="flex: 1;">Save PIN</button>
        </div>
      </div>
    `;
    modal.style.display = 'flex';

    const digits = modal.querySelectorAll('.pin-digit');
    digits.forEach((d, i) => {
      d.addEventListener('input', (e) => {
        if (e.target.value && i < digits.length - 1) digits[i + 1].focus();
      });
      d.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !e.target.value && i > 0) digits[i - 1].focus();
      });
    });
    digits[0].focus();
  }

  savePinSecurity() {
    const digits = document.querySelectorAll('#pinSecurityModal .pin-digit');
    let pin = '';
    digits.forEach(d => pin += d.value);

    if (pin.length !== 4 || !/^\d{4}$/.test(pin)) {
      this.showToast('Please enter a valid 4-digit PIN', 'warning');
      return;
    }

    localStorage.setItem('connekt_pin_code', pin);
    localStorage.setItem('connekt_pin_enabled', 'true');
    document.getElementById('pinSecurityModal').style.display = 'none';
    this.showToast('4-Digit Security PIN is active!', 'success');
    this.renderCurrentView();
  }

  // ====================================================================
  // WORLD CLOCK MODAL
  // ====================================================================

  showWorldClockModal() {
    let modal = document.getElementById('worldClockModal');
    if (!modal) {
      modal = document.createElement('div');
      modal.id = 'worldClockModal';
      modal.className = 'modal-overlay';
      modal.style.zIndex = '3100';
      document.body.appendChild(modal);
    }

    const zones = [
      { city: 'Local Time', tz: undefined, flag: '📍' },
      { city: 'New Delhi (IST)', tz: 'Asia/Kolkata', flag: '🇮🇳' },
      { city: 'London (GMT)', tz: 'Europe/London', flag: '🇬🇧' },
      { city: 'New York (EST)', tz: 'America/New_York', flag: '🇺🇸' },
      { city: 'Tokyo (JST)', tz: 'Asia/Tokyo', flag: '🇯🇵' },
      { city: 'Dubai (GST)', tz: 'Asia/Dubai', flag: '🇦🇪' }
    ];

    modal.innerHTML = `
      <div class="modal-content" style="max-width: 440px; border-radius: var(--radius-lg); padding: 20px;">
        <div class="modal-header" style="padding-bottom: 14px; border-bottom: 1px solid var(--border-subtle); display: flex; justify-content: space-between; align-items: center;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 1.3rem;">🕒</span>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">World Clock</h3>
          </div>
          <button class="icon-btn" onclick="document.getElementById('worldClockModal').style.display='none'" style="font-size: 1.2rem;">&times;</button>
        </div>
        <div style="padding: 14px 0;">
          ${zones.map(z => {
            const now = new Date();
            const timeStr = z.tz 
              ? now.toLocaleTimeString('en-US', { timeZone: z.tz, hour: '2-digit', minute: '2-digit', second: '2-digit' })
              : now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
            return `
              <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
                <div style="display: flex; align-items: center; gap: 10px;">
                  <span style="font-size: 1.2rem;">${z.flag}</span>
                  <span style="font-weight: 700; font-size: 0.92rem;">${z.city}</span>
                </div>
                <span style="font-size: 1rem; font-weight: 800; color: var(--accent-cyan); font-family: monospace;">${timeStr}</span>
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;
    modal.style.display = 'flex';
  }

  copyToClipboard(text, msg = 'Copied to clipboard!') {
    navigator.clipboard.writeText(text).then(() => {
      this.showToast(msg, 'success');
    }).catch(() => {
      this.showToast('Unable to copy', 'warning');
    });
  }

  showNotifications() {
    this.showToast('You have no new unread notifications.', 'info');
  }

  toggleMobileMenu() {
    const sidebar = document.getElementById('appSidebar');
    const overlay = document.getElementById('mobileOverlay');
    sidebar?.classList.toggle('mobile-open');
    overlay?.classList.toggle('active');
  }

}
);
