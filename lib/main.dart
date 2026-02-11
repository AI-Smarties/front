import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:front/services/lc3_decoder.dart';
import 'package:front/services/audio_pipeline.dart';
import 'services/websocket_service.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final G1Manager? manager;
  final WebsocketService? ws;
  final Lc3Decoder? decoder;
  final AudioPipeline? audioPipeline;

  const MyApp(
      {this.manager, this.ws, this.decoder, this.audioPipeline, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(
        manager: manager,
        ws: ws,
        decoder: decoder,
        audioPipeline: audioPipeline,
      ),
    );
  }
}
