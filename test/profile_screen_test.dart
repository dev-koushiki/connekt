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
}
