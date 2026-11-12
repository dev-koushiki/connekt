import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/mail_models.dart';

class MailSettingsSheet extends StatefulWidget {
  final MailSettings settings;
  final ValueChanged<MailSettings> onSave;

  const MailSettingsSheet({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<MailSettingsSheet> createState() => _MailSettingsSheetState();
}

class _MailSettingsSheetState extends State<MailSettingsSheet> {
  late bool _conversationView;
  late bool _compactDensity;
  late bool _signatureEnabled;
  late bool _vacationEnabled;
  late String _rightSwipe;
  late String _leftSwipe;
  late TextEditingController _sigCtrl;
  late TextEditingController _vacSubjectCtrl;
  late TextEditingController _vacBodyCtrl;

  static const _swipeOptions = [
    {'id': 'archive', 'label': 'Archive'},
    {'id': 'delete', 'label': 'Move to Trash'},
    {'id': 'mark_read', 'label': 'Mark read / unread'},
    {'id': 'snooze', 'label': 'Snooze'},
    {'id': 'none', 'label': 'None'},
  ];

  @override
  void initState() {
    super.initState();
    _conversationView = widget.settings.conversationView;
    _compactDensity = widget.settings.compactDensity;
    _signatureEnabled = widget.settings.signatureEnabled;
    _vacationEnabled = widget.settings.vacationEnabled;
    _rightSwipe = widget.settings.rightSwipeAction;
    _leftSwipe = widget.settings.leftSwipeAction;
    _sigCtrl = TextEditingController(text: widget.settings.signature);
    _vacSubjectCtrl = TextEditingController(text: widget.settings.vacationSubject);
    _vacBodyCtrl = TextEditingController(text: widget.settings.vacationBody);
  }

  @override
  void dispose() {
    _sigCtrl.dispose();
    _vacSubjectCtrl.dispose();
    _vacBodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);

    return Material(
      color: bgColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.settings_rounded, color: AppTheme.brandBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mail Settings',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final updated = widget.settings.copyWith(
                      conversationView: _conversationView,
                      compactDensity: _compactDensity,
                      signatureEnabled: _signatureEnabled,
                      signature: _sigCtrl.text.trim(),
                      vacationEnabled: _vacationEnabled,
                      vacationSubject: _vacSubjectCtrl.text.trim(),
                      vacationBody: _vacBodyCtrl.text.trim(),
                      rightSwipeAction: _rightSwipe,
                      leftSwipeAction: _leftSwipe,
                    );
                    widget.onSave(updated);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'GENERAL',
                  style: TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.brandBlue,
                  title: Text('Conversation view', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Group emails with the same subject into threads', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: _conversationView,
                  onChanged: (v) => setState(() => _conversationView = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.brandBlue,
                  title: Text('Compact list density', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Show more emails per screen', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: _compactDensity,
                  onChanged: (v) => setState(() => _compactDensity = v),
                ),

                const Divider(height: 24),
                Text(
                  'SWIPE ACTIONS',
                  style: TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9),
                ),
                const SizedBox(height: 10),
                _buildSwipeDropdown(
                  label: 'Right swipe',
                  value: _rightSwipe,
                  textPrimary: textPrimary,
                  onChanged: (val) => setState(() => _rightSwipe = val ?? 'archive'),
                ),
                const SizedBox(height: 12),
                _buildSwipeDropdown(
                  label: 'Left swipe',
                  value: _leftSwipe,
                  textPrimary: textPrimary,
                  onChanged: (val) => setState(() => _leftSwipe = val ?? 'delete'),
                ),

                const Divider(height: 28),
                Text(
                  'MOBILE SIGNATURE',
                  style: TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.brandBlue,
                  title: Text('Append signature to sent emails', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  value: _signatureEnabled,
                  onChanged: (v) => setState(() => _signatureEnabled = v),
                ),
                TextField(
                  controller: _sigCtrl,
                  maxLines: 3,
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: const InputDecoration(
                    hintText: 'Sent from Connekt Mail\nBest regards, ...',
                  ),
                ),

                const Divider(height: 28),
                Text(
                  'VACATION RESPONDER (OUT OF OFFICE)',
                  style: TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppTheme.brandBlue,
                  title: Text('Auto-reply when away', style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('Automatically replies to incoming Connekt messages', style: TextStyle(color: textSecondary, fontSize: 12)),
                  value: _vacationEnabled,
                  onChanged: (v) => setState(() => _vacationEnabled = v),
                ),
                if (_vacationEnabled) ...[
                  TextField(
                    controller: _vacSubjectCtrl,
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                    decoration: const InputDecoration(labelText: 'Auto-reply Subject'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _vacBodyCtrl,
                    maxLines: 3,
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                    decoration: const InputDecoration(labelText: 'Out of Office Message'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildSwipeDropdown({
    required String label,
    required String value,
    required Color textPrimary,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        DropdownButton<String>(
          value: _swipeOptions.any((o) => o['id'] == value) ? value : 'archive',
          onChanged: onChanged,
          items: _swipeOptions
              .map(
                (opt) => DropdownMenuItem<String>(
                  value: opt['id'],
                  child: Text(opt['label']!),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
