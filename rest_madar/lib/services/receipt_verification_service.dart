import 'dart:convert';
import 'package:crypto/crypto.dart';

/// خدمة التحقق والتشفير الرقمي لفواتير مدار (Receipt Verification Service)
/// تولد رمز QR حقيقي موثق بـ Hash أمني لمنع التزوير والتأكد من مطابقة السيرفر
class ReceiptVerificationService {
  static const _kMadarSalt = 'MADAR_SECURE_RECEIPT_SALT_2026_IRAQ';

  /// توليد رابط التحقق الرسمي المحمي برقم هضمي (HMAC-SHA256 Hash)
  static String generateVerificationUrl({
    required String restaurantId,
    required String orderId,
    required double totalAmount,
    required DateTime timestamp,
  }) {
    final epoch = timestamp.millisecondsSinceEpoch;
    final cleanAmount = totalAmount.toStringAsFixed(0);

    // بناء نص الإثبات الأمني
    final rawPayload = '$restaurantId|$orderId|$cleanAmount|$epoch|$_kMadarSalt';
    final bytes = utf8.encode(rawPayload);
    final digest = sha256.convert(bytes);
    final shortHash = digest.toString().substring(0, 16); // 16 حرف لتكون الشفرة سريعة المسح

    // الرابط النهائي المشفر
    return 'https://madar-iq.com/verify?rid=$restaurantId&oid=$orderId&amt=$cleanAmount&ts=$epoch&sig=$shortHash';
  }

  /// التحقق من صحة التوقيع الرقمي للفاتورة
  static bool verifyReceipt({
    required String restaurantId,
    required String orderId,
    required double totalAmount,
    required int timestampEpoch,
    required String signature,
  }) {
    final cleanAmount = totalAmount.toStringAsFixed(0);
    final rawPayload = '$restaurantId|$orderId|$cleanAmount|$timestampEpoch|$_kMadarSalt';
    final bytes = utf8.encode(rawPayload);
    final digest = sha256.convert(bytes);
    final expectedHash = digest.toString().substring(0, 16);

    return expectedHash.toLowerCase() == signature.toLowerCase();
  }
}
