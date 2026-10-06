import 'package:flutter/foundation.dart';

/// نتيجة مطابقة واستعادة الاتساق بعد إعادة الاتصال (Reconciliation Result)
@immutable
class ReconciliationResult {
  final bool isConsistent;
  final int unreconciledCount;
  final List<String> resolvedConflicts;
  final DateTime reconciledAt;

  const ReconciliationResult({
    required this.isConsistent,
    required this.unreconciledCount,
    this.resolvedConflicts = const [],
    required this.reconciledAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'isConsistent': isConsistent,
      'unreconciledCount': unreconciledCount,
      'resolvedConflicts': resolvedConflicts,
      'reconciledAt': reconciledAt.toIso8601String(),
    };
  }

  factory ReconciliationResult.fromMap(Map<String, dynamic> map) {
    return ReconciliationResult(
      isConsistent: map['isConsistent'] == true,
      unreconciledCount: (map['unreconciledCount'] as num?)?.toInt() ?? 0,
      resolvedConflicts: (map['resolvedConflicts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      reconciledAt: map['reconciledAt'] != null
          ? DateTime.tryParse(map['reconciledAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
