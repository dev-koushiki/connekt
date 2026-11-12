import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/screens/profile_screen.dart';
import 'package:connekt/models/user_model.dart';

void main() {
  final testUser = UserModel(
    id: 'user-123',
    phone: '9836828816',
    username: 'kou12',
    email: 'kou12@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'koushiki podder',
      displayName: 'koushiki podder',
      avatarUrl: '',
      bio: 'Software engineer and builder',
      location: 'Kolkata, India',
      website: 'https://connekt.me',
    ),
    professionalProfile: ProfessionalProfile(
      headline: 'Full-Stack Developer',
      currentCompany: 'CONNEKT',
      industry: 'Technology',
      summary: 'Building real-time collaboration apps',
      yearsOfExperience: 3,
      isOpenToWork: true,
      isHiring: false,
    ),
  );

  testWidgets('ProfileScreen renders personal details, edit button, and tabs', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ProfileScreen(
          user: testUser,
          onLogout: () {},
        ),
      ),
    );

    // Verify user display name is visible
    expect(find.text('koushiki podder'), findsWidgets);
    expect(find.text('@kou12'), findsOneWidget);
    expect(find.text('kou12@connekt.me'), findsOneWidget);

    // Verify Edit Profile button is present
    expect(find.text('Edit Profile'), findsOneWidget);

    // Verify tabs are present
    expect(find.text('Personal'), findsWidgets);
    expect(find.text('Career & Skills'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify personal info tiles
    expect(find.text('Full Legal Name'), findsOneWidget);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
  });

  testWidgets('ProfileScreen triggers onLogout from AppBar and Settings Sign Out button', (WidgetTester tester) async {
    int logoutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ProfileScreen(
          user: testUser,
          onLogout: () => logoutCalls++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Log Out'));
    await tester.pump();
    expect(logoutCalls, 1);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final signOutFinder = find.text('Sign Out');
    await tester.ensureVisible(signOutFinder);
    await tester.tap(signOutFinder);
    await tester.pump();
    expect(logoutCalls, 2);
  });

  testWidgets('ProfileScreen opens Set Profile Picture sheet from avatar header and Edit Profile dialog', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: ProfileScreen(
          user: testUser,
          onLogout: () {},
        ),
      ),
    );

    // Entry point 1: Tapping the avatar camera badge
    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Set Profile Picture'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Browse Files'), findsOneWidget);

    // Dismiss photo sheet by popping
    Navigator.of(tester.element(find.text('Set Profile Picture'))).pop();
    await tester.pumpAndSettle();

    // Entry point 2: Edit Profile sheet -> Change Photo
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile Picture'), findsOneWidget);
    expect(find.text('Change Photo'), findsOneWidget);

    await tester.tap(find.text('Change Photo'));
    await tester.pumpAndSettle();

    expect(find.text('Set Profile Picture'), findsOneWidget);
  });
}
