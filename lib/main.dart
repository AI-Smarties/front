import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  String _responseText = "";
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const bool useLocalBackend =
      true; // Change to false when using staging-prod

  static final Uri backendUrl = useLocalBackend
      ? Uri.parse("http://127.0.0.1:8000/api/message/")
      : Uri.parse(
          "https://g1-smart-glasses-backend-ohtuprojekti-staging.ext.ocp-prod-0.k8s.it.helsinki.fi/api/message/");

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _responseText = "";
    });

    final url = backendUrl;

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _responseText = data["reply"] ?? "No reply field";
        });
      } else {
        setState(() => _responseText = "Virhe: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _responseText = "Yhteysvirhe: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Smarties App")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "Kirjoita viesti"),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _sendText,
                    child: const Text("Lähetä"),
                  ),
            const SizedBox(height: 24),
            Text("Vastaus:", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(_responseText),
          ],
        ),
      ),
    );
  }
}
