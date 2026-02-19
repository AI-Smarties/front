import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import '/services/websocket_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  final G1Manager? manager;
  final WebsocketService? ws;
  final Lc3Decoder? decoder;
  final AudioPipeline? audioPipeline;

  const LoginScreen({
    super.key,
    this.manager,
    this.ws,
    this.decoder,
    this.audioPipeline,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(
                      manager: manager,
                      ws: ws,
                      decoder: decoder,
                      audioPipeline: audioPipeline,
                    ),
                  ),
                );
              },
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Color(0xFF00239D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
