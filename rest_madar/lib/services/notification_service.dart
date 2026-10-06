import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'dart:async';

class NotificationService {
  // Supabase Events URL (Central Decision Brain)
  static const String _eventsUrl = "https://tgrtnaarvxqowuhdxcau.supabase.co/functions/v1/events";

  // The anon key is used to authenticate with Supabase Edge Functions.
  // Sensitive OneSignal REST API keys are now handled entirely on the server.
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRncnRuYWFydnhxb3d1aGR4Y2F1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYxNjQyNTMsImV4cCI6MjA4MTc0MDI1M30.b-UKgTInVrP6JRkiAxXYzAuk84SymS7RSKpjB0FIGac';

  /// Primary method to trigger a server-side notification event.
  /// Flutter acts as an "Event Producer"; the server acts as the "Brain".
  static Future<void> emitEvent({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    // 1. Connectivity check
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint(" Event suppressed: No internet connection.");
      return;
    }

    try {
      debugPrint(" Emitting Event: $type");

      final body = {"type": type, "payload": payload};

      final response = await http
          .post(
            Uri.parse(_eventsUrl),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $_anonKey",
              "apikey": _anonKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(" Event Emitted Successfully: ${response.statusCode}");
      } else {
        debugPrint(" Event Emission Failed: ${response.statusCode} - ${response.body}");
      }
    } on SocketException catch (e) {
      debugPrint(" Network error: ${e.message}");
    } on TimeoutException {
      debugPrint(" Event emission timed out.");
    } catch (e) {
      debugPrint(" Unexpected error: $e");
    }
  }
}
