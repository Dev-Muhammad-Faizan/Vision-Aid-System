import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';

class CameraControlsCard extends StatelessWidget {
  const CameraControlsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Camera Controls",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        // ── Start / Stop Row ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: provider.isConnected && !provider.isCameraRunning
                    ? provider.startDetection
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Run Detection"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: provider.isConnected && provider.isCameraRunning
                    ? provider.stopDetection
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text("Stop"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Announce Location ─────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: provider.isConnected ? provider.announceLocation : null,
          icon: const Icon(Icons.location_on),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Text("Announce Live Location from Phone to Glasses"),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
