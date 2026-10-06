import 'dart:convert';
import 'package:crypto/crypto.dart';

/// خدمة التخزين المحلي الآمن والمشفر (Secure Local Storage Service)
class SecureStorageService {
  final Map<String, String> _secureStore = {};
  final String _masterSecretKey;

  SecureStorageService({
    String masterSecretKey = 'MADAR_SECURE_STORAGE_KEY_PRODUCTION_2026',
  }) : _masterSecretKey = masterSecretKey;

  /// كتابة قيمة حساسة مشفرة بمفتاح العزل
  Future<void> writeSecure({
    required String key,
    required String value,
  }) async {
    final encryptedValue = _encryptValue(value);
    _secureStore[key] = encryptedValue;
  }

  /// قراءة وفك تشفير قيمة حساسة
  Future<String?> readSecure(String key) async {
    final encrypted = _secureStore[key];
    if (encrypted == null) return null;
    return _decryptValue(encrypted);
  }

  /// مسح مفتاح حساس بشكل آمن
  Future<void> deleteSecure(String key) async {
    _secureStore.remove(key);
  }

  /// مسح كامل المخزن الآمن عند تسجيل الخروج
  Future<void> deleteAll() async {
    _secureStore.clear();
  }

  bool containsKey(String key) => _secureStore.containsKey(key);

  // التشفير وفك التشفير مع عزل الـ Master Key
  String _encryptValue(String raw) {
    final bytes = utf8.encode(raw);
    final keyBytes = utf8.encode(_masterSecretKey);
    final hmac = Hmac(sha256, keyBytes);
    final signature = hmac.convert(bytes).toString();
    final encodedPayload = base64Encode(bytes);
    return '$encodedPayload.$signature';
  }

  String? _decryptValue(String encrypted) {
    final parts = encrypted.split('.');
    if (parts.length != 2) return null;
    final encodedPayload = parts[0];
    final expectedSignature = parts[1];

    final rawBytes = base64Decode(encodedPayload);
    final keyBytes = utf8.encode(_masterSecretKey);
    final hmac = Hmac(sha256, keyBytes);
    final computedSignature = hmac.convert(rawBytes).toString();

    if (computedSignature != expectedSignature) {
      // تم التلاعب بالبيانات المخزنة محلياً!
      return null;
    }

    return utf8.decode(rawBytes);
  }
}
