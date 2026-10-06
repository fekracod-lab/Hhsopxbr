import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:math';

class AppleAuthService {
  /// Generates a cryptographically secure random nonce.
  static String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Hashes the nonce using SHA-256.
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<User?> signIn() async {
    if (kIsWeb) {
      debugPrint('Apple Sign-In is not supported on web in this flow.');
      return null;
    }

    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user == null) return null;

      // Extract details if available (only sent during first sign-in)
      final String name = [
        appleCredential.givenName ?? '',
        appleCredential.familyName ?? '',
      ].join(' ').trim();

      await _saveUser(user, name.isNotEmpty ? name : null);
      await _updateLastActive(user.uid);

      return user;
    } catch (e) {
      debugPrint(' Apple Sign-In failed: $e');
      rethrow;
    }
  }

  static Future<void> _saveUser(User user, String? name) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name ?? user.displayName ?? '',
      'email': user.email ?? '',
      'authProvider': 'apple',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _updateLastActive(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
