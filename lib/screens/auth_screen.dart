import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';

class AuthScreen extends StatefulWidget {
  final Function(UserModel user) onAuthSuccess;

  const AuthScreen({super.key, required this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedMode = 'common';

  // Login Controllers
  final _loginIdController = TextEditingController();
  final _loginPassController = TextEditingController();
  final _loginOtpController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _useOtpLogin = false; // Toggle between password and SMS OTP login

  // Register Controllers
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _regPassController = TextEditingController();
  bool _obscureRegPassword = true;

  bool _isSendingOtp = false;
  int _otpCooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Silently verify or auto-detect working server host across networks
    ApiConfig.autoDetectHost();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _loginIdController.dispose();
    _loginPassController.dispose();
    _loginOtpController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.accentCoral : AppTheme.accentBlue,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _otpCooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_otpCooldownSeconds > 1) {
          _otpCooldownSeconds--;
        } else {
          _otpCooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendOtp({required String phone, required String purpose}) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) {
      _showSnack('Please enter your phone number first', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);
    try {
      final res = await ApiService.sendOtp(cleanPhone, purpose: purpose);
      _startCooldownTimer();
      final preview = res['data']?['previewCode']?.toString();
      final smsDispatched = res['data']?['smsDispatched'] != false;

      if (!smsDispatched && preview != null && preview.isNotEmpty) {
        _showSnack('⚠️ Main phone SMS Gateway offline. Fallback OTP: $preview (Auto-filled)');
        if (purpose == 'registration') {
          _otpController.text = preview;
        } else {
          _loginOtpController.text = preview;
        }
      } else {
        _showSnack('Verification code sent via SMS to $cleanPhone. Please check your text messages!');
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final pass = _regPassController.text;

    // Field-specific validation
    if (phone.isEmpty) {
      _showSnack('Please enter your phone number', isError: true);
      return;
    }
    if (otp.isEmpty) {
      _showSnack('Please enter the 6-digit verification code sent via SMS', isError: true);
      return;
    }
    if (otp.length != 6) {
      _showSnack('Verification code must be 6 digits', isError: true);
      return;
    }
    if (fullName.isEmpty) {
      _showSnack('Please enter your full name', isError: true);
      return;
    }
    if (username.isEmpty) {
      _showSnack('Please enter a unique username', isError: true);
      return;
    }
    if (pass.isEmpty) {
      _showSnack('Please enter a password', isError: true);
      return;
    }
    if (pass.length < 6) {
      _showSnack('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await ApiService.register(
        phone: phone,
        otpCode: otp,
        username: username,
        fullName: fullName,
        password: pass,
        currentMode: _selectedMode,
      );
      _showSnack('Welcome to CONNEKT, ${user.personalProfile?.displayName ?? user.username}!');
      widget.onAuthSuccess(user);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLoginWithOtp() async {
    final phone = _loginIdController.text.trim();
    final otp = _loginOtpController.text.trim();

    if (phone.isEmpty) {
      _showSnack('Please enter your registered phone number', isError: true);
      return;
    }
    if (otp.isEmpty) {
      _showSnack('Please enter the 6-digit verification code sent via SMS', isError: true);
      return;
    }
    if (otp.length != 6) {
      _showSnack('Verification code must be 6 digits', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await ApiService.loginWithOtp(phone: phone, otpCode: otp);
      _showSnack('Welcome back, @${user.username}!');
      widget.onAuthSuccess(user);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    final id = _loginIdController.text.trim();
    final pass = _loginPassController.text;

    if (id.isEmpty) {
      _showSnack('Please enter your Phone, Username, or Connekt Mail', isError: true);
      return;
    }
    if (pass.isEmpty) {
      _showSnack('Please enter your password', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await ApiService.login(identifier: id, password: pass);
      _showSnack('Welcome back, @${user.username}!');
      widget.onAuthSuccess(user);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hostController = TextEditingController(text: ApiConfig.currentHost);
    bool isDetecting = false;
    String? statusMsg;
    bool? isSuccess;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.bgCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.wifi_tethering, color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Server Connection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your PC\'s Wi-Fi IP address, USB localhost, or Cloud Tunnel URL:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hostController,
                    decoration: InputDecoration(
                      hintText: '192.168.29.98:5000 or https://...loca.lt',
                      labelText: 'Host or Cloud URL',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setDialogState(() => hostController.clear()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Auto-Detect Button
                  OutlinedButton.icon(
                    onPressed: isDetecting
                        ? null
                        : () async {
                            setDialogState(() {
                              isDetecting = true;
                              statusMsg = 'Scanning local network for server...';
                              isSuccess = null;
                            });
                            final detected = await ApiConfig.autoDetectHost();
                            setDialogState(() {
                              isDetecting = false;
                              if (detected != null) {
                                hostController.text = detected;
                                statusMsg = 'Connected to $detected!';
                                isSuccess = true;
                              } else {
                                statusMsg = 'No active server found. Check if Node is running.';
                                isSuccess = false;
                              }
                            });
                          },
                    icon: isDetecting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search, size: 16),
                    label: Text(isDetecting ? 'Scanning...' : 'Auto-Detect Active Server'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),

                  if (statusMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      statusMsg!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isSuccess == true
                            ? const Color(0xFF10B981)
                            : (isSuccess == false ? AppTheme.accentCoral : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Text(
                    'Quick Presets:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.cloud_outlined, size: 14),
                        label: const Text('5G Mobile Data (Cloud Tunnel)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => hostController.text = 'https://swift-hoops-trade.loca.lt'),
                      ),
                      ActionChip(
                        label: const Text('Wi-Fi (192.168.29.98:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => hostController.text = '192.168.29.98:5000'),
                      ),
                      ActionChip(
                        label: const Text('USB (localhost:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () => setDialogState(() => hostController.text = 'localhost:5000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '💡 For Mobile Data (4G/5G): Run "npm run tunnel" on PC and paste the HTTPS URL above.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppTheme.textMuted : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final text = hostController.text.trim();
                  if (text.isNotEmpty) {
                    await ApiConfig.setHost(text);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    _showSnack('Server updated to: ${ApiConfig.currentHost}');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                ),
                child: const Text('Save & Connect', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Bar (Light/Dark Mood Toggle & Server Settings)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? const Color(0xFFFFB800) : const Color(0xFF475569),
                      size: 22,
                    ),
                    tooltip: isDark ? 'Switch to Light Mood' : 'Switch to Dark Mood',
                    onPressed: () => ThemeService.toggleTheme(),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                      size: 22,
                    ),
                    tooltip: 'Server Connection Settings',
                    onPressed: _showServerSettingsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Brand Header: Official CONNEKT Emblem Badge
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : const Color(0x14000000),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/icons/connekt_emblem.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text(
                        'C',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Official CONNEKT Brandmark (Red & Blue Typography)
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.2,
                      fontFamily: 'Roboto',
                    ),
                    children: [
                      TextSpan(
                        text: 'CONN',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3B82),
                        ),
                      ),
                      const TextSpan(
                        text: 'E',
                        style: TextStyle(
                          color: AppTheme.brandRed,
                        ),
                      ),
                      TextSpan(
                        text: 'KT',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3B82),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'CONNECTING THE UNCONNECTED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                ),
              ),
              const SizedBox(height: 24),

              // Switcher Tab (Sign In / Create Account)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isLogin ? AppTheme.brandBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: _isLogin
                                ? [
                                    BoxShadow(
                                      color: AppTheme.brandBlue.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Sign In',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _isLogin
                                  ? Colors.white
                                  : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isLogin ? AppTheme.brandBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: !_isLogin
                                ? [
                                    BoxShadow(
                                      color: AppTheme.brandBlue.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: !_isLogin
                                  ? Colors.white
                                  : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isLogin) ...[
                // Sign In Form (Supports both Password and Real SMS OTP)
                if (!_useOtpLogin) ...[
                  TextField(
                    controller: _loginIdController,
                    decoration: const InputDecoration(
                      labelText: 'Phone, Username, or Connekt Mail',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _loginPassController,
                    obscureText: _obscureLoginPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureLoginPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                          size: 20,
                        ),
                        tooltip: _obscureLoginPassword ? 'Show password' : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscureLoginPassword = !_obscureLoginPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.brandBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ] else ...[
                  // Sign In with Real SMS OTP
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _loginIdController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Registered Phone Number',
                            hintText: 'e.g. 9836828816',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSendingOtp || _otpCooldownSeconds > 0)
                              ? null
                              : () => _handleSendOtp(phone: _loginIdController.text, purpose: 'login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? AppTheme.bgCard : const Color(0xFFF1F5F9),
                            foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: _isSendingOtp
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandBlue))
                              : Text(
                                  _otpCooldownSeconds > 0 ? 'Wait ${_otpCooldownSeconds}s' : 'Send OTP',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _loginOtpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6-Digit Verification Code',
                      hintText: 'Enter code received via SMS',
                      prefixIcon: const Icon(Icons.sms_outlined, color: AppTheme.brandBlue),
                      counterText: '',
                      suffixIcon: _loginOtpController.text.length == 6
                          ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLoginWithOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.brandBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Sign In with SMS OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _useOtpLogin = !_useOtpLogin;
                      });
                    },
                    icon: Icon(
                      _useOtpLogin ? Icons.lock_outline : Icons.sms_outlined,
                      size: 16,
                      color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                    ),
                    label: Text(
                      _useOtpLogin ? 'Sign In with Password instead' : 'Sign In with SMS OTP instead',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Register Form with Real SMS Verification
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g. 9836828816',
                          prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSendingOtp || _otpCooldownSeconds > 0)
                            ? null
                            : () => _handleSendOtp(phone: _phoneController.text, purpose: 'registration'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.bgCard : const Color(0xFFF1F5F9),
                          foregroundColor: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandBlue))
                            : Text(
                                _otpCooldownSeconds > 0 ? 'Wait ${_otpCooldownSeconds}s' : 'Send OTP',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // OTP Verification Code Field
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '6-Digit Verification Code (OTP)',
                    hintText: 'Enter code received via SMS on your phone',
                    prefixIcon: const Icon(Icons.verified_outlined, color: AppTheme.brandBlue),
                    counterText: '',
                    suffixIcon: _otpController.text.length == 6
                        ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _usernameController,
                  onChanged: (v) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Unique Username',
                    prefixIcon: Icon(Icons.alternate_email, color: AppTheme.textSecondary),
                  ),
                ),
                if (_usernameController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Connekt Mail: ${_usernameController.text.trim().toLowerCase()}@connekt.me',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                TextField(
                  controller: _regPassController,
                  obscureText: _obscureRegPassword,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 characters)',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureRegPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark ? AppTheme.textSecondary : const Color(0xFF64748B),
                        size: 20,
                      ),
                      tooltip: _obscureRegPassword ? 'Show password' : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureRegPassword = !_obscureRegPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Account Experience Mode
                Text(
                  'Choose Your Account Experience:',
                  style: TextStyle(
                    color: isDark ? AppTheme.textSecondary : const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildModeChip('common', 'Personal', isDark),
                    const SizedBox(width: 8),
                    _buildModeChip('professional', 'Professional', isDark),
                    const SizedBox(width: 8),
                    _buildModeChip('both', 'Both', isDark),
                  ],
                ),
                const SizedBox(height: 22),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppTheme.brandBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create My Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String mode, String label, bool isDark) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.brandBlue.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.brandBlue
                  : (isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? (isDark ? const Color(0xFF60A5FA) : AppTheme.brandBlue)
                  : (isDark ? AppTheme.textSecondary : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}
