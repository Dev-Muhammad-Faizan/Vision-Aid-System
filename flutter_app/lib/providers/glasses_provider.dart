import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/api_service.dart';

class GlassesProvider extends ChangeNotifier {
  // ── Connection ──────────────────────────────────────────────
  String piIpAddress = "192.168.1.100";
  bool isConnected = false;
  bool isChecking = false;
  late ApiService _api;

  // ── Camera & Stream ─────────────────────────────────────────
  bool isCameraRunning = false;
  bool isStreaming = false;
  WebViewController? webViewController;

  // ── Config ───────────────────────────────────────────────────
  bool isColorEnabled = false;
  double distanceThresh = 0.35;
  double positionDelay = 3.0;
  String language = "English";

  ApiService get api => _api;

  GlassesProvider() {
    _api = ApiService("http://192.168.1.100:5000");
    _init();
  }

  // ── Initialisation ───────────────────────────────────────────
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    piIpAddress = prefs.getString('pi_ip') ?? "192.168.1.100";
    _api = ApiService("http://$piIpAddress:5000");
    _initWebViewController();
    notifyListeners();
    await checkConnection();
  }

  void _initWebViewController() {
    webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse('about:blank'));
  }

  // ── IP / Connection ──────────────────────────────────────────
  Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pi_ip', ip);
    piIpAddress = ip;
    _api = ApiService("http://$piIpAddress:5000");
    _initWebViewController();
    notifyListeners();
    await checkConnection();
  }

  Future<void> checkConnection() async {
    isChecking = true;
    notifyListeners();

    final statusMap = await _api.checkStatus();
    if (statusMap != null) {
      isConnected = true;
      isCameraRunning = statusMap["camera_active"] ?? false;
      final config = statusMap["config"] ?? {};
      isColorEnabled = config["COLOR_ENABLED"] ?? false;
      distanceThresh = (config["DISTANCE_THRESH_NEAR"] ?? 0.35).toDouble();
      positionDelay = (config["POSITION_DELAY"] ?? 3.0).toDouble();
      language = config["LANGUAGE"] ?? "English";
    } else {
      isConnected = false;
    }
    isChecking = false;
    notifyListeners();
  }

  // ── Camera Controls ──────────────────────────────────────────
  Future<void> startDetection() async {
    await _api.startDetection();
    isCameraRunning = true;
    isStreaming = false;
    notifyListeners();
  }

  Future<void> stopDetection() async {
    await _api.stopDetection();
    webViewController?.loadRequest(Uri.parse('about:blank'));
    isCameraRunning = false;
    isStreaming = false;
    notifyListeners();
  }

  // ── Live Stream ──────────────────────────────────────────────
  void startLiveView() {
    final streamUrl = 'http://$piIpAddress:5000/video_feed';
    final html = '''<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:100%;height:100%;background:#000;overflow:hidden}
  img{width:100%;height:100%;object-fit:fill;display:block}
</style>
</head>
<body><img src="$streamUrl"/></body>
</html>''';
    webViewController?.loadHtmlString(html);
    isStreaming = true;
    notifyListeners();
  }

  void hideLiveView() {
    webViewController?.loadRequest(Uri.parse('about:blank'));
    isStreaming = false;
    notifyListeners();
  }

  // ── Config Updates ───────────────────────────────────────────
  Future<void> toggleColorMode(bool value) async {
    final success = await _api.updateConfig({"COLOR_ENABLED": value});
    if (success) {
      isColorEnabled = value;
      notifyListeners();
    }
  }

  Future<void> updateDistance(double value) async {
    distanceThresh = value;
    notifyListeners();
    await _api.updateConfig({"DISTANCE_THRESH_NEAR": value});
  }

  Future<void> updateDelay(double value) async {
    positionDelay = value;
    notifyListeners();
    await _api.updateConfig({"POSITION_DELAY": value});
  }

  Future<void> updateLanguage(String value) async {
    language = value;
    notifyListeners();
    await _api.updateConfig({"LANGUAGE": value});
  }

  // ── Location ─────────────────────────────────────────────────
  Future<void> announceLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final msg = language == "Urdu"
          ? "Location service band hai."
          : "Location services are disabled on the phone.";
      await _api.speakText(msg);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        final msg = language == "Urdu"
            ? "Location ki ijazat nahi mili."
            : "Location permission was denied.";
        await _api.speakText(msg);
        return;
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.locality,
          place.subLocality,
          place.subAdministrativeArea,
          place.administrativeArea,
        ].where((p) => p != null && p.isNotEmpty).toSet().cast<String>().toList();

        final placeName =
            parts.isNotEmpty ? parts.join(', ') : "unknown area";
        final announcement = language == "Urdu"
            ? "Aap abhi $placeName mein hain."
            : "You are currently in $placeName.";
        await _api.speakText(announcement);
      } else {
        final msg = language == "Urdu"
            ? "jagah ka naam nahi mila."
            : "Could not resolve place name.";
        await _api.speakText(msg);
      }
    } catch (e) {
      final msg = language == "Urdu"
          ? "Location mein error aayi."
          : "Error fetching location.";
      await _api.speakText(msg);
    }
  }

  // ── TTS ────────────────────────────────────────────────────-
  Future<bool> speakText(String text) => _api.speakText(text);
}
