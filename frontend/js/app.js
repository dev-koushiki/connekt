/**
 * CONNEKT Main Application Orchestrator
 * Pure Vanilla JavaScript ES6+ Architecture
 */

class AppController {
  constructor() {
    this.currentUser = null;
    this.activeModule = 'home';
    this.activeMode = 'common'; // 'common' | 'professional' | 'both'
  }

  async init() {
    this.setupGlobalListeners();
    window.authManager.init();

    // Check if user is logged in
    const token = window.api.getToken();
    if (token) {
      await this.loadUserProfile();
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
    });

    // Auth expired event
    window.addEventListener('auth:expired', () => {
      this.currentUser = null;
      this.showToast('Your session has expired. Please sign in again.', 'warning');
      this.showAuthModal(true);
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
    const avatarUrl = user.personalProfile?.avatar_url || '/assets/images/default-avatar.png';

    if (avatar) avatar.src = avatarUrl;
    if (topAvatar) topAvatar.src = avatarUrl;
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

  navigateTo(moduleName) {
    this.activeModule = moduleName;

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
      case 'profile':
        this.renderProfileView(mainContent);
        break;
      case 'settings':
        this.renderSettingsView(mainContent);
        break;
      case 'messages':
      case 'communities':
      case 'meetings':
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
            <button class="btn btn-primary" onclick="window.app.navigateTo('profile')">Edit Profile & Credentials</button>
            <button class="btn btn-secondary" onclick="window.app.navigateTo('settings')">Security & Device Sessions</button>
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
            <img src="${user.personalProfile?.avatar_url || '/assets/images/default-avatar.png'}" style="width: 64px; height: 64px; border-radius: 50%; object-fit: cover; border: 2px solid var(--accent-primary);" />
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
            <img id="profileAvatarPreview" src="${personal.avatar_url || '/assets/images/default-avatar.png'}" class="avatar-preview-lg" />
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

  async handleAvatarUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('avatar', file);

    try {
      this.showLoading(true);
      const res = await window.api.user.uploadAvatar(formData);
      this.currentUser.personalProfile.avatar_url = res.data.avatarUrl;
      this.showToast('Avatar updated successfully!', 'success');
      this.applyUserSession();
      const preview = document.getElementById('profileAvatarPreview');
      if (preview) preview.src = res.data.avatarUrl;
    } catch (err) {
      this.showToast(err.message, 'error');
    } finally {
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

  async handleLogout() {
    try {
      this.showLoading(true);
      await window.api.auth.logout();
    } catch (e) {
      // ignore
    } finally {
      window.api.removeToken();
      this.currentUser = null;
      this.showLoading(false);
      this.showToast('Logged out safely.', 'info');
      this.showAuthModal(true);
    }
  }

  renderPhaseModulePlaceholder(container, moduleName) {
    const modules = {
      messages: { title: 'Direct & Group Messaging', phase: 'Phase 2', desc: 'Real-time WebSocket chat, read receipts, voice notes, and group invitation approval.' },
      communities: { title: 'Communities & Live Streaming', phase: 'Phase 3', desc: 'Public & private communities, interactive live streams, comments, and member roles.' },
      mail: { title: 'Connekt Mail Client', phase: 'Phase 4', desc: 'Dedicated email interface with your unique ID ' + (this.currentUser?.email || 'user@connekt.me') + ', SMTP delivery, and attachments.' },
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
