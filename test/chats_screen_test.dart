import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/screens/chats_screen.dart';

void main() {
  testWidgets('ChatsScreen renders clean empty state when no chats exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatsScreen(),
      ),
    );

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
}
