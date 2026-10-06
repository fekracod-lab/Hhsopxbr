// كائن مفتاح منع تكرار المعاملات المالية (MADAR SHOP POS Idempotency Key)
// Pure Dart — Zero UI Dependencies

class IdempotencyKey {
  final String key;
  final DateTime createdAt;
  final DateTime expiresAt;

  const IdempotencyKey({
    required this.key,
    required this.createdAt,
    required this.expiresAt,
  });

  /// إنشاء مفتاح تكرار صالح لمدة محددة (افتراضياً 24 ساعة)
  factory IdempotencyKey.create(String key, {Duration ttl = const Duration(hours: 24)}) {
    final now = DateTime.now();
    return IdempotencyKey(
      key: key,
      createdAt: now,
      expiresAt: now.add(ttl),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdempotencyKey &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}
