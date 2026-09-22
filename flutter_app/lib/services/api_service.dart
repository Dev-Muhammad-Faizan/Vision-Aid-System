import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  String baseUrl;

  ApiService(this.baseUrl);

  /// Tests the connection to the Raspberry Pi & fetches current config
  Future<Map<String, dynamic>?> checkStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint("Status check failed: $e");
    }
    return null;
  }

  /// Triggers the YOLOv5 detection script in headless mode
  Future<bool> startDetection() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/start'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 || response.statusCode == 400) {
        return true;
      }
    } catch (e) {
      debugPrint("Start detection failed: $e");
    }
    return false;
  }

  /// Stops detection
  Future<bool> stopDetection() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/stop'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Stop detection failed: $e");
    }
    return false;
  }

  /// Starts the camera in streaming mode
  Future<bool> startStream() async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl/start_stream'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Start stream failed: $e");
    }
    return false;
  }

  /// Update configurations on the fly
  Future<bool> updateConfig(Map<String, dynamic> newConfig) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/config'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(newConfig),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Config update failed: $e");
    }
    return false;
  }

  /// Sends a text string for the Raspberry Pi to speak via eSpeak
  Future<bool> speakText(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/speak'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Speak failed: $e");
    }
    return false;
  }
}
