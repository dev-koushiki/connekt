const fs = require('fs');
const path = require('path');

const appJsPath = path.join(__dirname, '..', '..', 'frontend', 'js', 'app.js');
let appJs = fs.readFileSync(appJsPath, 'utf8');

// 1. Update constructor to initialize reminders & calendar state
const constructorTarget = `    this.activeMode = 'common'; // 'common' | 'professional' | 'both'
    this.globalSocket = null;
    this._isLoggingOut = false;`;

const constructorReplacement = `    this.activeMode = 'common'; // 'common' | 'professional' | 'both'
    this.globalSocket = null;
    this._isLoggingOut = false;
    this.reminders = [];
    this.calendarDate = new Date();
    this.pinSecurityActive = localStorage.getItem('connekt_pin_enabled') === 'true';`;

if (appJs.includes(constructorTarget)) {
  appJs = appJs.replace(constructorTarget, constructorReplacement);
  console.log('✓ Updated AppController constructor');
}

// 2. Update renderCurrentView to handle 'schedule' and 'reminders'
const renderCurrentViewTarget = `      case 'settings':
        this.renderSettingsView(mainContent);
        break;
      case 'messages':
      case 'communities':
      case 'mail':
      case 'reminders':`;

const renderCurrentViewReplacement = `      case 'settings':
        this.renderSettingsView(mainContent);
        break;
      case 'schedule':
      case 'reminders':
        this.renderScheduleView(mainContent);
        break;
      case 'messages':
      case 'communities':
      case 'mail':`;

if (appJs.includes(renderCurrentViewTarget)) {
  appJs = appJs.replace(renderCurrentViewTarget, renderCurrentViewReplacement);
  console.log('✓ Updated renderCurrentView routing for schedule & reminders');
}

// 3. New renderHomeView implementation
const newRenderHomeView = `  async renderHomeView(container) {
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

      calCellsHtml += \`<div class="\${classes}">\${d}\${dot}</div>\`;
    }

    const isProf = this.activeMode === 'professional';

    container.innerHTML = \`
      <!-- Cyber Top Header Banner with CONNEKT Logo & Tagline -->
      <div class="app-cyber-header">
        <div class="brand-title-box">
          <h1>CONNEKT</h1>
          <p>CONNECTING THE UNCONNECTED</p>
        </div>
        <button class="btn btn-secondary btn-sm" onclick="window.i18n.showLanguageSelector()" style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.2); border-radius: 8px; color: #ffffff; display: flex; align-items: center; gap: 6px; padding: 6px 12px; cursor: pointer; font-weight: 700;">
          <span style="font-size: 1.1rem;">A/文</span>
          <span style="font-size: 0.82rem;">\${window.i18n ? window.i18n.getCurrentLanguage().name : 'English'}</span>
        </button>
      </div>

      <!-- Top Dashboard Grid (Schedule, World Clock, Reminder, Quick Notes) -->
      <div class="home-top-grid">
        <!-- Schedule Mini Calendar Card -->
        <div class="schedule-mini-card" onclick="window.app.navigateTo('schedule')" title="Click to open Full Schedule & Calendar">
          <div class="mini-cal-header">
            <span class="mini-cal-title">Schedule</span>
            <span class="mini-cal-month">\${monthStr}</span>
          </div>
          <div class="mini-cal-days-row">
            <span>S</span><span>M</span><span>T</span><span>W</span><span>T</span><span>F</span><span>S</span>
          </div>
          <div class="mini-cal-grid">
            \${calCellsHtml}
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
              \${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          </div>

          <!-- Reminder Widget with Live Counter Badge -->
          <div class="widget-pill-card" onclick="window.app.showRemindersModal()">
            <div class="widget-pill-left">
              <div class="widget-pill-icon">☑️</div>
              <span class="widget-pill-title">Reminder</span>
            </div>
            <span class="widget-counter-badge">\${pendingRemindersCount}</span>
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
          <div class="id-email-text">\${email}</div>
          <div class="pro-toggle-row">
            <label class="switch" style="position: relative; display: inline-block; width: 44px; height: 24px; margin-right: 6px;">
              <input type="checkbox" \${isProf ? 'checked' : ''} onchange="window.app.switchMode(this.checked ? 'professional' : 'common')" style="opacity: 0; width: 0; height: 0;" />
              <span class="slider round" style="position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: \${isProf ? '#2563eb' : '#475569'}; transition: .3s; border-radius: 24px;"></span>
            </label>
            <span>Switch to \${isProf ? 'Personal' : 'Professional'}</span>
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
    \`;
  }`;

