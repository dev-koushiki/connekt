import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/mail_models.dart';
import '../../i18n/app_localizations.dart';
import '../language_selector_sheet.dart';

class MailDrawer extends StatelessWidget {
  final String userEmail;
  final String selectedView; // 'inbox', 'primary', 'social', 'promotions', 'starred', 'snoozed', 'important', 'sent', 'scheduled', 'drafts', 'all', 'spam', 'trash', or 'label:<name>'
  final List<MailMessage> allMessages;
  final List<MailLabel> labels;
  final ValueChanged<String> onSelectView;
  final VoidCallback onCreateLabel;
  final ValueChanged<MailLabel> onDeleteLabel;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenContacts;
  final VoidCallback? onBackToHome;
  final bool isBottomSheet;

  const MailDrawer({
    super.key,
    required this.userEmail,
    required this.selectedView,
    required this.allMessages,
    required this.labels,
    required this.onSelectView,
    required this.onCreateLabel,
    required this.onDeleteLabel,
    required this.onOpenSettings,
    this.onOpenContacts,
    this.onBackToHome,
    this.isBottomSheet = false,
  });

  /// Displays the Mail folders and labels as a bottom sheet sliding up from the bottom
  static Future<void> showAsBottomSheet({
    required BuildContext context,
    required String userEmail,
    required String selectedView,
    required List<MailMessage> allMessages,
    required List<MailLabel> labels,
    required ValueChanged<String> onSelectView,
    required VoidCallback onCreateLabel,
    required ValueChanged<MailLabel> onDeleteLabel,
    required VoidCallback onOpenSettings,
    VoidCallback? onOpenContacts,
    VoidCallback? onBackToHome,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: MailDrawer(
            userEmail: userEmail,
            selectedView: selectedView,
            allMessages: allMessages,
            labels: labels,
            onSelectView: onSelectView,
            onCreateLabel: onCreateLabel,
            onDeleteLabel: onDeleteLabel,
            onOpenSettings: onOpenSettings,
            onOpenContacts: onOpenContacts,
            onBackToHome: onBackToHome,
            isBottomSheet: true,
          ),
        );
      },
    );
  }

  int _countForView(String key) {
    switch (key) {
      case 'inbox':
        return allMessages.where((m) => m.folder == 'inbox').length;
      case 'primary':
      case 'social':
      case 'updates':
      case 'forums':
        return allMessages.where((m) => m.folder == 'inbox' && m.category == key).length;
      case 'starred':
        return allMessages.where((m) => m.folder != 'trash' && m.folder != 'spam' && m.isStarred).length;
      case 'snoozed':
        return allMessages.where((m) => m.folder == 'snoozed').length;
      case 'important':
        return allMessages.where((m) => m.folder != 'trash' && m.folder != 'spam' && m.isImportant).length;
      case 'sent':
        return allMessages.where((m) => m.folder == 'sent').length;
      case 'scheduled':
        return allMessages.where((m) => m.folder == 'scheduled').length;
      case 'drafts':
        return allMessages.where((m) => m.folder == 'drafts').length;
      case 'spam':
        return allMessages.where((m) => m.folder == 'spam').length;
      case 'trash':
        return allMessages.where((m) => m.folder == 'trash').length;
      default:
        if (key.startsWith('label:')) {
          final labelName = key.substring(6);
          return allMessages.where((m) => m.folder != 'trash' && m.labels.contains(labelName)).length;
        }
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final bgColor = isDark ? const Color(0xFF0E1422) : Colors.white;
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);

    final content = SafeArea(
      top: !isBottomSheet,
      child: Column(
        children: [
          if (isBottomSheet) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.mail_rounded, color: AppTheme.brandBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connekt Mail',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      if (isBottomSheet)
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),

            _drawerItem(
              context,
              keyId: 'inbox',
              icon: Icons.all_inbox_rounded,
              label: context.tr('mails.inbox'),
              count: _countForView('inbox'),
              highlightBadge: true,
            ),
            _drawerItem(
              context,
              keyId: 'primary',
              icon: Icons.inbox_rounded,
              label: context.tr('mails.primary'),
              count: _countForView('primary'),
              highlightBadge: true,
            ),
            _drawerItem(
              context,
              keyId: 'social',
              icon: Icons.people_outline_rounded,
              label: context.tr('mails.social'),
              count: _countForView('social'),
            ),
            _drawerItem(
              context,
              keyId: 'updates',
              icon: Icons.info_outline_rounded,
              label: 'Updates',
              count: _countForView('updates'),
            ),
            _drawerItem(
              context,
              keyId: 'forums',
              icon: Icons.forum_outlined,
              label: 'Forums',
              count: _countForView('forums'),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                'ALL LABELS',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            _drawerItem(context, keyId: 'starred', icon: Icons.star_border_rounded, label: context.tr('mails.starred'), count: _countForView('starred')),
            _drawerItem(context, keyId: 'snoozed', icon: Icons.schedule_rounded, label: 'Snoozed', count: _countForView('snoozed')),
            _drawerItem(context, keyId: 'important', icon: Icons.label_important_outline_rounded, label: 'Important', count: _countForView('important')),
            _drawerItem(context, keyId: 'sent', icon: Icons.send_outlined, label: context.tr('mails.sent'), count: _countForView('sent')),
            _drawerItem(context, keyId: 'scheduled', icon: Icons.schedule_send_outlined, label: 'Scheduled', count: _countForView('scheduled')),
            _drawerItem(context, keyId: 'drafts', icon: Icons.insert_drive_file_outlined, label: context.tr('mails.drafts'), count: _countForView('drafts')),
            _drawerItem(context, keyId: 'all', icon: Icons.mail_outline_rounded, label: 'All mail'),
            _drawerItem(context, keyId: 'spam', icon: Icons.report_gmailerrorred_outlined, label: context.tr('mails.spam'), count: _countForView('spam')),
            _drawerItem(context, keyId: 'trash', icon: Icons.delete_outline_rounded, label: context.tr('mails.trash'), count: _countForView('trash')),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'CUSTOM LABELS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onCreateLabel();
                    },
                    icon: const Icon(Icons.add, size: 16, color: AppTheme.brandBlue),
                    label: const Text(
                      'Create new',
                      style: TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),
            ...labels.map((lbl) {
              final viewKey = 'label:${lbl.name}';
              final count = _countForView(viewKey);
              final isSelected = selectedView == viewKey;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  selected: isSelected,
                  selectedTileColor: AppTheme.brandBlue.withValues(alpha: 0.14),
                  leading: Icon(Icons.label_outline_rounded, color: lbl.color, size: 20),
                  title: Text(
                    lbl.name,
                    style: TextStyle(
                      color: isSelected ? AppTheme.brandBlue : textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count > 0)
                        Text(
                          '$count',
                          style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      IconButton(
                        icon: Icon(Icons.close, size: 15, color: textSecondary),
                        tooltip: 'Delete label',
                        onPressed: () => onDeleteLabel(lbl),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onSelectView(viewKey);
                  },
                ),
              );
            }),

            const Divider(height: 24),
            if (onOpenContacts != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  leading: Icon(Icons.contacts_outlined, color: textSecondary, size: 20),
                  title: Text('Mail Contacts', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenContacts!();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                leading: Icon(Icons.translate_rounded, color: textSecondary, size: 20),
                title: Text(context.tr('common.select_language'), style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  LanguageSelectorSheet.show(context);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                leading: Icon(Icons.settings_outlined, color: textSecondary, size: 20),
                title: Text('Mail Settings & Signature', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  onOpenSettings();
                },
              ),
            ),
            if (onBackToHome != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  leading: Icon(Icons.home_outlined, color: textSecondary, size: 20),
                  title: Text('Back to Home', style: TextStyle(color: textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    onBackToHome!();
                  },
                ),
              ),
          ],
        ),
      ),
    ],
  ),
);

    if (isBottomSheet) {
      return Material(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: content,
      );
    }

    return Drawer(
      backgroundColor: bgColor,
      child: content,
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required String keyId,
    required IconData icon,
    required String label,
    int count = 0,
    bool highlightBadge = false,
  }) {
    final isSelected = selectedView == keyId;
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        selected: isSelected,
        selectedTileColor: AppTheme.brandBlue.withValues(alpha: 0.14),
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppTheme.brandBlue : textSecondary,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.brandBlue : textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13.5,
          ),
        ),
        trailing: count > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: highlightBadge
                    ? BoxDecoration(
                        color: AppTheme.brandBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: isSelected || highlightBadge ? AppTheme.brandBlue : textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          onSelectView(keyId);
        },
      ),
    );
  }
}
