import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/mail_models.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/call_log_service.dart';
import '../services/mail_service.dart';
import '../widgets/mail/mail_compose_sheet.dart';
import '../widgets/mail/mail_drawer.dart';
import '../widgets/mail/mail_settings_sheet.dart';
import '../widgets/mail/mail_thread_screen.dart';
import '../widgets/safe_avatar.dart';

class MailScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onBackToHome;

  const MailScreen({super.key, this.user, this.onBackToHome});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<MailMessage> _messages = [];
  List<MailLabel> _labels = MailService.defaultLabels();
  List<MailTemplate> _templates = [];
  List<MailContact> _contacts = [];
  MailSettings _settings = const MailSettings();
  MailExternalStatus _externalStatus = const MailExternalStatus();
  List<String> _knownContacts = [];

  String _selectedView = 'primary'; // primary, social, promotions, updates, forums, inbox, starred, snoozed, important, sent, scheduled, drafts, all, spam, trash, label:<name>
  String _sortBy = 'newest'; // newest, oldest, unread, sender
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSyncing = false;
  final Set<String> _selectedThreadIds = {};
  final Set<String> _quickOperators = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
    _initMailbox();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _userEmail {
    if (widget.user?.email.isNotEmpty == true) return widget.user!.email;
    return '${widget.user?.username ?? "user"}@connekt.net.in';
  }

  String get _userDisplayName {
    if (widget.user?.personalProfile?.fullName.isNotEmpty == true) {
      return widget.user!.personalProfile!.fullName;
    }
    return widget.user?.username ?? 'Connekt User';
  }

  Future<void> _initMailbox() async {
    // Load local cache instantly, then sync with server if available.
    final cached = await MailService.loadCachedOrSeed(widget.user);
    if (!mounted) return;
    setState(() {
      _messages = cached.messages;
      _labels = cached.labels;
      _templates = cached.templates;
      _contacts = cached.contacts;
      _settings = cached.settings;
      _isLoading = false;
    });
    await _refreshFromServer();
    unawaited(_loadKnownContacts());
  }

  Future<void> _refreshFromServer() async {
    setState(() => _isSyncing = true);
    try {
      await MailService.syncImapMailbox();
      final remote = await MailService.fetchWorkspace(widget.user);
      if (!mounted) return;
      setState(() {
        _messages = remote.messages;
        _labels = remote.labels;
        _templates = remote.templates;
        _contacts = remote.contacts;
        _settings = remote.settings;
        _externalStatus = remote.externalStatus;
      });
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _loadKnownContacts() async {
    final emails = <String>{};
    for (final m in _messages) {
      if (m.senderEmail.isNotEmpty && m.senderEmail != _userEmail) {
        emails.add(m.senderEmail);
      }
      for (final r in m.to) {
        if (r.isNotEmpty && r != _userEmail) emails.add(r);
      }
    }
    try {
      final apiContacts = await ApiService.getContacts();
      for (final c in apiContacts) {
        final e = (c['email'] ?? '').toString().trim();
        if (e.isNotEmpty) emails.add(e);
      }
    } catch (_) {}
    try {
      final phoneContacts = await CallLogService.fetchDeviceContacts(limit: 50);
      for (final c in phoneContacts) {
        final p = (c['phone'] ?? '').toString().trim();
        if (p.isNotEmpty) emails.add(p);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _knownContacts = emails.toList());
    }
  }

  Future<void> _persistLocalState() async {
    await MailService.saveCache(
      widget.user?.id,
      MailWorkspaceData(
        messages: _messages,
        labels: _labels,
        templates: _templates,
        contacts: _contacts,
        settings: _settings,
        externalStatus: _externalStatus,
      ),
    );
  }

  String get _effectiveSearchQuery {
    final parts = <String>[];
    if (_searchQuery.isNotEmpty) parts.add(_searchQuery);
    parts.addAll(_quickOperators);
    return parts.join(' ').trim();
  }

  bool _matchesSelectedView(MailMessage m) {
    if (_effectiveSearchQuery.isNotEmpty) {
      return m.folder != 'trash' && m.folder != 'spam';
    }
    switch (_selectedView) {
      case 'inbox':
        return m.folder == 'inbox';
      case 'primary':
      case 'social':
      case 'promotions':
      case 'updates':
      case 'forums':
        return m.folder == 'inbox' && m.category == _selectedView;
      case 'starred':
        return m.folder != 'trash' && m.folder != 'spam' && m.isStarred;
      case 'snoozed':
        return m.folder == 'snoozed';
      case 'important':
        return m.folder != 'trash' && m.folder != 'spam' && m.isImportant;
      case 'sent':
        return m.folder == 'sent';
      case 'scheduled':
        return m.folder == 'scheduled';
      case 'drafts':
        return m.folder == 'drafts';
      case 'spam':
        return m.folder == 'spam';
      case 'trash':
        return m.folder == 'trash';
      case 'all':
        return m.folder != 'trash' && m.folder != 'spam';
      default:
        if (_selectedView.startsWith('label:')) {
          final lbl = _selectedView.substring(6);
          return m.folder != 'trash' && m.labels.contains(lbl);
        }
        return m.folder == 'inbox';
    }
  }

  List<MailThread> get _visibleThreads {
    final q = _effectiveSearchQuery;
    final matching = _messages.where((m) {
      if (!_matchesSelectedView(m)) return false;
      if (q.isNotEmpty && !MailQueryFilter.matches(m, q)) return false;
      return true;
    }).toList();

    return MailQueryFilter.groupIntoThreads(
      matching,
      conversationView: _settings.conversationView,
      sortBy: _sortBy,
    );
  }

  int _mailCountForCategory(String cat) {
    final matching = _messages.where((m) {
      if (m.folder != 'inbox') return false;
      if (cat != 'inbox' && m.category != cat) return false;
      return true;
    }).toList();

    return _settings.conversationView
        ? MailQueryFilter.groupIntoThreads(matching, conversationView: true).length
        : matching.length;
  }

  String _viewTitle() {
    const titles = {
      'inbox': 'All Inboxes',
      'primary': 'Primary',
      'social': 'Social',
      'promotions': 'Promotions',
      'updates': 'Updates',
      'forums': 'Forums',
      'starred': 'Starred',
      'snoozed': 'Snoozed',
      'important': 'Important',
      'sent': 'Sent',
      'scheduled': 'Scheduled',
      'drafts': 'Drafts',
      'all': 'All Mail',
      'spam': 'Spam',
      'trash': 'Trash',
    };
    if (titles.containsKey(_selectedView)) return titles[_selectedView]!;
    if (_selectedView.startsWith('label:')) return _selectedView.substring(6);
    return 'Mail';
  }

  // ---------------------------------------------------------------------------
  // COMPOSE, REPLY, REPLY ALL, FORWARD, DRAFT EDITING
  // ---------------------------------------------------------------------------
  Future<void> _openCompose({
    String title = 'Compose',
    List<String> initialTo = const [],
    List<String> initialCc = const [],
    List<String> initialBcc = const [],
    String initialSubject = '',
    String initialBody = '',
    String? draftId,
    String? threadId,
    String? inReplyTo,
    List<MailAttachment> initialAttachments = const [],
  }) async {
    final result = await Navigator.of(context).push<MailComposeResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MailComposeSheet(
          fromEmail: _userEmail,
          title: title,
          initialTo: initialTo,
          initialCc: initialCc,
          initialBcc: initialBcc,
          initialSubject: initialSubject,
          initialBody: initialBody,
          draftId: draftId,
          threadId: threadId,
          inReplyTo: inReplyTo,
          initialAttachments: initialAttachments,
          knownContacts: {
            ..._knownContacts,
            ..._contacts.map((c) => c.email),
          }.toList(),
          templates: _templates,
          onSaveTemplate: (name, subject, body, htmlBody) async {
            final tpl = await MailService.saveTemplateOnServer(
              name: name,
              subject: subject,
              body: body,
              htmlBody: htmlBody,
            );
            if (tpl != null && mounted) {
              setState(() => _templates.insert(0, tpl));
              await _persistLocalState();
            }
            return tpl;
          },
          onDeleteTemplate: (id) async {
            setState(() => _templates.removeWhere((t) => t.id == id));
            await _persistLocalState();
            await MailService.deleteTemplateOnServer(id);
          },
          settings: _settings,
        ),
      ),
    );

    if (result == null || !mounted) return;

    if (result.action == 'discard') {
      if (result.draftId != null) {
        setState(() => _messages.removeWhere((m) => m.id == result.draftId));
        unawaited(MailService.syncBulkAction([result.draftId!], 'delete_forever'));
        await _persistLocalState();
      }
      _showSnack('Draft discarded');
      return;
    }

    final isDraft = result.action == 'draft';
    final isScheduled = !isDraft && result.scheduledAt != null && result.scheduledAt!.isAfter(DateTime.now());
    final targetFolder = isDraft ? 'drafts' : (isScheduled ? 'scheduled' : 'sent');
    final newId = result.draftId ?? 'mail_${DateTime.now().microsecondsSinceEpoch}';
    final newThreadId = result.threadId ?? 'thr_${DateTime.now().microsecondsSinceEpoch}';

    final localMsg = MailMessage(
      id: newId,
      threadId: newThreadId,
      inReplyTo: result.inReplyTo,
      senderName: _userDisplayName,
      senderEmail: _userEmail,
      to: result.to,
      cc: result.cc,
      bcc: result.bcc,
      subject: result.subject.isEmpty ? '(no subject)' : result.subject,
      body: result.body,
      snippet: MailMessage.makeSnippet(result.body),
      folder: targetFolder,
      originalFolder: targetFolder,
      attachments: result.attachments,
      isConfidential: result.isConfidential,
      confidentialExpiresAt: result.confidentialExpiresAt,
      scheduledAt: result.scheduledAt,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.removeWhere((m) => m.id == newId);
      _messages.insert(0, localMsg);
    });
    await _persistLocalState();

    // Sync to backend
    final serverSaved = await MailService.sendOrSaveDraft(
      user: widget.user,
      draftId: result.draftId,
      to: result.to,
      cc: result.cc,
      bcc: result.bcc,
      subject: result.subject,
      body: result.body,
      htmlBody: result.htmlBody,
      threadId: result.threadId,
      inReplyTo: result.inReplyTo,
      attachments: result.attachments,
      isDraft: isDraft,
      isConfidential: result.isConfidential,
      confidentialExpiresAt: result.confidentialExpiresAt,
      scheduledAt: result.scheduledAt,
    );
    if (serverSaved != null && mounted) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == newId);
        if (idx != -1) _messages[idx] = serverSaved;
      });
      await _persistLocalState();
    }

    if (isDraft) {
      _showSnack('Draft saved');
    } else if (isScheduled) {
      _showSnack('Message scheduled for ${MailMessage.formatFullDate(result.scheduledAt!)}');
    } else if (serverSaved?.deliveryStatus == 'pending_smtp_config') {
      _showSnack('Saved to Sent — external SMTP credentials not yet configured on server');
    } else if (serverSaved?.deliveryStatus == 'failed') {
      _showSnack('Saved to Sent, external delivery failed: ${serverSaved?.deliveryError ?? 'SMTP error'}');
    } else if (serverSaved?.deliveryStatus == 'sent_external') {
      _showSnack('Email delivered externally via SMTP');
    } else {
      _showSnack('Message sent');
    }
  }

  void _openReplyFlow(MailMessage msg, String mode) {
    final subj = msg.subject;
    if (mode == 'forward') {
      final fwdSubj = subj.toLowerCase().startsWith('fwd:') ? subj : 'Fwd: $subj';
      final quoted = '\n\n---------- Forwarded message ---------\n'
          'From: ${msg.senderName} <${msg.senderEmail}>\n'
          'Date: ${MailMessage.formatFullDate(msg.createdAt)}\n'
          'Subject: $subj\n\n${msg.body}';
      _openCompose(
        title: 'Forward',
        initialSubject: fwdSubj,
        initialBody: quoted,
        initialAttachments: msg.attachments,
      );
      return;
    }

    final replySubj = subj.toLowerCase().startsWith('re:') ? subj : 'Re: $subj';
    final selfLower = _userEmail.toLowerCase();
    final toList = <String>[
      if (msg.senderEmail.toLowerCase() != selfLower) msg.senderEmail else ...msg.to,
    ];
    final ccList = mode == 'reply_all'
        ? [
            ...msg.to.where((e) => e.toLowerCase() != selfLower && !toList.contains(e)),
            ...msg.cc.where((e) => e.toLowerCase() != selfLower && !toList.contains(e)),
          ]
        : <String>[];

    final quoted = '\n\nOn ${MailMessage.formatFullDate(msg.createdAt)}, ${msg.senderName} wrote:\n> ${msg.body.replaceAll('\n', '\n> ')}';
    _openCompose(
      title: mode == 'reply_all' ? 'Reply all' : 'Reply',
      initialTo: toList,
      initialCc: ccList,
      initialSubject: replySubj,
      initialBody: quoted,
      threadId: msg.threadId,
      inReplyTo: msg.id,
    );
  }

  Future<void> _sendQuickSmartReply(MailMessage msg, String replyBody) async {
    final selfLower = _userEmail.toLowerCase();
    final target = msg.senderEmail.toLowerCase() != selfLower
        ? [msg.senderEmail]
        : msg.to;
    final replySubj = msg.subject.toLowerCase().startsWith('re:') ? msg.subject : 'Re: ${msg.subject}';

    final localReply = MailMessage(
      id: 'mail_${DateTime.now().microsecondsSinceEpoch}',
      threadId: msg.threadId,
      inReplyTo: msg.id,
      senderName: _userDisplayName,
      senderEmail: _userEmail,
      to: target,
      subject: replySubj,
      body: replyBody,
      snippet: MailMessage.makeSnippet(replyBody),
      folder: 'sent',
      originalFolder: 'sent',
      createdAt: DateTime.now(),
    );

    setState(() => _messages.insert(0, localReply));
    await _persistLocalState();
    unawaited(
      MailService.sendOrSaveDraft(
        user: widget.user,
        to: target,
        subject: replySubj,
        body: replyBody,
        threadId: msg.threadId,
        inReplyTo: msg.id,
      ),
    );
    _showSnack('Reply sent');
  }

  // ---------------------------------------------------------------------------
  // MESSAGE / THREAD MUTATIONS + UNDO SNACKBAR
  // ---------------------------------------------------------------------------
  Future<void> _applyActionToIds(
    List<String> ids,
    String action, {
    DateTime? snoozedUntil,
    String? labelName,
    String? targetFolder,
    String? targetCategory,
    bool allowUndo = true,
  }) async {
    if (ids.isEmpty) return;
    final snapshot = [..._messages];

    setState(() {
      if (action == 'delete_forever') {
        _messages.removeWhere((m) => ids.contains(m.id));
      } else {
        _messages = _messages.map((m) {
          if (!ids.contains(m.id)) return m;
          switch (action) {
            case 'archive':
              return m.copyWith(folder: 'archive');
            case 'trash':
            case 'delete':
              return m.copyWith(folder: 'trash');
            case 'spam':
              return m.copyWith(folder: 'spam');
            case 'restore':
            case 'not_spam':
              return m.copyWith(folder: m.originalFolder.isNotEmpty ? m.originalFolder : 'inbox', clearSnooze: true);
            case 'mark_read':
              return m.copyWith(isUnread: false);
            case 'mark_unread':
              return m.copyWith(isUnread: true);
            case 'star':
              return m.copyWith(isStarred: true);
            case 'unstar':
              return m.copyWith(isStarred: false);
            case 'important':
              return m.copyWith(isImportant: !m.isImportant);
            case 'mute':
              return m.copyWith(isMuted: !m.isMuted);
            case 'snooze':
              return m.copyWith(
                folder: 'snoozed',
                snoozedUntil: snoozedUntil ?? DateTime.now().add(const Duration(hours: 4)),
              );
            case 'apply_label':
              if (labelName != null && !m.labels.contains(labelName)) {
                return m.copyWith(labels: [...m.labels, labelName]);
              }
              return m;
            case 'move':
              return m.copyWith(
                folder: targetFolder ?? m.folder,
                category: targetCategory ?? m.category,
              );
            default:
              return m;
          }
        }).toList();
      }
      _selectedThreadIds.clear();
    });

    await _persistLocalState();
    unawaited(
      MailService.syncBulkAction(
        ids,
        action,
        extra: {
          'snoozedUntil': ?snoozedUntil?.toIso8601String(),
          'label': ?labelName,
          'folder': ?targetFolder,
          'category': ?targetCategory,
        },
      ),
    );

    if (allowUndo && action != 'delete_forever') {
      final undoLabel = switch (action) {
        'archive' => 'Archived',
        'trash' || 'delete' => 'Moved to Trash',
        'spam' => 'Reported as spam',
        'snooze' => 'Snoozed',
        'mark_unread' => 'Marked as unread',
        _ => 'Updated',
      };
      _showUndoSnack(undoLabel, snapshot, ids);
    }
  }

  void _showUndoSnack(String message, List<MailMessage> previousState, List<String> ids) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.amberAccent,
          onPressed: () async {
            if (!mounted) return;
            setState(() => _messages = previousState);
            await _persistLocalState();
            unawaited(MailService.syncBulkAction(ids, 'restore'));
          },
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.brandBlue, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _showSnoozeSheet(List<String> ids) async {
    final now = DateTime.now();
    final laterToday = now.add(const Duration(hours: 4));
    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 8, 0);
    final nextWeek = DateTime(now.year, now.month, now.day + ((8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7), 8, 0);

    final until = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.schedule_rounded, color: AppTheme.brandBlue),
              title: Text('Snooze until...', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.wb_twilight_rounded),
              title: const Text('Later today'),
              trailing: Text(MailMessage.formatShortTime(laterToday)),
              onTap: () => Navigator.pop(ctx, laterToday),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Tomorrow morning (8:00 AM)'),
              trailing: Text(MailMessage.formatFullDate(tomorrowMorning)),
              onTap: () => Navigator.pop(ctx, tomorrowMorning),
            ),
            ListTile(
              leading: const Icon(Icons.next_week_outlined),
              title: const Text('Next week'),
              trailing: Text(MailMessage.formatFullDate(nextWeek)),
              onTap: () => Navigator.pop(ctx, nextWeek),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Pick date & time'),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: tomorrowMorning,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (d == null || !ctx.mounted) return;
                final t = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 8, minute: 0));
                if (t == null || !ctx.mounted) return;
                Navigator.pop(ctx, DateTime(d.year, d.month, d.day, t.hour, t.minute));
              },
            ),
          ],
        ),
      ),
    );

    if (until != null) {
      await _applyActionToIds(ids, 'snooze', snoozedUntil: until);
    }
  }

  Future<void> _showCreateLabelDialog() async {
    final nameCtrl = TextEditingController();
    String selectedColor = '#1D4ED8';
    const colors = ['#1D4ED8', '#059669', '#D97706', '#7C3AED', '#DC2626', '#0891B2'];

    final created = await showDialog<MailLabel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create new label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Label name', hintText: 'e.g. Invoices, Projects'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                children: colors.map((hex) {
                  final color = MailLabel(id: '', name: '', colorHex: hex).color;
                  final isSel = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setDlgState(() => selectedColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () {
                final clean = nameCtrl.text.trim();
                if (clean.isEmpty) return;
                Navigator.pop(
                  ctx,
                  MailLabel(id: 'lbl_${DateTime.now().millisecondsSinceEpoch}', name: clean, colorHex: selectedColor),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();

    if (created != null && mounted) {
      final serverLabel = await MailService.createLabelOnServer(created.name, created.colorHex);
      setState(() {
        _labels.removeWhere((l) => l.name.toLowerCase() == created.name.toLowerCase());
        _labels.add(serverLabel ?? created);
      });
      await _persistLocalState();
      _showSnack('Label "${created.name}" created');
    }
  }

  Future<void> _deleteLabel(MailLabel lbl) async {
    setState(() {
      _labels.removeWhere((l) => l.id == lbl.id || l.name == lbl.name);
      _messages = _messages.map((m) {
        if (!m.labels.contains(lbl.name)) return m;
        return m.copyWith(labels: m.labels.where((n) => n != lbl.name).toList());
      }).toList();
      if (_selectedView == 'label:${lbl.name}') _selectedView = 'primary';
    });
    await _persistLocalState();
    unawaited(MailService.deleteLabelOnServer(lbl.id));
    _showSnack('Label "${lbl.name}" removed');
  }

  Future<void> _openContactsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final textPrimary = AppTheme.getTextPrimary(ctx);
            final textSecondary = AppTheme.getTextSecondary(ctx);
            return SafeArea(
              child: DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (_, scrollCtrl) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.contacts_outlined, color: AppTheme.brandBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Mail Contacts (${_contacts.length})',
                                style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: const Text('Add'),
                            onPressed: () async {
                              final nameCtrl = TextEditingController();
                              final emailCtrl = TextEditingController();
                              final companyCtrl = TextEditingController();
                              final added = await showDialog<bool>(
                                context: ctx,
                                builder: (dCtx) => AlertDialog(
                                  title: const Text('Add Mail Contact'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                                      const SizedBox(height: 8),
                                      TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address')),
                                      const SizedBox(height: 8),
                                      TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company (optional)')),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
                                      onPressed: () => Navigator.pop(dCtx, true),
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                              if (added == true && emailCtrl.text.trim().contains('@')) {
                                final saved = await MailService.saveContactOnServer(
                                  name: nameCtrl.text.trim().isEmpty ? emailCtrl.text.trim().split('@').first : nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim().toLowerCase(),
                                  company: companyCtrl.text.trim(),
                                );
                                final item = saved ??
                                    MailContact(
                                      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                                      name: nameCtrl.text.trim().isEmpty ? emailCtrl.text.trim().split('@').first : nameCtrl.text.trim(),
                                      email: emailCtrl.text.trim().toLowerCase(),
                                      company: companyCtrl.text.trim(),
                                    );
                                setState(() {
                                  _contacts.removeWhere((c) => c.email == item.email);
                                  _contacts.add(item);
                                });
                                setSheetState(() {});
                                await _persistLocalState();
                              }
                              nameCtrl.dispose();
                              emailCtrl.dispose();
                              companyCtrl.dispose();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _contacts.isEmpty
                          ? Center(child: Text('No saved mail contacts yet.', style: TextStyle(color: textSecondary)))
                          : ListView.builder(
                              controller: scrollCtrl,
                              itemCount: _contacts.length,
                              itemBuilder: (_, i) {
                                final c = _contacts[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.14),
                                    child: Text(
                                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '@',
                                      style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(c.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    c.company.isNotEmpty ? '${c.email} • ${c.company}' : c.email,
                                    style: TextStyle(color: textSecondary, fontSize: 12.5),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.send_outlined, size: 19, color: AppTheme.brandBlue),
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _openCompose(initialTo: [c.email]);
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, size: 19, color: textSecondary),
                                        onPressed: () async {
                                          setState(() => _contacts.removeWhere((x) => x.id == c.id));
                                          setSheetState(() {});
                                          await _persistLocalState();
                                          await MailService.deleteContactOnServer(c.id);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
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

  Future<void> _openSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MailSettingsSheet(
        settings: _settings,
        onSave: (updated) async {
          setState(() => _settings = updated);
          await _persistLocalState();
          unawaited(MailService.syncSettings(updated));
          _showSnack('Mail settings saved');
        },
      ),
    );
  }

  Future<void> _handleOpenThread(MailThread thread) async {
    final latest = thread.latest;
    if (latest.folder == 'drafts') {
      await _openCompose(
        title: 'Edit Draft',
        initialTo: latest.to,
        initialCc: latest.cc,
        initialBcc: latest.bcc,
        initialSubject: latest.subject == '(no subject)' ? '' : latest.subject,
        initialBody: latest.body,
        draftId: latest.id,
        threadId: latest.threadId,
        initialAttachments: latest.attachments,
      );
      return;
    }

    if (thread.isUnread) {
      await _applyActionToIds(thread.messageIds, 'mark_read', allowUndo: false);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MailThreadScreen(
          thread: thread,
          selfEmail: _userEmail,
          availableLabels: _labels,
          onReplyAction: (msg, mode) => _openReplyFlow(msg, mode),
          onQuickSmartReply: _sendQuickSmartReply,
          onToggleStar: () => _applyActionToIds(
            [latest.id],
            thread.isStarred ? 'unstar' : 'star',
            allowUndo: false,
          ),
          onToggleImportant: () => _applyActionToIds([latest.id], 'important', allowUndo: false),
          onArchive: () => _applyActionToIds(thread.messageIds, 'archive'),
          onDelete: () => _applyActionToIds(
            thread.messageIds,
            latest.folder == 'trash' ? 'delete_forever' : 'trash',
          ),
          onMarkUnread: () => _applyActionToIds([latest.id], 'mark_unread', allowUndo: false),
          onToggleSpam: () => _applyActionToIds(
            thread.messageIds,
            latest.folder == 'spam' ? 'not_spam' : 'spam',
          ),
          onToggleMute: () => _applyActionToIds(thread.messageIds, 'mute', allowUndo: false),
          onSnooze: () => _showSnoozeSheet(thread.messageIds),
          onUpdateLabels: (nextLabels) async {
            setState(() {
              _messages = _messages.map((m) {
                if (!thread.messageIds.contains(m.id)) return m;
                return m.copyWith(labels: nextLabels);
              }).toList();
            });
            await _persistLocalState();
            for (final id in thread.messageIds) {
              unawaited(MailService.syncMessagePatch(id, {'labels': nextLabels}));
            }
          },
        ),
      ),
    );
  }

  Future<void> _executeSwipeAction(MailThread thread, String action) async {
    switch (action) {
      case 'archive':
        await _applyActionToIds(thread.messageIds, 'archive');
        break;
      case 'delete':
        await _applyActionToIds(
          thread.messageIds,
          thread.latest.folder == 'trash' ? 'delete_forever' : 'trash',
        );
        break;
      case 'mark_read':
        await _applyActionToIds(
          thread.messageIds,
          thread.isUnread ? 'mark_read' : 'mark_unread',
          allowUndo: false,
        );
        break;
      case 'snooze':
        await _showSnoozeSheet(thread.messageIds);
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    final threads = _visibleThreads;
    final inInboxGroup = ['inbox', 'primary', 'social', 'updates', 'forums'].contains(_selectedView) &&
        _effectiveSearchQuery.isEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: MailDrawer(
        userEmail: _userEmail,
        selectedView: _selectedView,
        allMessages: _messages,
        labels: _labels,
        onSelectView: (v) => setState(() {
          _selectedView = v;
          _selectedThreadIds.clear();
        }),
        onCreateLabel: _showCreateLabelDialog,
        onDeleteLabel: _deleteLabel,
        onOpenSettings: _openSettings,
        onOpenContacts: _openContactsSheet,
        onBackToHome: widget.onBackToHome,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        onPressed: () => _openCompose(),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Compose', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Contextual Multi-Select Bar OR Gmail Search Pill
            if (_selectedThreadIds.isNotEmpty)
              _buildSelectionAppBar(threads, textPrimary, cardColor)
            else
              _buildSearchTopBar(cardColor, borderColor, textPrimary, textSecondary),

            // Search Operator Chips when searching or any filter active
            if (_searchFocusNode.hasFocus || _searchQuery.isNotEmpty || _quickOperators.isNotEmpty)
              _buildSearchOperatorsBar(cardColor, borderColor, textSecondary),

            // Category Tabs in Inbox (Primary / Social / Promotions / All)
            if (inInboxGroup) _buildInboxCategoryTabs(cardColor, borderColor, textSecondary),

            // Vacation Responder / Folder Banners
            if (_settings.vacationEnabled) _buildVacationBanner(),
            if (_selectedView == 'trash' || _selectedView == 'spam')
              _buildEmptyFolderBanner(textSecondary, threads.isNotEmpty),

            // Active View Header Label
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  Text(
                    _effectiveSearchQuery.isNotEmpty ? 'SEARCH RESULTS' : _viewTitle().toUpperCase(),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const Spacer(),
                  if (_isSyncing)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandBlue),
                    )
                  else
                    Text(
                      '${threads.length} ${threads.length == 1 ? 'conversation' : 'conversations'}',
                      style: TextStyle(color: textSecondary, fontSize: 11.5),
                    ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Sort emails',
                    icon: Icon(Icons.sort_rounded, size: 18, color: textSecondary),
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'newest', child: Text('Sort: Newest first')),
                      PopupMenuItem(value: 'oldest', child: Text('Sort: Oldest first')),
                      PopupMenuItem(value: 'unread', child: Text('Sort: Unread first')),
                      PopupMenuItem(value: 'sender', child: Text('Sort: Sender A–Z')),
                    ],
                  ),
                ],
              ),
            ),

            // Threads List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.brandBlue))
                  : RefreshIndicator(
                      color: AppTheme.brandBlue,
                      onRefresh: _refreshFromServer,
                      child: threads.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.45,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.mark_email_read_outlined, size: 52, color: textSecondary.withValues(alpha: 0.5)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Nothing in ${_viewTitle()}',
                                          style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Emails matching this view will appear here.',
                                          style: TextStyle(color: textSecondary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.only(bottom: 84),
                              itemCount: threads.length,
                              itemBuilder: (context, index) =>
                                  _buildThreadTile(threads[index], cardColor, borderColor, textPrimary, textSecondary),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTopBar(Color cardColor, Color borderColor, Color textPrimary, Color textSecondary) {
    final userInitial = _userDisplayName.isNotEmpty ? _userDisplayName[0].toUpperCase() : 'U';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (widget.onBackToHome != null)
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 21),
                tooltip: 'Back to Home',
                onPressed: widget.onBackToHome,
              ),
            IconButton(
              icon: Icon(Icons.menu_rounded, color: textPrimary),
              tooltip: 'Open mail folders',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(color: textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search in mail',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14.5),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                onPressed: () => _searchController.clear(),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _openSettings,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.brandBlue,
                  child: SafeAvatar(
                    url: widget.user?.personalProfile?.avatarUrl,
                    fallbackText: userInitial,
                    size: 32,
                    radius: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionAppBar(List<MailThread> visibleThreads, Color textPrimary, Color cardColor) {
    final selectedIds = visibleThreads
        .where((t) => _selectedThreadIds.contains(t.threadId))
        .expand((t) => t.messageIds)
        .toList();
    final anyUnread = visibleThreads
        .where((t) => _selectedThreadIds.contains(t.threadId))
        .any((t) => t.isUnread);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: textPrimary),
            onPressed: () => setState(() => _selectedThreadIds.clear()),
          ),
          Text(
            '${_selectedThreadIds.length}',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.select_all_rounded, color: textPrimary),
            tooltip: 'Select all',
            onPressed: () => setState(() {
              _selectedThreadIds.addAll(visibleThreads.map((t) => t.threadId));
            }),
          ),
          IconButton(
            icon: Icon(Icons.archive_outlined, color: textPrimary),
            tooltip: 'Archive',
            onPressed: () => _applyActionToIds(selectedIds, 'archive'),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: textPrimary),
            tooltip: _selectedView == 'trash' ? 'Delete forever' : 'Trash',
            onPressed: () => _applyActionToIds(
              selectedIds,
              _selectedView == 'trash' ? 'delete_forever' : 'trash',
            ),
          ),
          IconButton(
            icon: Icon(
              anyUnread ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined,
              color: textPrimary,
            ),
            tooltip: anyUnread ? 'Mark read' : 'Mark unread',
            onPressed: () => _applyActionToIds(
              selectedIds,
              anyUnread ? 'mark_read' : 'mark_unread',
              allowUndo: false,
            ),
          ),
          IconButton(
            icon: Icon(Icons.schedule_rounded, color: textPrimary),
            tooltip: 'Snooze',
            onPressed: () => _showSnoozeSheet(selectedIds),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOperatorsBar(Color cardColor, Color borderColor, Color textSecondary) {
    const operators = [
      {'op': 'is:unread', 'label': 'Unread'},
      {'op': 'is:starred', 'label': 'Starred'},
      {'op': 'has:attachment', 'label': 'Has attachment'},
      {'op': 'is:important', 'label': 'Important'},
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: operators.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = operators[index];
          final op = item['op']!;
          final active = _quickOperators.contains(op);
          return FilterChip(
            label: Text(item['label']!, style: TextStyle(fontSize: 12, color: active ? Colors.white : textSecondary)),
            selected: active,
            selectedColor: AppTheme.brandBlue,
            backgroundColor: cardColor,
            side: BorderSide(color: active ? AppTheme.brandBlue : borderColor),
            onSelected: (v) {
              setState(() {
                if (v) {
                  _quickOperators.add(op);
                } else {
                  _quickOperators.remove(op);
                }
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildInboxCategoryTabs(Color cardColor, Color borderColor, Color textSecondary) {
    const categories = [
      {'id': 'primary', 'label': 'Primary', 'icon': Icons.inbox_rounded},
      {'id': 'social', 'label': 'Social', 'icon': Icons.people_outline_rounded},
      {'id': 'updates', 'label': 'Updates', 'icon': Icons.info_outline_rounded},
      {'id': 'forums', 'label': 'Forums', 'icon': Icons.forum_outlined},
      {'id': 'inbox', 'label': 'All', 'icon': Icons.all_inbox_rounded},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final cat = categories[index];
          final id = cat['id'] as String;
          final active = _selectedView == id;
          final count = _mailCountForCategory(id);
          return ChoiceChip(
            avatar: Icon(
              cat['icon'] as IconData,
              size: 16,
              color: active ? Colors.white : AppTheme.brandBlue,
            ),
            label: Text(
              count > 0 ? '${cat['label']} ($count)' : '${cat['label']}',
              style: TextStyle(
                color: active ? Colors.white : textSecondary,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            selected: active,
            selectedColor: AppTheme.brandBlue,
            backgroundColor: cardColor,
            side: BorderSide(color: active ? AppTheme.brandBlue : borderColor),
            onSelected: (_) => setState(() => _selectedView = id),
          );
        },
      ),
    );
  }

  Widget _buildVacationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access_outlined, color: AppTheme.accentAmber, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Vacation responder is on: "${_settings.vacationSubject}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _openSettings,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFolderBanner(Color textSecondary, bool hasItems) {
    final isTrash = _selectedView == 'trash';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: Row(
        children: [
          Icon(
            isTrash ? Icons.auto_delete_outlined : Icons.report_gmailerrorred_outlined,
            size: 18,
            color: AppTheme.accentCoral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isTrash ? 'Messages in Trash are deleted automatically.' : 'Spam messages are isolated from your Inbox.',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
          if (hasItems)
            TextButton(
              onPressed: () async {
                setState(() => _messages.removeWhere((m) => m.folder == _selectedView));
                await _persistLocalState();
                unawaited(MailService.syncEmptyFolder(_selectedView));
                _showSnack('${_viewTitle()} emptied');
              },
              child: Text(
                isTrash ? 'Empty Trash now' : 'Empty Spam now',
                style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThreadTile(
    MailThread thread,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final latest = thread.latest;
    final isSelected = _selectedThreadIds.contains(thread.threadId);
    final isUnread = thread.isUnread;
    final isDraft = latest.folder == 'drafts';
    final verticalPad = _settings.compactDensity ? 8.0 : 12.0;

    final canSwipeRight = _settings.rightSwipeAction != 'none';
    final canSwipeLeft = _settings.leftSwipeAction != 'none';
    final direction = canSwipeRight && canSwipeLeft
        ? DismissDirection.horizontal
        : canSwipeRight
            ? DismissDirection.startToEnd
            : canSwipeLeft
                ? DismissDirection.endToStart
                : DismissDirection.none;

    final rowContent = InkWell(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedThreadIds.remove(thread.threadId);
          } else {
            _selectedThreadIds.add(thread.threadId);
          }
        });
      },
      onTap: () {
        if (_selectedThreadIds.isNotEmpty) {
          setState(() {
            if (isSelected) {
              _selectedThreadIds.remove(thread.threadId);
            } else {
              _selectedThreadIds.add(thread.threadId);
            }
          });
          return;
        }
        _handleOpenThread(thread);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPad),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.brandBlue.withValues(alpha: 0.14)
              : (isUnread ? cardColor : Colors.transparent),
          border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.6))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tap avatar to toggle selection (like Gmail)
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedThreadIds.remove(thread.threadId);
                  } else {
                    _selectedThreadIds.add(thread.threadId);
                  }
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: isSelected
                    ? AppTheme.brandBlue
                    : AppTheme.brandBlue.withValues(alpha: 0.16),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : Text(
                        latest.senderName.isNotEmpty ? latest.senderName[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: AppTheme.brandBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (thread.isImportant) ...[
                        const Icon(Icons.label_important_rounded, size: 16, color: AppTheme.accentAmber),
                        const SizedBox(width: 4),
                      ],
                      if (isDraft) ...[
                        const Text(
                          'Draft',
                          style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        if (thread.messageCount > 1) const Text(' '),
                      ],
                      Expanded(
                        child: Text(
                          isDraft && thread.messageCount == 1
                              ? (latest.to.isEmpty ? '(No recipient)' : 'To: ${latest.to.join(', ')}')
                              : '${thread.participantsSummary(_userEmail)}${thread.messageCount > 1 ? ' ${thread.messageCount}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      if (thread.isConfidential)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.brandBlue),
                        ),
                      Text(
                        MailMessage.formatShortTime(latest.createdAt),
                        style: TextStyle(
                          color: isUnread ? AppTheme.brandBlue : textSecondary,
                          fontSize: 11.5,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.first.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread ? textPrimary : textSecondary,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          latest.snippet,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textSecondary, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _applyActionToIds(
                          [latest.id],
                          thread.isStarred ? 'unstar' : 'star',
                          allowUndo: false,
                        ),
                        child: Icon(
                          thread.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 20,
                          color: thread.isStarred ? AppTheme.accentAmber : textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (latest.folder == 'snoozed' && latest.snoozedUntil != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Snoozed until ${MailMessage.formatFullDate(latest.snoozedUntil!)}',
                        style: const TextStyle(color: AppTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (latest.folder == 'scheduled' && latest.scheduledAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Scheduled for ${MailMessage.formatFullDate(latest.scheduledAt!)}',
                        style: const TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (thread.hasAttachment || thread.labels.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...latest.attachments.take(2).map((att) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attachment_rounded, size: 13, color: AppTheme.brandBlue),
                                    const SizedBox(width: 4),
                                    Text(att.filename, style: TextStyle(color: textSecondary, fontSize: 11)),
                                  ],
                                ),
                              )),
                          ...thread.labels.take(3).map((lbl) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  lbl,
                                  style: const TextStyle(color: AppTheme.brandBlue, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (direction == DismissDirection.none) return rowContent;

    return Dismissible(
      key: ValueKey('mail_thread_${thread.threadId}_$_selectedView'),
      direction: direction,
      background: _buildSwipeBg(_settings.rightSwipeAction, Alignment.centerLeft),
      secondaryBackground: _buildSwipeBg(_settings.leftSwipeAction, Alignment.centerRight),
      confirmDismiss: (dir) async {
        final action = dir == DismissDirection.startToEnd
            ? _settings.rightSwipeAction
            : _settings.leftSwipeAction;
        if (action == 'mark_read') {
          await _executeSwipeAction(thread, action);
          return false;
        }
        return true;
      },
      onDismissed: (dir) {
        final action = dir == DismissDirection.startToEnd
            ? _settings.rightSwipeAction
            : _settings.leftSwipeAction;
        _executeSwipeAction(thread, action);
      },
      child: rowContent,
    );
  }

  Widget _buildSwipeBg(String action, Alignment alignment) {
    final Color bg;
    final IconData icon;
    switch (action) {
      case 'delete':
        bg = AppTheme.accentCoral;
        icon = Icons.delete_outline_rounded;
        break;
      case 'mark_read':
        bg = AppTheme.brandBlue;
        icon = Icons.mark_email_read_outlined;
        break;
      case 'snooze':
        bg = AppTheme.accentAmber;
        icon = Icons.schedule_rounded;
        break;
      default:
        bg = const Color(0xFF059669);
        icon = Icons.archive_outlined;
    }
    return Container(
      color: bg,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Icon(icon, color: Colors.white),
    );
  }
}
