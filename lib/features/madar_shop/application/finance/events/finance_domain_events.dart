// أحداث نطاق العمليات المالية وهوامش الأرباح (MADAR SHOP Finance Domain Events)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/value_objects/gross_profit_result.dart';
import '../../../domain/finance/value_objects/inventory_valuation_report.dart';

abstract class FinanceDomainEvent {
  final String eventId;
  final DateTime occurredAt;

  const FinanceDomainEvent({
    required this.eventId,
    required this.occurredAt,
  });
}

class SaleRevenuePostedEvent extends FinanceDomainEvent {
  final FinancialEntry revenueEntry;
  final String saleId;

  const SaleRevenuePostedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.revenueEntry,
    required this.saleId,
  });
}

class SaleCogsPostedEvent extends FinanceDomainEvent {
  final FinancialEntry cogsEntry;
  final String saleId;

  const SaleCogsPostedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.cogsEntry,
    required this.saleId,
  });
}

class GrossProfitCalculatedEvent extends FinanceDomainEvent {
  final String businessId;
  final String? branchId;
  final GrossProfitResult result;

  const GrossProfitCalculatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.businessId,
    this.branchId,
    required this.result,
  });
}

class InventoryValuationCalculatedEvent extends FinanceDomainEvent {
  final InventoryValuationReport report;

  const InventoryValuationCalculatedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.report,
  });
}

class FinanceReconciliationMismatchEvent extends FinanceDomainEvent {
  final String businessId;
  final String checkType;
  final String description;

  const FinanceReconciliationMismatchEvent({
    required super.eventId,
    required super.occurredAt,
    required this.businessId,
    required this.checkType,
    required this.description,
  });
}

class DuplicateFinanceCommandDetectedEvent extends FinanceDomainEvent {
  final String idempotencyKey;
  final String referenceId;

  const DuplicateFinanceCommandDetectedEvent({
    required super.eventId,
    required super.occurredAt,
    required this.idempotencyKey,
    required this.referenceId,
  });
}
