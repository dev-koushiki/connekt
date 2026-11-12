import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connekt/models/social_models.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/screens/social_screen.dart';

void main() {
  final testUser = UserModel(
    id: 'social-user-1',
    phone: '+919876543210',
    username: 'koushikisoc',
    email: 'koushikisoc@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'Koushiki Social',
      displayName: 'Koushiki',
      avatarUrl: '',
      bio: 'Testing Social Module',
      location: 'Kolkata',
      website: '',
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('UserSubscriptionState checks server entitlements accurately', () {
    const freeState = UserSubscriptionState();
    expect(freeState.isSubscribed, isFalse);
    expect(freeState.hasFeature('basic_feed'), isTrue);
    expect(freeState.hasFeature('publish_articles'), isFalse);
    expect(freeState.hasFeature('post_job_listings'), isFalse);

    final proState = UserSubscriptionState.fromJson({
      'isSubscribed': true,
      'planId': 'pro_monthly',
      'planName': 'Connekt Pro Monthly',
      'status': 'active',
      'features': ['basic_feed', 'publish_articles', 'post_job_listings', 'profile_analytics'],
    });
    expect(proState.isSubscribed, isTrue);
    expect(proState.hasFeature('publish_articles'), isTrue);
    expect(proState.hasFeature('profile_analytics'), isTrue);
  });

  testWidgets('SocialScreen renders mode toggle for Social Mode, Professional Mode, and Community', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SocialScreen(user: testUser),
      ),
    );
    await tester.pump();

    expect(find.text('Social'), findsOneWidget);
    expect(find.text('Social Mode'), findsOneWidget);
    expect(find.text('Professional Mode'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);

    // Switch to Professional Mode
    await tester.tap(find.text('Professional Mode'));
    await tester.pump();
    expect(find.text('Jobs & Internships'), findsOneWidget);

    // Switch to Community
    await tester.tap(find.text('Community'));
    await tester.pump();
    expect(find.text('Create'), findsOneWidget);
  });
}
