import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';

class ConfigHubCard extends StatelessWidget {
  const ConfigHubCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Configuration Hub",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                // ── Color Mode ────────────────────────────────────────
                SwitchListTile(
                  title: const Text("Color Detection Mode"),
                  subtitle: const Text(
                      "Announces dominant color of detected objects"),
                  value: provider.isColorEnabled,
                  onChanged:
                      provider.isConnected ? provider.toggleColorMode : null,
                ),

                const Divider(height: 1),

                // ── Language ──────────────────────────────────────────
                ListTile(
                  title: const Text("Announcement Language"),
                  trailing: DropdownButton<String>(
                    value: provider.language,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: "English", child: Text("English")),
                      DropdownMenuItem(value: "Urdu", child: Text("Urdu")),
                    ],
                    onChanged: provider.isConnected
                        ? (val) {
                            if (val != null) provider.updateLanguage(val);
                          }
                        : null,
                  ),
                ),

                const Divider(height: 1),

                // ── Distance Threshold ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Near Distance Threshold (${provider.distanceThresh.toStringAsFixed(2)})",
                        style: const TextStyle(fontSize: 14),
                      ),
                      Slider(
                        value: provider.distanceThresh,
                        min: 0.1,
                        max: 0.8,
                        divisions: 14,
                        label: provider.distanceThresh.toStringAsFixed(2),
                        onChanged:
                            provider.isConnected ? provider.updateDistance : null,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ── TTS Delay ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TTS Repeat Delay (${provider.positionDelay.toStringAsFixed(1)} sec)",
                        style: const TextStyle(fontSize: 14),
                      ),
                      Slider(
                        value: provider.positionDelay,
                        min: 1.0,
                        max: 10.0,
                        divisions: 18,
                        label: provider.positionDelay.toStringAsFixed(1),
                        onChanged:
                            provider.isConnected ? provider.updateDelay : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
