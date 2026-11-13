import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/mail_models.dart';
import '../translatable_text_widget.dart';

class MailThreadScreen extends StatefulWidget {
  final MailThread thread;
  final String selfEmail;
  final List<MailLabel> availableLabels;
  final void Function(MailMessage msg, String mode) onReplyAction; // 'reply', 'reply_all', 'forward'
  final void Function(MailMessage msg, String replyBody) onQuickSmartReply;
  final VoidCallback onToggleStar;
  final VoidCallback onToggleImportant;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onMarkUnread;
  final VoidCallback onToggleSpam;
  final VoidCallback onToggleMute;
  final VoidCallback onSnooze;
  final ValueChanged<List<String>> onUpdateLabels;

  const MailThreadScreen({
    super.key,
    required this.thread,
    required this.selfEmail,
    required this.availableLabels,
    required this.onReplyAction,
    required this.onQuickSmartReply,
    required this.onToggleStar,
    required this.onToggleImportant,
    required this.onArchive,
    required this.onDelete,
    required this.onMarkUnread,
    required this.onToggleSpam,
    required this.onToggleMute,
    required this.onSnooze,
    required this.onUpdateLabels,
  });

  @override
  State<MailThreadScreen> createState() => _MailThreadScreenState();
}

class _MailThreadScreenState extends State<MailThreadScreen> {
  final Set<String> _expandedMessageIds = {};
  final Set<String> _expandedDetailsIds = {};
  final Set<String> _showQuotedIds = {};
  late bool _isStarred;
  late bool _isImportant;
  late List<String> _labels;

  @override
  void initState() {
    super.initState();
    _expandedMessageIds.add(widget.thread.latest.id);
    _isStarred = widget.thread.isStarred;
    _isImportant = widget.thread.isImportant;
    _labels = [...widget.thread.labels];
  }

