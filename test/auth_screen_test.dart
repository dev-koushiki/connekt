import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/screens/auth_screen.dart';

void main() {
  testWidgets('AuthScreen renders official CONNEKT emblem, brandmark text, and tagline', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthSuccess: (_) {}),
      ),
    );

    // Verify official brand emblem image is present
    expect(find.byType(Image), findsWidgets);

    // Verify official tagline from brand identity
    expect(find.text('CONNECTING THE UNCONNECTED'), findsOneWidget);

    // Verify Sign In and Create Account tabs
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);

    // Verify input fields
    expect(find.text('Phone, Username, or Connekt Mail'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('AuthScreen password visibility toggle works for Sign In and Register', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(onAuthSuccess: (_) {}),
      ),
    );

    // 1. In Sign In tab: initial state is obscured (visibility_off icon)
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // Tap the eye icon to reveal password
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Tap again to hide password
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    // 2. Switch to Create Account tab
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Verify password visibility toggle is present in register tab
    final regEyeOff = find.byIcon(Icons.visibility_off_outlined);
    await tester.ensureVisible(regEyeOff);
    expect(regEyeOff, findsOneWidget);

    // Tap the eye icon to reveal password
    await tester.tap(regEyeOff);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
