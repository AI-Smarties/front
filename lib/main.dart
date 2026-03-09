import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  fbp.FlutterBluePlus.setLogLevel(fbp.LogLevel.none,
      color: false);  // Disable logging for fbp package
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LandingScreen(),
    );
  }
}
