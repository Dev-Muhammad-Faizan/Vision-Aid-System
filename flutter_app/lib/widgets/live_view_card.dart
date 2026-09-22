import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/glasses_provider.dart';

class LiveViewCard extends StatelessWidget {
  const LiveViewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Caretaker Live View",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),

        // ── Video Container ────────────────────────────────────────
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.hardEdge,
          child: provider.isStreaming && provider.webViewController != null
              ? WebViewWidget(controller: provider.webViewController!)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off,
                          color: Colors.white54, size: 42),
                      const SizedBox(height: 8),
                      Text(
                        provider.isCameraRunning
                            ? "Tap below to view the live feed"
                            : "Start Object Detection first",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: provider.isConnected && provider.isCameraRunning
                            ? provider.startLiveView
                            : null,
                        icon: const Icon(Icons.videocam),
                        label: const Text("Start Live View"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // ── Hide Feed Button ───────────────────────────────────────
        if (provider.isStreaming)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: OutlinedButton.icon(
              onPressed: provider.hideLiveView,
              icon: const Icon(Icons.videocam_off),
              label: const Text("Hide Live Feed"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
      ],
    );
  }
}
