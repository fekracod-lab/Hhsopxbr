import 'dart:async';

/// محرك ضمان اللا تكرار ومعالجة الطلبات المتطابقة ذرياً (Atomic Idempotency Engine)
class IdempotencyEngine {
  final Map<String, dynamic> _canonicalResults = {};
  final Map<String, Completer<dynamic>> _inFlightOperations = {};

  IdempotencyEngine();

  Map<String, dynamic> get canonicalResults => Map.unmodifiable(_canonicalResults);

  /// التحقق والتنفيذ لمرة واحدة فقط وإرجاع النتيجة المحفوظة عند التكرار
  Future<T> executeIdempotent<T>({
    required String idempotencyKey,
    required Future<T> Function() operation,
  }) async {
    // 1. إذا كانت النتيجة مسجلة مسبقاً -> إرجاع النتيجة الأصلية فوراً (Canonical Result)
    if (_canonicalResults.containsKey(idempotencyKey)) {
      return _canonicalResults[idempotencyKey] as T;
    }

    // 2. إذا كان الطلب قيد التنفيذ حالياً (Concurrent In-Flight Request) -> انتظار النتيجة نفسها
    if (_inFlightOperations.containsKey(idempotencyKey)) {
      final result = await _inFlightOperations[idempotencyKey]!.future;
      return result as T;
    }

    // 3. بدء التنفيذ الحصري الذري (Exclusive Atomic Execution)
    final completer = Completer<dynamic>();
    _inFlightOperations[idempotencyKey] = completer;

    try {
      final result = await operation();
      _canonicalResults[idempotencyKey] = result;
      completer.complete(result);
      return result;
    } catch (error, stack) {
      completer.future.ignore();
      completer.completeError(error, stack);
      rethrow;
    } finally {
      _inFlightOperations.remove(idempotencyKey);
    }
  }

  bool hasResult(String idempotencyKey) => _canonicalResults.containsKey(idempotencyKey);

  void clear() {
    _canonicalResults.clear();
    _inFlightOperations.clear();
  }
}
