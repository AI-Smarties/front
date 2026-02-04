import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
<<<<<<< HEAD
import 'package:front/main.dart';

void main() {
  testWidgets('App shows UI components correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
=======
import 'ble_mock/g1_manager_mock.dart';

import 'package:front/main.dart';

void main() {
  late MockG1Manager mockManager;

  setUp(() {
    mockManager = MockG1Manager();
  });

  tearDown(() {
    mockManager.dispose();
  });
  testWidgets('App shows text input and send button',
      (WidgetTester tester) async {
    // Build and render the app
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));
>>>>>>> dev

    expect(find.text('Live Speech → Text'), findsOneWidget);
    expect(find.text('Yhdistä'), findsOneWidget);
    expect(find.text('Tyhjennä'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsOneWidget);
    expect(find.byType(DropdownButton<Transport>), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

<<<<<<< HEAD
    await tester.pumpAndSettle();
=======
    // Verify that the Send button exists
    expect(find.text('Send'), findsOneWidget);

    // Verify that the app title is shown
    expect(find.text('Smarties App'), findsOneWidget);
>>>>>>> dev
  });

  testWidgets('Connecting to glasses text is shown when bluetooth is scanning ',
      (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));

    mockManager.emitState(
        const G1ConnectionEvent(state: G1ConnectionState.connecting));

    await tester.pump();
    expect(find.text('Connecting to glasses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('Disconnect from glasses button is shown', (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));

    mockManager.emitState(
        const G1ConnectionEvent(state: G1ConnectionState.disconnected));
    await tester.pump();
    final connectionButton =
        find.widgetWithText(ElevatedButton, 'Connect to glasses');
    // Initially shows connect button (not connected)
    expect(connectionButton, findsOneWidget);
  });
  testWidgets('On connecting error right error message is shown',
      (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.error));
    await tester.pump();
    final connectionButton =
        find.widgetWithText(ElevatedButton, 'Connect to glasses');
    expect(find.text('Error in connecting to glasses'), findsOneWidget);

    expect(connectionButton, findsOneWidget);
  });
  testWidgets('On scanning Scanning for glasses message is shown',
      (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.scanning));
    await tester.pump();
    expect(find.text('Searching for glasses'), findsOneWidget);
  });
  testWidgets('When connected show right text', (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));

    mockManager
        .emitState(const G1ConnectionEvent(state: G1ConnectionState.connected));
    await tester.pump();
    final disconnectButton = find.widgetWithText(ElevatedButton, 'Disconnect');
    expect(find.text('Connected to glasses'), findsOneWidget);
    expect(disconnectButton, findsOneWidget);
  });
  testWidgets('Shows scanning state when connecting', (tester) async {
    await tester.pumpWidget(MyApp(
      manager: mockManager,
    ));
    final connectButton =
        find.widgetWithText(ElevatedButton, 'Connect to glasses');
    await tester.tap(connectButton);

    await tester.pump();

// Search state
    expect(find.text('Searching for glasses'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    // Connecting state
    expect(find.text('Connecting to glasses'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    // Connected state
    expect(find.text('Connected to glasses'), findsOneWidget);
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
