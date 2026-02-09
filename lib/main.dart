import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/* ================= APP ================= */

class MyApp extends StatelessWidget {
  final G1Manager? manager;
  const MyApp({this.manager, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(manager: manager),
    );
  }
}

/* ================= MODELS ================= */

class Recording {
  final String text;
  final String latency;
  final DateTime timestamp;

  Recording({
    required this.text,
    required this.latency,
    required this.timestamp,
  });
}

enum Transport { websocket, webrtc }

/* ================= PAGE ================= */

class HomePage extends StatefulWidget {
  final G1Manager? manager;
  const HomePage({this.manager, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /* ---------- audio ---------- */
  late FlutterSoundRecorder _recorder;
  late StreamController<Uint8List> _audioStreamController;

  /* ---------- connections ---------- */
  WebSocketChannel? _audioChannel;
  StreamSubscription? _audioChannelSub;

  bool _connected = false;
  bool _recording = false;
  bool _ready = false;

  double? _connectStartTs;
  String _connectLatency = "";

  /* ---------- speech ---------- */
  String _committedText = "";
  String _interimText = "";

  final List<Recording> _history = [];

  /* ================= INIT ================= */
  final TextEditingController _controller = TextEditingController();
  String _responseText = '';
  bool _isLoading = false;
  late final G1Manager _manager;

  @override
  void initState() {
    super.initState();
    // Kaverin lasit:
    _manager = widget.manager ?? G1Manager();

    // Sinun nauhurisi:
    _recorder = FlutterSoundRecorder();
    _audioStreamController = StreamController<Uint8List>();
    _init();
  }

  Future<void> _init() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();

    _audioStreamController.stream.listen((buffer) {
      _audioChannel?.sink.add(buffer);
    });

    setState(() => _ready = true);
  }

  /* ================= CONNECT ================= */

  Future<void> _toggleConnection() async {
    if (_connected) {
      await _disconnect();
      return;
    }
    await _connectWebSocket();
  }

// Uses config_dev.json / config_staging.json for environment variables
  static final Uri backendUrl = Uri.parse(
    const String.fromEnvironment('API_URL'),
  );

  Future<void> _sendTextToGlasses(String text) async {
    if (_manager.isConnected) {
      await _manager.display.showText(text);
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    try {
      final response = await http
          .post(
            backendUrl.resolve('/api/message/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json.containsKey('error')) {
          final error = json['error'] as String? ?? 'error';
          unawaited(_sendTextToGlasses(error));
          setState(() {
            _responseText = error;
          });
        } else if (json.containsKey('reply')) {
          final reply = json['reply'] as String? ?? 'No reply field';
          unawaited(_sendTextToGlasses(reply));
          setState(() {
            _responseText = reply;
          });
        } else {
          setState(() {
            _responseText = 'No reply';
          });
        }
      } else {
        setState(() => _responseText = 'Error: ${response.statusCode}');
      }
    } on Exception catch (e) {
      setState(() => _responseText = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnect() async {
    await _audioChannelSub?.cancel();
    _audioChannelSub = null;
    await _audioChannel?.sink.close();

    _audioChannel = null;

    if (!mounted) return; // Tarkistetaan, että sovellus on vielä käynnissä

    setState(() {
      _connected = false;
      _connectLatency = "";
    });
  }

  // VALITSE TÄMÄN MUKAAN MISSÄ FLUTTERIA AJETAAN:
  // Emulaattori: 10.0.2.2 | Puhelin: Tietokoneesi IP | Web: localhost
  final String _baseUrl = "localhost";
  final int _backendPort = 8001;

  /* ================= WEBSOCKET ================= */

  void _handleWsMessage(dynamic msg) {
    final data = jsonDecode(msg) as Map<String, dynamic>;

    if (data["type"] == "control" && data["cmd"] == "ready") {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      final start = _connectStartTs ?? now;
      final ms = (now - start).round();

      if (!mounted) return;
      setState(() {
        _connected = true;
        _connectLatency = "$ms ms";
      });

      _connectStartTs = null;
      return;
    }

    if (data["type"] == "transcript") {
      final payload = data["data"];
      final status = payload["status"];
      final text = (payload["text"] ?? "").toString().trim();

      if (status == "partial") {
        if (!mounted) return;
        setState(() => _interimText = text);
      }

      if (status == "final") {
        if (!mounted) return;
        setState(() {
          _committedText = text;
          _interimText = "";
        });
      }
    }
  }

  Future<void> _connectWebSocket() async {
    _connectStartTs = DateTime.now().millisecondsSinceEpoch.toDouble();
    _connectLatency = "";

    final uri = Uri.parse("ws://$_baseUrl:$_backendPort/ws/");

    _audioChannel = WebSocketChannel.connect(uri);

    await _audioChannelSub?.cancel();
    _audioChannelSub = _audioChannel!.stream.listen(
      _handleWsMessage,
      onError: (_) => _disconnect(),
      onDone: () => _disconnect(),
    );
  }

  /* ================= RECORDING ================= */

  Future<void> _start() async {
    setState(() {
      _recording = true;
      _committedText = "";
      _interimText = "";
    });

    await _recorder.startRecorder(
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
      toStream: _audioStreamController.sink,
    );
    _audioChannel?.sink.add(jsonEncode({"type": "control", "cmd": "start"}));
  }

  Future<void> _stop() async {
    await _recorder.stopRecorder();

    _audioChannel?.sink.add(jsonEncode({"type": "control", "cmd": "stop"}));

    final fullText =
        [_committedText, _interimText].where((s) => s.isNotEmpty).join(" ");

    if (fullText.isNotEmpty) {
      setState(() {
        _history.insert(
          0,
          Recording(
            text: fullText,
            latency: _connectLatency,
            timestamp: DateTime.now(),
          ),
        );
      });
    }

    setState(() {
      _recording = false;
      _committedText = "";
      _interimText = "";
    });
  }

  void _clearHistory() {
    setState(() => _history.clear());
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smarties App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _toggleConnection,
                  child: Text(_connected ? "Disconnect" : "Connect"),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _connected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (!_ready || !_connected)
                      ? null
                      : (_recording ? _stop : _start),
                  child: Text(_recording ? "Stop" : "Start"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _clearHistory,
                  child: const Text("Clear"),
                ),
              ],
            ),
            if (_connectLatency.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Connection latency: $_connectLatency",
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _committedText,
                        style: const TextStyle(
                            fontSize: 20, color: Colors.black87),
                      ),
                      if (_interimText.isNotEmpty)
                        TextSpan(
                          text: (_committedText.isNotEmpty ? " " : "") +
                              _interimText,
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  ..._history.map((r) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${r.timestamp.toLocal()} • ${r.latency}",
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 6),
                              Text(r.text,
                                  style: const TextStyle(fontSize: 18)),
                            ],
                          ),
                        ),
                      )),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Write message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _sendText,
                      child: const Text('Send to Glasses'),
                    ),
                  const SizedBox(height: 16),
                  Text('Response:',
                      style: Theme.of(context).textTheme.titleMedium),
                  SelectableText(_responseText),
                  const Divider(),
                  StreamBuilder<G1ConnectionEvent>(
                    stream: _manager.connectionState,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ElevatedButton(
                            onPressed: _manager.startScan,
                            child: const Text('Connect to glasses'));
                      }

                      if (snapshot.hasData) {
                        switch (snapshot.data!.state) {
                          case G1ConnectionState.connected:
                            return Column(
                              children: [
                                const Text('Connected to glasses'),
                                ElevatedButton(
                                    onPressed: _manager.disconnect,
                                    child: const Text('Disconnect')),
                              ],
                            );
                          case G1ConnectionState.scanning:
                          case G1ConnectionState.connecting:
                            return const Center(
                                child: CircularProgressIndicator());
                          default:
                            return ElevatedButton(
                                onPressed: _manager.startScan,
                                child: const Text('Connect to glasses'));
                        }
                      }
                      return ElevatedButton(
                          onPressed: _manager.startScan,
                          child: const Text('Connect to glasses'));
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioStreamController.close();
    _recorder.closeRecorder();
    _disconnect();
    super.dispose();
  }
}
