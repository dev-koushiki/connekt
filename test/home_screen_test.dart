import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/screens/home_screen.dart';

void main() {
  final testUser = UserModel(
    id: 'test-user-id',
    phone: '+1234567890',
    username: 'alexdev',
    email: 'alexdev@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'Alex Developer',
      displayName: 'Alex',
      avatarUrl: '',
      bio: 'Testing CONNEKT Mobile App',
      location: 'San Francisco, CA',
      website: '',
    ),
  );

  testWidgets('HomeScreen renders CONNEKT branding, header, greeting, and 3 cards', (tester) async {
    int? navigatedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          user: testUser,
          onNavigateToTab: (index) {
            navigatedIndex = index;
          },
        ),
      ),
    );

    // Verify Brand Logo & Header
    expect(find.byType(Image), findsWidgets);
    expect(find.text('CONNEKT'), findsOneWidget);
    expect(find.text('Hello, Alex Developer!'), findsOneWidget);
    expect(find.text('Welcome to CONNEKT!'), findsOneWidget);
    expect(
      find.text('Everything you need to connect, communicate and collaborate.'),
      findsOneWidget,
    );

    // Verify 3 Cards
    expect(find.text('Meetings'), findsOneWidget);
    expect(find.text('Connect through video and audio meetings.'), findsOneWidget);

    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Connect through individual and group conversations.'), findsOneWidget);

    expect(find.text('Mails'), findsOneWidget);
    expect(find.text('Send, receive and manage your emails.'), findsOneWidget);
    expect(find.text('Call Logs'), findsNothing);

    // Tap Meetings card
    await tester.tap(find.text('Meetings'));
    await tester.pump();
    expect(navigatedIndex, 1);

    // Tap Chats card
    await tester.tap(find.text('Chats'));
    await tester.pump();
    expect(navigatedIndex, 2);

    // Tap Mails card
    await tester.tap(find.text('Mails'));
    await tester.pump();
    expect(navigatedIndex, 3);
  });

  testWidgets('HomeScreen avatar tap navigates to Profile tab', (tester) async {
    int? navigatedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          user: testUser,
          onNavigateToTab: (index) {
            navigatedIndex = index;
          },
        ),
      ),
    );

    // Tap Profile avatar on top right (letter 'A')
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(navigatedIndex, 4);
  });
}
