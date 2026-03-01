import 'package:even_realities_g1/even_realities_g1.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Widget that manages the BLE connection UI for the G1 glasses.
///
/// Reacts to [G1ConnectionState] changes via a StreamBuilder and shows
/// different UI for each state
class GlassesConnection extends StatefulWidget {
  final G1Manager manager;

  /// Called when the user taps the Record/Stop button (only visible when connected).
  final Future<void> Function()? onRecordToggle;
  const GlassesConnection(
      {super.key, required this.manager, this.onRecordToggle});

  @override
  State<GlassesConnection> createState() => _GlassesConnectionState();
}

class _GlassesConnectionState extends State<GlassesConnection> {
  void startScan() async {
    try {
      await widget.manager.startScan();
    } on Exception catch (e) {
      //If Bluetooth is off, attempt to turn it on.
      if (e.toString().contains('Bluetooth is turned off')) {
        await FlutterBluePlus.turnOn();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the glasses connection state changes
    return StreamBuilder<G1ConnectionEvent>(
      stream: widget.manager.connectionState,
      builder: (context, snapshot) {
        // No event yet — show the initial connect button
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(
            onPressed: startScan,
            child: const Text('Connect to glasses'),
          );
        }

        if (snapshot.hasData) {
          switch (snapshot.data!.state) {
            // Connected
            case G1ConnectionState.connected:
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: widget.manager.disconnect,
                        child: const Text('Disconnect'),
                      ),
                      const SizedBox(width: 8),
                      // Toggle between Record/Stop based on transcription state
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.manager.transcription.isActive,
                        builder: (context, isRecording, _) => ElevatedButton(
                          onPressed: () => widget.onRecordToggle?.call(),
                          style: ElevatedButton.styleFrom(
                            iconColor:
                                isRecording ? Colors.red : Colors.lightGreen,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isRecording ? Icons.mic_off : Icons.mic),
                              const SizedBox(width: 4),
                              Text(isRecording ? 'Stop' : 'Record'),
                            ],
                          ),
                        ),
                      )
                    ],
                  )
                ],
              );

            // Disconnected
            case G1ConnectionState.disconnected:
              return ElevatedButton(
                onPressed: startScan,
                child: const Text('Connect to glasses'),
              );

            // Scanning
            case G1ConnectionState.scanning:
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Searching for glasses'),
                  CircularProgressIndicator(),
                ],
              );

            // Connecting
            case G1ConnectionState.connecting:
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Connecting to glasses'),
                  CircularProgressIndicator(),
                ],
              );

            // Error
            case G1ConnectionState.error:
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Error in connecting to glasses'),
                  ElevatedButton(
                    onPressed: startScan,
                    child: const Text('Connect to glasses'),
                  ),
                ],
              );
          }
        }

        // Fallback if no data in stream
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No glasses found'),
            ElevatedButton(
              onPressed: startScan,
              child: const Text('Connect to glasses'),
            ),
          ],
        );
      },
    );
  }
}
