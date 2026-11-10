import 'dart:convert';
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
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      return await requestFn(ApiConfig.baseUrl).timeout(timeout);
    } catch (e) {
      // If network error occurred, automatically probe candidate server hosts
      final recovered = await ApiConfig.autoDetectHost();
      if (recovered != null) {
        try {
          return await requestFn(ApiConfig.baseUrl).timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      final errStr = e.toString();
      if (errStr.contains('TimeoutException') ||
          errStr.contains('SocketException') ||
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

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/logout');
      try {
        await http.post(url, headers: _headers(token));
      } catch (_) {}
    }
    await clearToken();
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
}
