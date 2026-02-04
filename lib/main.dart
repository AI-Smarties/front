import 'dart:async';
import 'dart:convert';
import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
void main() {
  runApp(const MyApp());
}

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

class HomePage extends StatefulWidget {
  final G1Manager? manager;
  const HomePage({this.manager, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _responseText = '';
  bool _isLoading = false;
  late final G1Manager _manager;
  StreamSubscription<List<int>>? _audioSubscription;

  // Platform channel for native LC3 decoding
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


  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? G1Manager();

    // Listen to audio data from microphone
    _audioSubscription = _manager.microphone.audioStream.listen(
      (audioData) async {
        // audioData is raw lc3 audio bytes from glasses
        print('starting to decode');

        // Decode lc3 to pcm using native Android decoder
        final pcmData = await decodeLc3(audioData);
        print('decoded');

        if (pcmData != null) {
          // TODO: Send pcm audio to backend
          print('Decoded ${audioData.length} LC3 bytes → ${pcmData.length} PCM bytes');
        }
      },
      onError: (error) {
        print('Audio stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smarties App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Write message'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _sendText,
                child: const Text('Send'),
              ),
            const SizedBox(height: 24),
            Text('Response:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_responseText),
            StreamBuilder<G1ConnectionEvent>(
              stream: _manager.connectionState,
              builder: (context, snapshot) {
                // 1. Handle loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ElevatedButton(
                    onPressed: _manager.startScan,
                    child: const Text('Connect to glasses'),
                  );
                }

                // 2. Handle data
                if (snapshot.hasData) {
                  switch (snapshot.data!.state) {
                    case G1ConnectionState.connected:
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Connection ${_manager.isConnected}'),
                          const Text('Connected to glasses'),
                          ElevatedButton(
                            onPressed: _manager.disconnect,
                            child: const Text('Disconnect'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (_manager.microphone.isActive) {
                                await _manager.microphone.disable();
                              } else {
                                await _manager.microphone.enable();
                              }
                              setState(() {});
                            },
                            child: Text(_manager.microphone.isActive
                                ? 'Stop recording'
                                : 'Start recording'),
                          ),
                        ],
                      );
                    case G1ConnectionState.disconnected:
                      return ElevatedButton(
                        onPressed: _manager.startScan,
                        child: const Text('Connect to glasses'),
                      );
                    case G1ConnectionState.scanning:
                      return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Searching for glasses'),
                          CircularProgressIndicator(),
                        ],
                      );

                    case G1ConnectionState.connecting:
                      return const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Connecting to glasses'),
                          CircularProgressIndicator(),
                        ],
                      );
                    case G1ConnectionState.error:
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Error in connecting to glasses'),
                          ElevatedButton(
                            onPressed: _manager.startScan,
                            child: const Text('Connect to glasses'),
                          ),
                        ],
                      );
                  }
                }

                // 3. Handle error or empty
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No glasses found'),
                    ElevatedButton(
                      onPressed: _manager.startScan,
                      child: const Text('Connect to glasses'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
