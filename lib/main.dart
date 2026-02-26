import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  const MyApp(
      {this.manager, this.ws, this.decoder, this.audioPipeline, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LandingScreen(
        manager: manager,
        ws: ws,
        decoder: decoder,
        audioPipeline: audioPipeline,
      ),
    );
  }
}
