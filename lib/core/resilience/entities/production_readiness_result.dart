import 'package:flutter/foundation.dart';
import '../enums/resilience_enums.dart';

/// نتيجة تقييم بوابة الجاهزية الإنتاجية الشاملة (Production Readiness Result)
@immutable
class ProductionReadinessResult {
  final ReadinessGateStatus overallStatus;
  final double overallScore; // 0.0 .. 100.0%
  final Map<ReadinessCategory, double> categoryScores;
  final Map<ReadinessCategory, ReadinessGateStatus> categoryStatuses;
  final List<String> blockingIssues;
  final List<String> warnings;
  final DateTime evaluatedAt;

  const ProductionReadinessResult({
    required this.overallStatus,
    required this.overallScore,
    this.categoryScores = const {},
    this.categoryStatuses = const {},
    this.blockingIssues = const [],
    this.warnings = const [],
    required this.evaluatedAt,
  });

  bool get isProductionReady => overallStatus == ReadinessGateStatus.productionReady && blockingIssues.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'overallStatus': overallStatus.key,
      'overallScore': overallScore,
      'categoryScores': categoryScores.map((k, v) => MapEntry(k.key, v)),
      'categoryStatuses': categoryStatuses.map((k, v) => MapEntry(k.key, v.key)),
      'blockingIssues': blockingIssues,
      'warnings': warnings,
      'evaluatedAt': evaluatedAt.toIso8601String(),
    };
  }

  factory ProductionReadinessResult.fromMap(Map<String, dynamic> map) {
    final rawScores = map['categoryScores'] is Map ? Map<String, dynamic>.from(map['categoryScores'] as Map) : <String, dynamic>{};
    final parsedScores = <ReadinessCategory, double>{};
    rawScores.forEach((k, v) {
      final cat = ReadinessCategory.fromString(k);
      parsedScores[cat] = (v as num).toDouble();
    });

    final rawStatuses = map['categoryStatuses'] is Map ? Map<String, dynamic>.from(map['categoryStatuses'] as Map) : <String, dynamic>{};
    final parsedStatuses = <ReadinessCategory, ReadinessGateStatus>{};
    rawStatuses.forEach((k, v) {
      final cat = ReadinessCategory.fromString(k);
      parsedStatuses[cat] = ReadinessGateStatus.fromString(v?.toString());
    });

    return ProductionReadinessResult(
      overallStatus: ReadinessGateStatus.fromString(map['overallStatus']?.toString()),
      overallScore: (map['overallScore'] as num?)?.toDouble() ?? 0.0,
      categoryScores: parsedScores,
      categoryStatuses: parsedStatuses,
      blockingIssues: (map['blockingIssues'] as List?)?.map((e) => e.toString()).toList() ?? [],
      warnings: (map['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
      evaluatedAt: map['evaluatedAt'] != null
          ? DateTime.tryParse(map['evaluatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
