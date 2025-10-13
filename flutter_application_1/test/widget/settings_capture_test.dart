import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/settings_capture.dart';

void main() {
  testWidgets('SettingsCaptureScreen toggles update UI', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsCaptureScreen()));

    // Find switches
    final forwardTile = find.text('Forward to Server');
    expect(forwardTile, findsOneWidget);

    // Toggle forward
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    // Presence of Local-only tile
    expect(find.text('Local-only Mode'), findsOneWidget);
  });
}


