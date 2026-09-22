import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF80CBC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon ────────────────────────────────────────────
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(
                      Icons.remove_red_eye_outlined,
                      size: 62,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Title ────────────────────────────────────────────
                  const Text(
                    "Vision-Aid Glasses",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "Smart assistive glasses companion app for real-time object detection, navigation, and caretaker monitoring.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),

                  // ── Connection Badge ──────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: provider.isConnected
                          ? Colors.green.withValues(alpha: 0.25)
                          : Colors.red.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: provider.isConnected
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.isChecking
                              ? Icons.hourglass_top
                              : provider.isConnected
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isChecking
                              ? "Connecting..."
                              : provider.isConnected
                                  ? "Connected — ${provider.piIpAddress}"
                                  : "Not Connected",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 42),

                  // ── Open Dashboard Button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.dashboard_rounded),
                      label: const Text(
                        "Open Dashboard",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00695C),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DashboardScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Retry Connection ──────────────────────────────────
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    label: const Text(
                      "Retry Connection",
                      style: TextStyle(color: Colors.white70),
                    ),
                    onPressed: provider.isChecking
                        ? null
                        : () => provider.checkConnection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
