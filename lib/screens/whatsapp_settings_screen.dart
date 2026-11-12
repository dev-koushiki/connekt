import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class WhatsAppSettingsScreen extends StatefulWidget {
  final VoidCallback? onClearAllChats;

  const WhatsAppSettingsScreen({super.key, this.onClearAllChats});

  @override
  State<WhatsAppSettingsScreen> createState() => _WhatsAppSettingsScreenState();
}

class _WhatsAppSettingsScreenState extends State<WhatsAppSettingsScreen> {
  bool _readReceipts = true;
  bool _keepArchived = true;
  bool _isBackingUp = false;
  String _lastBackupTime = 'Today, 2:00 am';
  final String _backupSize = '14.2 MB';

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

  void _showWallpaperPicker() {
    final colors = [
      const Color(0xFF0F172A), // Slate
      const Color(0xFF1E3A8A), // Blue
      const Color(0xFF064E3B), // Emerald
      const Color(0xFF701A75), // Fuchsia
      const Color(0xFF451A03), // Brown
      const Color(0xFF18181B), // Dark Zinc
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Chat Wallpaper',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wallpaper updated!')),
                    );
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          // Display Section
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
                  leading: const Icon(Icons.wallpaper_rounded, color: Color(0xFF1D4ED8)),
                  title: Text('Wallpaper', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Change chat background color & doodles', style: TextStyle(color: textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showWallpaperPicker,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Chat Settings Section
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

          // Backup Section
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

          // Chat History Section
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
