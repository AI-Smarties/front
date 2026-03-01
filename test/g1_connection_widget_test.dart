import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ble_mock/g1_manager_mock.dart';
import 'package:front/widgets/g1_connection.dart';

void main() {
  late MockG1Manager mockManager;

  setUp(() {
    mockManager = MockG1Manager();
  });

  tearDown(() {
    mockManager.dispose();
  });

  Future<void> pumpConnection(WidgetTester tester,
      {Future<void> Function()? onRecordToggle}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GlassesConnection(
            manager: mockManager,
            onRecordToggle: onRecordToggle,
          ),
        ),
      ),
    );
  }

  testWidgets('Shows connect UI when stream is waiting', (tester) async {
    await pumpConnection(tester);

    // StreamBuilder starts in ConnectionState.waiting
    expect(find.text('Connect to glasses'), findsOneWidget);
  });

  testWidgets('Shows connect UI when disconnected', (tester) async {
    await pumpConnection(tester);

    mockManager.emitState(
      const G1ConnectionEvent(state: G1ConnectionState.disconnected),
    );
    await tester.pump();

    expect(find.text('Connect to glasses'), findsOneWidget);
  });

  testWidgets('Shows scanning UI when scanning', (tester) async {
    await pumpConnection(tester);

    mockManager.emitState(
      const G1ConnectionEvent(state: G1ConnectionState.scanning),
    );
    await tester.pump();

    expect(find.text('Searching for glasses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Shows connecting UI when connecting', (tester) async {
    await pumpConnection(tester);

    mockManager.emitState(
      const G1ConnectionEvent(state: G1ConnectionState.connecting),
    );
    await tester.pump();

    expect(find.text('Connecting to glasses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Shows error UI when error', (tester) async {
    await pumpConnection(tester);

    mockManager.emitState(
      const G1ConnectionEvent(state: G1ConnectionState.error),
    );
    await tester.pump();

    expect(find.text('Error in connecting to glasses'), findsOneWidget);
    expect(
        find.text('Retry').evaluate().isNotEmpty ||
            find.text('Connect to glasses').evaluate().isNotEmpty,
        isTrue);
  });

  testWidgets('When connected shows Connected state', (tester) async {
    await pumpConnection(tester);

    mockManager.emitState(
      const G1ConnectionEvent(state: G1ConnectionState.connected),
    );
    await tester.pump();

    expect(find.text('Connected'), findsOneWidget);
  });
}
