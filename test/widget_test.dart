import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'ble_mock/g1_manager_mock.dart';
import 'package:front/screens/landing_screen.dart';

void main() {
  late MockG1Manager mockManager;

  setUp(() {
    mockManager = MockG1Manager();
  });

  tearDown(() {
    mockManager.dispose();
  });

  Future<void> pumpLanding(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LandingScreen(
          manager: mockManager,
        ),
      ),
    );
  }

  Future<void> disposeLanding(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('App shows text input and send button',
      (WidgetTester tester) async {
    await pumpLanding(tester);

    expect(find.text('Even realities G1 smart glasses'), findsOneWidget);
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.text('Even realities G1 smart glasses'), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('Connecting to glasses text is shown when bluetooth is scanning',
      (tester) async {
    await pumpLanding(tester);

    mockManager.emitState(
        const G1ConnectionEvent(state: G1ConnectionState.connecting));

    await tester.pump();

    expect(find.text('Connecting to glasses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('Disconnect from glasses button is shown', (tester) async {
    await pumpLanding(tester);

    mockManager.emitState(
        const G1ConnectionEvent(state: G1ConnectionState.disconnected));

    await tester.pump();

    expect(find.text('Connect to glasses'), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('On connecting error right error message is shown',
      (tester) async {
    await pumpLanding(tester);

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.error));

    await tester.pump();

    expect(find.text('Error in connecting to glasses'), findsOneWidget);
    expect(find.text('Connect to glasses'), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('On scanning Scanning for glasses message is shown',
      (tester) async {
    await pumpLanding(tester);

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.scanning));

    await tester.pump();

    expect(find.text('Searching for glasses'), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('When connected show right text', (tester) async {
    await pumpLanding(tester);

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.connected));

    await tester.pump();

    expect(find.text('Connected'), findsOneWidget);

    await disposeLanding(tester);
  });

  testWidgets('Shows scanning state when connecting', (tester) async {
    await pumpLanding(tester);

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.scanning));
    await tester.pump();
    expect(find.text('Searching for glasses'), findsOneWidget);

    mockManager.emitState(
        const G1ConnectionEvent(state: G1ConnectionState.connecting));
    await tester.pump();
    expect(find.text('Connecting to glasses'), findsOneWidget);

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.connected));
    await tester.pump();
    expect(find.text('Connected'), findsOneWidget);

    await disposeLanding(tester);
  });

  test('Can send text to glasses when connected', () async {
    mockManager.setConnected(true);

    await mockManager.sendTextToGlasses('test');

    final mockDisplay = mockManager.display as MockG1Display;
    expect(mockDisplay.getText, contains('test'));
  });

  test('Cannot send text to glasses when not connected', () async {
    mockManager.setConnected(false);

    await mockManager.sendTextToGlasses('test');

    final mockDisplay = mockManager.display as MockG1Display;
    expect(mockDisplay.getText, []);
  });
}
