import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/screens/chats_screen.dart';
import 'package:connekt/screens/chat_screen.dart';

void main() {
  testWidgets('ChatsScreen renders clean empty state when no chats exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatsScreen(),
      ),
    );
    await tester.pump();

    // Verify Title & Search
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Search chats & people...'), findsOneWidget);

    // Verify Filter Tabs
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Groups'), findsOneWidget);

    // Verify Clean Empty State
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Start a Chat'), findsOneWidget);

    // Verify that old mock users are NOT present
    expect(find.text('Lena Rivers'), findsNothing);
    expect(find.text('CONNEKT Core Team'), findsNothing);
    expect(find.text('David Kim'), findsNothing);
    expect(find.text('Mobile Engineers'), findsNothing);
  });

  testWidgets('ChatScreen renders safely with empty avatarUrl without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Soumo'), findsOneWidget);
    expect(find.text('online'), findsOneWidget);
    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.text('S'), findsOneWidget); // Initial avatar fallback
  });

  testWidgets('ChatScreen renders WhatsApp attachment option menu (+ button)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Verify + button exists
    final plusFinder = find.byIcon(Icons.add_rounded);
    expect(plusFinder, findsOneWidget);

    // Tap + button
    await tester.tap(plusFinder);
    await tester.pumpAndSettle();

    // Verify WhatsApp 6-option attachment sheet
    expect(find.text('Document'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Contact'), findsOneWidget);
  });

  testWidgets('ChatScreen microphone button triggers workable voice recording mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Verify mic button exists
    final micFinder = find.byIcon(Icons.mic_rounded);
    expect(micFinder, findsOneWidget);

    // Tap mic button to enter recording mode
    await tester.tap(micFinder);
    await tester.pump();

    // Verify voice recording bar is active
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    // Tap discard button
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pump();

    // Verify normal input bar is restored
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('ChatScreen 3-dots menu renders all individual chat features from screenshot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Verify 3-dots menu button exists
    final menuButtonFinder = find.byIcon(Icons.more_vert_rounded);
    expect(menuButtonFinder, findsOneWidget);

    // Tap 3-dots menu
    await tester.tap(menuButtonFinder);
    await tester.pumpAndSettle();

    // Verify all 9 individual chat options from the user screenshot exist
    expect(find.text('Ask Meta AI privately'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);
    expect(find.text('View contact'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Media, links, and docs'), findsOneWidget);
    expect(find.text('Mute notifications'), findsOneWidget);
    expect(find.text('Disappearing messages'), findsOneWidget);
    expect(find.text('Chat theme'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('ChatScreen Search mode activates and searches messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Open 3-dots menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // Tap Search
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Verify Search input field appears in AppBar
    expect(find.byType(TextField), findsNWidgets(2)); // Search bar + Chat input bar
    expect(find.text('Search messages...'), findsOneWidget);

    // Tap close search
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify standard AppBar is restored
    expect(find.text('online'), findsOneWidget);
  });

  testWidgets('ChatScreen group chat renders all 13 features from screenshot', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'CONNEKT Team',
          avatarUrl: '',
          showBackButton: true,
          isGroup: true,
          initialMembers: ['You', 'Soumo', 'Lena Rivers'],
        ),
      ),
    );
    await tester.pump();

    // Verify Group Header
    expect(find.text('CONNEKT Team'), findsOneWidget);
    expect(find.text('You, Soumo, Lena Rivers'), findsOneWidget);

    // Verify Group Header icons: Video dropdown, Search icon, 3-dots
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

    // Open Group 3-dots menu
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // Verify all 13 options from the group chat screenshot
    expect(find.text('Add member'), findsOneWidget);
    expect(find.text('Group info'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Select messages'), findsOneWidget);
    expect(find.text('Mute notifications'), findsOneWidget);
    expect(find.text('Disappearing messages'), findsOneWidget);
    expect(find.text('Chat theme'), findsOneWidget);
    expect(find.text('Add to favourites'), findsOneWidget);
    expect(find.text('Add to list'), findsOneWidget);
    expect(find.text('Export chat'), findsOneWidget);
    expect(find.text('Close chat'), findsOneWidget);
    expect(find.text('Clear chat'), findsOneWidget);
    expect(find.text('Exit group'), findsOneWidget);
  });

  testWidgets('ChatScreen delete message dialog offers "Delete for everyone" and "Delete for me"', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Send a message first
    await tester.enterText(find.byType(TextField), 'Hello testing delete feature');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    // Verify message appears
    expect(find.text('Hello testing delete feature'), findsOneWidget);

    // Long press on the sent message bubble
    await tester.longPress(find.text('Hello testing delete feature'));
    await tester.pumpAndSettle();

    // Verify bottom action sheet opens with "Delete message"
    expect(find.text('Delete message'), findsOneWidget);

    // Tap "Delete message"
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();

    // Verify WhatsApp-style dialog shows "Delete for everyone", "Delete for me", and "Cancel"
    expect(find.text('Delete for everyone'), findsOneWidget);
    expect(find.text('Delete for me'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap "Delete for everyone"
    await tester.tap(find.text('Delete for everyone'));
    await tester.pumpAndSettle();

    // Verify original message is replaced with WhatsApp placeholder
    expect(find.text('Hello testing delete feature'), findsNothing);
    expect(find.text('You deleted this message'), findsOneWidget);
    expect(find.byIcon(Icons.block_flipped), findsOneWidget);
  });

  testWidgets('ChatScreen delete for me completely removes message from chat', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatScreen(
          contactName: 'Soumo',
          avatarUrl: '',
          showBackButton: true,
        ),
      ),
    );
    await tester.pump();

    // Send a message
    await tester.enterText(find.byType(TextField), 'Message to delete for me');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('Message to delete for me'), findsOneWidget);

    // Long press message
    await tester.longPress(find.text('Message to delete for me'));
    await tester.pumpAndSettle();

    // Tap "Delete message"
    await tester.tap(find.text('Delete message'));
    await tester.pumpAndSettle();

    // Tap "Delete for me"
    await tester.tap(find.text('Delete for me'));
    await tester.pumpAndSettle();

    // Verify message is completely removed
    expect(find.text('Message to delete for me'), findsNothing);
    expect(find.text('You deleted this message'), findsNothing);
    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('ChatsScreen WhatsApp 3-dots overflow menu renders all 9 options', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatsScreen(),
      ),
    );
    await tester.pump();

    // Tap 3-dots menu button
    final moreBtn = find.byIcon(Icons.more_vert_rounded);
    expect(moreBtn, findsOneWidget);
    await tester.tap(moreBtn);
    await tester.pumpAndSettle();

    // Verify all 9 WhatsApp features in overflow menu
    expect(find.text('New group'), findsOneWidget);
    expect(find.text('New broadcast'), findsOneWidget);
    expect(find.text('Linked devices'), findsOneWidget);
    expect(find.text('Starred messages'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
    expect(find.text('Archived chats'), findsOneWidget);
    expect(find.text('Locked chats'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('ChatsScreen navigates through WhatsApp sub-tabs: Updates, Calls, Communities', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatsScreen(),
      ),
    );
    await tester.pump();

    // 1. Verify sub-tabs exist
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Calls'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);

    // 2. Switch to Updates tab
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();

    expect(find.text('My status'), findsOneWidget);
    expect(find.text('RECENT UPDATES'), findsOneWidget);

    // 3. Switch to Calls tab
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();

    expect(find.text('Create call link'), findsOneWidget);
    expect(find.text('RECENT CALLS'), findsOneWidget);

    // 4. Switch to Communities tab
    await tester.tap(find.text('Communities'));
    await tester.pumpAndSettle();

    expect(find.text('Stay connected with a Community'), findsOneWidget);
    expect(find.text('Start your Community'), findsOneWidget);
  });
}
