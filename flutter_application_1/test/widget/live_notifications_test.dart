import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personalized_ai/services/notification_forwarder.dart';

void main() {
  testWidgets('LiveNotifications container shows simulated events', (tester) async {
    // Minimal app with a StreamBuilder on contextEventList
    final widget = MaterialApp(
      home: Scaffold(
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: NotificationForwarderService.contextEventList,
          builder: (context, snapshot) {
            final items = (snapshot.data ?? const <Map<String, dynamic>>[]);
            if (items.isEmpty) {
              return const Center(child: Text('No live events yet. Send a notification to see it here.'));
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final e = items[index];
                return ListTile(
                  title: Text((e['sender'] ?? e['package'] ?? '').toString()),
                  subtitle: Text((e['text'] ?? '').toString()),
                );
              },
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(widget);

    // Initially empty
    expect(find.text('No live events yet. Send a notification to see it here.'), findsOneWidget);

    // Simulate two events
    NotificationForwarderService.simulateEvent({
      'package': 'com.whatsapp',
      'sender': 'Alice',
      'text': 'Hello there!'
    });
    NotificationForwarderService.simulateEvent({
      'package': 'com.whatsapp',
      'sender': 'Bob',
      'text': 'Ping'
    });

    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Hello there!'), findsOneWidget);
    expect(find.text('Ping'), findsOneWidget);
  });
}


