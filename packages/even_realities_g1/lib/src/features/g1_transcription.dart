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
/// - 0x01 = start (battery saver, no time on glasses)
/// - 0x02 = start (full, shows time on glasses)
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
  Timer? _pageTimer;
  final List<List<String>> _pageQueue = [];
  List<String> _lastSentPage = [''];

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
  /// [batterySaver] - If true (default), uses mode 0x01 (no timer on glasses).
  /// If false, uses mode 0x02 (shows timer/counter on glasses).
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
          '[G1Transcription] Cannot pause (active=$isActive.value, paused=$_isPaused)');
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
          '[G1Transcription] Cannot resume (active=$isActive.value, paused=$_isPaused)');
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
    _pageTimer?.cancel();
    _pageTimer = null;
    _pageQueue.clear();

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

  /// Max text lines per page (line 1 is spacer).
  static const int _linesPerPage = 4;

  /// Queue text to display on the glasses.
  ///
  /// Splits long text into pages. Each page shows for 10 seconds,
  /// then advances. After the last page, clears the display.
  /// Keep-alive heartbeat only runs when nothing is queued.
  Future<void> displayText(String text, {bool isInterim = false}) async {
    if (!isActive.value || _isPaused) return;

    // Cancel any running page timer
    _pageTimer?.cancel();
    _pageTimer = null;

    if (text.isEmpty) {
      _pageQueue.clear();
      await _sendPage([''], isInterim: isInterim);
      return;
    }

    // Split into BLE-safe lines, then group into pages
    final lines = _splitText(text);
    _pageQueue.clear();
    for (int i = 0; i < lines.length; i += _linesPerPage) {
      final end = (i + _linesPerPage).clamp(0, lines.length);
      _pageQueue.add(lines.sublist(i, end));
    }

    // Show first page immediately
    await _showNextPage(isInterim: isInterim);
  }

  /// Show the next page from the queue, schedule advancement.
  Future<void> _showNextPage({bool isInterim = false}) async {
    if (_pageQueue.isEmpty) {
      // All pages shown — clear display after 10s
      _pageTimer = Timer(const Duration(seconds: 10), () {
        _sendPage([''], isInterim: false);
      });
      return;
    }

    final page = _pageQueue.removeAt(0);
    await _sendPage(page, isInterim: isInterim);

    // Schedule next page in 10 seconds
    _pageTimer = Timer(const Duration(seconds: 10), () {
      _showNextPage(isInterim: isInterim);
    });
  }

  /// Send a single page (list of text lines) to the glasses.
  Future<void> _sendPage(List<String> lines, {bool isInterim = false}) async {
    _lastSentPage = lines;
    final totalLines = lines.length + 1; // +1 for spacer

    // Line 1: empty spacer
    await _sendDisplayLine(
        line: 1, text: '', totalLines: totalLines, isInterim: isInterim);

    for (int i = 0; i < lines.length; i++) {
      await _sendDisplayLine(
          line: i + 2,
          text: lines[i],
          totalLines: totalLines,
          isInterim: isInterim);
    }
  }

  /// Split text into lines that fit within BLE packet size limit.
  List<String> _splitText(String text) {
    if (text.isEmpty) return [''];
    final textBytes = utf8.encode(text);
    if (textBytes.length <= _maxTextBytes) return [text];

    final chunks = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = text.length;
      while (utf8.encode(text.substring(start, end)).length > _maxTextBytes) {
        end--;
      }
      // Try to break at a space
      if (end < text.length) {
        final spaceIdx = text.lastIndexOf(' ', end);
        if (spaceIdx > start) end = spaceIdx;
      }
      chunks.add(text.substring(start, end).trim());
      start = end;
      while (start < text.length && text[start] == ' ') {
        start++;
      }
    }
    return chunks;
  }

  /// Build and send a single display line packet.
  Future<void> _sendDisplayLine({
    required int line,
    required String text,
    required int totalLines,
    required bool isInterim,
  }) async {
    final seq = _nextSeq();
    final textBytes = utf8.encode(text);

    final body = textBytes.isEmpty ? [0x0a, 0x0a] : [...textBytes, 0x0a];

    final packet = <int>[
      G1TranscriptionCommands.transcribeDisplay,
      0x00, // placeholder for total length
      0x00,
      seq,
      0x02, // sub-command: text display
      totalLines,
      0x00,
      line,
      0x00,
      isInterim ? 0x01 : 0x00,
      0x00,
      0x00,
      ...body,
    ];

    packet[1] = packet.length;

    await _manager.sendCommand(packet, needsAck: false);
  }

  /// Keep-alive heartbeat — resends the last page to keep the session alive.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (isActive.value && !_isPaused) {
        _sendPage(_lastSentPage, isInterim: false);
      }
    });
  }
}
