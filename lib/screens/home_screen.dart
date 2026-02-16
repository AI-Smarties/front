import 'dart:async';

import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import '../widgets/glasses_connection.dart';
import '../services/websocket_service.dart';

/// Main screen of the app. Manages BLE glasses connection,
/// audio streaming, and live transcription display.

class HomePage extends StatefulWidget {
  /// All dependencies are optional — defaults are created in initState
  /// so they can be injected as mocks in tests.
  final G1Manager? manager;
  final WebsocketService? ws;
  final Lc3Decoder? decoder;
  final AudioPipeline? audioPipeline;
  const HomePage(
      {this.manager, this.decoder, this.ws, this.audioPipeline, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  late final G1Manager _manager;
  late final Lc3Decoder _decoder;
  late final WebsocketService _ws;
  late final AudioPipeline _audioPipeline;

  @override
  void initState() {
    super.initState();

    // Use injected dependencies or create real ones
    _manager = widget.manager ?? G1Manager();
    _decoder = widget.decoder ?? Lc3Decoder();
    _ws = widget.ws ?? WebsocketService();
    _audioPipeline = widget.audioPipeline ??
        AudioPipeline(
          _manager,
          _decoder,
          onPcmData: (pcm) {
            // Forward decoded pcm audio to the backend via WebSocket
            if (_ws.connected.value) _ws.sendAudio(pcm);
          },
        );

    // Connect to backend WebSocket server when homePage is initialized
    _ws.connect();

    // Add listener for mic audio packets from glasses
    _audioPipeline.addListenerToMicrophone();

    // React to Speech to text updates from the backend
    // Used to update the UI (fired when committedText/interimText is changed)
    _ws.committedText.addListener(_onWsChange);
    _ws.interimText.addListener(_onWsChange);
  }

  @override
  void dispose() {
    _ws.committedText.removeListener(_onWsChange);
    _ws.interimText.removeListener(_onWsChange);
    _controller.dispose();
    _audioPipeline.dispose();
    _ws.dispose();
    _manager.dispose();
    super.dispose();
  }

  /// Forwards changes to the glasses display if connected and transcription is active.
  void _onWsChange() {
    if (_manager.isConnected && _manager.transcription.isActive.value) {
      final text = _ws.getFullText();
      _manager.transcription.displayText(
        text,
        isInterim: _ws.interimText.value.isNotEmpty,
      );
    }
  }

  /// Begin a transcription session
  Future<void> _startTranscription() async {
    await _ws.startAudioStream();
    await _manager.transcription.start();
  }

  /// End a transcription session
  Future<void> _stopTranscription() async {
    await _audioPipeline.stop();
    await _ws.stopAudioStream();
    await _manager.transcription.stop();
  }

  /// Send the text field contents to the glasses and clear the input.
  void _sendAndClear() {
    final text = _controller.text.trim();
    _sendTextToGlasses(text);
    _controller.clear();
  }

  /// Display text on the glasses (only works when
  /// connected and transcription mode is active).
  /// can be used to test without backend
  Future<void> _sendTextToGlasses(String text) async {
    if (_manager.isConnected && _manager.transcription.isActive.value) {
      await _manager.transcription.displayText(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smarties App'),
        actions: [
          // WebSocket connection status indicator / reconnect button
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ListenableBuilder(
                listenable: _ws.connected,
                builder: (context, _) => _ws.connected.value
                    ? const Row(
                        children: [
                          Icon(Icons.signal_cellular_alt,
                              color: Colors.green, size: 20),
                          SizedBox(width: 6),
                          Text('Connected',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.green)),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _ws.connect(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reconnect to server'),
                      ),
              )),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text('Response:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Live transcription text
            ListenableBuilder(
              listenable:
                  Listenable.merge([_ws.committedText, _ws.interimText]),
              builder: (context, _) => SelectableText(_ws.getFullText()),
            ),

            // Text input row — only enabled during active transcription
            ListenableBuilder(
              listenable: _manager.transcription.isActive,
              builder: (context, _) {
                final active = _manager.transcription.isActive.value;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: active,
                        decoration: const InputDecoration(
                          hintText: 'Type text to send to glasses',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _sendAndClear(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: active ? _sendAndClear : null,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                );
              },
            ),
            ElevatedButton(
                onPressed: () => _ws.clearCommittedText(),
                child: const Text('Clear text')),
            const SizedBox(height: 16),

            // BLE glasses connection widget + record toggle button
            GlassesConnection(
              manager: _manager,
              onRecordToggle: () async {
                if (!_manager.transcription.isActive.value) {
                  await _startTranscription();
                } else {
                  await _stopTranscription();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
