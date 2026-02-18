import 'package:flutter/material.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            children: [
                Row(
                    children: [
                        IconButton(
                            onPressed: () {},
                            icon: const Icon (Icons.menu),
                        ),
                        const Spacer(),
                        Image.asset(
                            'assets/images/Elisa_logo_blue_RGB.png',
                            height: 28,
                            fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.wb_sunny_outlined)
                        ),
                    ],
                ),
                const SizedBox(height: 24),

                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Image.asset(
                                'assets/images/g1-smart-glasses.webp',
                                height: 120,
                                fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                                'Even realities G1 smart glasses',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                ),
                            ),
                            const SizedBox(height: 34),
                            Row(
                                children: [
                                    Expanded(
                                        child: LandingTile(
                                            icon: Icons.bluetooth, 
                                            label: 'Connect to glasses', 
                                            onTap: () {},
                                        ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: LandingTile(
                                            icon: Icons.fiber_manual_record,
                                            label: 'Start recording',
                                            onTap: () {},
                                        ),
                                    ),
                                ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                                children: [
                                    Expanded(
                                        child: LandingTile(
                                            icon: Icons.list_alt,
                                            label: 'Key points', 
                                            onTap: () {},
                                        ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                        child: LandingTile(
                                            icon: Icons.play_circle_outline, 
                                            label: 'Recordings', 
                                            onTap: () {},
                                        ),
                                    ),
                                ],
                            ),
                            const SizedBox(height: 22),
                            Center(
                                child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black12),
                                        borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            Icon(Icons.battery_full, size: 18),
                                            SizedBox(width: 8),
                                            Text('G1 smart glasses'),
                                        ],
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            // top bar
            // content
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        TextButton(
                            onPressed: () {
                                //TODO navigate to login
                            },
                            child: const Text('Sign in'),
                        ),
                        const Text('|'),
                        TextButton(
                            onPressed: (){
                                //TODO navigate to register
                            },
                            child: const Text('Register'),
                        ),
                    ],
                )
            ),
            ],
          ), 
        ),
      ),
    );
  }
}



class LandingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const LandingTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                    child: Text(
                        label,
                        style: const TextStyle(fontSize: 14),
                    ) 
                ),
            ],
        ),
      ),
    );
  }
}