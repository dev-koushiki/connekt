import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/social_models.dart';
import 'api_service.dart';

class ApiActionOutcome<T> {
  final bool success;
  final String? code;
  final String? requiredFeature;
  final String message;
  final T? data;

  const ApiActionOutcome({
    required this.success,
    this.code,
    this.requiredFeature,
    this.message = '',
    this.data,
  });

  bool get requiresSubscription => code == 'SUBSCRIPTION_REQUIRED';
}

/// REST client for Social Mode, Professional Mode, Subscriptions, and Communities.
class SocialService {
  static Future<Map<String, String>> _headers() async {
    final token = await ApiService.getToken();
    return ApiService.authHeaders(token);
  }

  static ApiActionOutcome<T> _parseOutcome<T>(
    http.Response res,
    T Function(Map<String, dynamic> data)? mapper,
  ) {
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] != false;
      final dataMap = decoded['data'] is Map
          ? Map<String, dynamic>.from(decoded['data'] as Map)
          : <String, dynamic>{};
      return ApiActionOutcome<T>(
        success: ok,
        code: decoded['code']?.toString(),
        requiredFeature: decoded['requiredFeature']?.toString(),
        message: (decoded['message'] ?? '').toString(),
        data: ok && mapper != null ? mapper(dataMap) : null,
      );
    } catch (e) {
      return ApiActionOutcome<T>(success: false, message: e.toString());
    }
  }

  // -------------------------
  // SOCIAL & PRO FEED
  // -------------------------
  static Future<List<SocialPost>> getFeed({
    required String mode,
    String filter = 'all',
  }) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/social/feed?mode=$mode&filter=$filter'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
      return (data['posts'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((p) => SocialPost.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }
    return [];
  }

  static Future<SocialPost?> createPost({
    required String mode,
    String postType = 'text',
    String title = '',
    required String content,
    List<SocialMediaAttachment> mediaUrls = const [],
    String visibility = 'public',
    String? sharedPostId,
  }) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/posts'),
        headers: h,
        body: jsonEncode({
          'mode': mode,
          'postType': postType,
          'title': title,
          'content': content,
          'mediaUrls': mediaUrls.map((m) => m.toJson()).toList(),
          'visibility': visibility,
          'sharedPostId': ?sharedPostId,
        }),
      );
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final p = jsonDecode(res.body)['data']?['post'];
      if (p is Map) return SocialPost.fromJson(Map<String, dynamic>.from(p));
    }
    return null;
  }

  static Future<bool> updatePost(String postId, {String? content, String? visibility}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.patch(
        Uri.parse('$base/social/posts/$postId'),
        headers: h,
        body: jsonEncode({
          'content': ?content,
          'visibility': ?visibility,
        }),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> deletePost(String postId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.delete(Uri.parse('$base/social/posts/$postId'), headers: h);
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> reactToPost(String postId, String reactionType) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/posts/$postId/react'),
        headers: h,
        body: jsonEncode({'reactionType': reactionType}),
      );
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<List<PostComment>> getComments(String postId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/social/posts/$postId/comments'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final raw = jsonDecode(res.body)['data']?['comments'] as List<dynamic>? ?? const [];
      return raw.whereType<Map>().map((c) => PostComment.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  static Future<PostComment?> addComment(String postId, String content, {String? parentCommentId}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/posts/$postId/comments'),
        headers: h,
        body: jsonEncode({
          'content': content,
          'parentCommentId': ?parentCommentId,
        }),
      );
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final raw = jsonDecode(res.body)['data']?['comment'];
      if (raw is Map) return PostComment.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  static Future<bool?> toggleSavePost(String postId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/social/posts/$postId/save'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data']?['isSaved'] == true;
    }
    return null;
  }

  static Future<bool> shareWithUsers(String postId, List<String> recipientIds, {String note = ''}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/posts/$postId/share-users'),
        headers: h,
        body: jsonEncode({'recipientIds': recipientIds, 'note': note}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<SocialMediaAttachment?> uploadSocialMedia({
    required String filename,
    required Uint8List bytes,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return null;
      final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/social/media'));
      req.headers.addAll({'Authorization': 'Bearer $token', 'bypass-tunnel-reminder': 'true'});
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        final d = jsonDecode(body)['data'] as Map<String, dynamic>;
        return SocialMediaAttachment.fromJson(d);
      }
    } catch (_) {}
    return null;
  }

  // -------------------------
  // CONNECTIONS, PEOPLE, PROFILES, BLOCKING, REPORTING
  // -------------------------
  static Future<Map<String, dynamic>> getPeopleOverview({String kind = 'friend'}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/social/people?kind=$kind'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
    }
    return const {};
  }

  static Future<List<PersonSummary>> searchUsers(String query) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/social/users/search?q=${Uri.encodeQueryComponent(query)}'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body)['data']?['users'] as List<dynamic>? ?? const [];
      return list.whereType<Map>().map((u) => PersonSummary.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId, {String mode = 'social'}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/social/users/$userId/profile?mode=$mode'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data']?['profile'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<bool> sendConnectionRequest(String addresseeId, {String kind = 'friend'}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/connections'),
        headers: h,
        body: jsonEncode({'addresseeId': addresseeId, 'kind': kind}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> respondConnectionRequest(String requestId, String action) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/connections/$requestId/respond'),
        headers: h,
        body: jsonEncode({'action': action}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool?> toggleFollow(String userId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/social/follow/$userId'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data']?['isFollowing'] == true;
    }
    return null;
  }

  static Future<bool> updateSocialProfile(Map<String, dynamic> patch) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.put(Uri.parse('$base/social/profile'), headers: h, body: jsonEncode(patch));
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> blockUser(String userId, {String reason = 'User blocked'}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/block/$userId'),
        headers: h,
        body: jsonEncode({'reason': reason}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
  }) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/social/reports'),
        headers: h,
        body: jsonEncode({'targetType': targetType, 'targetId': targetId, 'reason': reason}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<void> markNotificationsRead() async {
    final h = await _headers();
    await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/social/notifications/read'), headers: h);
    });
  }

  // -------------------------
  // PROFESSIONAL & SUBSCRIPTIONS
  // -------------------------
  static Future<Map<String, dynamic>> getSubscriptionOverview() async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/subscriptions/plans'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
    }
    return const {};
  }

  static Future<ApiActionOutcome<UserSubscriptionState>> subscribePlan(String planId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/subscriptions/subscribe'),
        headers: h,
        body: jsonEncode({'planId': planId}),
      );
    });
    return _parseOutcome(res, (data) => UserSubscriptionState.fromJson(Map<String, dynamic>.from(data['currentSubscription'] ?? const {})));
  }

  static Future<ApiActionOutcome<UserSubscriptionState>> cancelSubscription({String mode = 'cancelled'}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/subscriptions/cancel'),
        headers: h,
        body: jsonEncode({'mode': mode}),
      );
    });
    return _parseOutcome(res, (data) => UserSubscriptionState.fromJson(Map<String, dynamic>.from(data['currentSubscription'] ?? const {})));
  }

  static Future<Map<String, dynamic>> listJobsAndCompanies({String jobType = 'all', String q = ''}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(
        Uri.parse('$base/professional/jobs?jobType=$jobType&q=${Uri.encodeQueryComponent(q)}'),
        headers: h,
      );
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
    }
    return const {};
  }

  static Future<ApiActionOutcome<JobListing>> createJob(Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/professional/jobs'), headers: h, body: jsonEncode(payload));
    });
    return _parseOutcome(res, (data) => JobListing.fromJson(Map<String, dynamic>.from(data['job'] ?? const {})));
  }

  static Future<ApiActionOutcome<CompanyProfile>> createCompany(Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/professional/companies'), headers: h, body: jsonEncode(payload));
    });
    return _parseOutcome(res, (data) => CompanyProfile.fromJson(Map<String, dynamic>.from(data['company'] ?? const {})));
  }

  static Future<ApiActionOutcome<Map<String, dynamic>>> applyForJob(String jobId, {String resumeUrl = '', String coverNote = ''}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/professional/jobs/$jobId/apply'),
        headers: h,
        body: jsonEncode({'resumeUrl': resumeUrl, 'coverNote': coverNote}),
      );
    });
    return _parseOutcome(res, (data) => data);
  }

  static Future<ApiActionOutcome<Map<String, dynamic>>> publishArticle({required String title, required String content}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/professional/articles'),
        headers: h,
        body: jsonEncode({'title': title, 'content': content}),
      );
    });
    return _parseOutcome(res, (data) => data);
  }

  static Future<ApiActionOutcome<Map<String, dynamic>>> getProfileAnalytics() async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/professional/analytics'), headers: h);
    });
    return _parseOutcome(res, (data) => data);
  }

  static Future<bool> updateProProfile(Map<String, dynamic> patch) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.put(Uri.parse('$base/professional/profile'), headers: h, body: jsonEncode(patch));
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> addCertification(Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/professional/certifications'), headers: h, body: jsonEncode(payload));
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> addProject(Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/professional/projects'), headers: h, body: jsonEncode(payload));
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<Map<String, dynamic>?> endorseSkill(int skillId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/professional/skills/$skillId/endorse'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<bool> addRecommendation(String userId, {String relationship = 'Colleague', required String content}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/professional/recommendations/$userId'),
        headers: h,
        body: jsonEncode({'relationship': relationship, 'content': content}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  // -------------------------
  // COMMUNITIES, GROUPS & LIVE
  // -------------------------
  static Future<List<CommunityModel>> listCommunities({String q = ''}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/communities?q=${Uri.encodeQueryComponent(q)}'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final list = jsonDecode(res.body)['data']?['communities'] as List<dynamic>? ?? const [];
      return list.whereType<Map>().map((c) => CommunityModel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  static Future<CommunityModel?> createCommunity(Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities'), headers: h, body: jsonEncode(payload));
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final c = jsonDecode(res.body)['data']?['community'];
      if (c is Map) return CommunityModel.fromJson(Map<String, dynamic>.from(c));
    }
    return null;
  }

  static Future<Map<String, dynamic>> getCommunityDetail(String communityId, {String? groupId}) async {
    final h = await _headers();
    final qs = groupId != null ? '?groupId=$groupId' : '';
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/communities/$communityId$qs'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
    }
    return const {};
  }

  static Future<Map<String, dynamic>?> joinCommunity(String communityId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/$communityId/join'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<bool> leaveCommunity(String communityId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/$communityId/leave'), headers: h);
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> manageCommunityMember(String communityId, {required String userId, required String action, String? role}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/communities/$communityId/members'),
        headers: h,
        body: jsonEncode({'userId': userId, 'action': action, 'role': ?role}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<CommunityGroupModel?> createGroup(String communityId, Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/$communityId/groups'), headers: h, body: jsonEncode(payload));
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final g = jsonDecode(res.body)['data']?['group'];
      if (g is Map) return CommunityGroupModel.fromJson(Map<String, dynamic>.from(g));
    }
    return null;
  }

  static Future<bool?> toggleJoinGroup(String groupId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/groups/$groupId/toggle-join'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data']?['isMember'] == true;
    }
    return null;
  }

  static Future<bool> createCommunityPost(String communityId, Map<String, dynamic> payload) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/$communityId/posts'), headers: h, body: jsonEncode(payload));
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> moderateCommunityPost(String postId, String action) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/communities/posts/$postId/moderate'),
        headers: h,
        body: jsonEncode({'action': action}),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<CommunityLiveSession?> startOrScheduleLive(
    String communityId, {
    required String title,
    String description = '',
    String? groupId,
    DateTime? scheduledFor,
  }) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/communities/$communityId/live'),
        headers: h,
        body: jsonEncode({
          'title': title,
          'description': description,
          'groupId': ?groupId,
          if (scheduledFor != null) 'scheduledFor': scheduledFor.toIso8601String(),
        }),
      );
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final s = jsonDecode(res.body)['data']?['session'];
      if (s is Map) return CommunityLiveSession.fromJson(Map<String, dynamic>.from(s));
    }
    return null;
  }

  static Future<Map<String, dynamic>> getLiveSessionDetail(String sessionId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.get(Uri.parse('$base/communities/live/$sessionId'), headers: h);
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body)['data'] as Map<String, dynamic>? ?? const {};
    }
    return const {};
  }

  static Future<bool> postLiveComment(String sessionId, {String content = '', bool isReaction = false, String? reactionType}) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(
        Uri.parse('$base/communities/live/$sessionId/comments'),
        headers: h,
        body: jsonEncode({
          'content': content,
          'isReaction': isReaction,
          'reactionType': ?reactionType,
        }),
      );
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  static Future<bool> endLiveSession(String sessionId) async {
    final h = await _headers();
    final res = await ApiService.safeRequest((base) {
      return http.post(Uri.parse('$base/communities/live/$sessionId/end'), headers: h);
    });
    return res.statusCode >= 200 && res.statusCode < 300;
  }
}
