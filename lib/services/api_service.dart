import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class ApiService {
  static const String _tokenKey = 'connekt_jwt_token';
  static const String _cachedUserKey = 'connekt_cached_user';

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_cachedUserKey);
    } catch (_) {}
  }

  static Future<UserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedUserKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw);
        return UserModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveCachedUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  static Map<String, String> _headers(String? token) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'bypass-tunnel-reminder': 'true',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static Future<http.Response> _safeRequest(
    Future<http.Response> Function(String baseUrl) requestFn, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      return await requestFn(ApiConfig.baseUrl).timeout(timeout);
    } catch (e) {
      // If network error occurred, automatically probe candidate server hosts & LAN subnet
      final recovered = await ApiConfig.autoDetectHost();
      if (recovered != null) {
        try {
          return await requestFn(ApiConfig.baseUrl).timeout(timeout);
        } catch (retryErr) {
          final retryStr = retryErr.toString();
          if (retryStr.contains('TimeoutException') ||
              retryStr.contains('SocketException') ||
              retryStr.contains('ClientException') ||
              retryStr.contains('Failed host lookup') ||
              retryStr.contains('Connection refused')) {
            throw Exception(
              'Cannot reach server (${ApiConfig.currentHost}). Make sure the backend server is running on PC or tap ⚙️ Settings.',
            );
          }
          rethrow;
        }
      }
      final errStr = e.toString();
      if (errStr.contains('TimeoutException') ||
          errStr.contains('SocketException') ||
          errStr.contains('ClientException') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('Connection refused')) {
        throw Exception(
          'Cannot reach server (${ApiConfig.currentHost}). If on 5G/Mobile Data, turn on Wi-Fi (same as PC) or tap ⚙️ Settings.',
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> sendOtp(String identifier, {String purpose = 'registration'}) async {
    final res = await _safeRequest((base) {
      return http.post(
        Uri.parse('$base/auth/send-otp'),
        headers: _headers(null),
        body: jsonEncode({'identifier': identifier, 'purpose': purpose}),
      );
    });
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }
    return data;
  }

  static Future<UserModel> register({
    required String phone,
    required String otpCode,
    required String username,
    required String fullName,
    required String password,
    String currentMode = 'common',
  }) async {
    final res = await _safeRequest((base) {
      return http.post(
        Uri.parse('$base/auth/register'),
        headers: _headers(null),
        body: jsonEncode({
          'phone': phone,
          'otpCode': otpCode,
          'username': username,
          'fullName': fullName,
          'password': password,
          'currentMode': currentMode,
        }),
      );
    });
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Registration failed');
    }

    final token = data['data']['token'] as String;
    await saveToken(token);
    final user = UserModel.fromJson(data['data']['user']);
    await saveCachedUser(user);
    return user;
  }

  static Future<UserModel> loginWithOtp({
    required String phone,
    required String otpCode,
  }) async {
    final res = await _safeRequest((base) {
      return http.post(
        Uri.parse('$base/auth/login'),
        headers: _headers(null),
        body: jsonEncode({
          'identifier': phone,
          'otpCode': otpCode,
          'loginType': 'otp',
        }),
      );
    });
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'OTP Login failed');
    }

    final token = data['data']['token'] as String;
    await saveToken(token);
    final user = UserModel.fromJson(data['data']['user']);
    await saveCachedUser(user);
    return user;
  }

  static Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _safeRequest((base) {
      return http.post(
        Uri.parse('$base/auth/login'),
        headers: _headers(null),
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'loginType': 'password',
        }),
      );
    });
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Login failed');
    }

    final token = data['data']['token'] as String;
    await saveToken(token);
    final user = UserModel.fromJson(data['data']['user']);
    await saveCachedUser(user);
    return user;
  }

  static Future<UserModel?> getMe() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final res = await _safeRequest((base) {
        return http.get(Uri.parse('$base/auth/me'), headers: _headers(token));
      }, timeout: const Duration(seconds: 4));

      if (res.statusCode == 401) {
        await clearToken();
        return null;
      }
      final data = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        return null;
      }
      final user = UserModel.fromJson(data['data']['user']);
      await saveCachedUser(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<UserModel> updatePersonalProfile({
    String? fullName,
    String? displayName,
    String? bio,
    String? location,
    String? website,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/profile/personal');
    final payload = <String, dynamic>{};
    if (fullName != null) payload['fullName'] = fullName;
    if (displayName != null) payload['displayName'] = displayName;
    if (bio != null) payload['bio'] = bio;
    if (location != null) payload['location'] = location;
    if (website != null) payload['website'] = website;

    final res = await http
        .put(
          url,
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to update personal profile');
    }

    final refreshed = await getMe();
    if (refreshed != null) {
      await saveCachedUser(refreshed);
      return refreshed;
    }
    final cached = await getCachedUser();
    return cached!;
  }

  static Future<UserModel> updateProfessionalProfile({
    String? headline,
    String? currentCompany,
    String? industry,
    String? summary,
    int? yearsOfExperience,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/profile/professional');
    final payload = <String, dynamic>{};
    if (headline != null) payload['headline'] = headline;
    if (currentCompany != null) payload['currentCompany'] = currentCompany;
    if (industry != null) payload['industry'] = industry;
    if (summary != null) payload['summary'] = summary;
    if (yearsOfExperience != null) payload['yearsOfExperience'] = yearsOfExperience;

    final res = await http
        .put(
          url,
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to update professional profile');
    }

    final refreshed = await getMe();
    if (refreshed != null) {
      await saveCachedUser(refreshed);
      return refreshed;
    }
    final cached = await getCachedUser();
    return cached!;
  }

  /// Upload a profile avatar image as multipart/form-data ('avatar') and return
  /// the refreshed [UserModel]. Works across mobile, desktop, and web.
  static Future<UserModel> uploadAvatar(
    Uint8List bytes,
    String fileName, {
    UserModel? currentUser,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please sign in again.');
    }

    final safeName = _normalizeImageFilename(fileName);

    Future<http.Response> sendUpload(String baseUrl) async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/users/profile/avatar'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['bypass-tunnel-reminder'] = 'true';
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: safeName),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 20));
      return http.Response.fromStream(streamed);
    }

    http.Response response;
    try {
      response = await sendUpload(ApiConfig.baseUrl);
    } catch (e) {
      final recovered = await ApiConfig.autoDetectHost();
      if (recovered != null) {
        response = await sendUpload(ApiConfig.baseUrl);
      } else {
        rethrow;
      }
    }

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = {'message': 'Unexpected server response (${response.statusCode})'};
    }

    if (response.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to upload profile picture');
    }

    final payload = data['data'] as Map<String, dynamic>?;
    final rawUser = payload?['user'];
    if (rawUser is Map<String, dynamic>) {
      final updated = UserModel.fromJson(rawUser);
      await saveCachedUser(updated);
      return updated;
    }

    final avatarUrl = payload?['avatarUrl']?.toString() ?? '';
    final refreshed = await getMe();
    if (refreshed != null) {
      await saveCachedUser(refreshed);
      return refreshed;
    }

    final baseUser = currentUser ?? await getCachedUser();
    if (baseUser != null) {
      final existingProfile = baseUser.personalProfile ??
          PersonalProfile(
            fullName: baseUser.username,
            displayName: baseUser.username,
            avatarUrl: '',
            bio: '',
            location: '',
            website: '',
          );
      final patched = baseUser.copyWith(
        personalProfile: existingProfile.copyWith(avatarUrl: avatarUrl),
      );
      await saveCachedUser(patched);
      return patched;
    }

    throw Exception('Avatar uploaded, but failed to refresh user profile');
  }

  static String _normalizeImageFilename(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) return 'avatar.jpg';
    final base = trimmed.split(RegExp(r'[/\\]')).last;
    final lower = base.toLowerCase();
    const allowedExts = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif'];
    if (allowedExts.any((ext) => lower.endsWith(ext))) {
      return base;
    }
    return '$base.jpg';
  }

  static Future<String> switchMode(String mode) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/users/mode');
    final res = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({'mode': mode}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to switch mode');
    }
    return data['data']['currentMode'] ?? mode;
  }

  /// Notify the backend to revoke the active JWT session without throwing.
  static Future<void> revokeSessionOnServer(
    String? token, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    if (token == null || token.isEmpty) return;
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/logout');
    try {
      await http.post(url, headers: _headers(token)).timeout(timeout);
    } catch (_) {}
  }

  /// Clear local auth state first, then best-effort revoke the token on server.
  static Future<void> logout({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final token = await getToken();
    await clearToken();
    await revokeSessionOnServer(token, timeout: timeout);
  }

  static Future<List<Map<String, dynamic>>> getContacts({String? query}) async {
    final token = await getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}/users/contacts').replace(
      queryParameters: query != null && query.isNotEmpty ? {'q': query} : null,
    );
    try {
      final res = await http.get(uri, headers: _headers(token));
      if (res.statusCode < 400) {
        final data = jsonDecode(res.body);
        final list = data['data']?['contacts'] as List<dynamic>?;
        if (list != null) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createInstantMeeting({String? title}) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/meetings/rooms/create');
    final res = await http
        .post(
          url,
          headers: _headers(token),
          body: jsonEncode({'title': title ?? 'Instant Meeting'}),
        )
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to create instant meeting');
    }
    return (data['data'] as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> scheduleMeeting({
    required String title,
    required DateTime scheduledAt,
    int durationMinutes = 45,
    String? description,
    String? agenda,
  }) async {
    final token = await getToken();
    final url = Uri.parse('${ApiConfig.baseUrl}/meetings');
    final payload = <String, dynamic>{
      'title': title,
      'scheduledAt': scheduledAt.toIso8601String(),
      'durationMinutes': durationMinutes,
    };
    if (description != null && description.isNotEmpty) payload['description'] = description;
    if (agenda != null && agenda.isNotEmpty) payload['agenda'] = agenda;

    final res = await http
        .post(
          url,
          headers: _headers(token),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to schedule meeting');
    }
    return (data['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Get list of active conversations for current user
  static Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final token = await getToken();
      final res = await _safeRequest((base) {
        return http.get(
          Uri.parse('$base/chats'),
          headers: _headers(token),
        );
      });
      final data = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        return [];
      }
      final list = data['data'] as List<dynamic>?;
      if (list != null) {
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Get message history for a conversation or target contact (phone / username)
  static Future<List<Map<String, dynamic>>> getChatMessages(String target) async {
    try {
      final token = await getToken();
      final encodedTarget = Uri.encodeComponent(target.trim());
      final res = await _safeRequest((base) {
        return http.get(
          Uri.parse('$base/chats/$encodedTarget/messages'),
          headers: _headers(token),
        );
      });
      final data = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        return [];
      }
      final payload = data['data'] as Map<String, dynamic>?;
      final list = payload?['messages'] as List<dynamic>?;
      if (list != null) {
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Send a message to a recipient (phone number or username) and dispatch real SMS
  static Future<Map<String, dynamic>> sendChatMessage(String recipient, String content) async {
    final token = await getToken();
    final res = await _safeRequest((base) {
      return http.post(
        Uri.parse('$base/chats/send'),
        headers: _headers(token),
        body: jsonEncode({
          'recipient': recipient.trim(),
          'content': content.trim(),
        }),
      );
    });
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['message'] ?? 'Failed to send message');
    }
    return (data['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Upload a file or audio attachment for chat
  static Future<Map<String, dynamic>?> uploadChatFile(String filePath, String fileName) async {
    try {
      final token = await getToken();
      final uri = Uri.parse('${ApiConfig.baseUrl}/chats/upload');
      final request = http.MultipartRequest('POST', uri);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['bypass-tunnel-reminder'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Delete chat message: 'for_me' or 'for_everyone'
  static Future<bool> deleteChatMessage(String messageId, {required bool forEveryone}) async {
    try {
      final token = await getToken();
      final res = await _safeRequest((base) {
        return http.delete(
          Uri.parse('$base/chats/messages/$messageId'),
          headers: _headers(token),
          body: jsonEncode({'mode': forEveryone ? 'for_everyone' : 'for_me'}),
        );
      });
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Upload phone call logs to the backend database
  static Future<Map<String, dynamic>> uploadDeviceCallLogs(List<Map<String, dynamic>> logs) async {
    try {
      final token = await getToken();
      final res = await _safeRequest((base) {
        return http.post(
          Uri.parse('$base/calls/device-logs'),
          headers: _headers(token),
          body: jsonEncode({'logs': logs}),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}: ${res.body}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch call logs stored in backend database
  static Future<List<Map<String, dynamic>>> getDeviceCallLogs({String type = 'all', int limit = 50}) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return [];
      final res = await _safeRequest((base) {
        return http.get(
          Uri.parse('$base/calls/device-logs?type=$type&limit=$limit'),
          headers: _headers(token),
        );
      });
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data['data'] != null && data['data']['logs'] is List) {
          return List<Map<String, dynamic>>.from(data['data']['logs']);
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Check if the website has requested call logs sync
  static Future<bool> checkCallSyncRequested() async {
    try {
      final token = await getToken();
      final res = await _safeRequest((base) {
        return http.get(
          Uri.parse('$base/calls/sync-status'),
          headers: _headers(token),
        );
      }, timeout: const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data['data']?['syncRequested'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
