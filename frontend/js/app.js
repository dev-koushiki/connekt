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
      case 'messages':
      case 'communities':
      case 'mail':
      case 'reminders':
      case 'network':
      case 'ai':
      case 'shield':
        this.renderPhaseModulePlaceholder(mainContent, this.activeModule);
        break;
      default:
        this.renderHomeView(mainContent);
    }
  }

  renderHomeView(container) {
    const user = this.currentUser;
    const isProf = this.activeMode === 'professional';
    const isBoth = this.activeMode === 'both';

    const greeting = isProf ? 'Welcome to your Executive Command Center' : 'Welcome back to your Social Hub';
    const subtext = isProf 
      ? 'Manage your professional network, skills, portfolio, career milestones, and enterprise collaboration.'
      : isBoth
      ? 'Universal Hybrid Mode Active: Seamlessly managing both your Personal connections and Professional career.'
      : 'Connect with friends, explore trending community stories, and engage in real-time communication.';

    container.innerHTML = `
      <div class="hero-banner">
        <div class="hero-content">
          <h1>Hello, ${user.personalProfile?.display_name || user.username}! 👋</h1>
          <p>${subtext}</p>
          <div style="display: flex; gap: 12px; margin-top: 16px;">
            <button class="btn btn-primary" onclick="window.app.navigateTo('meetings')">Open Meetings Module 📹</button>
            <button class="btn btn-secondary" onclick="window.app.navigateTo('profile')">Edit Profile & Credentials</button>
          </div>
        </div>
        <div style="text-align: right; min-width: 200px;">
          <div style="font-size: 0.8rem; color: var(--text-muted); margin-bottom: 4px;">CONNEKT MAIL ID</div>
          <div style="font-weight: 700; color: var(--accent-cyan); font-size: 1.05rem;">${user.email}</div>
          <div style="margin-top: 10px;">
            <span class="badge badge-success">● Status: Active & Secured</span>
          </div>
        </div>
      </div>

      <!-- 3 Primary Application Shortcut Cards (Meetings, Chats, Mails) -->
      <div style="margin-bottom: 28px;">
        <div style="font-size: 0.82rem; font-weight: 700; letter-spacing: 0.05em; color: var(--text-muted); margin-bottom: 14px; text-transform: uppercase;">
          Primary Ecosystem Applications
        </div>
        <div class="grid-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 18px;">
          <!-- Card 1: Meetings -->
          <div class="card card-glow" style="cursor: pointer; display: flex; flex-direction: column; justify-content: space-between; border-left: 3px solid #2563eb; transition: all 0.2s ease;" onclick="window.app.navigateTo('meetings')">
            <div>
              <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(37, 99, 235, 0.15); color: #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 1.4rem;">
                  📹
                </div>
                <span class="badge badge-primary">Phase 1 Active</span>
              </div>
              <h3 style="font-size: 1.15rem; margin-bottom: 6px; display: flex; align-items: center; gap: 8px;">
                <span>Meetings</span>
              </h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4;">
                Connect through video and audio meetings. Instant rooms, scheduled conferences & attendance.
              </p>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.85rem; color: #60a5fa; font-weight: 600;">
              <span>Open Meetings Module</span>
              <span>→</span>
            </div>
          </div>

          <!-- Card 2: Chats -->
          <div class="card card-glow" style="cursor: pointer; display: flex; flex-direction: column; justify-content: space-between; border-left: 3px solid #06b6d4; transition: all 0.2s ease;" onclick="window.app.navigateTo('messages')">
            <div>
              <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(6, 182, 212, 0.15); color: #06b6d4; display: flex; align-items: center; justify-content: center; font-size: 1.4rem;">
                  💬
                </div>
                <span class="badge badge-success">Direct & Group</span>
              </div>
              <h3 style="font-size: 1.15rem; margin-bottom: 6px;">Chats</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4;">
                Connect through individual and group conversations with real-time delivery and voice notes.
              </p>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.85rem; color: var(--accent-cyan); font-weight: 600;">
              <span>Open Chat Messenger</span>
              <span>→</span>
            </div>
          </div>

          <!-- Card 3: Mails -->
          <div class="card card-glow" style="cursor: pointer; display: flex; flex-direction: column; justify-content: space-between; border-left: 3px solid #8b5cf6; transition: all 0.2s ease;" onclick="window.app.navigateTo('mail')">
            <div>
              <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(139, 92, 246, 0.15); color: #a78bfa; display: flex; align-items: center; justify-content: center; font-size: 1.4rem;">
                  ✉️
                </div>
                <span class="badge badge-mode" style="background: rgba(139, 92, 246, 0.2); color: #c4b5fd;">@${user.username}</span>
              </div>
              <h3 style="font-size: 1.15rem; margin-bottom: 6px;">Mails</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4;">
                Send, receive and manage your emails with your unique CONNEKT identity.
              </p>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.85rem; color: #c084fc; font-weight: 600;">
              <span>Open Connekt Mail</span>
              <span>→</span>
            </div>
          </div>

          <!-- Card 4: Phone Call Logs -->
          <div class="card card-glow" style="cursor: pointer; display: flex; flex-direction: column; justify-content: space-between; border-left: 3px solid #10b981; transition: all 0.2s ease;" onclick="window.app.navigateTo('call_logs')">
            <div>
              <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <div style="width: 44px; height: 44px; border-radius: 12px; background: rgba(16, 185, 129, 0.15); color: #10b981; display: flex; align-items: center; justify-content: center; font-size: 1.4rem;">
                  📞
                </div>
                <span class="badge badge-success">Phone Sync</span>
              </div>
              <h3 style="font-size: 1.15rem; margin-bottom: 6px;">Call Logs</h3>
              <p style="color: var(--text-secondary); font-size: 0.88rem; line-height: 1.4;">
                View incoming, outgoing, and missed phone call history synced from your mobile device.
              </p>
            </div>
            <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.85rem; color: #34d399; font-weight: 600;">
              <span>Open Call Logs</span>
              <span>→</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Metrics & Mode Highlights -->
      <div class="grid-4" style="margin-bottom: 28px;">
        <div class="card card-glow">
          <div style="font-size: 0.8rem; color: var(--text-muted); font-weight: 600;">ACTIVE EXPERIENCE</div>
          <div style="font-size: 1.4rem; font-weight: 800; color: var(--text-primary); margin: 6px 0;">${this.activeMode.toUpperCase()} MODE</div>
          <div style="font-size: 0.8rem; color: var(--accent-cyan);">Instant toggle via topbar</div>
        </div>
        <div class="card card-glow">
          <div style="font-size: 0.8rem; color: var(--text-muted); font-weight: 600;">CONNEKT IDENTITY</div>
          <div style="font-size: 1.4rem; font-weight: 800; color: #60a5fa; margin: 6px 0;">@${user.username}</div>
          <div style="font-size: 0.8rem; color: var(--text-muted);">Phone: ${user.phone}</div>
        </div>
        <div class="card card-glow">
          <div style="font-size: 0.8rem; color: var(--text-muted); font-weight: 600;">VERIFIED SKILLS</div>
          <div style="font-size: 1.4rem; font-weight: 800; color: #34d399; margin: 6px 0;">${user.skills?.length || 0} Listed</div>
          <div style="font-size: 0.8rem; color: var(--accent-cyan); cursor: pointer;" onclick="window.app.navigateTo('profile')">+ Add more skills</div>
        </div>
        <div class="card card-glow">
          <div style="font-size: 0.8rem; color: var(--text-muted); font-weight: 600;">SHIELD DEFENSE</div>
          <div style="font-size: 1.4rem; font-weight: 800; color: #10b981; margin: 6px 0;">100% Protected</div>
          <div style="font-size: 0.8rem; color: var(--color-success);">Anti-phishing active</div>
        </div>
      </div>

      <!-- Main Overview Cards -->
      <div class="grid-2">
        <div class="card">
          <h3 style="margin-bottom: 16px; display: flex; align-items: center; justify-content: space-between;">
            <span>Personal Profile Snapshot</span>
            <button class="btn btn-secondary btn-sm" onclick="window.app.navigateTo('profile')">Manage</button>
          </h3>
          <div style="display: flex; gap: 16px; align-items: center; margin-bottom: 16px;">
            <img src="${user.personalProfile?.avatar_url || '/assets/images/default-avatar.png'}" onerror="this.onerror=null;this.src='/assets/images/default-avatar.png';" style="width: 64px; height: 64px; border-radius: 50%; object-fit: cover; border: 2px solid var(--accent-primary);" />
            <div>
              <div style="font-weight: 700; font-size: 1.1rem;">${user.personalProfile?.full_name || user.username}</div>
              <div style="color: var(--text-muted); font-size: 0.85rem;">${user.personalProfile?.bio || 'No personal bio added yet.'}</div>
              <div style="color: var(--accent-cyan); font-size: 0.8rem; margin-top: 4px;">📍 ${user.personalProfile?.location || 'Location not specified'}</div>
            </div>
          </div>
        </div>

        <div class="card">
          <h3 style="margin-bottom: 16px; display: flex; align-items: center; justify-content: space-between;">
            <span>Professional Profile Snapshot</span>
            <button class="btn btn-secondary btn-sm" onclick="window.app.navigateTo('profile')">Manage</button>
          </h3>
          <div style="margin-bottom: 12px;">
            <div style="font-weight: 700; color: var(--text-primary); font-size: 1rem;">${user.professionalProfile?.headline || 'No headline set'}</div>
            <div style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 4px;">🏢 Company: ${user.professionalProfile?.current_company || 'Not specified'} | Industry: ${user.professionalProfile?.industry || 'General'}</div>
          </div>
          <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-top: 12px;">
            ${(user.skills || []).slice(0, 5).map(s => `<span class="badge badge-primary">${s.skill_name} (${s.proficiency})</span>`).join('') || '<span style="color: var(--text-muted); font-size: 0.85rem;">No professional skills listed yet.</span>'}
          </div>
        </div>
      </div>
    `;
  }

  renderProfileView(container) {
    const user = this.currentUser;
    const personal = user.personalProfile || {};
    const prof = user.professionalProfile || {};

    container.innerHTML = `
      <div style="margin-bottom: 24px;">
        <h2>Profile & Identity Management</h2>
        <p style="color: var(--text-muted);">Manage your personal social identity, professional credentials, skills, and portfolio.</p>
      </div>

      <div class="tabs-container">
        <button class="tab-btn active" onclick="window.app.switchProfileTab('personal')">Personal Profile</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('professional')">Professional Credentials</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('skills')">Skills & Endorsements</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('experience')">Work Experience</button>
        <button class="tab-btn" onclick="window.app.switchProfileTab('education')">Education</button>
      </div>

      <!-- Tab 1: Personal Profile -->
      <div id="tab-personal" class="profile-tab-content">
        <div class="card">
          <div class="avatar-upload-wrapper">
            <img id="profileAvatarPreview" src="${personal.avatar_url || '/assets/images/default-avatar.png'}" onerror="this.onerror=null;this.src='/assets/images/default-avatar.png';" title="Click to change profile photo" onclick="document.getElementById('avatarFileInput')?.click()" class="avatar-preview-lg" />
            <div>
              <h4 style="margin-bottom: 4px;">Profile Photo</h4>
              <p style="font-size: 0.8rem; color: var(--text-muted); margin-bottom: 10px;">JPG, PNG, or WEBP up to 5MB.</p>
              <label class="btn btn-secondary btn-sm" style="cursor: pointer;">
                Change Photo
                <input type="file" id="avatarFileInput" accept="image/*" style="display: none;" />
              </label>
            </div>
          </div>

          <form id="personalProfileForm" onsubmit="window.app.handleSavePersonalProfile(event)">
            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Full Legal Name</label>
                <input type="text" class="form-control" id="pFullName" value="${personal.full_name || ''}" required />
              </div>
              <div class="form-group">
                <label class="form-label">Display Name / Nickname</label>
                <input type="text" class="form-control" id="pDisplayName" value="${personal.display_name || ''}" />
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Personal Bio</label>
              <textarea class="form-control" id="pBio" rows="3" placeholder="Tell people about yourself...">${personal.bio || ''}</textarea>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Location / City</label>
                <input type="text" class="form-control" id="pLocation" value="${personal.location || ''}" placeholder="e.g. San Francisco, CA" />
              </div>
              <div class="form-group">
                <label class="form-label">Personal Website</label>
                <input type="url" class="form-control" id="pWebsite" value="${personal.website || ''}" placeholder="https://yourwebsite.com" />
              </div>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Birthdate</label>
                <input type="date" class="form-control" id="pBirthdate" value="${personal.birthdate ? personal.birthdate.split('T')[0] : ''}" />
              </div>
              <div class="form-group">
                <label class="form-label">Gender</label>
                <select class="form-control" id="pGender">
                  <option value="" ${!personal.gender ? 'selected' : ''}>Prefer not to say</option>
                  <option value="Female" ${personal.gender === 'Female' ? 'selected' : ''}>Female</option>
                  <option value="Male" ${personal.gender === 'Male' ? 'selected' : ''}>Male</option>
                  <option value="Non-Binary" ${personal.gender === 'Non-Binary' ? 'selected' : ''}>Non-Binary</option>
                  <option value="Other" ${personal.gender === 'Other' ? 'selected' : ''}>Other</option>
                </select>
              </div>
            </div>

            <button type="submit" class="btn btn-primary" style="margin-top: 10px;">Save Personal Profile</button>
          </form>
        </div>
      </div>

      <!-- Tab 2: Professional Profile -->
      <div id="tab-professional" class="profile-tab-content" style="display: none;">
        <div class="card">
          <form id="professionalProfileForm" onsubmit="window.app.handleSaveProfessionalProfile(event)">
            <div class="form-group">
              <label class="form-label">Professional Headline</label>
              <input type="text" class="form-control" id="profHeadline" value="${prof.headline || ''}" placeholder="e.g. Senior Software Architect | AI & Distributed Systems" required />
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Current Company / Organization</label>
                <input type="text" class="form-control" id="profCompany" value="${prof.current_company || ''}" placeholder="e.g. DeepMind" />
              </div>
              <div class="form-group">
                <label class="form-label">Industry</label>
                <input type="text" class="form-control" id="profIndustry" value="${prof.industry || ''}" placeholder="e.g. Software & Technology" />
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Years of Experience</label>
              <input type="number" class="form-control" id="profExperienceYears" value="${prof.years_of_experience || 0}" min="0" max="60" />
            </div>

            <div class="form-group">
              <label class="form-label">Professional Summary</label>
              <textarea class="form-control" id="profSummary" rows="4" placeholder="Briefly describe your career background, expertise, and goals...">${prof.summary || ''}</textarea>
            </div>

            <div class="grid-3">
              <div class="form-group">
                <label class="form-label">Portfolio URL</label>
                <input type="url" class="form-control" id="profPortfolio" value="${prof.portfolio_url || ''}" placeholder="https://portfolio.dev" />
              </div>
              <div class="form-group">
                <label class="form-label">GitHub URL</label>
                <input type="url" class="form-control" id="profGithub" value="${prof.github_url || ''}" placeholder="https://github.com/..." />
              </div>
              <div class="form-group">
                <label class="form-label">LinkedIn URL</label>
                <input type="url" class="form-control" id="profLinkedin" value="${prof.linkedin_url || ''}" placeholder="https://linkedin.com/in/..." />
              </div>
            </div>

            <div style="display: flex; gap: 24px; margin: 16px 0;">
              <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
                <input type="checkbox" id="profOpenToWork" ${prof.is_open_to_work ? 'checked' : ''} />
                <span>Open to Work / Opportunities</span>
              </label>
              <label style="display: flex; align-items: center; gap: 8px; cursor: pointer;">
                <input type="checkbox" id="profHiring" ${prof.is_hiring ? 'checked' : ''} />
                <span>Currently Hiring for My Team</span>
              </label>
            </div>

            <button type="submit" class="btn btn-primary">Save Professional Profile</button>
          </form>
        </div>
      </div>

      <!-- Tab 3: Skills -->
      <div id="tab-skills" class="profile-tab-content" style="display: none;">
        <div class="card" style="margin-bottom: 24px;">
          <h4 style="margin-bottom: 12px;">Add Verified Skill</h4>
          <form onsubmit="window.app.handleAddSkill(event)" style="display: flex; gap: 12px; align-items: flex-end; flex-wrap: wrap;">
            <div class="form-group" style="margin-bottom: 0; flex: 2; min-width: 200px;">
              <label class="form-label">Skill Name</label>
              <input type="text" id="newSkillName" class="form-control" placeholder="e.g. Node.js, PostgreSQL, System Design" required />
            </div>
            <div class="form-group" style="margin-bottom: 0; flex: 1; min-width: 150px;">
              <label class="form-label">Proficiency</label>
              <select id="newSkillProficiency" class="form-control">
                <option value="Beginner">Beginner</option>
                <option value="Intermediate" selected>Intermediate</option>
                <option value="Advanced">Advanced</option>
                <option value="Expert">Expert</option>
              </select>
            </div>
            <button type="submit" class="btn btn-primary" style="height: 42px;">+ Add Skill</button>
          </form>
        </div>

        <div class="card">
          <h4 style="margin-bottom: 16px;">Current Skills (${user.skills?.length || 0})</h4>
          <div style="display: flex; gap: 10px; flex-wrap: wrap;">
            ${(user.skills || []).map(skill => `
              <div class="badge badge-primary" style="padding: 8px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 8px;">
                <span>${skill.skill_name}</span>
                <span style="opacity: 0.7; font-size: 0.75rem;">• ${skill.proficiency}</span>
                <button onclick="window.app.handleDeleteSkill('${skill.id}')" style="background: none; border: none; color: #ef4444; cursor: pointer; font-size: 1rem; margin-left: 4px;">×</button>
              </div>
            `).join('') || '<p style="color: var(--text-muted);">No skills added yet.</p>'}
          </div>
        </div>
      </div>

      <!-- Tab 4: Work Experience -->
      <div id="tab-experience" class="profile-tab-content" style="display: none;">
        <div class="card" style="margin-bottom: 24px;">
          <h4 style="margin-bottom: 12px;">Add Work Experience</h4>
          <form onsubmit="window.app.handleAddExperience(event)">
            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Company Name</label>
                <input type="text" id="expCompany" class="form-control" placeholder="e.g. Acme Corp" required />
              </div>
              <div class="form-group">
                <label class="form-label">Job Title</label>
                <input type="text" id="expTitle" class="form-control" placeholder="e.g. Lead Engineer" required />
              </div>
            </div>
            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Start Date</label>
                <input type="date" id="expStartDate" class="form-control" />
              </div>
              <div class="form-group">
                <label class="form-label">End Date</label>
                <input type="date" id="expEndDate" class="form-control" />
              </div>
            </div>
            <div class="form-group">
              <label class="form-label">Description & Achievements</label>
              <textarea id="expDescription" class="form-control" rows="2" placeholder="Key responsibilities and achievements..."></textarea>
            </div>
            <button type="submit" class="btn btn-primary">+ Add Experience</button>
          </form>
        </div>

        <div class="card">
          <h4 style="margin-bottom: 16px;">Experience History</h4>
          <div style="display: flex; flex-direction: column; gap: 14px;">
            ${(user.experience || []).map(exp => `
              <div style="border-bottom: 1px solid var(--border-subtle); padding-bottom: 14px; display: flex; justify-content: space-between;">
                <div>
                  <h4 style="color: var(--text-primary);">${exp.title}</h4>
                  <div style="color: var(--accent-cyan); font-size: 0.9rem;">${exp.company_name}</div>
                  <div style="color: var(--text-muted); font-size: 0.8rem; margin: 4px 0;">
                    ${exp.start_date ? exp.start_date.split('T')[0] : 'N/A'} - ${exp.is_current ? 'Present' : (exp.end_date ? exp.end_date.split('T')[0] : 'N/A')}
                  </div>
                  <p style="font-size: 0.85rem; color: var(--text-secondary);">${exp.description || ''}</p>
                </div>
                <button onclick="window.app.handleDeleteExperience('${exp.id}')" class="btn btn-secondary btn-sm" style="color: var(--color-danger); height: fit-content;">Delete</button>
              </div>
            `).join('') || '<p style="color: var(--text-muted);">No experience records added.</p>'}
          </div>
        </div>
      </div>

      <!-- Tab 5: Education -->
      <div id="tab-education" class="profile-tab-content" style="display: none;">
        <div class="card" style="margin-bottom: 24px;">
          <h4 style="margin-bottom: 12px;">Add Education</h4>
          <form onsubmit="window.app.handleAddEducation(event)">
            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Institution / University</label>
                <input type="text" id="eduInstitution" class="form-control" placeholder="e.g. Stanford University" required />
              </div>
              <div class="form-group">
                <label class="form-label">Degree</label>
                <input type="text" id="eduDegree" class="form-control" placeholder="e.g. Bachelor of Science" required />
              </div>
            </div>
            <div class="grid-3">
              <div class="form-group">
                <label class="form-label">Field of Study</label>
                <input type="text" id="eduField" class="form-control" placeholder="e.g. Computer Science" />
              </div>
              <div class="form-group">
                <label class="form-label">Start Year</label>
                <input type="number" id="eduStartYear" class="form-control" placeholder="2020" />
              </div>
              <div class="form-group">
                <label class="form-label">End Year</label>
                <input type="number" id="eduEndYear" class="form-control" placeholder="2024" />
              </div>
            </div>
            <button type="submit" class="btn btn-primary">+ Add Education</button>
          </form>
        </div>

        <div class="card">
          <h4 style="margin-bottom: 16px;">Education Credentials</h4>
          <div style="display: flex; flex-direction: column; gap: 14px;">
            ${(user.education || []).map(edu => `
              <div style="border-bottom: 1px solid var(--border-subtle); padding-bottom: 14px; display: flex; justify-content: space-between;">
                <div>
                  <h4 style="color: var(--text-primary);">${edu.degree} in ${edu.field_of_study || 'General'}</h4>
                  <div style="color: var(--accent-cyan); font-size: 0.9rem;">${edu.institution}</div>
                  <div style="color: var(--text-muted); font-size: 0.8rem; margin-top: 4px;">
                    ${edu.start_year || 'N/A'} - ${edu.end_year || 'Present'}
                  </div>
                </div>
                <button onclick="window.app.handleDeleteEducation('${edu.id}')" class="btn btn-secondary btn-sm" style="color: var(--color-danger); height: fit-content;">Delete</button>
              </div>
            `).join('') || '<p style="color: var(--text-muted);">No education records added.</p>'}
          </div>
        </div>
      </div>
    `;

    // Rebind avatar file input
    const avatarInput = document.getElementById('avatarFileInput');
    if (avatarInput) {
      avatarInput.addEventListener('change', (e) => this.handleAvatarUpload(e));
    }
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
});
