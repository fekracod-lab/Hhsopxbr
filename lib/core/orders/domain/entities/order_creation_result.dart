import 'package:flutter/foundation.dart';
import 'unified_order.dart';

/// نتيجة إنشاء الطلب الذري (Order Creation Result)
@immutable
class OrderCreationResult {
  final bool isSuccess;
  final UnifiedOrder? order;
  final String idempotencyKey;
  final String? financialTxId;
  final String? errorMessage;

  const OrderCreationResult._({
    required this.isSuccess,
    this.order,
    required this.idempotencyKey,
    this.financialTxId,
    this.errorMessage,
  });

  factory OrderCreationResult.success({
    required UnifiedOrder order,
    required String idempotencyKey,
    String? financialTxId,
  }) {
    return OrderCreationResult._(
      isSuccess: true,
      order: order,
      idempotencyKey: idempotencyKey,
      financialTxId: financialTxId,
    );
  }

  factory OrderCreationResult.failure({
    required String errorMessage,
    required String idempotencyKey,
  }) {
    return OrderCreationResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      idempotencyKey: idempotencyKey,
    );
  }
}
