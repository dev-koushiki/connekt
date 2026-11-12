import 'dart:async';
import 'dart:io';

/// Probes the device's active private LAN /24 subnets on [port] to locate
/// the CONNEKT server even after router/hotspot DHCP IP changes.
Future<String?> probeLocalSubnetServer({
  int port = 5000,
  required Future<bool> Function(String host, {Duration timeout}) testHost,
}) async {
  // Never spawn raw OS sockets while running inside `flutter test`.
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return null;
  }

  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final prefixes = <String>{};
    final selfIps = <String>{};

    for (final iface in interfaces) {
      final lowerName = iface.name.toLowerCase();
      if (lowerName.contains('tun') ||
          lowerName.contains('tap') ||
          lowerName.contains('vethernet') ||
          lowerName.contains('virtual')) {
        continue;
      }
      for (final addr in iface.addresses) {
        final ip = addr.address;
        if (_isPrivateLanIpv4(ip)) {
          selfIps.add(ip);
          final lastDot = ip.lastIndexOf('.');
          if (lastDot > 0) {
            prefixes.add(ip.substring(0, lastDot));
          }
        }
      }
    }

    if (prefixes.isEmpty) return null;

    // Prioritize common host octets first (e.g. hotspot/router .1, .196, .100, etc.)
    const priorityOctets = [196, 1, 2, 10, 15, 50, 98, 100, 101, 150, 200, 210];
    final orderedIps = <String>[];
    for (final prefix in prefixes) {
      for (final octet in priorityOctets) {
        final ip = '$prefix.$octet';
        if (!selfIps.contains(ip) && !orderedIps.contains(ip)) {
          orderedIps.add(ip);
        }
      }
      for (int octet = 1; octet <= 254; octet++) {
        final ip = '$prefix.$octet';
        if (!selfIps.contains(ip) && !orderedIps.contains(ip)) {
          orderedIps.add(ip);
        }
      }
    }

    const batchSize = 48;
    for (int i = 0; i < orderedIps.length; i += batchSize) {
      final end = (i + batchSize > orderedIps.length) ? orderedIps.length : i + batchSize;
      final batch = orderedIps.sublist(i, end);

      final openHosts = await Future.wait(
        batch.map((ip) async {
          try {
            final socket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 350),
            );
            socket.destroy();
            return '$ip:$port';
          } catch (_) {
            return null;
          }
        }),
      );

      for (final candidate in openHosts) {
        if (candidate != null &&
            await testHost(candidate, timeout: const Duration(milliseconds: 1200))) {
          return candidate;
        }
      }
    }
  } catch (_) {}

  return null;
}

bool _isPrivateLanIpv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]) ?? -1;
  final b = int.tryParse(parts[1]) ?? -1;
  if (a == 192 && b == 168) return true;
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}
