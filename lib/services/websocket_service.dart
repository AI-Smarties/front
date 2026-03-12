import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Handles all communication with the backend over a WebSocket.
///
/// Responsibilities:
/// - Connect/disconnect to `ws://<baseUrl>:<port>/ws/`
/// - Send raw PCM audio bytes for speech-to-text
/// - Send control commands (start/stop audio stream)
/// - Receive and expose transcription results (committed + interim text)
///
/// Message protocol (JSON):
///   Incoming:
///     { "type": "control",    "cmd": "ready" | "asr_started" | "asr_stopped" }
///     { "type": "transcript", "data": { "status": "partial"|"final", "text": "..." } }
///     { "type": "error",      ... }
///   Outgoing:
///     { "type": "control", "cmd": "start" | "stop" }
///     Raw PCM bytes (binary frame)
class WebsocketService {
  final String baseUrl;

  WebsocketService({
    this.baseUrl =
        const String.fromEnvironment('API_URL', defaultValue: '127.0.0.1:8000'),
  });

  WebSocketChannel? _audioChannel;

  final connected = ValueNotifier<bool>(false);

  final committedText = ValueNotifier<String>('');
  final interimText = ValueNotifier<String>('');

  /// Whether the backend's ASR (speech recognition) engine is active.
  /// Can be used for UI indicator
  final asrActive = ValueNotifier<bool>(false);

  void clearCommittedText() {
    committedText.value = '';
  }

  Future<void> connect() async {
    if (connected.value) return;
    try {
      final uri = Uri.parse('ws://$baseUrl/ws/');
      _audioChannel = WebSocketChannel.connect(uri);
      await _audioChannel!.ready;

      _audioChannel!.stream.listen(
        (msg) {
          final data = jsonDecode(msg as String);
          final type = data['type'];

          if (type == 'control') {
            // Server signals readiness or ASR state changes
            if (data['cmd'] == 'ready') {
              connected.value = true;
            } else if (data['cmd'] == 'asr_started') {
              asrActive.value = true;
            } else if (data['cmd'] == 'asr_stopped') {
              asrActive.value = false;
            }
          } else if (type == 'transcript') {
            // Speech-to-text results: partial (interim) or final (committed)
            final status = data['data']['status'];
            if (status == 'partial') {
              interimText.value =
                  (data['data']['text'] ?? '').toString().trim();
            } else if (status == 'final') {
              committedText.value =
                  (data['data']['text'] ?? '').toString().trim();
            }
          } else if (type == 'error') {
            //todo
          }
        },
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );
    } catch (e) {
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    try {
      _audioChannel?.sink.add(jsonEncode({'type': 'control', 'cmd': 'stop'}));
      await _audioChannel?.sink.close();
    } catch (_) {
      // Connection already closed or network gone
    } finally {
      _audioChannel = null;
      connected.value = false;
      committedText.value = '';
      interimText.value = '';
    }
  }

  /// Send raw PCM audio bytes to the backend for transcription.
  void sendAudio(Uint8List pcmData) {
    if (connected.value) {
      _audioChannel?.sink.add(pcmData);
    }
  }

  void sendCalendarContext(Map<String, dynamic> payload) {
    if (connected.value) {
      _audioChannel?.sink.add(jsonEncode(payload));
    }
  }

  /// Tell the backend to stop expecting audio data.
  Future<void> stopAudioStream() async {
    if (connected.value) {
      _audioChannel?.sink.add(jsonEncode({'type': 'control', 'cmd': 'stop'}));
    }
  }

  /// Tell the backend to start expecting audio data.
  Future<void> startAudioStream() async {
    if (connected.value) {
      _audioChannel?.sink.add(jsonEncode({'type': 'control', 'cmd': 'start'}));
    }
  }

  String getFullText() {
    return committedText.value;
  }

  void dispose() {
    disconnect();
    connected.dispose();
    committedText.dispose();
    interimText.dispose();
    asrActive.dispose();
  }
}
