// واجهة متجر تفادي التكرار لمحرك المشتريات (MADAR SHOP Purchasing Idempotency Store Contract)
// Pure Dart — Zero UI Dependencies

abstract class IPurchasingIdempotencyStore {
  /// التحقق مما إذا كان المفتاح قد تمت معالجته مسبقاً
  Future<bool> hasKey(String idempotencyKey);

  /// استرجاع النتيجة المسجلة لمفتاح مكرر
  Future<dynamic> getResult(String idempotencyKey);

  /// حفظ المفتاح والنتيجة المترتبة عليه
  Future<void> recordKey({
    required String idempotencyKey,
    required dynamic result,
    Duration? ttl,
  });
}
