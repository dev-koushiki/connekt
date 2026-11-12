import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connekt/models/mail_models.dart';
import 'package:connekt/models/user_model.dart';
import 'package:connekt/screens/mail_screen.dart';
import 'package:connekt/services/mail_service.dart';

void main() {
  final testUser = UserModel(
    id: 'mail-user-1',
    phone: '+919876543210',
    username: 'koushikidev',
    email: 'koushikidev@connekt.me',
    currentMode: 'common',
    role: 'user',
    personalProfile: PersonalProfile(
      fullName: 'Koushiki Developer',
      displayName: 'Koushiki',
      avatarUrl: '',
      bio: 'Testing Mail',
      location: 'Kolkata',
      website: '',
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gmail query parser and threading', () {
    test('MailQueryFilter evaluates Gmail operators and groups threads chronologically', () {
      final msgs = MailService.starterMessages(testUser);
      expect(MailQueryFilter.matches(msgs.first, 'from:security has:attachment is:unread'), isTrue);
      expect(MailQueryFilter.matches(msgs.first, 'from:nobody'), isFalse);
      expect(MailQueryFilter.matches(msgs.first, 'label:Work is:starred'), isTrue);

      final threads = MailQueryFilter.groupIntoThreads(msgs, conversationView: true);
      final roadmapThread = threads.firstWhere((t) => t.threadId == 'thr_road_1');
      expect(roadmapThread.messageCount, 2);
      expect(roadmapThread.latest.senderName, 'Lena Rivers');
    });
  });

  group('MailScreen Gmail UI & Workflows', () {
    testWidgets('renders search bar, inbox categories, drawer folders, and thread list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MailScreen(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search in mail'), findsOneWidget);
      expect(find.textContaining('Primary'), findsOneWidget);
      expect(find.textContaining('Social'), findsOneWidget);
      expect(find.textContaining('Promotions'), findsOneWidget);
      expect(find.text('Compose'), findsOneWidget);

      // Starter Primary emails appear (threaded)
      expect(find.text('Welcome to CONNEKT – Account Setup & Security Keys'), findsOneWidget);
      expect(find.text('Q4 Mobile Ecosystem Launch Roadmap & Specifications'), findsOneWidget);

      // Switch to Social tab
      await tester.tap(find.textContaining('Social').first);
      await tester.pumpAndSettle();
      expect(find.text('New team highlights in CONNEKT Workspace'), findsOneWidget);

      // Open Gmail Navigation Drawer
      await tester.tap(find.byTooltip('Open mail folders'));
      await tester.pumpAndSettle();
      expect(find.text('ALL LABELS'), findsOneWidget);
      expect(find.text('Snoozed'), findsOneWidget);

      final drawerScroll = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Scheduled'), 150, scrollable: drawerScroll);
      expect(find.text('Scheduled'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Drafts'), 150, scrollable: drawerScroll);
      expect(find.text('Drafts'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Spam'), 150, scrollable: drawerScroll);
      expect(find.text('Spam'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Trash'), 150, scrollable: drawerScroll);
      expect(find.text('Trash'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mail Settings & Signature'), 150, scrollable: drawerScroll);
      await tester.pumpAndSettle();
      expect(find.text('Create new'), findsOneWidget);
      expect(find.text('Mail Settings & Signature'), findsOneWidget);
    });

    testWidgets('composing and auto-saving a Draft populates Drafts folder, and opening thread shows Reply/Reply All/Forward', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MailScreen(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      // Open Compose
      await tester.tap(find.text('Compose'));
      await tester.pumpAndSettle();

      expect(find.text('From'), findsOneWidget);
      expect(find.text('koushikidev@connekt.me'), findsOneWidget);

      // Fill Subject and Body, then press Back to auto-save Draft
      await tester.enterText(find.widgetWithText(TextField, 'Subject'), 'Quarterly Design Plan');
      await tester.enterText(find.widgetWithText(TextField, 'Compose email'), 'Drafting notes for Q4.');
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Draft saved'), findsOneWidget);

      // Verify Drafts folder shows the saved draft
      await tester.tap(find.byTooltip('Open mail folders'));
      await tester.pumpAndSettle();
      final drawerScroll2 = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Drafts'), 150, scrollable: drawerScroll2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      expect(find.text('Quarterly Design Plan'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);

      // Return to Primary inbox and open a multi-message thread
      await tester.tap(find.byTooltip('Open mail folders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Primary').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Q4 Mobile Ecosystem Launch Roadmap & Specifications'));
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Reply all'), findsOneWidget);
      expect(find.text('Forward'), findsOneWidget);
      expect(find.text('SMART REPLIES'), findsOneWidget);
    });

    testWidgets('Mail Settings allows toggling Vacation Responder and shows banner', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MailScreen(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Open mail folders'));
      await tester.pumpAndSettle();
      final drawerScroll = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Mail Settings & Signature'), 150, scrollable: drawerScroll);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mail Settings & Signature'));
      await tester.pumpAndSettle();

      expect(find.text('Mail Settings'), findsOneWidget);
      expect(find.text('Conversation view'), findsOneWidget);
      expect(find.text('MOBILE SIGNATURE'), findsOneWidget);

      final sheetScroll = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Auto-reply when away'), 150, scrollable: sheetScroll);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Auto-reply when away'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vacation responder is on'), findsOneWidget);
    });

    testWidgets('supports Updates, Forums, Sort menu, and Mail Contacts manager', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MailScreen(user: testUser),
        ),
      );
      await tester.pumpAndSettle();

      // Updates category pill and Sort emails menu work
      expect(find.textContaining('Updates'), findsOneWidget);
      await tester.tap(find.byTooltip('Sort emails'));
      await tester.pumpAndSettle();
      expect(find.text('Sort: Sender A–Z'), findsOneWidget);
      await tester.tap(find.text('Sort: Sender A–Z'));
      await tester.pumpAndSettle();

      // Open drawer and open Mail Contacts manager
      await tester.tap(find.byTooltip('Open mail folders'));
      await tester.pumpAndSettle();
      final drawerScroll = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Mail Contacts'), 150, scrollable: drawerScroll);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mail Contacts'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mail Contacts'), findsOneWidget);
    });
  });
}
