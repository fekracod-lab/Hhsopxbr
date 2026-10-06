// أوامر العمليات المالية وهوامش الأرباح (MADAR SHOP Finance Commands)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/enums/costing_method.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/returns/entities/return_order.dart';

class PostSaleFinancialsCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final Sale sale;
  final CostingMethod costingMethod;
  final String actorId;
  final String idempotencyKey;

  const PostSaleFinancialsCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.sale,
    this.costingMethod = CostingMethod.weightedAverage,
    required this.actorId,
    required this.idempotencyKey,
  });
}

class ReverseSaleFinancialsOnReturnCommand {
  final String commandId;
  final String businessId;
  final String branchId;
  final ReturnOrder returnOrder;
  final String actorId;
  final String idempotencyKey;

  const ReverseSaleFinancialsOnReturnCommand({
    required this.commandId,
    required this.businessId,
    required this.branchId,
    required this.returnOrder,
    required this.actorId,
    required this.idempotencyKey,
  });
}

class CalculatePeriodProfitCommand {
  final String businessId;
  final String? branchId;
  final DateTime from;
  final DateTime to;
  final String actorId;

  const CalculatePeriodProfitCommand({
    required this.businessId,
    this.branchId,
    required this.from,
    required this.to,
    required this.actorId,
  });
}

class CalculateInventoryValuationCommand {
  final String businessId;
  final String? branchId;
  final CostingMethod costingMethod;
  final DateTime asOf;
  final String actorId;

  const CalculateInventoryValuationCommand({
    required this.businessId,
    this.branchId,
    this.costingMethod = CostingMethod.weightedAverage,
    required this.asOf,
    required this.actorId,
  });
}
