import 'package:flutter/foundation.dart';
import '../enums/orchestration_enums.dart';

/// تعريف خطوة الملحمة الموزعة (Saga Step Definition)
@immutable
class SagaDefinition {
  final SagaStepType stepType;
  final bool isIdempotent;
  final int retryLimit;
  final Duration timeout;

  const SagaDefinition({
    required this.stepType,
    this.isIdempotent = true,
    this.retryLimit = 3,
    this.timeout = const Duration(seconds: 15),
  });
}
