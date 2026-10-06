import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TaxiAuthService {
  static const String _kTokenKey = 'taxi_server_jwt';

  /// Get a valid JWT for the taxi server.
  /// If [forceRefresh] is true, it will always fetch a new token from the server.
  static Future<String?> getToken({
    required String serverUrl,
    required String role,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedToken = prefs.getString(_kTokenKey);
      if (cachedToken != null) return cachedToken;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Use http:// instead of ws:// for the auth endpoint
      final httpUrl = serverUrl.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://');

      final response = await http
          .post(
            Uri.parse('$httpUrl/auth/token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userId': user.uid, 'role': role}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        if (token != null) {
          await prefs.setString(_kTokenKey, token);
          return token;
        }
      } else {
        debugPrint('[TaxiAuth] Failed to get token: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[TaxiAuth] Error fetching token: $e');
    }

    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
  }
}
