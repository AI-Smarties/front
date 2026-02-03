import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front/main.dart';

void main() {
  testWidgets('App shows UI components correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Live Speech → Text'), findsOneWidget);
    expect(find.text('Yhdistä'), findsOneWidget);
    expect(find.text('Tyhjennä'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.byType(DropdownButton<Transport>), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpAndSettle();
  });
}
