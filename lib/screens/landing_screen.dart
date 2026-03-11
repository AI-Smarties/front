import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import '../widgets/g1_connection.dart';
import '../services/websocket_service.dart';
import '../services/phone_audio_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'dart:async';

/// Landing screen of the app. Manages BLE glasses connection,
/// audio streaming, and live transcription display.
/// Also manages display of the landing page and navigation to login/register screens.

class LandingScreen extends StatefulWidget {
  /// All dependencies are optional — defaults are created in initState
  /// so they can be injected as mocks in tests.
  final G1Manager? manager;
  final WebsocketService? ws;
  final Lc3Decoder? decoder;
  final AudioPipeline? audioPipeline;
  const LandingScreen(
      {this.manager, this.decoder, this.ws, this.audioPipeline, super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final G1Manager _manager;
  late final Lc3Decoder _decoder;
  late final WebsocketService _ws;
  late final AudioPipeline _audioPipeline;
  late final PhoneAudioService _phoneAudio;

  bool _usePhoneMic = false;
  bool _isMuted = false;
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<bool> _isRecordingBusy = ValueNotifier(false);

  final List<String> _displayedSentences = [];
  static const int _maxDisplayedSentences = 4;

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
            if (_ws.connected.value) _ws.sendAudio(pcm);
          },
        );

    // Connect to backend WebSocket
    _ws.connect();

    _phoneAudio = PhoneAudioService();
    _phoneAudio.init();

