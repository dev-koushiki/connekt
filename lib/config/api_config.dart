import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _hostKey = 'connekt_server_host';

  // PC's current detected Wi-Fi IP address
  static String defaultHost = '192.168.29.98:5000';
  static String currentHost = defaultHost;

  // Stale or deprecated development IPs to automatically prune
  static const List<String> staleHosts = [
    '10.161.165.196:5000',
    '192.168.188.196:5000',
  ];

  // Common network IPs and cloud tunnels tested during auto-detection
  static const List<String> candidateHosts = [
    'https://plain-clouds-take.loca.lt', // Active Cloud Tunnel (works on 5G / 4G Mobile Data worldwide!)
    'https://swift-hoops-trade.loca.lt',
    '192.168.29.98:5000',               // Current Wi-Fi IP
    '192.168.188.196:5000',             // Previous Wi-Fi IP
    '192.168.1.15:5000',
    '192.168.1.5:5000',
    '192.168.0.100:5000',
    '192.168.43.1:5000',                // Mobile Hotspot Gateway IP
    'localhost:5000',                   // USB Cable reverse mode (adb reverse tcp:5000 tcp:5000)
    '127.0.0.1:5000',
    '10.0.2.2:5000',                    // Android Emulator host loopback
  ];

  /// Initialize and load saved server host from storage
  static Future<void> loadHost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_hostKey);

      // If saved host exists and is not an outdated stale temporary IP
      if (saved != null &&
          saved.trim().isNotEmpty &&
          !staleHosts.any((stale) => saved.contains(stale))) {
        currentHost = saved.trim();
      } else {
        currentHost = defaultHost;
        await prefs.setString(_hostKey, defaultHost);
      }
    } catch (_) {
      currentHost = defaultHost;
    }
  }

  /// Persist a newly selected host
  static Future<void> setHost(String host) async {
    final prefs = await SharedPreferences.getInstance();
    currentHost = host.trim();
    await prefs.setString(_hostKey, currentHost);
  }

  /// Format an endpoint safely, supporting HTTPS cloud tunnels (e.g. *.loca.lt, *.ngrok.app)
  static String formatEndpoint(String hostOrUrl, {String endpoint = '/api'}) {
    String clean = hostOrUrl.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean.endsWith(endpoint) ? clean : '$clean$endpoint';
    }
    return 'http://$clean$endpoint';
  }

  /// Get the full REST API base URL
  static String get baseUrl {
    if (kIsWeb) {
      if (currentHost.isEmpty || currentHost == defaultHost) {
        return 'http://localhost:5000/api';
      }
    }
    return formatEndpoint(currentHost, endpoint: '/api');
  }

  /// Get the root URL for WebSocket connections
  static String get rootUrl {
    String clean = currentHost.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.endsWith('/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    return 'http://$clean';
  }

  /// Test connectivity to a given candidate server host
  static Future<bool> testHost(String host, {Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final healthUrl = formatEndpoint(host, endpoint: '/api/health');
      final res = await http.get(
        Uri.parse(healthUrl),
        headers: {'bypass-tunnel-reminder': 'true'},
      ).timeout(timeout);
      if (res.statusCode == 200 && res.body.contains('CONNEKT')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Automatically scan and find the currently reachable server across networks
  static Future<String?> autoDetectHost() async {
    // 1. First test if currentHost is already responding
    if (await testHost(currentHost, timeout: const Duration(milliseconds: 1000))) {
      return currentHost;
    }

    // 2. Build list of unique candidate hosts to probe
    final probeList = <String>[];
    if (currentHost.isNotEmpty && !probeList.contains(currentHost)) {
      probeList.add(currentHost);
    }
    for (final c in candidateHosts) {
      if (!probeList.contains(c)) probeList.add(c);
    }

    // 3. Probe candidate hosts in parallel
    final completer = Completer<String?>();
    int pending = probeList.length;

    for (final host in probeList) {
      testHost(host, timeout: const Duration(milliseconds: 1600)).then((isAlive) {
        if (isAlive && !completer.isCompleted) {
          completer.complete(host);
        } else {
          pending--;
          if (pending <= 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((_) {
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    final detected = await completer.future;
    if (detected != null) {
      await setHost(detected);
      return detected;
    }

    return null;
  }
}
