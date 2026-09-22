import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';

class AudioAnnouncementCard extends StatefulWidget {
  const AudioAnnouncementCard({super.key});

  @override
  State<AudioAnnouncementCard> createState() => _AudioAnnouncementCardState();
}

class _AudioAnnouncementCardState extends State<AudioAnnouncementCard> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Custom Push Announcement",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        // ── Text Field ────────────────────────────────────────────────
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: provider.language == "Urdu"
                ? "Urdu Text to speak"
                : "Text to speak",
            hintText: provider.language == "Urdu"
                ? "e.g: Ruko, aage khatara hai!"
                : "e.g. Stop, danger ahead!",
          ),
        ),

        const SizedBox(height: 10),

        // ── Send Button ───────────────────────────────────────────────
        ElevatedButton.icon(
          onPressed: provider.isConnected
              ? () async {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  final success = await provider.speakText(text);
                  if (!context.mounted) return;
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Failed to send speech command")),
                    );
                  } else {
                    _controller.clear();
                  }
                }
              : null,
          icon: const Icon(Icons.spatial_audio_off),
          label: Text(
            provider.language == "Urdu" ? "Alert bhejen" : "Send Audio Alert",
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
