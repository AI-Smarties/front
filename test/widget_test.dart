import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front/main.dart';

void main() {
  testWidgets('App shows text input and send button',
      (WidgetTester tester) async {
    // Build and render the app
    await tester.pumpWidget(const MyApp());

    // Verify that a text input field exists
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the Send button exists
    expect(find.text('Lähetä'), findsOneWidget);

    // Verify that the app title is shown
    expect(find.text('Smarties App'), findsOneWidget);
  });

  testWidgets('App shows glasses connection button', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Initially shows connect button (not connected)
    expect(find.text('Yhdistä laseihin'), findsOneWidget);

    // Should have 2 buttons: Lähetä + Yhdistä
    expect(find.byType(ElevatedButton), findsNWidgets(2));
  });
}
