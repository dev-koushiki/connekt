import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/screens/chats_screen.dart';
import 'package:connekt/screens/home_screen.dart';
import 'package:connekt/screens/meetings_screen.dart';
import 'package:connekt/services/call_log_service.dart';

void main() {
  const MethodChannel channel = MethodChannel('com.connekt.app/call_logs');

  final testUser = UserModel(
    id: 'user-call-1',
    phone: '+919876543210',
    username: 'alexdev',
    email: 'alexdev@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'Alex Developer',
      displayName: 'Alex',
      avatarUrl: '',
      bio: 'Testing',
      location: 'Kolkata',
      website: '',
    ),
  );

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final mockNativeLogs = <Map<String, dynamic>>[
    {
      'name': 'Priya Sharma',
      'number': '+919800001111',
      'type': 'incoming',
      'duration': 90,
      'timestamp': nowMs - 60000,
    },
    {
      'name': 'Mom',
      'number': '+919800002222',
      'type': 'missed',
      'duration': 0,
      'timestamp': nowMs - 120000,
    },
    {
      'name': 'Arjun Roy',
      'number': '+919800003333',
      'type': 'outgoing',
      'duration': 45,
      'timestamp': nowMs - 180000,
    },
  ];

  void installMockChannel({bool granted = true, List<Map<String, dynamic>>? logs}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        switch (call.method) {
          case 'checkPermission':
            return granted;
          case 'requestPermission':
            return true;
          case 'getCallLogs':
            return logs ?? mockNativeLogs;
          default:
            return null;
        }
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CallLogService.cachedLogs = const [];
    CallLogService.lastPermissionGranted = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    CallLogService.cachedLogs = const [];
    CallLogService.lastPermissionGranted = null;
  });

  group('CallLogService normalization & device loading', () {
    test('normalizes both native epoch millis and backend ISO call log payloads', () {
      final nativeNormalized = CallLogService.normalizeCallLog({
        'name': 'Priya Sharma',
        'number': '+919800001111',
        'type': 'INCOMING',
        'duration': 90,
        'timestamp': 1700000000000,
      });

      expect(nativeNormalized['name'], 'Priya Sharma');
      expect(nativeNormalized['number'], '+919800001111');
      expect(nativeNormalized['type'], 'incoming');
      expect(nativeNormalized['formattedDuration'], '1m 30s');
      expect(nativeNormalized['timestampMs'], 1700000000000);

      final remoteNormalized = CallLogService.normalizeCallLog({
        'contact_name': '',
        'phone_number': '+919800009999',
        'call_type': 'MISSED',
        'duration_seconds': 0,
        'call_timestamp': '2026-11-12T05:30:00.000Z',
      });

      expect(remoteNormalized['name'], '+919800009999');
      expect(remoteNormalized['type'], 'missed');
      expect(remoteNormalized['formattedDuration'], '0s');
    });

    test('loadCallLogs returns native device call logs when permission is granted', () async {
      installMockChannel(granted: true);

      final logs = await CallLogService.loadCallLogs(limit: 50);
      expect(logs.length, 3);
      expect(logs.first['name'], 'Priya Sharma');
      expect(logs[1]['type'], 'missed');
      expect(CallLogService.cachedLogs.length, 3);
    });
  });

  group('Call Logs UI integration', () {
    testWidgets('ChatsScreen Calls tab renders synced device call logs and filters cleanly', (tester) async {
      installMockChannel(granted: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatsScreen(
            user: testUser,
            initialTabIndex: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT CALLS'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Arjun Roy'), findsOneWidget);

      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();

      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);
      expect(find.text('Arjun Roy'), findsNothing);
    });

    testWidgets('MeetingsScreen renders Call Logs & History when device logs are available', (tester) async {
      installMockChannel(granted: true);

      await tester.pumpWidget(
        MaterialApp(
          home: MeetingsScreen(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Call Logs & History'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('Mom'), findsOneWidget);
      expect(find.text('Arjun Roy'), findsOneWidget);
    });

    testWidgets('HomeScreen displays Call Logs card and triggers onOpenCallLogs', (tester) async {
      bool openedCallLogs = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            user: testUser,
            onOpenCallLogs: () => openedCallLogs = true,
          ),
        ),
      );

      final cardFinder = find.text('Call Logs');
      expect(cardFinder, findsOneWidget);
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pump();

      expect(openedCallLogs, isTrue);
    });
  });
}
