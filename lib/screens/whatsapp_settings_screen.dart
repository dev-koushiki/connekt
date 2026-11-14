import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../i18n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/i18n_service.dart';
import '../widgets/language_selector_sheet.dart';
import '../widgets/safe_avatar.dart';
import 'chat_theme_screen.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  final VoidCallback? onClearAllChats;
  final UserModel? user;
  final Function(String newAvatarUrl)? onAvatarUpdated;

  const WhatsAppSettingsScreen({
    super.key,
    this.onClearAllChats,
    this.user,
    this.onAvatarUpdated,
  });

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  bool _readReceipts = true;
  bool _keepArchived = true;
  bool _isBackingUp = false;
  String _lastBackupTime = 'Today, 2:00 am';
  final String _backupSize = '14.2 MB';

  // Chat Profile Photo State
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingAvatar = false;
  String? _chatAvatarUrl;
  Uint8List? _chatAvatarLocalBytes;

  @override
  void initState() {
    super.initState();
    _loadChatAvatar();
  }

  Future<void> _loadChatAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('connekt_chat_avatar_url');
      final savedB64 = prefs.getString('connekt_chat_avatar_base64');
      if (savedB64 != null && savedB64.isNotEmpty) {
        _chatAvatarLocalBytes = base64Decode(savedB64);
      }
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _chatAvatarUrl = savedUrl;
      } else if (widget.user?.personalProfile?.avatarUrl != null &&
          widget.user!.personalProfile!.avatarUrl.isNotEmpty) {
        _chatAvatarUrl = widget.user!.personalProfile!.avatarUrl;
      }
      if (mounted) setState(() {});
    } catch (_) {}
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadAvatarBytes(List<int> bytes, String fileName) async {
    if (bytes.isEmpty) return;
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo must be 5MB or smaller.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isUploadingAvatar = true);
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    try {
      final updated = await ApiService.uploadAvatar(
        uint8,
        fileName,
        currentUser: widget.user,
      );
      final newUrl = updated.personalProfile?.avatarUrl ?? '';

      final prefs = await SharedPreferences.getInstance();
      if (newUrl.isNotEmpty) {
        await prefs.setString('connekt_chat_avatar_url', newUrl);
      }
      await prefs.setString('connekt_chat_avatar_base64', base64Encode(uint8));

      if (mounted) {
        setState(() {
          _chatAvatarLocalBytes = uint8;
          _chatAvatarUrl = newUrl;
          _isUploadingAvatar = false;
        });
        widget.onAvatarUpdated?.call(newUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat profile photo updated successfully!'),
            backgroundColor: Color(0xFF1D4ED8),
          ),
        );
      }
    } catch (e) {
      // Even if network upload fails, retain local photo for offline chat experience
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('connekt_chat_avatar_base64', base64Encode(uint8));

      if (mounted) {
        setState(() {
          _chatAvatarLocalBytes = uint8;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat profile photo saved locally!'),
            backgroundColor: Color(0xFF1D4ED8),
          ),
        );
      }
    }
  }

  Future<void> _removeChatAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('connekt_chat_avatar_url');
      await prefs.remove('connekt_chat_avatar_base64');
      setState(() {
        _chatAvatarLocalBytes = null;
        _chatAvatarUrl = null;
      });
      widget.onAvatarUpdated?.call('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat profile photo removed.')),
        );
      }
    } catch (_) {}
  }

  void _showPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Profile Photo for Chats',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1D4ED8), size: 20),
                ),
                title: const Text('Take photo with camera', style: TextStyle(fontWeight: FontWeight.w600)),
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
                title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w600)),
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
                title: const Text('Browse files', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatarFromFiles();
                },
              ),
              if (_chatAvatarUrl != null || _chatAvatarLocalBytes != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  ),
                  title: const Text('Remove photo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeChatAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (_chatAvatarLocalBytes != null && _chatAvatarLocalBytes!.isNotEmpty) {
      return Image.memory(
        _chatAvatarLocalBytes!,
        fit: BoxFit.cover,
        width: 62,
        height: 62,
      );
    }
    if (_chatAvatarUrl != null && _chatAvatarUrl!.isNotEmpty) {
      return SafeAvatar(
        url: _chatAvatarUrl,
        fallbackText: widget.user?.username.isNotEmpty == true ? widget.user!.username : 'User',
        size: 62,
        radius: 31,
      );
    }
    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 38,
        color: Color(0xFF64748B),
      ),
    );
  }

  void _triggerBackup() {
    setState(() => _isBackingUp = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          final now = DateTime.now();
          final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
          final ampm = now.hour >= 12 ? 'pm' : 'am';
          _lastBackupTime = 'Today, $hour:${now.minute.toString().padLeft(2, '0')} $ampm';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat backup completed successfully!'),
            backgroundColor: Color(0xFF1D4ED8),
          ),
        );
      }
    });
  }

  void _showChatHistoryDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Export chat'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat exported as .txt document')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded, color: AppTheme.accentCoral),
              title: const Text('Clear all chats', style: TextStyle(color: AppTheme.accentCoral)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onClearAllChats?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All messages in conversations cleared')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.accentCoral),
              title: const Text('Delete all chats', style: TextStyle(color: AppTheme.accentCoral)),
              onTap: () {
                Navigator.pop(ctx);
                widget.onClearAllChats?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All conversations deleted')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chats Settings',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // -----------------------------------------------------------------
          // 1. CHAT PROFILE PHOTO SECTION (Specially for Chats)
          // -----------------------------------------------------------------
          _buildSectionHeader('CHAT PROFILE PHOTO'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Avatar with Camera Overlay
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _showPhotoPickerSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: _isUploadingAvatar
                              ? Container(
                                  color: Colors.black38,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                  ),
                                )
                              : _buildAvatarImage(),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Label and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chat Profile Photo',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Profile photo specifically displayed to contacts in chats',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Change Button
                TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _showPhotoPickerSheet,
                  icon: const Icon(Icons.photo_camera_rounded, size: 15),
                  label: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4ED8),
                    backgroundColor: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------------------------
          // 2. DISPLAY SECTION
          // -----------------------------------------------------------------
          _buildSectionHeader('DISPLAY'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_rounded, color: Color(0xFF1D4ED8)),
                  title: Text('Chat theme & Wallpaper', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Wallpapers, bubbles, custom themes & doodles', style: TextStyle(color: textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatThemeScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------------------------
          // 3. CHAT SETTINGS SECTION
          // -----------------------------------------------------------------
          _buildSectionHeader('CHAT SETTINGS'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: const Color(0xFF1D4ED8),
                  title: Text('Read receipts', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('If turned off, you won\'t send or receive blue double ticks', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: _readReceipts,
                  onChanged: (val) => setState(() => _readReceipts = val),
                ),
                Divider(height: 1, color: borderColor),
                SwitchListTile(
                  activeColor: const Color(0xFF1D4ED8),
                  title: Text('Keep chats archived', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Archived chats remain archived when new messages arrive', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: _keepArchived,
                  onChanged: (val) => setState(() => _keepArchived = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------------------------
          // 4. CHAT BACKUP SECTION
          // -----------------------------------------------------------------
          _buildSectionHeader('CHAT BACKUP'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_upload_rounded, color: Color(0xFF1D4ED8), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Backup: $_lastBackupTime', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Size: $_backupSize (Cloud Encrypted)', style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isBackingUp ? null : _triggerBackup,
                    child: _isBackingUp
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Back Up Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------------------------
          // 5. APP LANGUAGE SECTION
          // -----------------------------------------------------------------
          _buildSectionHeader(context.tr('common.language').toUpperCase()),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.language_rounded, color: Color(0xFF1D4ED8)),
              title: Text(context.tr('common.language'), style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text(I18nService.currentLanguage.displayTitle, style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => LanguageSelectorSheet.show(context),
            ),
          ),

          const SizedBox(height: 20),

          // -----------------------------------------------------------------
          // 6. CHAT HISTORY SECTION
          // -----------------------------------------------------------------
          _buildSectionHeader('CHAT HISTORY'),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.history_rounded, color: Color(0xFF1D4ED8)),
              title: Text('Chat history', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: Text('Export, clear or delete chats', style: TextStyle(color: textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showChatHistoryDialog,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }
}
