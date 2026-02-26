import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import '../widgets/g1_connection.dart';
import '../services/websocket_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

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
            // Forward decoded pcm audio to the backend via WebSocket
            if (_ws.connected.value) _ws.sendAudio(pcm);
          },
        );

    // Connect to backend WebSocket server when homePage is initialized
    _ws.connect();

    // Add listener for mic audio packets from glasses
    _audioPipeline.addListenerToMicrophone();

    // React to Speech to text updates from the backend
    // Used to update the UI (fired when committedText/interimText is changed)
    _ws.committedText.addListener(_onWsChange);
    _ws.interimText.addListener(_onWsChange);
  }

  @override
  void dispose() {
    _ws.committedText.removeListener(_onWsChange);
    _ws.interimText.removeListener(_onWsChange);
    _audioPipeline.dispose();
    _ws.dispose();
    _manager.dispose();
    super.dispose();
  }

  /// Forwards changes to the glasses display if connected and transcription is active.
  void _onWsChange() {
    if (_manager.isConnected && _manager.transcription.isActive.value) {
      final text = _ws.getFullText();
      _manager.transcription.displayText(
        text,
        isInterim: _ws.interimText.value.isNotEmpty,
      );
    }
  }

  /// Begin a transcription session
  Future<void> _startTranscription() async {
    await _ws.startAudioStream();
    await _manager.transcription.start();
  }

  /// End a transcription session
  Future<void> _stopTranscription() async {
    await _audioPipeline.stop();
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
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.menu, color: Color(0xFF00239D)),
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/images/Elisa_logo_blue_RGB.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ListenableBuilder(
                      listenable: _ws.connected,
                      builder: (context, _) => _ws.connected.value
                        ? const Row(
                          children: [
                          Icon(Icons.signal_cellular_alt,
                              color: Colors.green, size: 20),
                          SizedBox(width: 6),
                          Text('Connected',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.green)),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _ws.connect(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reconnect to server'),
                      ),
              )),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.wb_sunny_outlined, color: Color(0xFF00239D))),
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
                    GlassesConnection(
                      manager: _manager,
                      onRecordToggle: () async {
                        if (!_manager.transcription.isActive.value) {
                          await _startTranscription();
                        } else {
                          await _stopTranscription();
                        }
                      },
                        
                    ),

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: LandingTile(
                            icon: Icons.list_alt,
                            label: 'Key points',
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 14),
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
                  )),
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
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            )),
          ],
        ),
      ),
    );
  }
}
