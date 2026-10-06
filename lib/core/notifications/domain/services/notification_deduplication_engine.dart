/// محرك منع تكرار الإشعارات (Notification Deduplication Engine)
class NotificationDeduplicationEngine {
  final Set<String> _processedKeys = {};

  NotificationDeduplicationEngine();

  /// التحقق مما إذا كان المفتاح تمت معالجته مسبقاً
  bool isDuplicate(String idempotencyKey) {
    if (idempotencyKey.isEmpty) return false;
    return _processedKeys.contains(idempotencyKey);
  }

  /// تسجيل المفتاح بعد نجاح المعالجة
  void markProcessed(String idempotencyKey) {
    if (idempotencyKey.isNotEmpty) {
      _processedKeys.add(idempotencyKey);
    }
  }

  /// تنظيف الذاكرة
  void clear() {
    _processedKeys.clear();
  }
}
