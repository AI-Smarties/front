import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebsocketService {
  final String baseUrl;
  final int port;

  WebsocketService({this.baseUrl = '127.0.0.1', this.port = 8001});

  WebSocketChannel? _audioChannel;

  final connected = ValueNotifier<bool>(false);
  final committedText = ValueNotifier<String>('');
  final interimText = ValueNotifier<String>('');
  final asrOpen = ValueNotifier<bool>(false);

  // connects to ws and adds listener for server messages
  Future<void> connect() async {
    if (connected.value) return;

    try {
      final uri = Uri.parse('ws://$baseUrl:$port/ws/audio/');
      _audioChannel = WebSocketChannel.connect(uri);
      await _audioChannel!.ready;

      _audioChannel!.stream.listen(
        (msg) {
          final data = jsonDecode(msg as String);
          final type = data['type'];

          if (type == 'ready') {
            connected.value = true;
          } else if (type == 'asr_started') {
            asrOpen.value = true;
          } else if (type == 'asr_stopped') {
            asrOpen.value = false;
          } else if (type == 'partial') {
            interimText.value = (data['text'] ?? '').toString().trim();
          } else if (type == 'final') {
            committedText.value = (data['text'] ?? '').toString().trim();
            interimText.value = '';
          }
        },
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );
    } catch (e) {
      print('WebSocket connect error: $e');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    try {
      await _audioChannel?.ready;
      await _audioChannel?.sink.close();
      _audioChannel = null;

      connected.value = false;
      committedText.value = '';
      interimText.value = '';
    } catch (e) {
      print(e);
    }
  }

  /// Send raw PCM bytes to the backend
  void sendAudio(Uint8List pcmData) {
    print('sedning data');
    _audioChannel?.sink.add(pcmData);
  }

  Future<void> stopAudioStream() async {
    _audioChannel?.sink.add(jsonEncode({'action': 'stop'}));
  }

  String getFullText() {
    return [committedText.value, interimText.value]
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  void dispose() {
    disconnect();
    connected.dispose();
    committedText.dispose();
    interimText.dispose();
    asrOpen.dispose();
  }
}
