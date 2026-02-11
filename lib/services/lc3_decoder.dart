import 'package:flutter/services.dart';

// Platform channel for native LC3 decoding
class Lc3Decoder {
  static const _lc3Channel = MethodChannel('com.smarties.audio/lc3');

  // Decode LC3 audio using native Android decoder
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
