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

  int _lastCommittedLength = 0;
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

    // Add listener for mic audio packets
    // _audioPipeline.addListenerToMicrophone();

    // React to committed (final) text only — interim is too noisy for glasses
    _ws.committedText.addListener(_onCommittedTextChange);

    // Korjattu: tyhjennys ja mic disable vain kerran käynnistyksessä
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manager.microphone.disable();
      if (_manager.isConnected) {
        _manager.clearScreen();
        debugPrint("Cleared screen on app start");
      }
    });
  }

  @override
  void dispose() {
    _ws.committedText.removeListener(_onCommittedTextChange);
    _audioPipeline.dispose();
    _phoneAudio.dispose();
    _ws.dispose();
    _manager.dispose();
    super.dispose();
  }

  /// Called when the backend commits a final transcript fragment.
  ///
  /// The backend accumulates all final text in one growing string
  /// (e.g. "First sentence. Second sentence."). We track how much
  /// has already been displayed via [_lastCommittedLength] and extract
  /// only the new portion. Each fragment from the backend already ends
  /// with punctuation, so it is a complete sentence ready to display.
  void _onCommittedTextChange() {
    final fullText = _ws.committedText.value;

    // Empty = session reset (disconnect / new start) → reset pointer
    if (fullText.isEmpty) {
      _lastCommittedLength = 0;
      return;
    }

    if (!_manager.isConnected || !_manager.transcription.isActive.value) return;

    // Nothing new to show
    if (fullText.length <= _lastCommittedLength) return;

    // Extract only the newly committed sentence
    final newSentence = fullText.substring(_lastCommittedLength).trim();
    _lastCommittedLength = fullText.length;

    if (newSentence.isEmpty) return;

    debugPrint("→ Adding to display: '$newSentence'");
    _addSentenceToDisplay(newSentence);
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
    await _manager.transcription.stop(); // pakota clean stop ensin
    await Future.delayed(const Duration(milliseconds: 300));
    _ws.clearCommittedText(); // reset accumulated text — backend starts fresh too
    _lastCommittedLength = 0;
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
  }

  /// End a transcription session
  Future<void> _stopTranscription() async {
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
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _usePhoneMic = !_usePhoneMic;
                              });
                            },
                            child: Container(
                              height: 72,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: _usePhoneMic
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _usePhoneMic
                                      ? Colors.green
                                      : Colors.black12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _usePhoneMic
                                      ? const Icon(
                                          Icons.mic,
                                          size: 22,
                                          color: Colors.green,
                                        )
                                      : Image.asset(
                                          'assets/images/g1-smart-glasses.webp',
                                          height: 22,
                                          fit: BoxFit.contain,
                                        ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _usePhoneMic
                                          ? 'Phone mic\n(Active)'
                                          : 'Glasses mic\n(Active)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _usePhoneMic
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _usePhoneMic
                                            ? Colors.green
                                            : Colors.black,
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

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        // Start / Stop recording
                        Expanded(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _manager.transcription.isActive,
                            builder: (context, isRecording, _) {
                              return InkWell(
                                onTap: () async {
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
                                    color: isRecording
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isRecording
                                          ? Colors.red
                                          : Colors.black12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isRecording
                                            ? Icons.stop_circle_outlined
                                            : Icons.fiber_manual_record,
                                        size: 22,
                                        color: isRecording
                                            ? Colors.red
                                            : Colors.grey[800],
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
                                            color: isRecording
                                                ? Colors.red
                                                : Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Recordings placeholder
                        Expanded(
                          child: LandingTile(
                            icon: Icons.play_circle_outline,
                            label: 'Recordings',
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

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
