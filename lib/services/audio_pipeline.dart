import 'dart:async';
import 'dart:typed_data';

import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:front/services/lc3_decoder.dart';

typedef PcmCallback = void Function(Uint8List pcmData);

class AudioPipeline {
  final G1Manager _manager;
  final Lc3Decoder _decoder;
  final PcmCallback onPcmData;
  StreamSubscription? _audioSubscription;

  final VoiceDataCollector _audioCollector = VoiceDataCollector();
  Timer? _sendTimer;

  AudioPipeline(this._manager, this._decoder, {required this.onPcmData});

  void addListenerToMicrophone() {
    _audioSubscription = _manager.microphone.audioPacketStream.listen(
      (data) {
        if (!_audioCollector.isRecording) {
          _audioCollector.isRecording = true;
          _audioCollector.reset();
          print('initialize the timer');
          _startSendTimer();
        }
        _audioCollector.addChunk(data.seq, data.data);
      },
      onError: (error) {
        print('Audio stream error: $error');
      },
    );
  }

  Future<Uint8List?> _getPcmDataAndClearBuffer() async {
    if (_audioCollector.chunkCount == 0) return null;

    final lc3Data = _audioCollector.getAllDataAndReset();
    return await _decoder.decodeLc3(lc3Data);
  }

  void _startSendTimer() {
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      Uint8List? pcmData = await _getPcmDataAndClearBuffer();
      if (pcmData != null) onPcmData(pcmData);
    });
  }

  Future<void> stop() async {
    _sendTimer?.cancel();
    _sendTimer = null;
    Uint8List? pcm = await _getPcmDataAndClearBuffer();
    if (pcm != null) onPcmData(pcm);
    _audioCollector.isRecording = false;
  }

  void dispose() {
    stop();
    _audioSubscription?.cancel();
    _audioSubscription = null;
  }
}