    // React to committed (final) text only — interim is too noisy for glasses
    _ws.aiResponse.addListener(_onAiResponse);
  }

  @override
  void dispose() {
    _ws.aiResponse.removeListener(_onAiResponse);
    _isRecording.dispose();
    _isRecordingBusy.dispose();
    _audioPipeline.dispose();
    _phoneAudio.dispose();
    _ws.dispose();
    _manager.dispose();
    super.dispose();
  }

  void _onAiResponse() {
    final aiResponse = _ws.aiResponse.value;

    debugPrint(aiResponse);

    if (!_isMuted) {
      debugPrint("→ Adding to display: '$aiResponse'");
      if (_manager.isConnected && _manager.transcription.isActive.value) {
        _addSentenceToDisplay(aiResponse);
      }
    } else {
      debugPrint("→ Display is muted, skipping display update: '$aiResponse'");
    }
  }

  /// Adds a sentence to the on-screen queue.
  ///
  /// Each sentence is a separate BLE packet (lineNumber 1..N).
  /// When the list is full, the oldest sentence is evicted to make room.
  /// Sentences never disappear on a timer — they scroll off only when
  /// pushed out by new ones.
  void _addSentenceToDisplay(String sentence) {
    if (_displayedSentences.length >= _maxDisplayedSentences) {
      _displayedSentences.removeAt(0);
    }

    _displayedSentences.add(sentence);
    _manager.transcription.displayLines(
      List.unmodifiable(_displayedSentences),
    );

    Future.delayed(const Duration(seconds: 10), () {
      _displayedSentences.remove(sentence);
      _manager.transcription.displayLines(
        List.unmodifiable(_displayedSentences),
      );
    });
  }

  void _clearDisplayQueue() {
    _displayedSentences.clear();
  }

  /// Begin a transcription session
  Future<void> _startTranscription() async {
    if (_isRecordingBusy.value) return;
    if (!_usePhoneMic && !_manager.isConnected) return;
    _isRecordingBusy.value = true;
    try {
      if (_manager.isConnected) {
        //glasses implementation
        await _manager.transcription.stop(); // pakota clean stop ensin
        await Future.delayed(const Duration(milliseconds: 300));
        _ws.clearCommittedText(); // reset accumulated text — backend starts fresh too
        _clearDisplayQueue();

        await _ws.startAudioStream();
        await _manager.transcription.start();

        if (_usePhoneMic) {
          await _phoneAudio.start((pcm) {
            if (_ws.connected.value) {
              _ws.sendAudio(pcm);
            }
          });
        } else {
          await _manager.microphone.enable();
          _audioPipeline.addListenerToMicrophone();
        }

        await _manager.transcription.displayText('Recording started.');
        debugPrint("Transcription (re)started");
      } else {
        //wo glasses
        _ws.clearCommittedText(); // reset accumulated text — backend starts fresh too
        _clearDisplayQueue();
        await _ws.startAudioStream();
        await _phoneAudio.start(
          (pcm) {
            if (_ws.connected.value) _ws.sendAudio(pcm);
          },
        );
      }
      _isRecording.value = true;
    } finally {
      _isRecordingBusy.value = false;
    }
  }

  /// End a transcription session
  Future<void> _stopTranscription() async {
    if (_isRecordingBusy.value) return;
    _isRecordingBusy.value = true;
    _isRecording.value = false;
    try {
      if (_manager.isConnected) {
        _clearDisplayQueue();
        await _manager.transcription.displayText('Recording stopped.');
        await Future.delayed(const Duration(seconds: 2));
        if (_usePhoneMic) {
          await _phoneAudio.stop();
        } else {
          await _manager.microphone.disable();
          await _audioPipeline.stop();
        }
        // lisätty jotta paketit kerkiävät lähteä ennen sulkemista
        await Future.delayed(const Duration(milliseconds: 200));
        await _ws.stopAudioStream();
        await _manager.transcription.stop();
      } else {
        await _phoneAudio.stop();
        await _ws.stopAudioStream();
      }
    } finally {
      _isRecordingBusy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            children: [
              // ===== YLÄBANNERI =====
              Row(
                children: [
                  // Vasen
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.menu, color: Color(0xFF00239D)),
                      ),
                    ),
                  ),

                  // Logo keskelle
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/Elisa_logo_blue_RGB.png',
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Oikea
                  SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ListenableBuilder(
                          listenable: _ws.connected,
                          builder: (context, _) => _ws.connected.value
                              ? const Icon(
                                  Icons.signal_cellular_alt,
                                  color: Colors.green,
                                  size: 20,
                                )
                              : IconButton(
                                  onPressed: () => _ws.connect(),
                                  icon: const Icon(Icons.refresh),
                                ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.wb_sunny_outlined,
                            color: Color(0xFF00239D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/g1-smart-glasses.webp',
                      height: 120,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Even realities G1 smart glasses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 34),

                    // ===== CONNECT
                    Row(
                      children: [
                        // Connect / Disconnect
                        Expanded(
                          child: GlassesConnection(
                            manager: _manager,
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Mic toggle
                        Expanded(
                          child: ListenableBuilder(
                            listenable: Listenable.merge(
                                [_isRecording, _isRecordingBusy]),
                            builder: (context, _) {
                              final isLocked =
                                  _isRecording.value || _isRecordingBusy.value;

                              final borderColor = isLocked
                                  ? Colors.black26
                                  : (_usePhoneMic
                                      ? Colors.lightGreen
                                      : Colors.black12);
                              final backgroundColor = isLocked
                                  ? Colors.black.withAlpha((0.04 * 255).round())
                                  : (_usePhoneMic
                                      ? Colors.lightGreen
                                          .withAlpha((0.15 * 255).round())
                                      : Colors.transparent);

                              final textColor = isLocked
                                  ? Colors.black38
                                  : (_usePhoneMic
                                      ? Colors.lightGreen
                                      : Colors.black);

                              return Opacity(
                                opacity: isLocked ? 0.55 : 1,
                                child: InkWell(
                                  onTap: isLocked
                                      ? null
                                      : () {
                                          setState(() {
                                            _usePhoneMic = !_usePhoneMic;
                                          });
                                        },
                                  child: Container(
                                    height: 72,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: backgroundColor,
                                      border: Border.all(color: borderColor),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _usePhoneMic
                                            ? Icon(
                                                Icons.phone_android,
                                                size: 22,
                                                color: isLocked
                                                    ? Colors.black38
                                                    : Colors.lightGreen,
                                              )
                                            : Image.asset(
                                                'assets/images/g1-smart-glasses.webp',
                                                height: 22,
                                                fit: BoxFit.contain,
                                                color: isLocked
                                                    ? Colors.black38
                                                    : null,
                                                colorBlendMode: isLocked
                                                    ? BlendMode.srcIn
                                                    : null,
                                              ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _usePhoneMic
                                                ? 'Switch to glasses mic'
                                                : 'Switch to phone mic',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: _usePhoneMic
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // Start / Stop recording
                        Expanded(
                          child: StreamBuilder<G1ConnectionEvent>(
                            stream: _manager.connectionState,
                            initialData: G1ConnectionEvent(
                              state: _manager.isConnected
                                  ? G1ConnectionState.connected
                                  : G1ConnectionState.disconnected,
                            ),
                            builder: (context, snapshot) {
                              final isGlassesConnected = snapshot.data?.state ==
                                  G1ConnectionState.connected;

                              return ListenableBuilder(
                                listenable: Listenable.merge(
                                    [_isRecording, _isRecordingBusy]),
                                builder: (context, _) {
                                  final isRecording = _isRecording.value;
                                  final isBusy = _isRecordingBusy.value;

                                  final canStart = _usePhoneMic ||
                                      isGlassesConnected == true;

                                  final isDisabled =
                                      isBusy || (!isRecording && !canStart);

                                  final borderColor = isDisabled
                                      ? Colors.black26
                                      : (isRecording
                                          ? Colors.red
                                          : Colors.black12);
                                  final backgroundColor = isDisabled
                                      ? Colors.black
                                          .withAlpha((0.04 * 255).round())
                                      : (isRecording
                                          ? Colors.red
                                              .withAlpha((0.15 * 255).round())
                                          : Colors.transparent);

                                  final foregroundColor = isDisabled
                                      ? Colors.black38
                                      : (isRecording
                                          ? Colors.red
                                          : Colors.grey[800]);

                                  return Opacity(
                                    opacity: isDisabled ? 0.55 : 1,
                                    child: InkWell(
                                      onTap: isDisabled
                                          ? null
                                          : () async {
                                              if (!isRecording) {
                                                await _startTranscription();
                                              } else {
                                                await _stopTranscription();
                                              }
                                            },
                                      child: Container(
                                        height: 72,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: backgroundColor,
                                          border:
                                              Border.all(color: borderColor),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isRecording
                                                  ? Icons.stop_circle_outlined
                                                  : Icons.fiber_manual_record,
                                              size: 22,
                                              color: foregroundColor,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                isRecording
                                                    ? 'Stop\nRecording'
                                                    : 'Start\nRecording',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: foregroundColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Mute button
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                            },
                            child: Container(
                              height: 72,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: _isMuted
                                    ? Colors.orange
                                        .withAlpha((0.15 * 255).round())
                                    : Colors.transparent,
                                border: Border.all(
                                  color:
                                      _isMuted ? Colors.orange : Colors.black12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isMuted
                                        ? Icons.comments_disabled_outlined
                                        : Icons.comment_outlined,
                                    size: 22,
                                    color: _isMuted
                                        ? Colors.orange
                                        : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _isMuted
                                          ? 'Unmute display'
                                          : 'Mute display',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _isMuted
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _isMuted
                                            ? Colors.orange
                                            : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    ValueListenableBuilder<String>(
                      valueListenable: _ws.aiResponse,
                      builder: (context, aiResponse, _) {
                        if (aiResponse.isEmpty) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            aiResponse,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.battery_full, size: 18),
                            SizedBox(width: 8),
                            Text('G1 smart glasses'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ===== LOGIN / REGISTER =====
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: Color(0xFF00239D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text('|'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Color(0xFF00239D),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LandingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const LandingTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
