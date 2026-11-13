import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/mail_models.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class MailWorkspaceData {
  final List<MailMessage> messages;
  final List<MailLabel> labels;
  final List<MailTemplate> templates;
  final List<MailContact> contacts;
  final MailSettings settings;
  final MailExternalStatus externalStatus;
  final bool syncedFromServer;

  const MailWorkspaceData({
    required this.messages,
    required this.labels,
    this.templates = const [],
    this.contacts = const [],
    required this.settings,
    this.externalStatus = const MailExternalStatus(),
    this.syncedFromServer = false,
  });
}

/// Service handling Gmail-like mail persistence, threading, search, labels,
/// attachments, scheduling, snooze, and settings across backend API and local storage.
class MailService {
  static String _cacheKey(String? userId) =>
      'connekt_mail_workspace_${(userId != null && userId.isNotEmpty) ? userId : 'guest'}';

  static List<MailLabel> defaultLabels() => const [
        MailLabel(id: 'lbl_work', name: 'Work', colorHex: '#1D4ED8'),
        MailLabel(id: 'lbl_personal', name: 'Personal', colorHex: '#059669'),
        MailLabel(id: 'lbl_finance', name: 'Finance', colorHex: '#D97706'),
        MailLabel(id: 'lbl_travel', name: 'Travel', colorHex: '#7C3AED'),
      ];

