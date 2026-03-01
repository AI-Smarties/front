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
      initialData: G1ConnectionEvent(
        state: widget.manager.isConnected
            ? G1ConnectionState.connected
            : G1ConnectionState.disconnected,
      ),
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
              return LandingTileButton(
                icon: Icons.bluetooth_connected,
                label: 'Connected',
                activeColor: Colors.lightGreen,
                onTap: () async {
                  await widget.manager.transcription.stop();
                  await widget.manager.disconnect();
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
  final Color? activeColor;
  final Future<void> Function()? onTap;

  const LandingTileButton({
    super.key,
    required this.icon,
    required this.label,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: activeColor != null
              ? activeColor!.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: activeColor ?? Colors.black12,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: activeColor ?? Colors.grey[700],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: activeColor ?? Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
