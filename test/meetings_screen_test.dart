import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/screens/meetings_screen.dart';
import 'package:connekt/widgets/meetings_illustration.dart';

void main() {
  final testUser = UserModel(
    id: 'test-user-id',
    phone: '+1234567890',
    username: 'kou12',
    email: 'kou12@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'koushiki podder',
      displayName: 'koushiki',
      avatarUrl: '',
      bio: '',
      location: '',
      website: '',
    ),
  );

  testWidgets('MeetingsScreen renders contact search bar, action buttons, and empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingsScreen(user: testUser),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Search bar & header controls
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
    expect(find.text('Search contacts'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);

    // 2. Action buttons after search tab: "start instant meeting" & "schedule meeting"
    expect(find.text('Start instant meeting'), findsOneWidget);
    expect(find.text('Schedule meeting'), findsOneWidget);

    // 3. Empty-state illustration & message
    expect(find.byType(MeetingsIllustration), findsOneWidget);
    expect(find.text('Your latest activity will appear here'), findsOneWidget);

    // 4. Floating "New call" action button
    expect(find.text('New call'), findsOneWidget);

    // 5. Tap "Start instant meeting" button
    await tester.tap(find.text('Start instant meeting'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Instant Meeting Ready'), findsOneWidget);
    expect(find.text('Join Call Now'), findsOneWidget);
  });

  testWidgets('MeetingsScreen schedule meeting action opens sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingsScreen(user: testUser),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap "Schedule meeting" button
    await tester.tap(find.text('Schedule meeting'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Meeting Title'), findsOneWidget);
    expect(find.text('Date & Start Time'), findsOneWidget);
  });
}