  static List<MailMessage> starterMessages(UserModel? user) {
    final userMail = user?.email.isNotEmpty == true
        ? user!.email
        : '${user?.username ?? "user"}@connekt.net.in';
    final now = DateTime.now();

    return [
      MailMessage(
        id: 'm_sec_1',
        threadId: 'thr_sec_1',
        senderName: 'CONNEKT Security Team',
        senderEmail: 'security@connekt.net.in',
        to: [userMail],
        subject: 'Welcome to CONNEKT – Account Setup & Security Keys',
        body: 'Hi ${user?.personalProfile?.fullName ?? user?.username ?? "there"},\n\n'
            'Your Connekt Mail workspace is active with full Gmail-style workflows: Primary/Social/Promotions tabs, '
            'conversation threads, custom labels, confidential mode, scheduled send, snooze, attachments, and vacation responder.\n\n'
            'Review the attached security setup guide anytime.',
        snippet: 'Your Connekt Mail workspace is active with full Gmail-style workflows, tabs, threads, labels, and confidential mode.',
        folder: 'inbox',
        originalFolder: 'inbox',
        category: 'primary',
        labels: const ['Work'],
        attachments: const [
          MailAttachment(
            url: '',
            filename: 'CONNEKT_Security_Guide.pdf',
            mimetype: 'application/pdf',
            size: 245760,
          ),
        ],
        isUnread: true,
        isStarred: true,
        isImportant: true,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      MailMessage(
        id: 'm_road_1',
        threadId: 'thr_road_1',
        senderName: 'Alex Chen (Product Lead)',
        senderEmail: 'alex.chen@connekt.net.in',
        to: [userMail],
        cc: const ['team@connekt.net.in'],
        subject: 'Q4 Mobile Ecosystem Launch Roadmap & Specifications',
        body: 'Hi team,\n\nPlease review the updated engineering milestones for the mobile release.\n'
            'Can you confirm whether the design assets are finalized for Friday\'s sync?',
        snippet: 'Please review the updated engineering milestones for the mobile release and confirm design assets for Friday.',
        folder: 'inbox',
        originalFolder: 'inbox',
        category: 'primary',
        labels: const ['Work'],
        attachments: const [
          MailAttachment(
            url: '',
            filename: 'Q4_Roadmap_Spec.docx',
            mimetype: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            size: 512000,
          ),
        ],
        isUnread: true,
        isStarred: false,
        isImportant: true,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      MailMessage(
        id: 'm_road_2',
        threadId: 'thr_road_1',
        inReplyTo: 'm_road_1',
        senderName: 'Lena Rivers',
        senderEmail: 'lena.rivers@connekt.net.in',
        to: ['alex.chen@connekt.net.in', userMail],
        subject: 'Re: Q4 Mobile Ecosystem Launch Roadmap & Specifications',
        body: 'Design assets and component specs are uploaded! Looking forward to Friday\'s schedule review.',
        snippet: 'Design assets and component specs are uploaded! Looking forward to Friday\'s schedule review.',
        folder: 'inbox',
        originalFolder: 'inbox',
        category: 'primary',
        labels: const ['Work'],
        isUnread: true,
        isStarred: false,
        isImportant: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      MailMessage(
        id: 'm_soc_1',
        threadId: 'thr_soc_1',
        senderName: 'CONNEKT Community',
        senderEmail: 'community@connekt.net.in',
        to: [userMail],
        subject: 'New team highlights in CONNEKT Workspace',
        body: 'Your colleagues shared 4 collaborative notes and meeting summaries this week.',
        snippet: 'Your colleagues shared 4 collaborative notes and meeting summaries this week.',
        folder: 'inbox',
        originalFolder: 'inbox',
        category: 'social',
        labels: const ['Personal'],
        isUnread: true,
        isStarred: false,
        isImportant: false,
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      MailMessage(
        id: 'm_promo_1',
        threadId: 'thr_promo_1',
        senderName: 'Cloud Infrastructure Digest',
        senderEmail: 'updates@connekt.net.in',
        to: [userMail],
        subject: 'Weekly Cloud Diagnostics & Productivity Tips',
        body: 'All systems nominal with 99.98% uptime. Try swiping messages left or right to archive or delete in one gesture.',
        snippet: 'All systems nominal with 99.98% uptime. Try swiping messages left or right to archive or delete.',
        folder: 'inbox',
        originalFolder: 'inbox',
        category: 'promotions',
        labels: const [],
        isUnread: false,
        isStarred: false,
        isImportant: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<MailMessage> _promoteDueMessages(List<MailMessage> messages) {
    final now = DateTime.now();
    return messages.map((m) {
      if (m.folder == 'snoozed' && m.snoozedUntil != null && !m.snoozedUntil!.isAfter(now)) {
        return m.copyWith(folder: 'inbox', originalFolder: 'inbox', clearSnooze: true, isUnread: true);
      }
      if (m.folder == 'scheduled' && m.scheduledAt != null && !m.scheduledAt!.isAfter(now)) {
        return m.copyWith(folder: 'sent', originalFolder: 'sent', clearSchedule: true, isUnread: false);
      }
      return m;
    }).toList();
  }

  static Future<MailWorkspaceData> loadCachedOrSeed(UserModel? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(user?.id));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final msgs = _promoteDueMessages(
          (decoded['messages'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((m) => MailMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList(),
        );
        final labels = (decoded['labels'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((l) => MailLabel.fromJson(Map<String, dynamic>.from(l)))
            .toList();
        final settings = decoded['settings'] is Map
            ? MailSettings.fromJson(Map<String, dynamic>.from(decoded['settings']))
            : const MailSettings();
        final templates = (decoded['templates'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((t) => MailTemplate.fromJson(Map<String, dynamic>.from(t)))
            .toList();
        final contacts = (decoded['contacts'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((c) => MailContact.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        return MailWorkspaceData(
          messages: msgs,
          labels: labels.isEmpty ? defaultLabels() : labels,
          templates: templates,
          contacts: contacts,
          settings: settings,
        );
      }
    } catch (_) {}

    final seeded = MailWorkspaceData(
      messages: starterMessages(user),
      labels: defaultLabels(),
      settings: const MailSettings(),
    );
    await saveCache(user?.id, seeded);
    return seeded;
  }

  static Future<void> saveCache(String? userId, MailWorkspaceData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(userId),
        jsonEncode({
          'messages': data.messages.map((m) => m.toJson()).toList(),
          'labels': data.labels.map((l) => l.toJson()).toList(),
          'templates': data.templates.map((t) => t.toJson()).toList(),
          'contacts': data.contacts.map((c) => c.toJson()).toList(),
          'settings': data.settings.toJson(),
        }),
      );
    } catch (_) {}
  }

  /// Load mailbox from server if authenticated & online, otherwise return local cache.
  static Future<MailWorkspaceData> fetchWorkspace(UserModel? user) async {
    try {
      final token = await ApiService.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await ApiService.safeRequest((base) {
          return http.get(
            Uri.parse('$base/mail'),
            headers: ApiService.authHeaders(token),
          );
        });
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final payload = json['data'] as Map<String, dynamic>? ?? const {};
          final msgs = (payload['messages'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((m) => MailMessage.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          final labels = (payload['labels'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((l) => MailLabel.fromJson(Map<String, dynamic>.from(l)))
              .toList();
          final templates = (payload['templates'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((t) => MailTemplate.fromJson(Map<String, dynamic>.from(t)))
              .toList();
          final contacts = (payload['contacts'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((c) => MailContact.fromJson(Map<String, dynamic>.from(c)))
              .toList();
          final settings = payload['settings'] is Map
              ? MailSettings.fromJson(Map<String, dynamic>.from(payload['settings']))
              : const MailSettings();
          final extStatus = payload['externalStatus'] is Map
              ? MailExternalStatus.fromJson(Map<String, dynamic>.from(payload['externalStatus']))
              : const MailExternalStatus();
          final data = MailWorkspaceData(
            messages: _promoteDueMessages(msgs),
            labels: labels.isEmpty ? defaultLabels() : labels,
            templates: templates,
            contacts: contacts,
            settings: settings,
            externalStatus: extStatus,
            syncedFromServer: true,
          );
          await saveCache(user?.id, data);
          return data;
        }
      }
    } catch (_) {}

    return loadCachedOrSeed(user);
  }

  static Future<MailAttachment?> uploadAttachment({
    required String filename,
    Uint8List? bytes,
    String? filePath,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('${ApiConfig.baseUrl}/mail/attachments');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll({
          'Authorization': 'Bearer $token',
          'bypass-tunnel-reminder': 'true',
        });
        if (bytes != null && bytes.isNotEmpty) {
          req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
        } else if (filePath != null && filePath.isNotEmpty) {
          req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename));
        } else {
          return null;
        }
        final streamed = await req.send().timeout(const Duration(seconds: 20));
        final body = await streamed.stream.bytesToString();
        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          final parsed = jsonDecode(body) as Map<String, dynamic>;
          final info = parsed['data'] as Map<String, dynamic>? ?? const {};
          return MailAttachment(
            url: (info['url'] ?? '').toString(),
            filename: (info['filename'] ?? filename).toString(),
            mimetype: (info['mimetype'] ?? 'application/octet-stream').toString(),
            size: int.tryParse((info['size'] ?? '0').toString()) ?? (bytes?.length ?? 0),
            localPath: filePath,
          );
        }
      }
    } catch (_) {}

    return MailAttachment(
      url: '',
      filename: filename,
      size: bytes?.length ?? 0,
      localPath: filePath,
    );
  }

  static Future<MailMessage?> sendOrSaveDraft({
    required UserModel? user,
    String? draftId,
    required List<String> to,
    List<String> cc = const [],
    List<String> bcc = const [],
    required String subject,
    required String body,
    String? htmlBody,
    String? threadId,
    String? inReplyTo,
    List<MailAttachment> attachments = const [],
    List<String> labels = const [],
    bool isDraft = false,
    bool isConfidential = false,
    DateTime? confidentialExpiresAt,
    DateTime? scheduledAt,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token != null && token.isNotEmpty) {
        final res = await ApiService.safeRequest((base) {
          return http.post(
            Uri.parse('$base/mail/send'),
            headers: ApiService.authHeaders(token),
            body: jsonEncode({
              'draftId': ?draftId,
              'to': to,
              'cc': cc,
              'bcc': bcc,
              'subject': subject,
              'body': body,
              'htmlBody': ?htmlBody,
              'threadId': ?threadId,
              'inReplyTo': ?inReplyTo,
              'attachments': attachments.map((a) => a.toJson()).toList(),
              'labels': labels,
              'isDraft': isDraft,
              'isConfidential': isConfidential,
              'confidentialExpiresAt': ?confidentialExpiresAt?.toIso8601String(),
              'scheduledAt': ?scheduledAt?.toIso8601String(),
            }),
          );
        }, timeout: const Duration(seconds: 8));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final parsed = jsonDecode(res.body) as Map<String, dynamic>;
          final msgJson = parsed['data']?['message'];
          if (msgJson is Map) {
            return MailMessage.fromJson(Map<String, dynamic>.from(msgJson));
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> syncMessagePatch(String messageId, Map<String, dynamic> patch) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.patch(
          Uri.parse('$base/mail/$messageId'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode(patch),
        );
      });
    } catch (_) {}
  }

  static Future<void> syncBulkAction(
    List<String> ids,
    String action, {
    Map<String, dynamic> extra = const {},
  }) async {
    if (ids.isEmpty) return;
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.post(
          Uri.parse('$base/mail/bulk'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode({
            'ids': ids,
            'action': action,
            ...extra,
          }),
        );
      });
    } catch (_) {}
  }

  static Future<void> syncEmptyFolder(String folder) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.delete(
          Uri.parse('$base/mail/folder/$folder'),
          headers: ApiService.authHeaders(token),
        );
      });
    } catch (_) {}
  }

  static Future<MailLabel?> createLabelOnServer(String name, String colorHex) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return null;
      final res = await ApiService.safeRequest((base) {
        return http.post(
          Uri.parse('$base/mail/labels'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode({'name': name, 'color': colorHex}),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = parsed['data']?['label'];
        if (raw is Map) {
          return MailLabel.fromJson(Map<String, dynamic>.from(raw));
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteLabelOnServer(String labelId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.delete(
          Uri.parse('$base/mail/labels/$labelId'),
          headers: ApiService.authHeaders(token),
        );
      });
    } catch (_) {}
  }

  static Future<void> syncSettings(MailSettings settings) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.put(
          Uri.parse('$base/mail/settings'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode(settings.toJson()),
        );
      });
    } catch (_) {}
  }

  static Future<MailTemplate?> saveTemplateOnServer({
    String? id,
    required String name,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return null;
      final res = await ApiService.safeRequest((base) {
        return http.post(
          Uri.parse('$base/mail/templates'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode({
            'id': ?id,
            'name': name,
            'subject': subject,
            'body': body,
            'htmlBody': ?htmlBody,
          }),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final raw = (jsonDecode(res.body) as Map<String, dynamic>)['data']?['template'];
        if (raw is Map) return MailTemplate.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteTemplateOnServer(String templateId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.delete(
          Uri.parse('$base/mail/templates/$templateId'),
          headers: ApiService.authHeaders(token),
        );
      });
    } catch (_) {}
  }

  static Future<MailContact?> saveContactOnServer({
    required String name,
    required String email,
    String phone = '',
    String company = '',
    String notes = '',
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return null;
      final res = await ApiService.safeRequest((base) {
        return http.post(
          Uri.parse('$base/mail/contacts'),
          headers: ApiService.authHeaders(token),
          body: jsonEncode({
            'name': name,
            'email': email,
            'phone': phone,
            'company': company,
            'notes': notes,
          }),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final raw = (jsonDecode(res.body) as Map<String, dynamic>)['data']?['contact'];
        if (raw is Map) return MailContact.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteContactOnServer(String contactId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return;
      await ApiService.safeRequest((base) {
        return http.delete(
          Uri.parse('$base/mail/contacts/$contactId'),
          headers: ApiService.authHeaders(token),
        );
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> syncImapMailbox() async {
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) return null;
      final res = await ApiService.safeRequest((base) {
        return http.post(
          Uri.parse('$base/mail/sync-imap'),
          headers: ApiService.authHeaders(token),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return decoded['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }
}
