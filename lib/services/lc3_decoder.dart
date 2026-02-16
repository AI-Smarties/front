import 'package:flutter/services.dart';

/// Decodes LC3 (Low Complexity Communication Codec) audio to raw PCM
/// by calling a native Android implementation via a platform channel.
///
/// LC3 is the codec used by the G1 glasses microphone.
/// The native side (Kotlin/C++) handles the actual decoding since
class Lc3Decoder {
  static const _lc3Channel = MethodChannel('com.smarties.audio/lc3');

  /// Decode a buffer of LC3 audio data into raw PCM bytes.
  /// Returns null if decoding fails (e.g. native library not available).
  Future<Uint8List?> decodeLc3(List<int> lc3Data) async {
    try {
      final result = await _lc3Channel.invokeMethod<Uint8List>(
        'decodeLc3',
        {'audioData': Uint8List.fromList(lc3Data)},
      );
      return result;
    } on PlatformException catch (e) {
      print('Failed to decode LC3: ${e.message}');
      return null;
    }
  }
}
