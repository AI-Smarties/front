import 'dart:async';
import 'package:even_realities_g1/even_realities_g1.dart';

/// Mock G1Manager for testing
/// Only implements methods we actually use, other methods handled by noSuchMethod
class MockG1Manager implements G1Manager {
  final StreamController<G1ConnectionEvent> _controller =
      StreamController.broadcast();
  bool _isConnected = false;
  final MockG1Display _mockDisplay = MockG1Display();

  @override
  Stream<G1ConnectionEvent> get connectionState => _controller.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  G1Display get display => _mockDisplay;

  @override
  Future<void> startScan({
    void Function()? onConnected,
    void Function(String, String)? onGlassesFound,
    void Function(String)? onUpdate,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Emit scanning
    _controller.add(const G1ConnectionEvent(
      state: G1ConnectionState.scanning,
    ));

    await Future.delayed(const Duration(milliseconds: 500));

    // Emit connecting
    _controller.add(const G1ConnectionEvent(
      state: G1ConnectionState.connecting,
    ));

    await Future.delayed(const Duration(milliseconds: 500));

    // Emit connected
    _isConnected = true;
    _controller.add(const G1ConnectionEvent(
      state: G1ConnectionState.connected,
      leftGlassName: 'Mock-L',
      rightGlassName: 'Mock-R',
    ));

    onConnected?.call();
  }

  @override
  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _isConnected = false;
    _controller.add(
      const G1ConnectionEvent(state: G1ConnectionState.disconnected),
    );
  }

  // Test helper methods
  void emitState(G1ConnectionEvent event) => _controller.add(event);

  void setConnected(bool connected) {
    _isConnected = connected;
    _controller.add(G1ConnectionEvent(
      state: connected
          ? G1ConnectionState.connected
          : G1ConnectionState.disconnected,
    ));
  }

  Future<void> sendTextToGlasses(String text) async {
    if (_isConnected) {
      await _mockDisplay.showText(text);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }

  // Handle all other methods we don't care about
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockG1Display implements G1Display {
  final List<String> displayedTexts = [];

  @override
  Future<void> showText(
    String text, {
    Duration duration = const Duration(seconds: 5),
    bool clearOnComplete = true,
    int margin = 5,
  }) async {
    displayedTexts.add(text);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  List<String> get getText => displayedTexts;

  void clearDisplay() {
    displayedTexts.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
