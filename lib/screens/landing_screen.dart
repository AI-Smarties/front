import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import '../services/rest_api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/g1_connection.dart';
import '../widgets/side_panel.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Landing screen of the app. Manages BLE glasses connection,
/// audio streaming, and live transcription display.
/// Also manages display of the landing page and navigation to login/register screens.
class LandingScreen extends StatefulWidget {
  /// All dependencies are optional — defaults are created in [initState]
  /// so they can be injected as mocks in tests.
  final G1Manager? manager;
  final WebsocketService? ws;
  final Lc3Decoder? decoder;
  final AudioPipeline? audioPipeline;
  final RestApiService? api;

  const LandingScreen({
    this.manager,
    this.decoder,
    this.ws,
    this.audioPipeline,
    this.api,
    super.key,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  // GlobalKey lets us open the drawer from multiple places,,
  // not just from a local BuildContext next to the Scaffold.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final G1Manager _manager;
  late final Lc3Decoder _decoder;
  late final WebsocketService _ws;
  late final AudioPipeline _audioPipeline;
  late final RestApiService _api;

  @override
  void initState() {
    super.initState();

    _manager = widget.manager ?? G1Manager();
    _decoder = widget.decoder ?? Lc3Decoder();
    _ws = widget.ws ?? WebsocketService();

    // Added as injectable dependency so REST API access stays testable
    // and consistent with other optional dependencies in this screen.
    _api = widget.api ?? const RestApiService();
    _audioPipeline = widget.audioPipeline ??
        AudioPipeline(
          _manager,
          _decoder,
          onPcmData: (pcm) {
            if (_ws.connected.value) _ws.sendAudio(pcm);
          },
        );

    _ws.connect();
    _audioPipeline.addListenerToMicrophone();
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

  void _onWsChange() {
    if (_manager.isConnected && _manager.transcription.isActive.value) {
      _manager.transcription.displayText(
        _ws.getFullText(),
        isInterim: _ws.interimText.value.isNotEmpty,
      );
    }
  }

  Future<void> _startTranscription() async {
    await _ws.startAudioStream();
    await _manager.transcription.start();
  }

  Future<void> _stopTranscription() async {
    await _audioPipeline.stop();
    await _ws.stopAudioStream();
    await _manager.transcription.stop();
  }

// Added helper so both menu button and landing tile can open the side panel.
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      // Main integration point for the new REST side panel feature.
      drawer: SidePanel(api: _api),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _openDrawer,
                    icon: const Icon(Icons.menu, color: Color(0xFF00239D)),
                    tooltip: 'Open history panel',
                  ),

                  // Top row layout changed to avoid right overflow on narrow phones.
                  // Old version used Spacer() + a long button, which overflowed.
                  Image.asset(
                    'assets/images/Elisa_logo_blue_RGB.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ListenableBuilder(
                          listenable: _ws.connected,
                          builder: (context, _) => _ws.connected.value
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.signal_cellular_alt,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Connected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                )
                              : FittedBox(
                                  // FittedBox added so the reconnect button can scale down
                                  // instead of overflowing on smaller screens.
                                  fit: BoxFit.scaleDown,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _ws.connect(),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text(
                                      'Reconnect to server',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
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
                          // Changed so "Key points" now opens the REST side panel.
                          child: LandingTile(
                            icon: Icons.list_alt,
                            label: 'Key points',
                            onTap: _openDrawer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          // Kept disabled because no recordings feature was added here. (Changeable when available)
                          child: LandingTile(
                            icon: Icons.play_circle_outline,
                            label: 'Recordings',
                            onTap: () {},
                            enabled: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
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
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
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
    // Styling adjusted so disabled tiles look visibly disabled
    // instead of feeling like broken clickable buttons.
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
            color: enabled ? null : Colors.grey.withValues(alpha: 0.06),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: enabled ? null : Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
