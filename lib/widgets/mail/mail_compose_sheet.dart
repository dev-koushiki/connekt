import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/mail_models.dart';
import '../../services/mail_service.dart';

class MailComposeResult {
  final String action; // 'send', 'draft', 'discard'
  final String? draftId;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? htmlBody;
  final String? threadId;
  final String? inReplyTo;
  final List<MailAttachment> attachments;
  final bool isConfidential;
  final DateTime? confidentialExpiresAt;
  final DateTime? scheduledAt;

  const MailComposeResult({
    required this.action,
    this.draftId,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    required this.body,
    this.htmlBody,
    this.threadId,
    this.inReplyTo,
    this.attachments = const [],
    this.isConfidential = false,
    this.confidentialExpiresAt,
    this.scheduledAt,
  });
}

class MailComposeSheet extends StatefulWidget {
  final String fromEmail;
  final List<String> initialTo;
  final List<String> initialCc;
  final List<String> initialBcc;
  final String initialSubject;
  final String initialBody;
  final String? draftId;
  final String? threadId;
  final String? inReplyTo;
  final List<MailAttachment> initialAttachments;
  final List<String> knownContacts;
  final List<MailTemplate> templates;
  final Future<MailTemplate?> Function(String name, String subject, String body, String? htmlBody)? onSaveTemplate;
  final Future<void> Function(String templateId)? onDeleteTemplate;
  final MailSettings settings;
  final String title;

  const MailComposeSheet({
    super.key,
    required this.fromEmail,
    this.initialTo = const [],
    this.initialCc = const [],
    this.initialBcc = const [],
    this.initialSubject = '',
    this.initialBody = '',
    this.draftId,
    this.threadId,
    this.inReplyTo,
    this.initialAttachments = const [],
    this.knownContacts = const [],
    this.templates = const [],
    this.onSaveTemplate,
    this.onDeleteTemplate,
    this.settings = const MailSettings(),
    this.title = 'Compose',
  });

  @override
  State<MailComposeSheet> createState() => _MailComposeSheetState();
}

class _MailComposeSheetState extends State<MailComposeSheet> {
  late TextEditingController _toCtrl;
  late TextEditingController _ccCtrl;
  late TextEditingController _bccCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;

  final List<String> _toList = [];
  final List<String> _ccList = [];
  final List<String> _bccList = [];
  late List<MailAttachment> _attachments;

  bool _showCcBcc = false;
  bool _showFormatBar = true;
  bool _isUploading = false;
  bool _isConfidential = false;
  DateTime? _confidentialExpiresAt;
  String _toInput = '';
  late List<MailTemplate> _templates;

