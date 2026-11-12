import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'subnet_probe_stub.dart' if (dart.library.io) 'subnet_probe_io.dart';

class ApiConfig {
  static const String _hostKey = 'connekt_server_host';

  // PC's current detected Wi-Fi IP address
  static String defaultHost = '192.168.161.196:5000';
  static String currentHost = defaultHost;
  static Future<String?>? _inFlightDetect;

  // Stale or deprecated development IPs/tunnels to automatically prune
  static const List<String> staleHosts = [
    '10.161.165.196:5000',
    'https://plain-spiders-tease.loca.lt',
    'https://plain-clouds-take.loca.lt',
    'https://swift-hoops-trade.loca.lt',
    'https://tame-paws-smell.loca.lt',
    'https://puny-dryers-cover.loca.lt',
  ];

  // Common network IPs and cloud tunnels tested during auto-detection
  static const List<String> candidateHosts = [
    '192.168.161.196:5000',             // Current Wi-Fi IP
    'localhost:5000',                   // USB Cable reverse mode (adb reverse tcp:5000 tcp:5000)
    '127.0.0.1:5000',
    'https://fifty-heads-train.loca.lt', // Active Cloud Tunnel (5G / 4G Mobile Data)
    'https://silver-geckos-warn.loca.lt',
    '192.168.29.98:5000',               // Previous Wi-Fi IP
    '192.168.188.196:5000',             // Previous Wi-Fi IP
    '192.168.1.15:5000',
    '192.168.1.5:5000',
    '192.168.0.100:5000',
    '192.168.43.1:5000',                // Mobile Hotspot Gateway IP
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

  /// Default headers required for tunnelled media fetches (e.g. *.loca.lt).
  static const Map<String, String> mediaHeaders = {
    'bypass-tunnel-reminder': 'true',
  };

  /// Get the root URL for WebSocket connections and static media assets.
  static String get rootUrl {
    if (kIsWeb && (currentHost.isEmpty || currentHost == defaultHost)) {
      return 'http://localhost:5000';
    }
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

  /// Resolve a relative backend asset path (e.g. '/uploads/...') or absolute URL.
  static String? resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final clean = rawUrl.trim();
    if (clean.isEmpty) return null;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return clean;
    }
    if (clean.startsWith('//')) {
      return 'https:$clean';
    }
    if (clean.contains('://')) {
      return null;
    }
    if (!clean.startsWith('/') &&
        !clean.startsWith('uploads/') &&
        !clean.startsWith('assets/')) {
      return null;
    }
    final normalizedPath = clean.startsWith('/') ? clean : '/$clean';
    return '$rootUrl$normalizedPath';
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

  /// Automatically scan and find the currently reachable server across networks.
  static Future<String?> autoDetectHost() {
    if (_inFlightDetect != null) return _inFlightDetect!;
    final future = _performAutoDetectHost().whenComplete(() {
      _inFlightDetect = null;
    });
    _inFlightDetect = future;
    return future;
  }

  static Future<String?> _performAutoDetectHost() async {
    // 1. First test if currentHost is already responding.
    if (await testHost(currentHost, timeout: const Duration(milliseconds: 1200))) {
      return currentHost;
    }

    // 2. Build list of unique candidate hosts to probe in parallel.
    final probeList = <String>[];
    for (final c in [defaultHost, ...candidateHosts]) {
      if (c.isNotEmpty && c != currentHost && !probeList.contains(c)) {
        probeList.add(c);
      }
    }

    if (probeList.isNotEmpty) {
      final completer = Completer<String?>();
      int pending = probeList.length;

      for (final host in probeList) {
        testHost(host, timeout: const Duration(milliseconds: 2200)).then((isAlive) {
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
    }

    // 3. Fallback on mobile/desktop: dynamically scan the active Wi-Fi/hotspot /24 subnet.
    final subnetHit = await probeLocalSubnetServer(port: 5000, testHost: testHost);
    if (subnetHit != null) {
      await setHost(subnetHit);
      return subnetHit;
    }

    return null;
  }
}
