import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/config/api_config.dart';

void main() {
  test('ApiConfig formatEndpoint handles IPs, localhosts, and HTTPS Cloud Tunnels', () {
    expect(ApiConfig.formatEndpoint('192.168.29.98:5000', endpoint: '/api'), 'http://192.168.29.98:5000/api');
    expect(ApiConfig.formatEndpoint('https://connekt.loca.lt', endpoint: '/api'), 'https://connekt.loca.lt/api');
    expect(ApiConfig.formatEndpoint('https://connekt.loca.lt/api', endpoint: '/api'), 'https://connekt.loca.lt/api');
    expect(ApiConfig.formatEndpoint('localhost:5000', endpoint: '/api'), 'http://localhost:5000/api');
  });

  test('ApiConfig testHost connects to active server on 192.168.29.98:5000', () async {
    final isAlive = await ApiConfig.testHost('192.168.29.98:5000');
    expect(isAlive, isTrue);
  });

  test('ApiConfig autoDetectHost detects the live server', () async {
    final host = await ApiConfig.autoDetectHost();
    expect(host, isNotNull);
    expect(host, contains('5000'));
  });
}
