import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:async';

class PhoneAudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>();

  bool _initialized = false;

  Future<void> init() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();

    _controller.stream.listen((buffer) {
      _onPcm?.call(buffer);
    });

    _initialized = true;
  }

  Function(Uint8List)? _onPcm;

  Future<void> start(Function(Uint8List pcm) onPcm) async {
    if (!_initialized) {
      await init();
    }

    _onPcm = onPcm;

    await _recorder.startRecorder(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      toStream: _controller.sink,
    );
  }

  Future<void> stop() async {
    if (_recorder.isRecording) {
    await _recorder.stopRecorder();
    }
  }

  Future<void> dispose() async {
    await _controller.close();
    await _recorder.closeRecorder();
  }
}