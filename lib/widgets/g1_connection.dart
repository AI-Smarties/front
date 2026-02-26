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
  Future<void> startScan() async {
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
          return LandingTileButton(
            icon: Icons.bluetooth,
            label: 'Connect to glasses',
            onTap: () async {
              await startScan();
            },
          );
        }

        if (snapshot.hasData) {
          switch (snapshot.data!.state) {
            // Connected
            case G1ConnectionState.connected:
              return ValueListenableBuilder<bool>(
                valueListenable: widget.manager.transcription.isActive,
                builder: (context, isRecording, _) {
                  return Row(
                    children: [
                      Expanded(
                        child: LandingTileButton(
                          icon: Icons.bluetooth_connected,
                          label: 'Disconnect',
                          onTap: () async {
                            await widget.manager.disconnect();
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: LandingTileButton(
                          icon: isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.mic,
                          label: isRecording ? 'Stop' : 'Record',
                          onTap: () async {
                            await widget.onRecordToggle?.call();
                          },
                        ),
                      ),
                    ],
                  );
                },
              );

            // Disconnected
            case G1ConnectionState.disconnected:
              return LandingTileButton(
                icon: Icons.bluetooth,
                label: 'Connect to glasses',
                onTap: () async {
                  await startScan();
                },
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
                  LandingTileButton(
                      icon: Icons.bluetooth,
                      label: 'Connect to glasses',
                      onTap: startScan)
                ],
              );
          }
        }

        // Fallback if no data in stream
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error in connecting to glasses'),
            const SizedBox(height: 10),
            LandingTileButton(
              icon: Icons.refresh,
              label: 'Retry',
              onTap: startScan,
            ),
          ],
        );
      },
    );
  }
}

class LandingTileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function()? onTap;

  const LandingTileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
