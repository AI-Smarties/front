import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front/main.dart';

void main() {
  testWidgets('App shows text input and send button', (WidgetTester tester) async {
    // Build and render the app
    await tester.pumpWidget(const MyApp());

    // Verify that a text input field exists
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the Send button exists
    expect(find.text('Lähetä'), findsOneWidget);

    // Verify that the app title is shown
    expect(find.text('Smarties App'), findsOneWidget);
  });
}
