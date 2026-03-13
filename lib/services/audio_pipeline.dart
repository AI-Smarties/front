import 'dart:async';
import 'dart:typed_data';

import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:front/services/lc3_decoder.dart';

/// Callback type for delivering decoded PCM audio data.
typedef PcmCallback = void Function(Uint8List pcmData);

/// Bridges the glasses microphone to the backend.
///
/// Flow: Glasses mic → LC3 packets → collect in buffer → decode to PCM → onPcmData callback
///
/// Audio packets arrive continuously from the glasses. They are buffered
/// in a [VoiceDataCollector] and flushed every 500 ms: the buffered
/// LC3 data is decoded to PCM and delivered via [onPcmData].
class AudioPipeline {
  final G1Manager _manager;
  final Lc3Decoder _decoder;
  final PcmCallback onPcmData;
  StreamSubscription? _audioSubscription;

  /// Collects incoming LC3 audio chunks between flush intervals.
  final VoiceDataCollector _audioCollector = VoiceDataCollector();

  /// Fires every 500ms to flush collected audio and send decoded PCM.
  Timer? _sendTimer;

  AudioPipeline(this._manager, this._decoder, {required this.onPcmData});

  /// Subscribe to the glasses microphone audio stream.
  /// On the first packet, starts recording and kicks off the 500ms flush timer.
  void addListenerToMicrophone() {
    _audioSubscription = _manager.microphone.audioPacketStream.listen(
      (data) {
        // When first packet is recieved, start recording
        if (!_audioCollector.isRecording) {
          _audioCollector.isRecording = true;
          _audioCollector.reset();
          _startSendTimer();
        }
        // Add to buffer
        _audioCollector.addChunk(data.seq, data.data);
        if (_audioCollector.chunkCount >= 5) {
          _getPcmDataAndClearBuffer().then((pcm) {
            if (pcm != null) onPcmData(pcm);
          });
        }
      },
      onError: (error) {
        //todo
      },
    );
  }

  Future<Uint8List?> _getPcmDataAndClearBuffer() async {
    if (_audioCollector.chunkCount == 0) return null;

    final lc3Data = _audioCollector.getAllDataAndReset();
    return await _decoder.decodeLc3(lc3Data);
  }

  /// Start a periodic timer that flushes the audio buffer every 500 ms. // Changed 100ms
  void _startSendTimer() {
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      Uint8List? pcmData = await _getPcmDataAndClearBuffer();
      if (pcmData != null) onPcmData(pcmData);
    });
  }

  /// Stop recording: cancel the flush timer, send any remaining
  /// buffered audio, and mark recording as inactive.
  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
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