// Find start and end of existing renderHomeView
const startHomeIdx = appJs.indexOf('  renderHomeView(container) {');
if (startHomeIdx !== -1) {
  const endHomeTarget = '  renderProfileView(container) {';
  const endHomeIdx = appJs.indexOf(endHomeTarget, startHomeIdx);
  if (endHomeIdx !== -1) {
    appJs = appJs.substring(0, startHomeIdx) + newRenderHomeView + '\n\n' + appJs.substring(endHomeIdx);
    console.log('✓ Replaced renderHomeView with modern mobile app matching layout');
  }
}

// 4. Update renderProfileView to match mobile app "My Profile & Security"
const newRenderProfileView = `  renderProfileView(container) {
    const user = this.currentUser;
    const personal = user.personalProfile || {};
    const prof = user.professionalProfile || {};
    const email = user.email ? (user.email.includes('@connekt.net.in') ? user.email : user.username + '@connekt.net.in') : (user.username + '@connekt.net.in');
    const displayName = personal.full_name || personal.display_name || user.username;
    const avatarUrl = personal.avatar_url || '/assets/images/default-avatar.png';
    const isPinActive = localStorage.getItem('connekt_pin_enabled') === 'true';

    container.innerHTML = \`
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
          <img src="\${avatarUrl}" onerror="this.src='/assets/images/default-avatar.png'" style="width: 90px; height: 90px; border-radius: 50%; object-fit: cover; border: 3px solid #2563eb;" />
          <button onclick="document.getElementById('avatarFileInput')?.click()" style="position: absolute; bottom: 0; right: 0; background: #2563eb; color: white; border: none; border-radius: 50%; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; font-size: 0.85rem; cursor: pointer; box-shadow: 0 2px 6px rgba(0,0,0,0.3);">
            📷
          </button>
          <input type="file" id="avatarFileInput" accept="image/*" style="display: none;" onchange="window.app.handleAvatarUpload(event)" />
        </div>

        <h3 style="font-size: 1.35rem; font-weight: 800; margin-bottom: 4px; display: flex; align-items: center; justify-content: center; gap: 6px;">
          <span>\${displayName}</span>
          <span style="color: #3b82f6; font-size: 1.1rem;" title="Verified User">✓</span>
        </h3>
        <div style="color: var(--accent-cyan); font-weight: 600; font-size: 0.9rem; margin-bottom: 8px;">@\${user.username}</div>

        <!-- Standardized Email Pill with Copy Button -->
        <div class="profile-pill-email">
          <span>@</span>
          <span>\${email}</span>
          <button class="icon-btn" onclick="window.app.copyToClipboard('\${email}', 'Email copied to clipboard!')" style="padding: 2px 4px; font-size: 0.9rem; color: var(--text-secondary);" title="Copy email">
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
          <button class="btn btn-sm \${this.activeMode === 'common' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('common')" style="border-radius: var(--radius-full); padding: 6px 16px;">
            Personal
          </button>
          <button class="btn btn-sm \${this.activeMode === 'professional' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('professional')" style="border-radius: var(--radius-full); padding: 6px 16px;">
            Professional
          </button>
          <button class="btn btn-sm \${this.activeMode === 'both' ? 'btn-primary' : 'btn-secondary'}" onclick="window.app.switchMode('both')" style="border-radius: var(--radius-full); padding: 6px 16px;">
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
            <div style="font-weight: 800; font-size: 1.05rem;">App Protection: \${isPinActive ? 'Active' : 'Standby'}</div>
            <div style="font-size: 0.82rem; opacity: 0.9;">\${isPinActive ? 'Secured with 4-Digit PIN & Biometrics' : 'Set up a 4-Digit Security PIN to protect your account'}</div>
          </div>
        </div>

        <!-- App Lock & PIN Security Card -->
        <div class="security-card-box">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.3rem;">🔢</span>
              <div>
                <div style="font-weight: 700; font-size: 0.95rem;">4-Digit Security PIN</div>
                <div style="font-size: 0.78rem; color: \${isPinActive ? '#22c55e' : 'var(--text-muted)'};">\${isPinActive ? 'PIN is set and active' : 'Not activated'}</div>
              </div>
            </div>
            <label class="switch" style="position: relative; display: inline-block; width: 44px; height: 24px;">
              <input type="checkbox" \${isPinActive ? 'checked' : ''} onchange="window.app.togglePinSecurity(this.checked)" style="opacity: 0; width: 0; height: 0;" />
              <span class="slider round" style="position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: \${isPinActive ? '#2563eb' : '#475569'}; transition: .3s; border-radius: 24px;"></span>
            </label>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 12px; border-top: 1px solid var(--border-subtle); font-size: 0.88rem;">
            <span style="color: var(--text-secondary);">Saved PIN: \${isPinActive ? '••••' : 'None'}</span>
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
                <input type="text" class="form-control" id="pFullName" value="\${personal.full_name || ''}" required />
              </div>
              <div class="form-group">
                <label class="form-label">Display Name</label>
                <input type="text" class="form-control" id="pDisplayName" value="\${personal.display_name || ''}" />
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Personal Bio</label>
              <textarea class="form-control" id="pBio" rows="3" placeholder="No personal bio added yet.">\${personal.bio || ''}</textarea>
            </div>

            <div class="grid-2">
              <div class="form-group">
                <label class="form-label">Location / City</label>
                <input type="text" class="form-control" id="pLocation" value="\${personal.location || ''}" placeholder="Location not set" />
              </div>
              <div class="form-group">
                <label class="form-label">Personal Website</label>
                <input type="url" class="form-control" id="pWebsite" value="\${personal.website_url || ''}" placeholder="No website" />
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
            <input type="text" class="form-control" id="profHeadline" value="\${prof.headline || ''}" placeholder="e.g. Senior Software Architect" />
          </div>
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label">Current Organization / Company</label>
              <input type="text" class="form-control" id="profCompany" value="\${prof.current_company || ''}" placeholder="e.g. Google / DeepMind" />
            </div>
            <div class="form-group">
              <label class="form-label">Industry</label>
              <input type="text" class="form-control" id="profIndustry" value="\${prof.industry || ''}" placeholder="e.g. Software & AI" />
            </div>
          </div>
          <div style="margin-top: 16px;">
            <label class="form-label">Listed Skills</label>
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              \${(user.skills || []).map(s => \`<span class="badge badge-primary">\${s.skill_name} (\${s.proficiency})</span>\`).join('') || '<span style="color: var(--text-muted); font-size: 0.85rem;">No skills listed yet.</span>'}
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
    \`;
  }`;

