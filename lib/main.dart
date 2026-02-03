import 'dart:async';
import 'dart:convert';
import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? G1Manager();
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
                          const Text('Connected to glasses'),
                          ElevatedButton(
                            onPressed: _manager.disconnect,
                            child: const Text('Disconnect'),
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
