/**
 * CONNEKT Authentication & Identity Controller (Vanilla JS)
 */
class AuthManager {
  constructor() {
    this.currentOtpPhone = '';
    this.otpTimer = null;
    this.countdownSeconds = 300;
  }

  init() {
    this.bindEvents();
    this.setupOtpInputs();
  }

  bindEvents() {
    // Mode choice pills in registration
    document.querySelectorAll('.reg-mode-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.reg-mode-btn').forEach(b => b.classList.remove('active'));
        e.currentTarget.classList.add('active');
        document.getElementById('regSelectedMode').value = e.currentTarget.dataset.mode;
      });
    });

    // Username real-time check & Connekt Mail preview
    const usernameInput = document.getElementById('regUsername');
    if (usernameInput) {
      usernameInput.addEventListener('input', (e) => {
        const val = e.target.value.trim().toLowerCase().replace(/[^a-z0-9._]/g, '');
        e.target.value = val;
        const mailPreview = document.getElementById('connektMailPreview');
        if (mailPreview) {
          mailPreview.textContent = val ? `${val}@connekt.me` : 'yourname@connekt.me';
        }
        this.checkUsernameDebounced(val);
      });
    }

    // Phone real-time availability check
    const phoneInput = document.getElementById('regPhone');
    if (phoneInput) {
      phoneInput.addEventListener('blur', (e) => {
        this.checkPhone(e.target.value.trim());
      });
    }

    // Auth Switcher tabs (Login vs Register vs Forgot)
    document.querySelectorAll('[data-auth-tab]').forEach(tab => {
      tab.addEventListener('click', (e) => {
        const target = e.currentTarget.dataset.authTab;
        this.switchAuthTab(target);
      });
    });

    // Login Form
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
      loginForm.addEventListener('submit', (e) => this.handleLogin(e));
    }

    // Register Form
    const regForm = document.getElementById('registerForm');
    if (regForm) {
      regForm.addEventListener('submit', (e) => this.handleRegister(e));
    }

    // Send Registration OTP Button
    const sendOtpBtn = document.getElementById('btnSendRegOtp');
    if (sendOtpBtn) {
      sendOtpBtn.addEventListener('click', () => this.handleSendRegistrationOtp());
    }

    // Resend OTP Button
    const resendOtpBtn = document.getElementById('btnResendOtp');
    if (resendOtpBtn) {
      resendOtpBtn.addEventListener('click', () => this.handleResendOtp());
    }

    // Forgot Password Form
    const forgotForm = document.getElementById('forgotPasswordForm');
    if (forgotForm) {
      forgotForm.addEventListener('submit', (e) => this.handleForgotPassword(e));
    }
    const sendForgotOtpBtn = document.getElementById('btnSendForgotOtp');
    if (sendForgotOtpBtn) {
      sendForgotOtpBtn.addEventListener('click', () => this.handleSendForgotOtp());
    }
  }

  setupOtpInputs() {
    const inputs = document.querySelectorAll('.otp-digit');
    inputs.forEach((input, index) => {
      input.addEventListener('input', (e) => {
        if (e.target.value.length === 1) {
          if (index < inputs.length - 1) {
            inputs[index + 1].focus();
          }
        }
      });

      input.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !e.target.value && index > 0) {
          inputs[index - 1].focus();
        }
      });

      // Handle paste
      input.addEventListener('paste', (e) => {
        e.preventDefault();
        const pasted = (e.clipboardData || window.clipboardData).getData('text').trim();
        if (/^\d{6}$/.test(pasted)) {
          inputs.forEach((inp, i) => {
            inp.value = pasted[i] || '';
          });
          inputs[inputs.length - 1].focus();
        }
      });
    });
  }

  getEnteredOtp() {
    const inputs = document.querySelectorAll('.otp-digit');
    let code = '';
    inputs.forEach(i => code += i.value);
    return code;
  }

  switchAuthTab(tabName) {
    document.querySelectorAll('[data-auth-tab]').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.auth-panel').forEach(p => p.style.display = 'none');

    const activeTab = document.querySelector(`[data-auth-tab="${tabName}"]`);
    if (activeTab) activeTab.classList.add('active');

    const panel = document.getElementById(`panel-${tabName}`);
    if (panel) panel.style.display = 'block';
  }

  async checkUsernameDebounced(username) {
    const statusEl = document.getElementById('usernameStatus');
    if (!statusEl) return;

    if (!username || username.length < 3) {
      statusEl.textContent = 'Minimum 3 characters required';
      statusEl.className = 'input-feedback invalid';
      return;
    }

    try {
      const res = await window.api.auth.checkAvailability('username', username);
      if (res.data.available) {
        statusEl.textContent = `✓ @${username} is available`;
        statusEl.className = 'input-feedback valid';
      } else {
        statusEl.textContent = `✗ @${username} is already taken`;
        statusEl.className = 'input-feedback invalid';
      }
    } catch (e) {
      // ignore
    }
  }

  async checkPhone(phone) {
    const statusEl = document.getElementById('phoneStatus');
    if (!statusEl || !phone) return;

    try {
      const res = await window.api.auth.checkAvailability('phone', phone);
      if (res.data.available) {
        statusEl.textContent = '✓ Phone number is valid & available';
        statusEl.className = 'input-feedback valid';
      } else {
        statusEl.textContent = '✗ Phone number is already registered';
        statusEl.className = 'input-feedback invalid';
      }
    } catch (e) {
      // ignore
    }
  }

  async handleSendRegistrationOtp() {
    const phoneInput = document.getElementById('regPhone');
    const phone = phoneInput ? phoneInput.value.trim() : '';

    if (!phone) {
      window.app.showToast('Please enter your phone number first.', 'warning');
      phoneInput?.focus();
      return;
    }

    try {
      window.app.showLoading(true);
      const res = await window.api.auth.sendOtp(phone, 'registration');
      this.currentOtpPhone = phone;

      // Show OTP verification section
      const otpContainer = document.getElementById('regOtpContainer');
      if (otpContainer) otpContainer.style.display = 'block';

      window.app.showToast(res.message || 'Verification code sent to your phone!', 'success');

      // If dev preview code is available, auto-populate or display alert
      if (res.data?.previewCode) {
        window.app.showToast(`[Dev Mode] Verification OTP: ${res.data.previewCode}`, 'info');
        const inputs = document.querySelectorAll('.otp-digit');
        const digits = res.data.previewCode.split('');
        inputs.forEach((inp, idx) => inp.value = digits[idx] || '');
      }

      this.startCountdown();
    } catch (err) {
      window.app.showToast(err.message, 'error');
    } finally {
      window.app.showLoading(false);
    }
  }

  async handleResendOtp() {
    if (!this.currentOtpPhone) {
      window.app.showToast('No phone number specified to resend OTP.', 'warning');
      return;
    }
    await this.handleSendRegistrationOtp();
  }

  startCountdown() {
    clearInterval(this.otpTimer);
    let remaining = 300;
    const timerEl = document.getElementById('otpTimerDisplay');
    const resendBtn = document.getElementById('btnResendOtp');
    if (resendBtn) resendBtn.disabled = true;

    this.otpTimer = setInterval(() => {
      remaining--;
      const mins = Math.floor(remaining / 60);
      const secs = remaining % 60;
      if (timerEl) {
        timerEl.textContent = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
      }

      if (remaining <= 0) {
        clearInterval(this.otpTimer);
        if (timerEl) timerEl.textContent = 'Expired';
        if (resendBtn) resendBtn.disabled = false;
      }
    }, 1000);
  }

  async handleRegister(e) {
    e.preventDefault();
    const phone = document.getElementById('regPhone')?.value.trim();
    const otpCode = this.getEnteredOtp();
    const fullName = document.getElementById('regFullName')?.value.trim();
    const username = document.getElementById('regUsername')?.value.trim();
    const password = document.getElementById('regPassword')?.value;
    const currentMode = document.getElementById('regSelectedMode')?.value || 'common';
    const recoveryEmail = document.getElementById('regRecoveryEmail')?.value.trim();

    if (!phone) {
      window.app.showToast('Phone number is required.', 'warning');
      return;
    }
    if (!otpCode || otpCode.length < 6) {
      window.app.showToast('Please enter the complete 6-digit OTP.', 'warning');
      return;
    }
    if (!fullName) {
      window.app.showToast('Full name is required.', 'warning');
      return;
    }
    if (!username) {
      window.app.showToast('Username is required.', 'warning');
      return;
    }
    if (!password || password.length < 6) {
      window.app.showToast('Password must be at least 6 characters long.', 'warning');
      return;
    }

    try {
      window.app.showLoading(true);
      const payload = {
        phone,
        otpCode,
        fullName,
        username,
        password,
        currentMode,
        recoveryEmail: recoveryEmail || undefined
      };

      const res = await window.api.auth.register(payload);
      window.api.setToken(res.data.token);
      window.api.setUser(res.data.user);

      window.app.showToast('Welcome to CONNEKT! Account created successfully.', 'success');
      window.dispatchEvent(new CustomEvent('auth:login_success', { detail: res.data.user }));
    } catch (err) {
      window.app.showToast(err.message, 'error');
    } finally {
      window.app.showLoading(false);
    }
  }

  async handleLogin(e) {
    e.preventDefault();
    const identifier = document.getElementById('loginIdentifier')?.value.trim();
    const password = document.getElementById('loginPassword')?.value;
    const loginType = document.querySelector('input[name="loginMode"]:checked')?.value || 'password';

    if (!identifier) {
      window.app.showToast('Please enter your Phone, Username, or Connekt Mail.', 'warning');
      return;
    }

    if (loginType === 'password' && !password) {
      window.app.showToast('Please enter your password.', 'warning');
      return;
    }

    try {
      window.app.showLoading(true);
      const res = await window.api.auth.login({
        identifier,
        password,
        loginType
      });

      window.api.setToken(res.data.token);
      window.api.setUser(res.data.user);

      window.app.showToast(res.message || 'Logged in successfully!', 'success');
      window.dispatchEvent(new CustomEvent('auth:login_success', { detail: res.data.user }));
    } catch (err) {
      window.app.showToast(err.message, 'error');
    } finally {
      window.app.showLoading(false);
    }
  }

  async handleSendForgotOtp() {
    const identInput = document.getElementById('forgotIdentifier');
    const identifier = identInput ? identInput.value.trim() : '';
    if (!identifier) {
      window.app.showToast('Please enter your Phone, Username, or Connekt Mail ID.', 'warning');
      return;
    }

    try {
      window.app.showLoading(true);
      const res = await window.api.auth.sendOtp(identifier, 'forgot_password');
      window.app.showToast(res.message || 'Reset code sent!', 'success');
      document.getElementById('forgotOtpStep').style.display = 'block';

      if (res.data?.previewCode) {
        window.app.showToast(`[Dev Mode] Reset Code: ${res.data.previewCode}`, 'info');
        const codeInput = document.getElementById('forgotOtpCode');
        if (codeInput) codeInput.value = res.data.previewCode;
      }
    } catch (err) {
      window.app.showToast(err.message, 'error');
    } finally {
      window.app.showLoading(false);
    }
  }

  async handleForgotPassword(e) {
    e.preventDefault();
    const identifier = document.getElementById('forgotIdentifier')?.value.trim();
    const otpCode = document.getElementById('forgotOtpCode')?.value.trim();
    const newPassword = document.getElementById('forgotNewPassword')?.value;

    if (!identifier || !otpCode || !newPassword) {
      window.app.showToast('All fields are required to reset your password.', 'warning');
      return;
    }

    try {
      window.app.showLoading(true);
      const res = await window.api.auth.resetPassword({
        identifier,
        otpCode,
        newPassword
      });
      window.app.showToast(res.message, 'success');
      this.switchAuthTab('login');
    } catch (err) {
      window.app.showToast(err.message, 'error');
    } finally {
      window.app.showLoading(false);
    }
  }
}

window.authManager = new AuthManager();
