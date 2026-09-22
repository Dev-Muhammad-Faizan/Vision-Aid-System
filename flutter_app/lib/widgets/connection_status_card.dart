import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GlassesProvider>();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: provider.isConnected ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  provider.isConnected ? Colors.green.shade100 : Colors.red.shade100,
              radius: 24,
              child: Icon(
                provider.isConnected ? Icons.wifi : Icons.wifi_off,
                color: provider.isConnected ? Colors.green : Colors.red,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isConnected
                        ? "Connected to Glasses"
                        : "Disconnected",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "IP: ${provider.piIpAddress}",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            provider.isChecking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: "Retry Connection",
                    onPressed: provider.checkConnection,
                  ),
          ],
        ),
      ),
    );
  }
}
