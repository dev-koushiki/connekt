import 'package:flutter/material.dart';

class MailAttachment {
  final String url;
  final String filename;
  final String mimetype;
  final int size;
  final String? localPath;

  const MailAttachment({
    required this.url,
    required this.filename,
    this.mimetype = 'application/octet-stream',
    this.size = 0,
    this.localPath,
  });

  factory MailAttachment.fromJson(Map<String, dynamic> json) {
    return MailAttachment(
      url: (json['url'] ?? '').toString(),
      filename: (json['filename'] ?? json['name'] ?? 'attachment').toString(),
      mimetype: (json['mimetype'] ?? 'application/octet-stream').toString(),
      size: int.tryParse((json['size'] ?? '0').toString()) ?? 0,
      localPath: json['localPath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'filename': filename,
        'mimetype': mimetype,
        'size': size,
        if (localPath != null) 'localPath': localPath,
      };

  String get formattedSize {
    if (size <= 0) return 'File';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class MailLabel {
  final String id;
  final String name;
  final String colorHex;

  const MailLabel({
    required this.id,
    required this.name,
    this.colorHex = '#1D4ED8',
  });

  factory MailLabel.fromJson(Map<String, dynamic> json) {
    return MailLabel(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      colorHex: (json['color'] ?? json['colorHex'] ?? '#1D4ED8').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorHex,
      };

  Color get color {
    final cleaned = colorHex.replaceAll('#', '');
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return Color(value ?? 0xFF1D4ED8);
  }
}

class MailSettings {
  final String signature;
  final bool signatureEnabled;
  final bool vacationEnabled;
  final String vacationSubject;
  final String vacationBody;
  final bool conversationView;
  final String rightSwipeAction;
  final String leftSwipeAction;
  final bool compactDensity;

  const MailSettings({
    this.signature = '',
    this.signatureEnabled = false,
    this.vacationEnabled = false,
    this.vacationSubject = 'Out of Office',
    this.vacationBody = 'I am currently away and will respond when I return.',
    this.conversationView = true,
    this.rightSwipeAction = 'archive',
    this.leftSwipeAction = 'delete',
    this.compactDensity = false,
  });

  factory MailSettings.fromJson(Map<String, dynamic> json) {
    return MailSettings(
      signature: (json['signature'] ?? '').toString(),
      signatureEnabled: json['signatureEnabled'] == true,
      vacationEnabled: json['vacationEnabled'] == true,
      vacationSubject: (json['vacationSubject'] ?? 'Out of Office').toString(),
      vacationBody: (json['vacationBody'] ?? 'I am currently away and will respond when I return.').toString(),
      conversationView: json['conversationView'] != false,
      rightSwipeAction: (json['rightSwipeAction'] ?? 'archive').toString(),
      leftSwipeAction: (json['leftSwipeAction'] ?? 'delete').toString(),
      compactDensity: json['compactDensity'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'signatureEnabled': signatureEnabled,
        'vacationEnabled': vacationEnabled,
        'vacationSubject': vacationSubject,
        'vacationBody': vacationBody,
        'conversationView': conversationView,
        'rightSwipeAction': rightSwipeAction,
        'leftSwipeAction': leftSwipeAction,
        'compactDensity': compactDensity,
      };

  MailSettings copyWith({
    String? signature,
    bool? signatureEnabled,
    bool? vacationEnabled,
    String? vacationSubject,
    String? vacationBody,
    bool? conversationView,
    String? rightSwipeAction,
    String? leftSwipeAction,
    bool? compactDensity,
  }) {
    return MailSettings(
      signature: signature ?? this.signature,
      signatureEnabled: signatureEnabled ?? this.signatureEnabled,
      vacationEnabled: vacationEnabled ?? this.vacationEnabled,
      vacationSubject: vacationSubject ?? this.vacationSubject,
      vacationBody: vacationBody ?? this.vacationBody,
      conversationView: conversationView ?? this.conversationView,
      rightSwipeAction: rightSwipeAction ?? this.rightSwipeAction,
      leftSwipeAction: leftSwipeAction ?? this.leftSwipeAction,
      compactDensity: compactDensity ?? this.compactDensity,
    );
  }
}

class MailTemplate {
  final String id;
  final String name;
  final String subject;
  final String body;
  final String? htmlBody;

  const MailTemplate({
    required this.id,
    required this.name,
    this.subject = '',
    this.body = '',
    this.htmlBody,
  });

  factory MailTemplate.fromJson(Map<String, dynamic> json) {
    return MailTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Template').toString(),
      subject: (json['subject'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      htmlBody: json['htmlBody']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'body': body,
        if (htmlBody != null) 'htmlBody': htmlBody,
      };
}

class MailContact {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String notes;

  const MailContact({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.company = '',
    this.notes = '',
  });

  factory MailContact.fromJson(Map<String, dynamic> json) {
    return MailContact(
      id: (json['id'] ?? json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'company': company,
        'notes': notes,
      };
}

class MailExternalStatus {
  final String domain;
  final bool smtpConfigured;
  final bool imapConfigured;
  final bool inboundWebhookConfigured;

  const MailExternalStatus({
    this.domain = 'connekt.me',
    this.smtpConfigured = false,
    this.imapConfigured = false,
    this.inboundWebhookConfigured = false,
  });

  factory MailExternalStatus.fromJson(Map<String, dynamic> json) {
    return MailExternalStatus(
      domain: (json['domain'] ?? 'connekt.me').toString(),
      smtpConfigured: json['smtpConfigured'] == true,
      imapConfigured: json['imapConfigured'] == true,
      inboundWebhookConfigured: json['inboundWebhookConfigured'] == true,
    );
  }
}

class MailMessage {
  final String id;
  final String threadId;
  final String? inReplyTo;
  final String senderName;
  final String senderEmail;
  final List<String> to;
  final List<String> cc;
  final List<String> bcc;
  final String subject;
  final String body;
  final String? htmlBody;
  final String snippet;
  final String folder; // inbox, sent, drafts, archive, spam, trash, scheduled, snoozed
  final String originalFolder;
  final String category; // primary, social, promotions, updates, forums
  final List<String> labels;
  final List<MailAttachment> attachments;
  final String deliveryStatus;
  final String? deliveryError;
  final String? spfStatus;
  final String? dkimStatus;
  final String? dmarcStatus;
  final bool isUnread;
  final bool isStarred;
  final bool isImportant;
  final bool isMuted;
  final bool isConfidential;
  final DateTime? confidentialExpiresAt;
  final DateTime? snoozedUntil;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  const MailMessage({
    required this.id,
    required this.threadId,
    this.inReplyTo,
    required this.senderName,
    required this.senderEmail,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    required this.subject,
    required this.body,
    this.htmlBody,
    required this.snippet,
    this.folder = 'inbox',
    this.originalFolder = 'inbox',
    this.category = 'primary',
    this.labels = const [],
    this.attachments = const [],
    this.deliveryStatus = 'delivered_internal',
    this.deliveryError,
    this.spfStatus,
    this.dkimStatus,
    this.dmarcStatus,
    this.isUnread = false,
    this.isStarred = false,
    this.isImportant = false,
    this.isMuted = false,
    this.isConfidential = false,
    this.confidentialExpiresAt,
    this.snoozedUntil,
    this.scheduledAt,
    required this.createdAt,
  });

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    final bodyStr = (json['body'] ?? '').toString();
    final rawSnippet = (json['snippet'] ?? '').toString();
    return MailMessage(
      id: (json['id'] ?? '').toString(),
      threadId: (json['threadId'] ?? json['id'] ?? '').toString(),
      inReplyTo: json['inReplyTo']?.toString(),
      senderName: (json['senderName'] ?? json['sender'] ?? json['senderEmail'] ?? 'User').toString(),
      senderEmail: (json['senderEmail'] ?? json['email'] ?? '').toString(),
      to: (json['to'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      cc: (json['cc'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      bcc: (json['bcc'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      subject: (json['subject'] ?? '(no subject)').toString(),
      body: bodyStr,
      htmlBody: json['htmlBody']?.toString(),
      snippet: rawSnippet.isNotEmpty ? rawSnippet : makeSnippet(bodyStr),
      folder: (json['folder'] ?? 'inbox').toString().toLowerCase(),
      originalFolder: (json['originalFolder'] ?? json['folder'] ?? 'inbox').toString().toLowerCase(),
      category: (json['category'] ?? 'primary').toString().toLowerCase(),
      labels: (json['labels'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((a) => MailAttachment.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      deliveryStatus: (json['deliveryStatus'] ?? 'delivered_internal').toString(),
      deliveryError: json['deliveryError']?.toString(),
      spfStatus: json['spfStatus']?.toString(),
      dkimStatus: json['dkimStatus']?.toString(),
      dmarcStatus: json['dmarcStatus']?.toString(),
      isUnread: json['isUnread'] == true,
      isStarred: json['isStarred'] == true,
      isImportant: json['isImportant'] == true,
      isMuted: json['isMuted'] == true,
      isConfidential: json['isConfidential'] == true,
      confidentialExpiresAt: _tryParseDate(json['confidentialExpiresAt']),
      snoozedUntil: _tryParseDate(json['snoozedUntil']),
      scheduledAt: _tryParseDate(json['scheduledAt']),
      createdAt: _tryParseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'threadId': threadId,
        'inReplyTo': inReplyTo,
        'senderName': senderName,
        'senderEmail': senderEmail,
        'to': to,
        'cc': cc,
        'bcc': bcc,
        'subject': subject,
        'body': body,
        if (htmlBody != null) 'htmlBody': htmlBody,
        'snippet': snippet,
        'folder': folder,
        'originalFolder': originalFolder,
        'category': category,
        'labels': labels,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'deliveryStatus': deliveryStatus,
        if (deliveryError != null) 'deliveryError': deliveryError,
        if (spfStatus != null) 'spfStatus': spfStatus,
        if (dkimStatus != null) 'dkimStatus': dkimStatus,
        if (dmarcStatus != null) 'dmarcStatus': dmarcStatus,
        'isUnread': isUnread,
        'isStarred': isStarred,
        'isImportant': isImportant,
        'isMuted': isMuted,
        'isConfidential': isConfidential,
        'confidentialExpiresAt': confidentialExpiresAt?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'scheduledAt': scheduledAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  MailMessage copyWith({
    String? id,
    String? threadId,
    String? inReplyTo,
    String? senderName,
    String? senderEmail,
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    String? subject,
    String? body,
    String? htmlBody,
    String? snippet,
    String? folder,
    String? originalFolder,
    String? category,
    List<String>? labels,
    List<MailAttachment>? attachments,
    String? deliveryStatus,
    String? deliveryError,
    bool? isUnread,
    bool? isStarred,
    bool? isImportant,
    bool? isMuted,
    bool? isConfidential,
    DateTime? confidentialExpiresAt,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    DateTime? scheduledAt,
    bool clearSchedule = false,
    DateTime? createdAt,
  }) {
    final nextBody = body ?? this.body;
    return MailMessage(
      id: id ?? this.id,
      threadId: threadId ?? this.threadId,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      body: nextBody,
      htmlBody: htmlBody ?? this.htmlBody,
      snippet: snippet ?? (body != null ? makeSnippet(nextBody) : this.snippet),
      folder: folder ?? this.folder,
      originalFolder: originalFolder ?? this.originalFolder,
      category: category ?? this.category,
      labels: labels ?? this.labels,
      attachments: attachments ?? this.attachments,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryError: deliveryError ?? this.deliveryError,
      spfStatus: spfStatus,
      dkimStatus: dkimStatus,
      dmarcStatus: dmarcStatus,
      isUnread: isUnread ?? this.isUnread,
      isStarred: isStarred ?? this.isStarred,
      isImportant: isImportant ?? this.isImportant,
      isMuted: isMuted ?? this.isMuted,
      isConfidential: isConfidential ?? this.isConfidential,
      confidentialExpiresAt: confidentialExpiresAt ?? this.confidentialExpiresAt,
      snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
      scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String makeSnippet(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 130) return singleLine;
    return '${singleLine.substring(0, 127)}...';
  }

  static DateTime? _tryParseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  static String formatShortTime(DateTime dt, {DateTime? now}) {
    final local = dt.toLocal();
    final ref = (now ?? DateTime.now()).toLocal();
    final isToday = local.year == ref.year && local.month == ref.month && local.day == ref.day;
    if (isToday) {
      final h = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
      final m = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (local.year == ref.year) {
      return '${months[local.month - 1]} ${local.day}';
    }
    return '${local.month}/${local.day}/${local.year % 100}';
  }

  static String formatFullDate(DateTime dt) {
    final local = dt.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final m = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year}, $h:$m $period';
  }
}

class MailThread {
  final String threadId;
  final List<MailMessage> messages; // Chronological oldest -> newest

  const MailThread({required this.threadId, required this.messages});

  MailMessage get latest => messages.last;
  MailMessage get first => messages.first;
  int get messageCount => messages.length;
  bool get isUnread => messages.any((m) => m.isUnread);
  bool get isStarred => messages.any((m) => m.isStarred);
  bool get isImportant => messages.any((m) => m.isImportant);
  bool get isMuted => messages.every((m) => m.isMuted);
  bool get isConfidential => messages.any((m) => m.isConfidential);
  bool get hasAttachment => messages.any((m) => m.attachments.isNotEmpty);
  List<String> get messageIds => messages.map((m) => m.id).toList();

  List<String> get labels {
    final seen = <String>{};
    final out = <String>[];
    for (final m in messages) {
      for (final lbl in m.labels) {
        if (seen.add(lbl)) out.add(lbl);
      }
    }
    return out;
  }

  String participantsSummary(String selfEmail) {
    final selfLower = selfEmail.trim().toLowerCase();
    final names = <String>[];
    final seen = <String>{};
    for (final m in messages) {
      final isSelf = m.senderEmail.trim().toLowerCase() == selfLower;
      final label = isSelf
          ? 'me'
          : (m.folder == 'drafts' ? 'Draft' : m.senderName.split(' ').first);
      if (seen.add(label)) {
        names.add(label);
      }
    }
    if (names.isEmpty) return latest.senderName;
    if (names.length <= 2) return names.join(', ');
    return '${names.first}, .. ${names.last}';
  }

  /// Context-aware 1-tap Smart Reply suggestions like Gmail.
  List<String> smartReplies() {
    final content = '${latest.subject} ${latest.body}'.toLowerCase();
    if (content.contains('meeting') || content.contains('schedule') || content.contains('sync')) {
      return ['Count me in!', 'Can we reschedule?', 'Sending calendar invite now.'];
    }
    if (content.contains('attach') || content.contains('document') || content.contains('report') || content.contains('roadmap')) {
      return ['Thanks, reviewing now.', 'Looks good to me!', 'Received with thanks.'];
    }
    if (content.contains('welcome') || content.contains('thank')) {
      return ['Thank you!', 'Glad to connect!', 'Appreciate the update.'];
    }
    return ['Sounds good!', 'Thanks for the update.', "I'll get back to you shortly."];
  }
}

/// Evaluates Gmail search queries supporting operators:
/// `from:`, `to:`, `subject:`, `label:`, `is:unread`, `is:starred`, `is:important`, `has:attachment`.
class MailQueryFilter {
  static bool matches(MailMessage msg, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final tokens = RegExp(r'''"[^"]*"|'[^']*'|[^\s]+''')
        .allMatches(query)
        .map((m) => m.group(0)!.replaceAll('"', '').replaceAll("'", '').trim())
        .where((t) => t.isNotEmpty)
        .toList();

    for (final token in tokens) {
      if (token.startsWith('from:')) {
        final target = token.substring(5);
        final sender = '${msg.senderName} ${msg.senderEmail}'.toLowerCase();
        if (!sender.contains(target)) return false;
      } else if (token.startsWith('to:')) {
        final target = token.substring(3);
        final recips = '${msg.to.join(' ')} ${msg.cc.join(' ')}'.toLowerCase();
        if (!recips.contains(target)) return false;
      } else if (token.startsWith('subject:')) {
        final target = token.substring(8);
        if (!msg.subject.toLowerCase().contains(target)) return false;
      } else if (token.startsWith('label:')) {
        final target = token.substring(6);
        if (!msg.labels.any((l) => l.toLowerCase().contains(target))) return false;
      } else if (token == 'is:unread') {
        if (!msg.isUnread) return false;
      } else if (token == 'is:read') {
        if (msg.isUnread) return false;
      } else if (token == 'is:starred') {
        if (!msg.isStarred) return false;
      } else if (token == 'is:important') {
        if (!msg.isImportant) return false;
      } else if (token == 'has:attachment') {
        if (msg.attachments.isEmpty) return false;
      } else {
        final haystack = [
          msg.senderName,
          msg.senderEmail,
          msg.to.join(' '),
          msg.cc.join(' '),
          msg.subject,
          msg.body,
          msg.labels.join(' '),
          msg.attachments.map((a) => a.filename).join(' '),
        ].join(' ').toLowerCase();
        if (!haystack.contains(token)) return false;
      }
    }
    return true;
  }

  /// Build threads grouped by threadId (or per-message if conversationView is off) and sort.
  static List<MailThread> groupIntoThreads(
    List<MailMessage> messages, {
    required bool conversationView,
    String sortBy = 'newest',
  }) {
    List<MailThread> threads;
    if (!conversationView) {
      threads = messages.map((m) => MailThread(threadId: m.id, messages: [m])).toList();
    } else {
      final grouped = <String, List<MailMessage>>{};
      for (final m in messages) {
        grouped.putIfAbsent(m.threadId, () => []).add(m);
      }
      threads = grouped.entries.map((entry) {
        final list = [...entry.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return MailThread(threadId: entry.key, messages: list);
      }).toList();
    }

    switch (sortBy) {
      case 'oldest':
        threads.sort((a, b) => a.latest.createdAt.compareTo(b.latest.createdAt));
        break;
      case 'unread':
        threads.sort((a, b) {
          if (a.isUnread != b.isUnread) return a.isUnread ? -1 : 1;
          return b.latest.createdAt.compareTo(a.latest.createdAt);
        });
        break;
      case 'sender':
        threads.sort((a, b) => a.latest.senderName.toLowerCase().compareTo(b.latest.senderName.toLowerCase()));
        break;
      case 'newest':
      default:
        threads.sort((a, b) => b.latest.createdAt.compareTo(a.latest.createdAt));
        break;
    }
    return threads;
  }
}