const startProfileIdx = appJs.indexOf('  renderProfileView(container) {');
if (startProfileIdx !== -1) {
  const endProfileTarget = '  switchProfileTab(tabName) {';
  const endProfileIdx = appJs.indexOf(endProfileTarget, startProfileIdx);
  if (endProfileIdx !== -1) {
    appJs = appJs.substring(0, startProfileIdx) + newRenderProfileView + '\n\n' + appJs.substring(endProfileIdx);
    console.log('✓ Replaced renderProfileView with mobile app matching layout');
  }
}

// 5. Append all new controller methods before the closing brace of AppController
const newMethods = `
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

        calCellsHtml += \`<div class="\${classes}" style="cursor: pointer;" onclick="window.app.selectCalendarDay(\${d})">\${d}\${dots}</div>\`;
      }

      // Filter day items
      const dayReminders = this.reminders.filter(r => this._matchesReminderDate(r, selDate));
      const dayMeetings = meetings.filter(m => {
        if (!m.scheduled_start_time) return false;
        const md = new Date(m.scheduled_start_time);
        return md.getFullYear() === selDate.getFullYear() && md.getMonth() === selDate.getMonth() && md.getDate() === selDate.getDate();
      });

      const dayTitle = selDate.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

      container.innerHTML = \`
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
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">\${monthStr}</h3>
              <button class="icon-btn" onclick="window.app.changeCalendarMonth(1)" style="font-size: 1.2rem;">›</button>
            </div>
            <div class="mini-cal-days-row" style="margin-bottom: 10px;">
              <span>Sun</span><span>Mon</span><span>Tue</span><span>Wed</span><span>Thu</span><span>Fri</span><span>Sat</span>
            </div>
            <div class="mini-cal-grid" style="gap: 8px;">
              \${calCellsHtml}
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
                <h4 style="margin: 2px 0 0; font-size: 1.05rem; font-weight: 800;">\${dayTitle}</h4>
              </div>
              <button class="btn btn-secondary btn-sm" onclick="window.app.showAddReminderModal()">+ Reminder</button>
            </div>

            <!-- Reminders List -->
            <div style="flex: 1; overflow-y: auto;">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--text-secondary); margin-bottom: 8px; text-transform: uppercase;">Reminders (\${dayReminders.length})</div>
              \${dayReminders.length === 0 ? \`
                <div style="padding: 16px; text-align: center; color: var(--text-muted); font-size: 0.88rem; background: rgba(255,255,255,0.02); border-radius: 8px;">
                  No reminders for this date.
                </div>
              \` : dayReminders.map(r => \`
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: var(--bg-card-hover); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
                  <div style="display: flex; align-items: center; gap: 10px;">
                    <input type="checkbox" \${r.is_completed ? 'checked' : ''} onchange="window.app.handleToggleReminder('\${r.id}')" style="cursor: pointer; width: 18px; height: 18px;" />
                    <div>
                      <div style="font-weight: 700; font-size: 0.92rem; text-decoration: \${r.is_completed ? 'line-through' : 'none'}; color: \${r.is_completed ? 'var(--text-muted)' : 'var(--text-primary)'};">\${r.title}</div>
                      <div style="font-size: 0.76rem; color: var(--text-secondary);">\${r.due_time || '10:00 AM'} \${r.repeat_frequency && r.repeat_frequency !== 'none' ? '• 🔁 ' + r.repeat_frequency : ''}</div>
                    </div>
                  </div>
                  <div style="display: flex; gap: 6px;">
                    <button class="icon-btn" onclick="window.app.handleDeleteReminder('\${r.id}')" title="Delete" style="color: #ef4444; font-size: 0.9rem;">🗑️</button>
                  </div>
                </div>
              \`).join('')}

              <div style="font-size: 0.8rem; font-weight: 700; color: var(--text-secondary); margin: 16px 0 8px; text-transform: uppercase;">Meetings (\${dayMeetings.length})</div>
              \${dayMeetings.length === 0 ? \`
                <div style="padding: 16px; text-align: center; color: var(--text-muted); font-size: 0.88rem; background: rgba(255,255,255,0.02); border-radius: 8px;">
                  No scheduled meetings for this date.
                </div>
              \` : dayMeetings.map(m => \`
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: rgba(37,99,235,0.08); border: 1px solid rgba(37,99,235,0.25); border-radius: 8px; margin-bottom: 8px;">
                  <div>
                    <div style="font-weight: 700; font-size: 0.92rem; color: #60a5fa;">\${m.title}</div>
                    <div style="font-size: 0.76rem; color: var(--text-secondary);">\${new Date(m.scheduled_start_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                  </div>
                  <button class="btn btn-primary btn-sm" onclick="window.app.handleJoinMeetingFromCard('\${m.meeting_code}')">Join</button>
                </div>
              \`).join('')}
            </div>
          </div>
        </div>
      \`;
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

    modal.innerHTML = \`
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
          \${items.length === 0 ? \`
            <div style="text-align: center; padding: 24px 0; color: var(--text-muted);">
              No reminders yet! Tap below to add your first reminder.
            </div>
          \` : items.map(r => \`
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
              <div style="display: flex; align-items: center; gap: 10px;">
                <input type="checkbox" \${r.is_completed ? 'checked' : ''} onchange="window.app.handleToggleReminder('\${r.id}')" style="cursor: pointer; width: 18px; height: 18px;" />
                <div>
                  <div style="font-weight: 700; font-size: 0.92rem; text-decoration: \${r.is_completed ? 'line-through' : 'none'}; color: \${r.is_completed ? 'var(--text-muted)' : 'var(--text-primary)'};">\${r.title}</div>
                  <div style="font-size: 0.76rem; color: var(--text-secondary);">📅 \${new Date(r.due_date).toLocaleDateString()} at \${r.due_time || '10:00 AM'}</div>
                </div>
              </div>
              <button class="icon-btn" onclick="window.app.handleDeleteReminder('\${r.id}')" style="color: #ef4444;">🗑️</button>
            </div>
          \`).join('')}
        </div>
        <div style="padding: 14px 20px; border-top: 1px solid var(--border-subtle); display: flex; gap: 10px;">
          <button class="btn btn-primary" onclick="document.getElementById('remindersSheetModal').style.display='none'; window.app.showAddReminderModal();" style="flex: 1;">+ Add New Reminder</button>
          <button class="btn btn-secondary" onclick="document.getElementById('remindersSheetModal').style.display='none'; window.app.navigateTo('schedule');">Open Calendar</button>
        </div>
      </div>
    \`;
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

    modal.innerHTML = \`
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
              <input type="date" id="remDate" class="form-control" value="\${todayStr}" required />
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
    \`;
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

    modal.innerHTML = \`
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
            <div style="font-size: 0.8rem; font-weight: 800; color: #854d0e; text-transform: uppercase; margin-bottom: 8px;">Saved Notes (\${notes.length})</div>
            <div style="max-height: 220px; overflow-y: auto;">
              \${notes.length === 0 ? \`
                <div style="font-size: 0.85rem; color: #a16207; text-align: center; padding: 12px 0;">No notes saved yet.</div>
              \` : notes.map((n, idx) => \`
                <div style="background: #ffffff; border: 1px solid #fef08a; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: flex-start;">
                  <div style="flex: 1; font-size: 0.9rem; color: #1e293b; white-space: pre-wrap;">\${n.text}</div>
                  <button class="icon-btn" onclick="window.app.deleteQuickNote(\${idx})" style="color: #ef4444; font-size: 0.85rem; margin-left: 8px;">&times;</button>
                </div>
              \`).join('')}
            </div>
          </div>
        </div>
      </div>
    \`;
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
    const inviteLink = \`https://connekt.net.in/join?ref=\${username}\`;

    modal.innerHTML = \`
      <div class="modal-content" style="max-width: 440px; text-align: center; border-radius: var(--radius-lg); padding: 24px;">
        <div style="width: 56px; height: 56px; border-radius: 50%; background: #2563eb; color: white; display: flex; align-items: center; justify-content: center; font-size: 1.6rem; margin: 0 auto 14px;">
          👥
        </div>
        <h3 style="font-size: 1.25rem; font-weight: 800; margin-bottom: 6px;">Invite Friends to CONNEKT</h3>
        <p style="font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 20px; line-height: 1.4;">
          Connect the unconnected. Share your personal invite link with friends and colleagues.
        </p>

        <div style="background: var(--bg-input); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between; margin-bottom: 18px;">
          <span style="font-size: 0.88rem; font-weight: 600; color: var(--accent-cyan); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">\${inviteLink}</span>
          <button class="icon-btn" onclick="window.app.copyToClipboard('\${inviteLink}', 'Invite link copied!')" title="Copy Link" style="font-size: 1.1rem; color: var(--text-primary); margin-left: 8px;">
            📋
          </button>
        </div>

        <button class="btn btn-primary" onclick="window.app.shareInviteLink('\${inviteLink}')" style="width: 100%; padding: 12px; font-weight: 700; border-radius: var(--radius-md); display: flex; align-items: center; justify-content: center; gap: 8px;">
          <span>🔗</span>
          <span>Share Link</span>
        </button>
      </div>
    \`;
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

    modal.innerHTML = \`
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
    \`;
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

    if (pin.length !== 4 || !/^\\d{4}$/.test(pin)) {
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

    modal.innerHTML = \`
      <div class="modal-content" style="max-width: 440px; border-radius: var(--radius-lg); padding: 20px;">
        <div class="modal-header" style="padding-bottom: 14px; border-bottom: 1px solid var(--border-subtle); display: flex; justify-content: space-between; align-items: center;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 1.3rem;">🕒</span>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800;">World Clock</h3>
          </div>
          <button class="icon-btn" onclick="document.getElementById('worldClockModal').style.display='none'" style="font-size: 1.2rem;">&times;</button>
        </div>
        <div style="padding: 14px 0;">
          \${zones.map(z => {
            const now = new Date();
            const timeStr = z.tz 
              ? now.toLocaleTimeString('en-US', { timeZone: z.tz, hour: '2-digit', minute: '2-digit', second: '2-digit' })
              : now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
            return \`
              <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 12px; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: 8px; margin-bottom: 8px;">
                <div style="display: flex; align-items: center; gap: 10px;">
                  <span style="font-size: 1.2rem;">\${z.flag}</span>
                  <span style="font-weight: 700; font-size: 0.92rem;">\${z.city}</span>
                </div>
                <span style="font-size: 1rem; font-weight: 800; color: var(--accent-cyan); font-family: monospace;">\${timeStr}</span>
              </div>
            \`;
          }).join('')}
        </div>
      </div>
    \`;
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
`;

// Insert newMethods right before the closing brace of AppController
const closingBraceIdx = appJs.lastIndexOf('}');
if (closingBraceIdx !== -1) {
  appJs = appJs.substring(0, closingBraceIdx) + newMethods + '\n}\n' + appJs.substring(closingBraceIdx + 1);
  console.log('✓ Injected Schedule, Calendar, Reminders, Notes, and PIN security methods into AppController');
}

fs.writeFileSync(appJsPath, appJs, 'utf8');
console.log('Successfully updated frontend/js/app.js!');
