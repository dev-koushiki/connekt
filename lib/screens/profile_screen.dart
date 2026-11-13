import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../widgets/safe_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onLogout;
  final Function(String mode)? onModeChanged;
  final Function(UserModel updatedUser)? onUserUpdated;
  final VoidCallback? onBackToHome;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    this.onModeChanged,
    this.onUserUpdated,
    this.onBackToHome,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0; // 0: Personal, 1: Career, 2: Security & PIN, 3: Settings
  late String _currentMode;
  UserModel? _user;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;
  bool _isLoggingOut = false;

  // Security & Privacy State
  bool _pinEnabled = false;
  String _pinCode = '';
  bool _biometricEnabled = false;
  String _autoLockTimeout = 'Immediately';
  bool _hideRecentApps = true;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _user = widget.user;
    _currentMode = widget.user?.currentMode ?? 'common';
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pinEnabled = prefs.getBool('connekt_pin_enabled') ?? false;
        _pinCode = prefs.getString('connekt_pin_code') ?? '';
        _biometricEnabled = prefs.getBool('connekt_biometric_enabled') ?? false;
        _autoLockTimeout = prefs.getString('connekt_autolock_timeout') ?? 'Immediately';
        _hideRecentApps = prefs.getBool('connekt_hide_recents') ?? true;
        _twoFactorEnabled = prefs.getBool('connekt_2fa_enabled') ?? false;
      });
    }
  }

  Future<void> _savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connekt_pin_code', pin);
    await prefs.setBool('connekt_pin_enabled', true);
    if (mounted) {
      setState(() {
        _pinCode = pin;
        _pinEnabled = true;
      });
      _showSnack('Security PIN set and enabled successfully!', color: const Color(0xFF16A34A));
    }
  }

  Future<void> _disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connekt_pin_enabled', false);
    await prefs.remove('connekt_pin_code');
    if (mounted) {
      setState(() {
        _pinEnabled = false;
        _pinCode = '';
      });
      _showSnack('PIN lock has been disabled.');
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connekt_biometric_enabled', value);
    if (mounted) {
      setState(() {
        _biometricEnabled = value;
      });
      _showSnack(
        value ? 'Biometric Authentication (Fingerprint / Face ID) enabled!' : 'Biometric Authentication disabled.',
        color: value ? const Color(0xFF16A34A) : null,
      );
    }
  }

  Future<void> _setAutoLockTimeout(String timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('connekt_autolock_timeout', timeout);
    if (mounted) {
      setState(() {
        _autoLockTimeout = timeout;
      });
      _showSnack('Auto-lock timer set to: $timeout');
    }
  }

  Future<void> _toggleHideRecentApps(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connekt_hide_recents', value);
    if (mounted) {
      setState(() {
        _hideRecentApps = value;
      });
      _showSnack(value ? 'App preview hidden from recent apps switcher' : 'App preview enabled in recent apps');
    }
  }

  Future<void> _toggleTwoFactor(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('connekt_2fa_enabled', value);
    if (mounted) {
      setState(() {
        _twoFactorEnabled = value;
      });
      _showSnack(value ? 'Two-Factor Verification (2FA) enabled!' : 'Two-Factor Verification disabled.');
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      setState(() {
        _user = widget.user;
        _currentMode = widget.user?.currentMode ?? 'common';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleLogout() {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      widget.onLogout();
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.accentCoral : (color ?? AppTheme.brandBlue),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _uploadAvatarBytes(List<int> bytes, String fileName) async {
    if (bytes.isEmpty) return;
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      _showSnack('Profile photo must be 5MB or smaller.', isError: true);
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final updated = await ApiService.uploadAvatar(
        uint8,
        fileName,
        currentUser: _user,
      );
      if (!mounted) return;
      setState(() => _user = updated);
      widget.onUserUpdated?.call(updated);
      _showSnack('Profile picture updated!', color: AppTheme.brandBlue);
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _uploadAvatarBytes(bytes, picked.name);
    } catch (_) {
      await _pickAvatarFromFiles();
    }
  }

  Future<void> _pickAvatarFromFiles() async {
    if (_isUploadingAvatar) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await _uploadAvatarBytes(bytes, file.name);
    } catch (e) {
      _showSnack('Could not pick image: $e', isError: true);
    }
  }

  void _showAvatarPickerSheet(bool isDark) {
    if (_isUploadingAvatar) return;
    final primaryColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final mutedColor = isDark ? AppTheme.textSecondary : const Color(0xFF64748B);
    final isDesktopOrWeb = kIsWeb ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.macOS;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.bgCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Profile Picture',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              if (!isDesktopOrWeb)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: AppTheme.brandBlue, size: 20),
                  ),
                  title: Text('Take Photo', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                  subtitle: Text('Use your device camera', style: TextStyle(color: mutedColor, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Text('Choose from Gallery', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Pick a photo from your library', style: TextStyle(color: mutedColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_open_rounded, color: Color(0xFF8B5CF6), size: 20),
                ),
                title: Text('Browse Files', style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Select JPG, PNG, WEBP, or GIF up to 5MB', style: TextStyle(color: mutedColor, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatarFromFiles();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleModeSwitch(String mode) async {
    try {
      final newMode = await ApiService.switchMode(mode);
      setState(() => _currentMode = newMode);
      widget.onModeChanged?.call(newMode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${newMode.toUpperCase()} Mode!'),
            backgroundColor: AppTheme.brandBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openEditProfileDialog(bool isDark, {int initialTab = 0}) {
    final personal = _user?.personalProfile;
    final prof = _user?.professionalProfile;

    final fullNameCtrl = TextEditingController(text: personal?.fullName ?? '');
    final displayNameCtrl = TextEditingController(text: personal?.displayName ?? '');
    final bioCtrl = TextEditingController(text: personal?.bio ?? '');
    final locationCtrl = TextEditingController(text: personal?.location ?? '');
    final websiteCtrl = TextEditingController(text: personal?.website ?? '');

    final headlineCtrl = TextEditingController(text: prof?.headline ?? '');
    final companyCtrl = TextEditingController(text: prof?.currentCompany ?? '');
    final industryCtrl = TextEditingController(text: prof?.industry ?? '');
    final expCtrl = TextEditingController(text: prof?.yearsOfExperience.toString() ?? '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.bgCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        int selectedSheetTab = initialTab;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final primaryColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
            final sheetBorderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          color: isDark ? AppTheme.textMuted : const Color(0xFF64748B),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sheetBorderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedSheetTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedSheetTab == 0 ? AppTheme.brandBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Personal',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedSheetTab == 0 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() => selectedSheetTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedSheetTab == 1 ? AppTheme.brandBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Professional',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: selectedSheetTab == 1 ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedSheetTab == 0) ...[
                      _buildTextField('Full Legal Name', fullNameCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Display Name', displayNameCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Bio', bioCtrl, isDark, maxLines: 3),
                      const SizedBox(height: 12),
                      _buildTextField('Location', locationCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Website', websiteCtrl, isDark),
                    ] else ...[
                      _buildTextField('Headline', headlineCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Company', companyCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Industry', industryCtrl, isDark),
                      const SizedBox(height: 12),
                      _buildTextField('Years of Experience', expCtrl, isDark, keyboardType: TextInputType.number),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                UserModel updated;
                                if (selectedSheetTab == 0) {
                                  updated = await ApiService.updatePersonalProfile(
                                    fullName: fullNameCtrl.text.trim(),
                                    displayName: displayNameCtrl.text.trim(),
                                    bio: bioCtrl.text.trim(),
                                    location: locationCtrl.text.trim(),
                                    website: websiteCtrl.text.trim(),
                                  );
                                } else {
                                  updated = await ApiService.updateProfessionalProfile(
                                    headline: headlineCtrl.text.trim(),
                                    currentCompany: companyCtrl.text.trim(),
                                    industry: industryCtrl.text.trim(),
                                    yearsOfExperience: int.tryParse(expCtrl.text.trim()) ?? 0,
                                  );
                                }
                                if (!mounted) return;
                                setState(() => _user = updated);
                                widget.onUserUpdated?.call(updated);
                                Navigator.pop(ctx);
                                _showSnack('Profile updated successfully!', color: AppTheme.brandBlue);
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, bool isDark, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textSecondary : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimaryLight, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: isDark ? AppTheme.bgInput : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.brandBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // INTERACTIVE PIN SETUP MODAL
  // ===========================================================================

  void _showPinSetupDialog(bool isDark) {
    String currentInput = '';
    String? firstPin;
    bool isConfirmStep = false;
    String errorMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final title = isConfirmStep ? 'Confirm Your 4-Digit PIN' : (_pinEnabled ? 'Enter New 4-Digit PIN' : 'Create 4-Digit Security PIN');
          final subtitle = isConfirmStep
              ? 'Re-enter your 4 digits to verify'
              : 'Secure your chats, profile, and meetings with an instant PIN';

          void handleDigit(String digit) {
            if (currentInput.length < 4) {
              setSheetState(() {
                currentInput += digit;
                errorMessage = '';
              });

              if (currentInput.length == 4) {
                if (!isConfirmStep) {
                  // Move to confirm step
                  Future.delayed(const Duration(milliseconds: 200), () {
                    setSheetState(() {
                      firstPin = currentInput;
                      currentInput = '';
                      isConfirmStep = true;
                    });
                  });
                } else {
                  // Verify confirm step
                  if (currentInput == firstPin) {
                    Future.delayed(const Duration(milliseconds: 250), () {
                      Navigator.pop(ctx);
                      _savePin(currentInput);
                    });
                  } else {
                    setSheetState(() {
                      errorMessage = 'PINs did not match. Please try again.';
                      currentInput = '';
                      firstPin = null;
                      isConfirmStep = false;
                    });
                  }
                }
              }
            }
          }

          void handleBackspace() {
            if (currentInput.isNotEmpty) {
              setSheetState(() {
                currentInput = currentInput.substring(0, currentInput.length - 1);
                errorMessage = '';
              });
            }
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lock Shield Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F3B82), Color(0xFF3B82F6)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F1E36),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4-Digit Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < currentInput.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? const Color(0xFF0F3B82)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          border: Border.all(
                            color: isFilled
                                ? const Color(0xFF3B82F6)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),

                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Custom Numeric Keypad
                  _buildNumericKeypad(
                    onDigit: handleDigit,
                    onBackspace: handleBackspace,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE TEST LOCK SCREEN MODAL
  // ===========================================================================

  void _showTestLockScreen(bool isDark) {
    String enteredPin = '';
    bool isError = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setLockState) {
          void handleKey(String key) {
            if (enteredPin.length < 4) {
              setLockState(() {
                enteredPin += key;
                isError = false;
              });

              if (enteredPin.length == 4) {
                if (_pinCode.isNotEmpty && enteredPin == _pinCode) {
                  // Successful unlock!
                  HapticFeedback.mediumImpact();
                  Future.delayed(const Duration(milliseconds: 200), () {
                    Navigator.pop(ctx);
                    _showSnack('Device Unlocked Successfully!', color: const Color(0xFF16A34A));
                  });
                } else if (_pinCode.isEmpty) {
                  // No PIN was set, any 4 digits work for simulation
                  Navigator.pop(ctx);
                  _showSnack('Unlocked with Demo PIN: $enteredPin', color: const Color(0xFF16A34A));
                } else {
                  // Mismatch
                  HapticFeedback.heavyImpact();
                  setLockState(() {
                    isError = true;
                    enteredPin = '';
                  });
                }
              }
            }
          }

          void handleDelete() {
            if (enteredPin.isNotEmpty) {
              setLockState(() {
                enteredPin = enteredPin.substring(0, enteredPin.length - 1);
                isError = false;
              });
            }
          }

          void handleBiometricSimulate() {
            HapticFeedback.selectionClick();
            Navigator.pop(ctx);
            _showSnack('Biometric Verified • Fingerprint Authenticated!', color: const Color(0xFF0F3B82));
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFFAFBFD),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F3B82),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CONNEKT App Lock',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F1E36),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Avatar or Shield
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isError
                            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                            : [const Color(0xFF0F3B82), const Color(0xFF3B82F6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isError ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      isError ? Icons.lock_open_rounded : Icons.shield_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    isError ? 'Incorrect PIN, Try Again' : 'Enter 4-Digit Security PIN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isError ? const Color(0xFFEF4444) : (isDark ? Colors.white : const Color(0xFF0F1E36)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pinEnabled ? 'PIN lock is active' : 'Test Mode (Set PIN in settings to lock strictly)',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4-Digit Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? const Color(0xFF0F3B82) : Colors.transparent,
                          border: Border.all(
                            color: isFilled ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Numeric Pad
                  _buildNumericKeypad(
                    onDigit: handleKey,
                    onBackspace: handleDelete,
                    isDark: isDark,
                  ),

                  if (_biometricEnabled) ...[
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: handleBiometricSimulate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3B82).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fingerprint_rounded, color: Color(0xFF0F3B82), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Unlock with Biometrics',
                              style: TextStyle(color: Color(0xFF0F3B82), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumericKeypad({
    required Function(String) onDigit,
    required VoidCallback onBackspace,
    required bool isDark,
  }) {
    final keyBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final keyTextColor = isDark ? Colors.white : const Color(0xFF0F1E36);

    Widget buildKey(String val) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: keyBg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onDigit(val),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                child: Text(
                  val,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: keyTextColor),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [buildKey('1'), buildKey('2'), buildKey('3')]),
        Row(children: [buildKey('4'), buildKey('5'), buildKey('6')]),
        Row(children: [buildKey('7'), buildKey('8'), buildKey('9')]),
        Row(
          children: [
            const Spacer(),
            buildKey('0'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: onBackspace,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      child: Icon(Icons.backspace_outlined, color: keyTextColor, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // MAIN BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final user = _user ?? widget.user;
    final personal = user?.personalProfile;
    final prof = user?.professionalProfile;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondary : const Color(0xFF475569);
    final mutedTextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final cardBgColor = isDark ? AppTheme.bgCard : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFFAFBFD),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: widget.onBackToHome != null
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
                tooltip: 'Back to Home',
                onPressed: widget.onBackToHome,
              )
            : null,
        title: Text(
          'My Profile & Security',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: primaryTextColor,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.brandRed),
            tooltip: 'Log Out',
            onPressed: _isLoggingOut ? null : _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // HERO PROFILE HEADER CARD
            _buildHeroProfileHeader(user, personal, isDark, primaryTextColor, secondaryTextColor, borderColor),

            const SizedBox(height: 16),

            // MODE SWITCHER (Personal / Professional / Both Modes)
            _buildModeSwitcherWidget(isDark, cardBgColor, borderColor),

            const SizedBox(height: 18),

            // MODERN 4-TAB SEGMENTED SELECTOR
            _buildSegmentedTabBar(isDark, cardBgColor, borderColor),

            const SizedBox(height: 16),

            // TAB CONTENT AREA (Smoothly dynamic without clipping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildActiveTabContent(user, personal, prof, isDark, primaryTextColor, secondaryTextColor, mutedTextColor, cardBgColor, borderColor),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. HERO PROFILE HEADER
  // ===========================================================================

  Widget _buildHeroProfileHeader(
    UserModel? user,
    PersonalProfile? personal,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color borderColor,
  ) {
    final displayName = personal?.displayName.isNotEmpty == true
        ? personal!.displayName
        : (personal?.fullName.isNotEmpty == true ? personal!.fullName : (user?.username ?? 'User'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151F33) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Glowing Gradient Avatar
            GestureDetector(
              onTap: _isUploadingAvatar ? null : () => _showAvatarPickerSheet(isDark),
              child: Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F3B82), Color(0xFF3B82F6), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF0B132B) : Colors.white,
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(48),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (resolveAvatarUrl(personal?.avatarUrl) != null)
                              Image.network(
                                resolveAvatarUrl(personal?.avatarUrl)!,
                                headers: ApiConfig.mediaHeaders,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Color(0xFF0F3B82)),
                              )
                            else
                              const Icon(Icons.person, size: 50, color: Color(0xFF0F3B82)),
                            if (_isUploadingAvatar)
                              Container(
                                color: Colors.black45,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Camera Badge Icon
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F3B82),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Display Name with Verified Check
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 3),

            // Handle
            Text(
              '@${user?.username ?? 'username'}',
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Email Pill with Copy Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alternate_email_rounded, size: 13, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        user?.email ?? 'user@connekt.me',
                        style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    final email = user?.email ?? '';
                    if (email.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: email));
                      _showSnack('Email copied to clipboard!');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Edit Profile Button
            ElevatedButton.icon(
              onPressed: () => _openEditProfileDialog(isDark),
              icon: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
              label: const Text('Edit Profile', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F3B82),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. MODE SWITCHER
  // ===========================================================================

  Widget _buildModeSwitcherWidget(bool isDark, Color cardBgColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _buildModeButton('common', 'Personal', Icons.person_rounded, isDark),
            _buildModeButton('professional', 'Professional', Icons.work_rounded, isDark),
            _buildModeButton('both', 'Both Modes', Icons.bolt_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon, bool isDark) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleModeSwitch(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F3B82) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F3B82).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. SEGMENTED TAB BAR
  // ===========================================================================

  Widget _buildSegmentedTabBar(bool isDark, Color cardBgColor, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            _buildTabPill(0, 'Personal', Icons.person_outline_rounded, isDark),
            _buildTabPill(1, 'Career', Icons.work_outline_rounded, isDark),
            _buildTabPill(2, 'Security', Icons.shield_outlined, isDark, hasBadge: _pinEnabled || _biometricEnabled),
            _buildTabPill(3, 'Settings', Icons.tune_rounded, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon, bool isDark, {bool hasBadge = false}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? const Color(0xFF0F3B82) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F3B82) : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ),
              if (hasBadge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. ACTIVE TAB CONTENT
  // ===========================================================================

  Widget _buildActiveTabContent(
    UserModel? user,
    PersonalProfile? personal,
    ProfessionalProfile? prof,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    switch (_selectedTab) {
      case 0:
        return _buildPersonalTab(personal, user, isDark, primaryTextColor, mutedTextColor, cardBgColor, borderColor);
      case 1:
        return _buildCareerTab(prof, user, isDark, primaryTextColor, mutedTextColor, cardBgColor, borderColor);
      case 2:
        return _buildSecurityTab(isDark, primaryTextColor, secondaryTextColor, mutedTextColor, cardBgColor, borderColor);
      case 3:
      default:
        return _buildSettingsTab(user, isDark, primaryTextColor, secondaryTextColor, mutedTextColor, cardBgColor, borderColor);
    }
  }

  // --- TAB 1: PERSONAL ---
  Widget _buildPersonalTab(
    PersonalProfile? personal,
    UserModel? user,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Personal Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
            ),
            TextButton.icon(
              onPressed: () => _openEditProfileDialog(isDark, initialTab: 0),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F3B82)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildModernInfoCard(
          label: 'Full Legal Name',
          value: personal?.fullName.isNotEmpty == true ? personal!.fullName : 'Not set',
          icon: Icons.person_outline_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Display Name',
          value: personal?.displayName.isNotEmpty == true ? personal!.displayName : (user?.username ?? 'Not set'),
          icon: Icons.badge_outlined,
          iconBg: const Color(0xFFF5F3FF),
          iconColor: const Color(0xFF8B5CF6),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Bio',
          value: personal?.bio.isNotEmpty == true ? personal!.bio : 'No personal bio added yet.',
          icon: Icons.format_quote_rounded,
          iconBg: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFD97706),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Location',
          value: personal?.location.isNotEmpty == true ? personal!.location : 'Location not set',
          icon: Icons.location_on_outlined,
          iconBg: const Color(0xFFECFDF5),
          iconColor: const Color(0xFF10B981),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Website',
          value: personal?.website.isNotEmpty == true ? personal!.website : 'No website',
          icon: Icons.link_rounded,
          iconBg: const Color(0xFFFDF2F8),
          iconColor: const Color(0xFFEC4899),
          isDark: isDark,
          borderColor: borderColor,
        ),
      ],
    );
  }

  // --- TAB 2: CAREER ---
  Widget _buildCareerTab(
    ProfessionalProfile? prof,
    UserModel? user,
    bool isDark,
    Color primaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Professional Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
            ),
            TextButton.icon(
              onPressed: () => _openEditProfileDialog(isDark, initialTab: 1),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F3B82)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildModernInfoCard(
          label: 'Headline',
          value: prof?.headline.isNotEmpty == true ? prof!.headline : 'Member at CONNEKT',
          icon: Icons.work_outline_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF3B82F6),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Company',
          value: prof?.currentCompany.isNotEmpty == true ? prof!.currentCompany : 'Not specified',
          icon: Icons.business_outlined,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Industry',
          value: prof?.industry.isNotEmpty == true ? prof!.industry : 'Not specified',
          icon: Icons.category_outlined,
          iconBg: const Color(0xFFFAF5FF),
          iconColor: const Color(0xFFA855F7),
          isDark: isDark,
          borderColor: borderColor,
        ),
        _buildModernInfoCard(
          label: 'Experience',
          value: '${prof?.yearsOfExperience ?? 0} Years',
          icon: Icons.history_rounded,
          iconBg: const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFEA580C),
          isDark: isDark,
          borderColor: borderColor,
        ),
        const SizedBox(height: 16),
        Text('Verified Skills', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (user?.skills ?? []).isEmpty
              ? [
                  Text('No skills added yet', style: TextStyle(fontSize: 12, color: mutedTextColor)),
                ]
              : (user?.skills ?? []).map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3B82).withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF0F3B82).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${s.skillName} • ${s.proficiency}',
                      style: const TextStyle(
                        color: Color(0xFF0F3B82),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
        ),
      ],
    );
  }

  // --- TAB 3: PRIVACY & SECURITY (THE CORE USER REQUEST) ---
  Widget _buildSecurityTab(
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Security Status Banner Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3B82), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F3B82).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pinEnabled ? 'App Protection: Active' : 'App Protection: Action Recommended',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pinEnabled
                          ? (_biometricEnabled ? 'Secured with 4-Digit PIN & Biometrics' : 'Secured with 4-Digit PIN')
                          : 'Set a PIN to lock chats, calls, and meetings',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 1. PIN LOCK SECTION
        Text(
          'App Lock & PIN Security',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F33) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F3B82).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pin_rounded, color: Color(0xFF0F3B82), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('4-Digit Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor)),
                        Text(
                          _pinEnabled ? 'PIN is set and active' : 'Not configured',
                          style: TextStyle(fontSize: 11.5, color: _pinEnabled ? const Color(0xFF16A34A) : mutedTextColor),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _pinEnabled,
                    activeColor: const Color(0xFF0F3B82),
                    onChanged: (val) {
                      if (val) {
                        _showPinSetupDialog(isDark);
                      } else {
                        _disablePin();
                      }
                    },
                  ),
                ],
              ),
              if (_pinEnabled) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Saved PIN: ••••', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    TextButton.icon(
                      onPressed: () => _showPinSetupDialog(isDark),
                      icon: const Icon(Icons.lock_reset_rounded, size: 16),
                      label: const Text('Change PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF0F3B82)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. BIOMETRIC UNLOCK SECTION
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F33) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Biometric Authentication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor)),
                    Text(
                      'Unlock with Fingerprint or Face ID',
                      style: TextStyle(fontSize: 11.5, color: mutedTextColor),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _biometricEnabled,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) {
                  _toggleBiometric(val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. AUTO-LOCK TIMER
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F33) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFF8B5CF6), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Auto-Lock Timeout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: primaryTextColor)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Immediately', 'After 1m', 'After 5m', 'After 15m'].map((timeout) {
                  final isSelected = _autoLockTimeout == timeout;
                  return InkWell(
                    onTap: () => _setAutoLockTimeout(timeout),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F3B82) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        timeout,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 4. SCREEN PRIVACY & RECENT APPS
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F33) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Hide App in Recent Apps', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryTextColor)),
                subtitle: Text('Blurs screen in Android task switcher', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                value: _hideRecentApps,
                activeColor: const Color(0xFF0F3B82),
                contentPadding: EdgeInsets.zero,
                onChanged: _toggleHideRecentApps,
              ),
              const Divider(height: 12),
              SwitchListTile(
                title: Text('Two-Factor Verification (2FA)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryTextColor)),
                subtitle: Text('Extra protection on new device logins', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                value: _twoFactorEnabled,
                activeColor: const Color(0xFF0F3B82),
                contentPadding: EdgeInsets.zero,
                onChanged: _toggleTwoFactor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // 5. TEST LOCK SCREEN BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showTestLockScreen(isDark),
            icon: const Icon(Icons.phonelink_lock_rounded, color: Colors.white, size: 18),
            label: const Text('Test Lock Screen Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3B82),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // --- TAB 4: SETTINGS & APPEARANCE ---
  Widget _buildSettingsTab(
    UserModel? user,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color mutedTextColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance & Visual Mood',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
        ),
        const SizedBox(height: 4),
        Text('Choose how CONNEKT looks on your phone', style: TextStyle(fontSize: 12, color: mutedTextColor)),
        const SizedBox(height: 12),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeModeNotifier,
          builder: (context, currentMode, _) {
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151F33) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _buildThemeOption(mode: ThemeMode.dark, current: currentMode, label: 'Dark Mood', icon: Icons.dark_mode_rounded),
                  _buildThemeOption(mode: ThemeMode.light, current: currentMode, label: 'Light Mood', icon: Icons.light_mode_rounded),
                  _buildThemeOption(mode: ThemeMode.system, current: currentMode, label: 'System', icon: Icons.brightness_auto_rounded),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        Text('Communication Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151F33) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Group Invitation Approval', style: TextStyle(fontSize: 13.5, color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Require approval before joining groups', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                value: user?.privacySettings?.groupInvitationApproval ?? true,
                onChanged: (_) {},
                activeColor: const Color(0xFF0F3B82),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 10),
              SwitchListTile(
                title: Text('Read Receipts', style: TextStyle(fontSize: 13.5, color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Show blue checks when message is read', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                value: user?.privacySettings?.readReceipts ?? true,
                onChanged: (_) {},
                activeColor: const Color(0xFF0F3B82),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 10),
              SwitchListTile(
                title: Text('Online Status Indicator', style: TextStyle(fontSize: 13.5, color: primaryTextColor, fontWeight: FontWeight.w600)),
                subtitle: Text('Show active green badge when online', style: TextStyle(fontSize: 11, color: mutedTextColor)),
                value: user?.privacySettings?.onlineStatus ?? true,
                onChanged: (_) {},
                activeColor: const Color(0xFF0F3B82),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoggingOut ? null : _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: AppTheme.brandRed, size: 18),
            label: const Text('Sign Out of CONNEKT', style: TextStyle(color: AppTheme.brandRed, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: AppTheme.brandRed.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  Widget _buildModernInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isDark,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151F33) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F1E36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required ThemeMode current,
    required String label,
    required IconData icon,
  }) {
    final isSelected = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ThemeService.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F3B82) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0F3B82).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
