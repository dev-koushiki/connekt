import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

/// Service to interface with Android's native CallLog ContentProvider
/// and synchronize phone contacts/call history with the CONNEKT ecosystem.
class CallLogService {
  static const MethodChannel _channel = MethodChannel('com.connekt.app/call_logs');

  /// Notifies mounted UI screens whenever call logs are loaded or synced.
  static final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);

  /// Latest normalized call logs cached in memory for instant display across tabs.
  static List<Map<String, dynamic>> cachedLogs = const [];

  /// Last observed native READ_CALL_LOG permission state on Android (null if non-Android).
  static bool? lastPermissionGranted;

  /// Check whether READ_CALL_LOG permission is currently granted.
  static Future<bool> checkPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('checkPermission');
      lastPermissionGranted = res ?? false;
      return lastPermissionGranted!;
    } on MissingPluginException {
      lastPermissionGranted = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime permissions from the user.
  static Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      lastPermissionGranted = res ?? false;
      return lastPermissionGranted!;
    } on MissingPluginException {
      lastPermissionGranted = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetch normalized call logs directly from Android device storage.
  static Future<List<Map<String, dynamic>>> fetchDeviceCallLogs({int limit = 100}) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getCallLogs', {'limit': limit});
      if (raw == null) return [];
      final normalized = raw
          .whereType<Map>()
          .map((item) => normalizeCallLog(Map<String, dynamic>.from(item)))
          .toList();
      if (normalized.isNotEmpty) {
        cachedLogs = normalized;
      }
      return normalized;
    } catch (_) {
      return [];
    }
  }

  /// Load call logs from native device storage first, falling back to synced backend records.
  static Future<List<Map<String, dynamic>>> loadCallLogs({
    int limit = 100,
    bool requestIfNeeded = false,
  }) async {
    bool hasPerm = await checkPermission();
    if (!hasPerm && requestIfNeeded) {
      hasPerm = await requestPermission();
    }

    if (hasPerm) {
      final deviceLogs = await fetchDeviceCallLogs(limit: limit);
      if (deviceLogs.isNotEmpty) {
        return deviceLogs;
      }
    }

    final token = await ApiService.getToken();
    if (token != null && token.isNotEmpty) {
      final remoteLogs = await ApiService.getDeviceCallLogs(limit: limit);
      if (remoteLogs.isNotEmpty) {
        final normalized = remoteLogs.map(normalizeCallLog).toList();
        cachedLogs = normalized;
        return normalized;
      }
    }

    return cachedLogs;
  }

  /// Fetch call logs and upload them to the CONNEKT backend server
  /// for access via the web client / website dashboard.
  static Future<Map<String, dynamic>> syncCallLogs({int limit = 100}) async {
    try {
      bool hasPerm = await checkPermission();
      if (!hasPerm) {
        hasPerm = await requestPermission();
        if (!hasPerm) {
          syncNotifier.value++;
          return {
            'success': false,
            'message': 'Permission denied by user to access device call logs.'
          };
        }
      }

      final logs = await fetchDeviceCallLogs(limit: limit);
      if (logs.isEmpty) {
        syncNotifier.value++;
        return {
          'success': true,
          'count': 0,
          'message': 'No call logs found on device.'
        };
      }

      cachedLogs = logs;
      syncNotifier.value++;

      final uploadPayload = logs
          .map((e) => {
                'name': e['name'],
                'number': e['number'],
                'type': e['type'],
                'duration': e['duration'],
                'timestamp': e['timestampMs'],
              })
          .toList();

      final uploadRes = await ApiService.uploadDeviceCallLogs(uploadPayload);
      syncNotifier.value++;
      return uploadRes;
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to sync device call logs: $e'
      };
    }
  }

  /// Normalize native Android or backend API call log entries into a single UI schema.
  static Map<String, dynamic> normalizeCallLog(Map<String, dynamic> raw) {
    final number = (raw['number'] ?? raw['phone_number'] ?? '').toString().trim();
    final rawName = (raw['name'] ?? raw['contact_name'] ?? '').toString().trim();
    final name = rawName.isNotEmpty ? rawName : (number.isNotEmpty ? number : 'Unknown Caller');
    final type = (raw['type'] ?? raw['call_type'] ?? 'unknown').toString().trim().toLowerCase();
    final duration = int.tryParse((raw['duration'] ?? raw['duration_seconds'] ?? '0').toString()) ?? 0;

    final tsMs = _parseTimestampMs(raw['timestampMs'] ?? raw['timestamp'] ?? raw['call_timestamp']);
    return {
      'name': name,
      'number': number,
      'type': type,
      'duration': duration,
      'timestamp': tsMs,
      'timestampMs': tsMs,
      'formattedTime': formatTimestamp(tsMs),
      'formattedDuration': formatDuration(duration),
    };
  }

  static int _parseTimestampMs(dynamic rawTs) {
    if (rawTs is int) return rawTs;
    if (rawTs is num) return rawTs.toInt();
    if (rawTs is String && rawTs.trim().isNotEmpty) {
      final asInt = int.tryParse(rawTs.trim());
      if (asInt != null) return asInt;
      final parsed = DateTime.tryParse(rawTs.trim());
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// Format epoch milliseconds as 'Today, 11:32 am', 'Yesterday, 6:30 pm', or 'Nov 12, 11:32 am'.
  static String formatTimestamp(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final callDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(callDate).inDays;

    final hour24 = dt.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'pm' : 'am';
    final timeStr = '$hour12:$minute $period';

    if (diffDays == 0) return 'Today, $timeStr';
    if (diffDays == 1) return 'Yesterday, $timeStr';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }

  /// Format duration seconds into compact human text (e.g. '1m 24s' or '42s').
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}
