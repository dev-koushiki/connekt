bool get isFlutterTestEnv => false;

/// Web stub for LAN subnet probing (browser apps cannot open raw TCP sockets).
Future<String?> probeLocalSubnetServer({
  int port = 5000,
  required Future<bool> Function(String host, {Duration timeout}) testHost,
}) async {
  return null;
}