  String _toHtml(String rawText) {
    var html = rawText
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );
    html = html.replaceAllMapped(
      RegExp(r'_(.+?)_'),
      (m) => '<em>${m.group(1)}</em>',
    );
    html = html.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)'),
      (m) => '<a href="${m.group(2)}" target="_blank">${m.group(1)}</a>',
    );
    return '<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.5;">${html.replaceAll('\n', '<br>')}</div>';
  }

  Future<void> _insertHyperlinkDialog() async {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final inserted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Hyperlink'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Link Text (optional)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL (https://...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Insert'),
          ),
        ],
      ),
    );
    if (inserted == true && urlCtrl.text.trim().isNotEmpty) {
      final url = urlCtrl.text.trim();
      final label = labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : url;
      final snippet = '[$label]($url)';
      final sel = _bodyCtrl.selection;
      final text = _bodyCtrl.text;
      final start = sel.isValid && sel.start >= 0 ? sel.start : text.length;
      final end = sel.isValid && sel.end >= 0 ? sel.end : text.length;
      _bodyCtrl.text = text.replaceRange(start, end, snippet);
      _bodyCtrl.selection = TextSelection.collapsed(offset: start + snippet.length);
    }
    labelCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _openTemplatesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description_outlined, color: AppTheme.brandBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Email Templates', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Save Current'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _promptSaveTemplate();
                      },
                    ),
                  ],
                ),
                const Divider(),
                if (_templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No templates saved yet. Save your current draft as a reusable template.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._templates.map((tpl) => ListTile(
                        leading: const Icon(Icons.article_outlined, color: AppTheme.brandBlue),
                        title: Text(tpl.name, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        subtitle: Text(tpl.subject.isEmpty ? tpl.body : tpl.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: textSecondary, size: 18),
                          onPressed: () async {
                            setState(() => _templates.removeWhere((t) => t.id == tpl.id));
                            if (widget.onDeleteTemplate != null) {
                              await widget.onDeleteTemplate!(tpl.id);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                        onTap: () {
                          if (_subjectCtrl.text.trim().isEmpty && tpl.subject.isNotEmpty) {
                            _subjectCtrl.text = tpl.subject;
                          }
                          _bodyCtrl.text = tpl.body;
                          Navigator.pop(ctx);
                        },
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptSaveTemplate() async {
    final nameCtrl = TextEditingController(text: _subjectCtrl.text.trim());
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Email Template'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Template Name', hintText: 'e.g. Meeting Follow-up'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final body = _bodyCtrl.text;
      final html = _toHtml(body);
      MailTemplate? created;
      if (widget.onSaveTemplate != null) {
        created = await widget.onSaveTemplate!(nameCtrl.text.trim(), _subjectCtrl.text.trim(), body, html);
      }
      setState(() {
        _templates.insert(
          0,
          created ??
              MailTemplate(
                id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
                name: nameCtrl.text.trim(),
                subject: _subjectCtrl.text.trim(),
                body: body,
                htmlBody: html,
              ),
        );
      });
    }
    nameCtrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    _templates = List<MailTemplate>.from(widget.templates);
    _toList.addAll(widget.initialTo);
    _ccList.addAll(widget.initialCc);
    _bccList.addAll(widget.initialBcc);
    _showCcBcc = _ccList.isNotEmpty || _bccList.isNotEmpty;
    _attachments = [...widget.initialAttachments];

    _toCtrl = TextEditingController();
    _ccCtrl = TextEditingController();
    _bccCtrl = TextEditingController();
    _subjectCtrl = TextEditingController(text: widget.initialSubject);

    var initialText = widget.initialBody;
    if (widget.settings.signatureEnabled &&
        widget.settings.signature.trim().isNotEmpty &&
        !initialText.contains(widget.settings.signature.trim()) &&
        widget.draftId == null) {
      initialText = '${initialText.trimRight()}\n\n--\n${widget.settings.signature.trim()}';
    }
    _bodyCtrl = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _ccCtrl.dispose();
    _bccCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  List<String> _collectAddresses(List<String> chips, TextEditingController ctrl) {
    final result = [...chips];
    final extra = ctrl.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final e in extra) {
      if (!result.contains(e)) result.add(e);
    }
    return result;
  }

  void _commitInputChip(TextEditingController ctrl, List<String> target) {
    final val = ctrl.text.replaceAll(',', '').trim();
    if (val.isNotEmpty && !target.contains(val)) {
      setState(() {
        target.add(val);
        ctrl.clear();
        _toInput = '';
      });
    }
  }

  Future<void> _pickAttachments() async {
    setState(() => _isUploading = true);
    try {
      final files = await FilePicker.pickFiles();
      if (files.isEmpty) return;

      for (final file in files) {
        final bytes = await file.readAsBytes();
        final uploaded = await MailService.uploadAttachment(
          filename: file.name,
          bytes: bytes,
          filePath: file.path,
        );
        if (uploaded != null && mounted) {
          setState(() => _attachments.add(uploaded));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment error: $e'), backgroundColor: AppTheme.accentCoral),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _applyFormatting(String prefix, [String suffix = '']) {
    final sel = _bodyCtrl.selection;
    final text = _bodyCtrl.text;
    if (!sel.isValid) {
      _bodyCtrl.text = '$text$prefix$suffix';
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final replacement = '$prefix${selected.isEmpty ? 'text' : selected}$suffix';
    _bodyCtrl.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _submitSend({DateTime? scheduledAt}) {
    final finalTo = _collectAddresses(_toList, _toCtrl);
    final finalCc = _collectAddresses(_ccList, _ccCtrl);
    final finalBcc = _collectAddresses(_bccList, _bccCtrl);

    if (finalTo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one recipient'),
          backgroundColor: AppTheme.accentCoral,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      MailComposeResult(
        action: 'send',
        draftId: widget.draftId,
        to: finalTo,
        cc: finalCc,
        bcc: finalBcc,
        subject: _subjectCtrl.text.trim(),
        body: _bodyCtrl.text,
        htmlBody: _toHtml(_bodyCtrl.text),
        threadId: widget.threadId,
        inReplyTo: widget.inReplyTo,
        attachments: _attachments,
        isConfidential: _isConfidential,
        confidentialExpiresAt: _confidentialExpiresAt,
        scheduledAt: scheduledAt,
      ),
    );
  }

  void _handleClose() {
    final finalTo = _collectAddresses(_toList, _toCtrl);
    final hasContent = finalTo.isNotEmpty ||
        _subjectCtrl.text.trim().isNotEmpty ||
        _bodyCtrl.text.trim().isNotEmpty ||
        _attachments.isNotEmpty;

    if (!hasContent) {
      Navigator.pop(context);
      return;
    }

    Navigator.pop(
      context,
      MailComposeResult(
        action: 'draft',
        draftId: widget.draftId,
        to: finalTo,
        cc: _collectAddresses(_ccList, _ccCtrl),
        bcc: _collectAddresses(_bccList, _bccCtrl),
        subject: _subjectCtrl.text.trim(),
        body: _bodyCtrl.text,
        htmlBody: _toHtml(_bodyCtrl.text),
        threadId: widget.threadId,
        inReplyTo: widget.inReplyTo,
        attachments: _attachments,
        isConfidential: _isConfidential,
        confidentialExpiresAt: _confidentialExpiresAt,
      ),
    );
  }

  Future<void> _showScheduleSendSheet() async {
    final now = DateTime.now();
    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 8, 0);
    final thisAfternoon = now.hour < 13
        ? DateTime(now.year, now.month, now.day, 13, 0)
        : DateTime(now.year, now.month, now.day + 1, 13, 0);
    final nextMonday = DateTime(now.year, now.month, now.day + ((8 - now.weekday) % 7 == 0 ? 7 : (8 - now.weekday) % 7), 8, 0);

    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_send_rounded, color: AppTheme.brandBlue),
                    const SizedBox(width: 10),
                    Text('Schedule send', style: TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined, color: AppTheme.brandBlue),
                title: Text('Tomorrow morning', style: TextStyle(color: textPrimary)),
                trailing: Text(MailMessage.formatFullDate(tomorrowMorning), style: TextStyle(color: textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, tomorrowMorning),
              ),
              ListTile(
                leading: const Icon(Icons.light_mode_outlined, color: AppTheme.brandBlue),
                title: Text('This afternoon / Tomorrow 1 PM', style: TextStyle(color: textPrimary)),
                trailing: Text(MailMessage.formatFullDate(thisAfternoon), style: TextStyle(color: textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, thisAfternoon),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined, color: AppTheme.brandBlue),
                title: Text('Monday morning', style: TextStyle(color: textPrimary)),
                trailing: Text(MailMessage.formatFullDate(nextMonday), style: TextStyle(color: textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, nextMonday),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined, color: AppTheme.brandBlue),
                title: Text('Pick date & time', style: TextStyle(color: textPrimary)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: tomorrowMorning,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                  if (time == null || !ctx.mounted) return;
                  Navigator.pop(ctx, DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
            ],
          ),
        );
      },
    );

    if (chosen != null && mounted) {
      _submitSend(scheduledAt: chosen);
    }
  }

  Future<void> _showConfidentialDialog() async {
    int days = 7;
    final enabled = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_clock_outlined, color: AppTheme.brandBlue),
              SizedBox(width: 8),
              Text('Confidential mode'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recipients will not have the option to forward or copy this email after expiry.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: days,
                decoration: const InputDecoration(labelText: 'Set expiration'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Expires in 1 day')),
                  DropdownMenuItem(value: 7, child: Text('Expires in 1 week')),
                  DropdownMenuItem(value: 30, child: Text('Expires in 1 month')),
                ],
                onChanged: (v) => setDlgState(() => days = v ?? 7),
              ),
            ],
          ),
          actions: [
            if (_isConfidential)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isConfidential = false;
                    _confidentialExpiresAt = null;
                  });
                  Navigator.pop(ctx, false);
                },
                child: const Text('Turn off', style: TextStyle(color: AppTheme.accentCoral)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (enabled == true && mounted) {
      setState(() {
        _isConfidential = true;
        _confidentialExpiresAt = DateTime.now().add(Duration(days: days));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);

    final matchingSuggestions = _toInput.isEmpty
        ? const <String>[]
        : widget.knownContacts
            .where((c) => c.toLowerCase().contains(_toInput.toLowerCase()) && !_toList.contains(c))
            .take(4)
            .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
            onPressed: _handleClose,
          ),
          title: Text(
            widget.title,
            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.brandBlue),
                    )
                  : Icon(Icons.attach_file_rounded, color: textPrimary),
              tooltip: 'Attach file',
              onPressed: _isUploading ? null : _pickAttachments,
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppTheme.brandBlue),
              tooltip: 'Send',
              onPressed: _submitSend,
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: textPrimary),
              onSelected: (value) {
                switch (value) {
                  case 'schedule':
                    _showScheduleSendSheet();
                    break;
                  case 'confidential':
                    _showConfidentialDialog();
                    break;
                  case 'format':
                    setState(() => _showFormatBar = !_showFormatBar);
                    break;
                  case 'draft':
                    _handleClose();
                    break;
                  case 'discard':
                    Navigator.pop(
                      context,
                      MailComposeResult(
                        action: 'discard',
                        draftId: widget.draftId,
                        to: const [],
                        subject: '',
                        body: '',
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'schedule', child: ListTile(leading: Icon(Icons.schedule_send_outlined), title: Text('Schedule send'), contentPadding: EdgeInsets.zero, dense: true)),
                const PopupMenuItem(value: 'confidential', child: ListTile(leading: Icon(Icons.lock_clock_outlined), title: Text('Confidential mode'), contentPadding: EdgeInsets.zero, dense: true)),
                const PopupMenuItem(value: 'format', child: ListTile(leading: Icon(Icons.format_color_text_rounded), title: Text('Formatting options'), contentPadding: EdgeInsets.zero, dense: true)),
                const PopupMenuItem(value: 'draft', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('Save draft'), contentPadding: EdgeInsets.zero, dense: true)),
                const PopupMenuItem(value: 'discard', child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral), title: Text('Discard', style: TextStyle(color: AppTheme.accentCoral)), contentPadding: EdgeInsets.zero, dense: true)),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // From Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 52, child: Text('From', style: TextStyle(color: textSecondary, fontSize: 14))),
                        Expanded(
                          child: Text(widget.fromEmail, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: borderColor),

                  // To Field
                  _buildRecipientRow(
                    label: 'To',
                    chips: _toList,
                    ctrl: _toCtrl,
                    onChanged: (v) {
                      if (v.endsWith(',') || v.endsWith(' ')) {
                        _commitInputChip(_toCtrl, _toList);
                      } else {
                        setState(() => _toInput = v.trim());
                      }
                    },
                    onSubmitted: (_) => _commitInputChip(_toCtrl, _toList),
                    trailing: IconButton(
                      icon: Icon(_showCcBcc ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: textSecondary),
                      onPressed: () => setState(() => _showCcBcc = !_showCcBcc),
                    ),
                  ),
                  if (matchingSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.getCardColor(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: matchingSuggestions
                            .map((s) => ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.brandBlue),
                                  title: Text(s, style: TextStyle(color: textPrimary, fontSize: 13.5)),
                                  onTap: () {
                                    setState(() {
                                      _toList.add(s);
                                      _toCtrl.clear();
                                      _toInput = '';
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  Divider(height: 1, color: borderColor),

                  if (_showCcBcc) ...[
                    _buildRecipientRow(
                      label: 'Cc',
                      chips: _ccList,
                      ctrl: _ccCtrl,
                      onChanged: (v) {
                        if (v.endsWith(',') || v.endsWith(' ')) _commitInputChip(_ccCtrl, _ccList);
                      },
                      onSubmitted: (_) => _commitInputChip(_ccCtrl, _ccList),
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildRecipientRow(
                      label: 'Bcc',
                      chips: _bccList,
                      ctrl: _bccCtrl,
                      onChanged: (v) {
                        if (v.endsWith(',') || v.endsWith(' ')) _commitInputChip(_bccCtrl, _bccList);
                      },
                      onSubmitted: (_) => _commitInputChip(_bccCtrl, _bccList),
                    ),
                    Divider(height: 1, color: borderColor),
                  ],

                  // Subject Field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      controller: _subjectCtrl,
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Subject',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: borderColor),

                  if (_isConfidential && _confidentialExpiresAt != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock_outlined, color: AppTheme.brandBlue, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Confidential: expires ${MailMessage.formatShortTime(_confidentialExpiresAt!)}',
                              style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _showConfidentialDialog,
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                    ),

                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _attachments.map((att) {
                          return Chip(
                            avatar: const Icon(Icons.insert_drive_file_outlined, size: 16, color: AppTheme.brandBlue),
                            label: Text('${att.filename} (${att.formattedSize})', style: const TextStyle(fontSize: 12)),
                            onDeleted: () => setState(() => _attachments.remove(att)),
                          );
                        }).toList(),
                      ),
                    ),

                  // Body Editor
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      minLines: 12,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        hintText: 'Compose email',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_showFormatBar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.getCardColor(context),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.format_bold_rounded),
                      tooltip: 'Bold',
                      onPressed: () => _applyFormatting('**', '**'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_italic_rounded),
                      tooltip: 'Italic',
                      onPressed: () => _applyFormatting('_', '_'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      tooltip: 'Bullet list',
                      onPressed: () => _applyFormatting('\n• '),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_quote_rounded),
                      tooltip: 'Quote',
                      onPressed: () => _applyFormatting('\n> '),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_rounded),
                      tooltip: 'Insert Link',
                      onPressed: _insertHyperlinkDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.description_outlined),
                      tooltip: 'Templates',
                      onPressed: _openTemplatesSheet,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientRow({
    required String label,
    required List<String> chips,
    required TextEditingController ctrl,
    required ValueChanged<String> onChanged,
    required ValueChanged<String> onSubmitted,
    Widget? trailing,
  }) {
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(width: 52, child: Text(label, style: TextStyle(color: textSecondary, fontSize: 14))),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...chips.map((addr) => InputChip(
                      label: Text(addr, style: const TextStyle(fontSize: 12.5)),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => setState(() => chips.remove(addr)),
                    )),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    decoration: const InputDecoration(
                      hintText: 'Add recipient',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