  Future<void> _showLabelPicker() async {
    final chosen = Set<String>.from(_labels);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Apply Labels'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: widget.availableLabels.map((lbl) {
                final checked = chosen.contains(lbl.name);
                return CheckboxListTile(
                  value: checked,
                  activeColor: AppTheme.brandBlue,
                  secondary: Icon(Icons.label_outline_rounded, color: lbl.color),
                  title: Text(lbl.name),
                  onChanged: (v) {
                    setDlgState(() {
                      if (v == true) {
                        chosen.add(lbl.name);
                      } else {
                        chosen.remove(lbl.name);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, chosen.toList()),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _labels = result);
      widget.onUpdateLabels(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.getBackgroundColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final textPrimary = AppTheme.getTextPrimary(context);
    final textSecondary = AppTheme.getTextSecondary(context);
    final borderColor = AppTheme.getBorderColor(context);
    final latest = widget.thread.latest;
    final inTrash = latest.folder == 'trash';
    final inSpam = latest.folder == 'spam';
    final smartReplies = widget.thread.smartReplies();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!inTrash)
            IconButton(
              icon: Icon(Icons.archive_outlined, color: textPrimary),
              tooltip: 'Archive',
              onPressed: () {
                widget.onArchive();
                Navigator.pop(context);
              },
            ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: textPrimary),
            tooltip: inTrash ? 'Delete forever' : 'Move to Trash',
            onPressed: () {
              widget.onDelete();
              Navigator.pop(context);
            },
          ),
          IconButton(
            icon: Icon(Icons.mark_email_unread_outlined, color: textPrimary),
            tooltip: 'Mark as unread',
            onPressed: () {
              widget.onMarkUnread();
              Navigator.pop(context);
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: textPrimary),
            onSelected: (action) {
              switch (action) {
                case 'snooze':
                  Navigator.pop(context);
                  widget.onSnooze();
                  break;
                case 'labels':
                  _showLabelPicker();
                  break;
                case 'spam':
                  widget.onToggleSpam();
                  Navigator.pop(context);
                  break;
                case 'mute':
                  widget.onToggleMute();
                  Navigator.pop(context);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'snooze', child: ListTile(leading: Icon(Icons.schedule_rounded), title: Text('Snooze'), contentPadding: EdgeInsets.zero, dense: true)),
              const PopupMenuItem(value: 'labels', child: ListTile(leading: Icon(Icons.label_outline_rounded), title: Text('Change labels'), contentPadding: EdgeInsets.zero, dense: true)),
              PopupMenuItem(
                value: 'spam',
                child: ListTile(
                  leading: const Icon(Icons.report_gmailerrorred_outlined),
                  title: Text(inSpam ? 'Not spam' : 'Report spam'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  leading: Icon(widget.thread.isMuted ? Icons.volume_up_outlined : Icons.volume_off_outlined),
                  title: Text(widget.thread.isMuted ? 'Unmute' : 'Mute conversation'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                // Subject + Important + Star
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            widget.thread.first.subject,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() => _isImportant = !_isImportant);
                              widget.onToggleImportant();
                            },
                            child: Icon(
                              _isImportant ? Icons.label_important_rounded : Icons.label_important_outline_rounded,
                              color: _isImportant ? AppTheme.accentAmber : textSecondary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                        color: _isStarred ? AppTheme.accentAmber : textSecondary,
                      ),
                      onPressed: () {
                        setState(() => _isStarred = !_isStarred);
                        widget.onToggleStar();
                      },
                    ),
                  ],
                ),

                // Labels row
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(latest.folder.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      ..._labels.map((lbl) => Chip(
                            label: Text(lbl, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          )),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 15, color: AppTheme.brandBlue),
                        label: const Text('Label', style: TextStyle(fontSize: 11, color: AppTheme.brandBlue)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _showLabelPicker,
                      ),
                    ],
                  ),
                ),

                if (widget.thread.isConfidential)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppTheme.brandBlue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            latest.confidentialExpiresAt != null
                                ? 'Confidential mode • Expires ${MailMessage.formatFullDate(latest.confidentialExpiresAt!)}'
                                : 'Confidential mode enabled',
                            style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Chronological Thread Messages
                ...widget.thread.messages.map((msg) => _buildMessageCard(msg, cardColor, borderColor, textPrimary, textSecondary)),

                // Smart Reply Chips
                if (latest.senderEmail.toLowerCase() != widget.selfEmail.toLowerCase() && !inTrash && !inSpam) ...[
                  const SizedBox(height: 14),
                  Text('SMART REPLIES', style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: smartReplies.map((replyText) {
                      return OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.brandBlue,
                          side: BorderSide(color: AppTheme.brandBlue.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () {
                          widget.onQuickSmartReply(latest, replyText);
                          Navigator.pop(context);
                        },
                        child: Text(replyText, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Gmail Footer Action Buttons (Reply, Reply All, Forward)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onReplyAction(latest, 'reply'),
                      icon: const Icon(Icons.reply_rounded, size: 18),
                      label: const Text('Reply'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onReplyAction(latest, 'reply_all'),
                      icon: const Icon(Icons.reply_all_rounded, size: 18),
                      label: const Text('Reply all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => widget.onReplyAction(latest, 'forward'),
                      icon: const Icon(Icons.forward_rounded, size: 18),
                      label: const Text('Forward'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(
    MailMessage msg,
    Color cardColor,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isExpanded = _expandedMessageIds.contains(msg.id);
    final showDetails = _expandedDetailsIds.contains(msg.id);
    final showQuoted = _showQuotedIds.contains(msg.id);

    final parts = msg.body.split('\n> ');
    final mainBody = parts.first.trim();
    final quotedBody = parts.length > 1 ? '> ${parts.sublist(1).join('\n> ')}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMessageIds.remove(msg.id);
                } else {
                  _expandedMessageIds.add(msg.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.16),
                    child: Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'M',
                      style: const TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                msg.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            Text(
                              MailMessage.formatShortTime(msg.createdAt),
                              style: TextStyle(color: textSecondary, fontSize: 11.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (!isExpanded)
                          Text(
                            msg.snippet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: textSecondary, fontSize: 12.5),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (showDetails) {
                                  _expandedDetailsIds.remove(msg.id);
                                } else {
                                  _expandedDetailsIds.add(msg.id);
                                }
                              });
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'to ${msg.to.isEmpty ? 'me' : msg.to.join(', ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ),
                                Icon(showDetails ? Icons.expand_less : Icons.expand_more, size: 16, color: textSecondary),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isExpanded)
                    IconButton(
                      icon: Icon(Icons.reply_rounded, size: 19, color: textSecondary),
                      onPressed: () => widget.onReplyAction(msg, 'reply'),
                    ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            if (showDetails)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.getInputColor(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('From: ${msg.senderName} <${msg.senderEmail}>', style: TextStyle(color: textSecondary, fontSize: 12)),
                    if (msg.to.isNotEmpty) Text('To: ${msg.to.join(', ')}', style: TextStyle(color: textSecondary, fontSize: 12)),
                    if (msg.cc.isNotEmpty) Text('Cc: ${msg.cc.join(', ')}', style: TextStyle(color: textSecondary, fontSize: 12)),
                    Text('Date: ${MailMessage.formatFullDate(msg.createdAt)}', style: TextStyle(color: textSecondary, fontSize: 12)),
                    Text(
                      'Status: ${msg.deliveryStatus.replaceAll('_', ' ')}'
                      '${msg.spfStatus != null ? ' • SPF: ${msg.spfStatus}' : ''}'
                      '${msg.dkimStatus != null ? ' • DKIM: ${msg.dkimStatus}' : ''}'
                      '${msg.dmarcStatus != null ? ' • DMARC: ${msg.dmarcStatus}' : ''}',
                      style: TextStyle(
                        color: msg.deliveryStatus == 'failed'
                            ? AppTheme.accentCoral
                            : const Color(0xFF059669),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatableTextWidget(
                    text: mainBody.isNotEmpty ? mainBody : '(Empty message body)',
                    style: TextStyle(color: textPrimary, fontSize: 14.5, height: 1.55),
                  ),
                  if (quotedBody.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() {
                        if (showQuoted) {
                          _showQuotedIds.remove(msg.id);
                        } else {
                          _showQuotedIds.add(msg.id);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.getInputColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(showQuoted ? 'Hide quoted text' : '•••', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (showQuoted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(quotedBody, style: TextStyle(color: textSecondary, fontSize: 13)),
                      ),
                  ],
                  if (msg.attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: msg.attachments.map((att) {
                        final isImage = att.mimetype.startsWith('image/') ||
                            RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(att.filename);
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showAttachmentPreview(att),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.getInputColor(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isImage ? Icons.image_outlined : Icons.description_outlined,
                                  size: 18,
                                  color: AppTheme.brandBlue,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(att.filename, style: TextStyle(color: textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    Text('${att.formattedSize} • Tap to preview', style: TextStyle(color: textSecondary, fontSize: 10.5)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAttachmentPreview(MailAttachment att) {
    final isImage = att.mimetype.startsWith('image/') ||
        RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false).hasMatch(att.filename);
    final serverOrigin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final resolvedUrl = att.url.startsWith('/') ? '$serverOrigin${att.url}' : att.url;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.getCardColor(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final textPrimary = AppTheme.getTextPrimary(ctx);
        final textSecondary = AppTheme.getTextSecondary(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded, color: AppTheme.brandBlue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(att.filename, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${att.mimetype} • ${att.formattedSize}', style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                if (isImage && att.localPath != null && File(att.localPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(att.localPath!), height: 240, width: double.infinity, fit: BoxFit.contain),
                  )
                else if (isImage && resolvedUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      resolvedUrl,
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Image preview unavailable offline')),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.getInputColor(ctx),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.description_outlined, size: 48, color: AppTheme.brandBlue),
                        const SizedBox(height: 8),
                        Text(att.filename, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          resolvedUrl.isNotEmpty ? resolvedUrl : 'Local / Sample Attachment',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                if (resolvedUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Attachment URL'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: resolvedUrl));
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
