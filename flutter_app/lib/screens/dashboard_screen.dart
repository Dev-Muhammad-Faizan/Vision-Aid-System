import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/glasses_provider.dart';
import '../widgets/connection_status_card.dart';
import '../widgets/live_view_card.dart';
import '../widgets/config_hub_card.dart';
import '../widgets/camera_controls_card.dart';
import '../widgets/audio_announcement_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _ipController = TextEditingController();

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _showSettingsDialog(BuildContext context, GlassesProvider provider) {
    _ipController.text = provider.piIpAddress;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Raspberry Pi Setup"),
        content: TextField(
          controller: _ipController,
          decoration: const InputDecoration(
            labelText: "IP Address (e.g. 192.168.1.100)",
            hintText: "Enter the IP address of the glasses",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              provider.saveIp(_ipController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text("Save & Connect"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GlassesProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Dashboard"),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: "Pi Settings",
                onPressed: () => _showSettingsDialog(context, provider),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                ConnectionStatusCard(),
                SizedBox(height: 20),
                LiveViewCard(),
                SizedBox(height: 20),
                ConfigHubCard(),
                SizedBox(height: 20),
                CameraControlsCard(),
                SizedBox(height: 20),
                AudioAnnouncementCard(),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
