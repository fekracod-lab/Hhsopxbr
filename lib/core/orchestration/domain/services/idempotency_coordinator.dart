import 'package:dalal_alqaim/core/security/domain/entities/security_models.dart';

/// منسق عدم التكرار الشامل وفاحص تطابق الـ Payload (Idempotency Coordinator)
class IdempotencyCoordinator {
  final Map<String, String> _keyToHashRegistry = {};
  final Map<String, dynamic> _keyToResultRegistry = {};

  IdempotencyCoordinator();

  /// توليد كود تجزئة الطلب (Request Hash)
  static String computeRequestHash({
    required String actorId,
    required String serviceType,
    required String orderId,
    required int amount,
    Map<String, dynamic> payload = const {},
  }) {
    final raw = 'act:$actorId|srv:$serviceType|ord:$orderId|amt:$amount|pld:${payload.toString()}';
    var hash1 = 0xcbf29ce484222325;
    const prime1 = 0x100000001b3;
    for (var i = 0; i < raw.length; i++) {
      hash1 = (hash1 ^ raw.codeUnitAt(i)) * prime1;
    }
    return 'hsh_${(hash1 & 0xFFFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0')}';
  }

  /// التحقق من صلاحية مفتاح عدم التكرار ومنع تضارب الـ Payloads
  bool checkAndRegister({
    required String idempotencyKey,
    required String requestHash,
    dynamic result,
  }) {
    if (idempotencyKey.isEmpty) return true;

    if (_keyToHashRegistry.containsKey(idempotencyKey)) {
      final existingHash = _keyToHashRegistry[idempotencyKey];
      if (existingHash != requestHash) {
        throw const SecurityViolationException(
          'تضارب في مفتاح عدم التكرار مع حمولة مختلفة (Idempotency Payload Conflict)',
          type: SecurityViolationType.tamperedPayload,
          fieldName: 'idempotencyKey',
        );
      }
      return false; // مكرر بنفس الحمولة (يتم استرجاع النتيجة السابقة)
    }

    _keyToHashRegistry[idempotencyKey] = requestHash;
    if (result != null) {
      _keyToResultRegistry[idempotencyKey] = result;
    }
    return true; // طلب جديد أصيل
  }

  /// جلب النتيجة السابقة لطلب مكرر
  dynamic getExistingResult(String idempotencyKey) {
    return _keyToResultRegistry[idempotencyKey];
  }

  void saveResult(String idempotencyKey, dynamic result) {
    if (idempotencyKey.isNotEmpty) {
      _keyToResultRegistry[idempotencyKey] = result;
    }
  }

  void clear() {
    _keyToHashRegistry.clear;
    _keyToResultRegistry.clear();
  }
}
