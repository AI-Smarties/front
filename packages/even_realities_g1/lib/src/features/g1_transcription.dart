import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../bluetooth/g1_connection_state.dart';
import '../bluetooth/g1_manager.dart';
import '../protocol/commands.dart';

/// G1 Transcription mode controller.
///
/// Handles the BLE commands to enter/exit transcription mode, which
/// programmatically activates the mic hardware on the glasses.
/// Audio data flows through the existing [G1Microphone] streams.
///
/// Display modes (byte 5 of 0x52 mode command):
/// - 0x00 = stop
/// - 0x01 = start (full, shows time on glasses)
/// - 0x02 = start (battery saver, no time on glasses)
/// - 0x03 = pause
/// - 0x04 = resume
class G1Transcription {
  final G1Manager _manager;
  
  int _seq = 0;

  /// Whether transcription mode is currently active (started and not stopped).
  final isActive = ValueNotifier<bool>(false);

  /// Whether currently paused (mic closed but session alive).
  bool _isPaused = false;

  /// Whether cleanup (0x53) was already sent (during resume).
  /// Cleanup is sent exactly once between start and stop.
  bool _cleanedUp = false;

  Timer? _keepAliveTimer;

  G1Transcription(this._manager);

  /// Whether transcription is currently paused.
  bool get isPaused => _isPaused;

  int _nextSeq() {
    final s = _seq;
    _seq = (_seq + 1) % 256;
    return s;
  }

  /// Start transcription mode.
  ///
  /// [batterySaver] - If true (default), uses mode 0x02 (no timer on glasses).
  /// If false, uses mode 0x01 (shows timer/counter on glasses).
  ///
  /// Audio data will be available via [G1Microphone.audioPacketStream].
  Future<void> start({bool batterySaver = true}) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    if (isActive.value) {
      debugPrint('[G1Transcription] Already active');
      return;
    }

    _cleanedUp = false;

    // Step 1: Setup command (0x39) to both sides
    final seq1 = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.setup, 0x05, 0x00, seq1, 0x01],
      needsAck: false,
    );

    // Step 2: Activate transcription mode (0x50) to RIGHT only
    await _manager.sendCommandToSide(
      GlassSide.right,
      [G1TranscriptionCommands.modeActivate, 0x06, 0x00, 0x00, 0x01, 0x01],
      needsAck: false,
    );

    // Step 3: Start transcribe display (0x52) to both sides
    final mode = batterySaver ? 0x02 : 0x01;
    final seq3 = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.transcribeDisplay, 0x06, 0x00, seq3, 0x01, mode],
      needsAck: false,
    );

    // Step 4: Open mic
    await _manager.microphone.enable();

    isActive.value = true;
    _isPaused = false;
    _startKeepAlive();
    debugPrint('[G1Transcription] Started (batterySaver=$batterySaver)');
  }

  /// Pause transcription (close mic but keep session alive).
  ///
  /// Sends mode 0x03 then closes mic. Call [resume] to continue.
  Future<void> pause() async {
    if (!isActive.value || _isPaused) {
      debugPrint(
          '[G1Transcription] Cannot pause (active=${isActive.value}, paused=$_isPaused)');
      return;
    }

    // Mode 0x03 (pause) to both sides
    final seq = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.transcribeDisplay, 0x06, 0x00, seq, 0x01, 0x03],
      needsAck: false,
    );

    // Close mic
    await _manager.microphone.disable();

    _isPaused = true;
    debugPrint('[G1Transcription] Paused');
  }

  /// Resume transcription after pause.
  ///
  /// Sends cleanup (0x53), mode 0x04, then reopens mic.
  Future<void> resume() async {
    if (!isActive.value || !_isPaused) {
      debugPrint(
          '[G1Transcription] Cannot resume (active=${isActive.value}, paused=$_isPaused)');
      return;
    }

    // Cleanup (0x53) to both sides
    final seq1 = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.cleanup, 0x06, 0x00, seq1, 0x03, 0x00],
      needsAck: false,
    );
    _cleanedUp = true;

    // Mode 0x04 (resume) to both sides
    final seq2 = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.transcribeDisplay, 0x06, 0x00, seq2, 0x01, 0x04],
      needsAck: false,
    );

    // Reopen mic
    await _manager.microphone.enable();

    _isPaused = false;
    debugPrint('[G1Transcription] Resumed');
  }

  /// Stop transcription mode.
  ///
  /// If paused, mic is already closed. If active, closes mic first.
  /// Sends cleanup (0x53) if not already done during resume.
  Future<void> stop() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    if (!isActive.value) {
      debugPrint('[G1Transcription] Not active');
      return;
    }

    isActive.value = false;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    // Close mic if not already paused
    if (!_isPaused) {
      await _manager.microphone.disable();
    }

    // Cleanup if not already done during resume
    if (!_cleanedUp) {
      final seqCleanup = _nextSeq();
      await _manager.sendCommand(
        [G1TranscriptionCommands.cleanup, 0x06, 0x00, seqCleanup, 0x03, 0x00],
        needsAck: false,
      );
    }

    // Stop display (mode 0x00)
    final seq = _nextSeq();
    await _manager.sendCommand(
      [G1TranscriptionCommands.transcribeDisplay, 0x06, 0x00, seq, 0x01, 0x00],
      needsAck: false,
    );

    _isPaused = false;
    _cleanedUp = false;
    debugPrint('[G1Transcription] Stopped');
  }

  /// Max text bytes per BLE packet (248 max - 13 header bytes).
  static const int _maxTextBytes = 235;

  /// Send text to the glasses display. Truncates to BLE packet limit.
  Future<void> displayText(String text, {bool isInterim = false}) async {
    if (!isActive.value || _isPaused) return;

    // Truncate to fit in one BLE packet
    String chunk = text;
    while (utf8.encode(chunk).length > _maxTextBytes) {
      chunk = chunk.substring(0, chunk.length - 1);
    }

    await _sendDisplay(chunk, isInterim: isInterim);
    _startKeepAlive();
  }

  /// Send a single text chunk to the glasses display.
  Future<void> _sendDisplay(String text, {bool isInterim = false}) async {
    final seq = _nextSeq();
    final textBytes = utf8.encode(text);
    final body = textBytes.isEmpty ? [0x0a, 0x0a] : [...textBytes, 0x0a];

    final packet = <int>[
      G1TranscriptionCommands.transcribeDisplay,
      0x00, // placeholder for total length
      0x00,
      seq,
      0x02, // sub-command: text display
      0x01, // totalLines
      0x00,
      0x01, // line number
      0x00,
      isInterim ? 0x01 : 0x00,
      0x00,
      0x00,
      ...body,
    ];
    packet[1] = packet.length;

    await _manager.sendCommand(packet, needsAck: false);
  }

  /// Keep-alive: resends empty display to keep transcription session alive.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (isActive.value && !_isPaused) {
        await _sendDisplay('', isInterim: false);
      }
    });
  }
}
