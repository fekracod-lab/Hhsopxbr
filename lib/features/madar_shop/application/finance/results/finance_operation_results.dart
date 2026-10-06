// نتائج العمليات المالية وتقارير المطابقة (MADAR SHOP Finance Operation Results)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/value_objects/gross_profit_result.dart';
import '../../../domain/finance/value_objects/inventory_valuation_report.dart';
import '../../../domain/pos/value_objects/money.dart';

class PostSaleFinancialsResult {
  final bool isSuccess;
  final FinancialEntry? revenueEntry;
  final FinancialEntry? cogsEntry;
  final Money grossProfit;
  final double? grossMargin;
  final String? message;

  const PostSaleFinancialsResult({
    required this.isSuccess,
    this.revenueEntry,
    this.cogsEntry,
    this.grossProfit = const Money.fromMinorUnits(0),
    this.grossMargin,
    this.message,
  });
}

class GrossProfitCalculationResult {
  final bool isSuccess;
  final GrossProfitResult? result;
  final String? message;

  const GrossProfitCalculationResult({
    required this.isSuccess,
    this.result,
    this.message,
  });
}

class InventoryValuationCalculationResult {
  final bool isSuccess;
  final InventoryValuationReport? report;
  final String? message;

  const InventoryValuationCalculationResult({
    required this.isSuccess,
    this.report,
    this.message,
  });
}

class FinanceDiscrepancy {
  final String checkType;
  final String entityId;
  final String description;
  final Money expectedAmount;
  final Money actualAmount;
  final Money discrepancy;

  const FinanceDiscrepancy({
    required this.checkType,
    required this.entityId,
    required this.description,
    required this.expectedAmount,
    required this.actualAmount,
    required this.discrepancy,
  });
}

class FinanceReconciliationReport {
  final String businessId;
  final DateTime auditedAt;
  final bool isRevenueBalanced;
  final bool isCogsBalanced;
  final bool isReturnsBalanced;
  final bool isCustomerCreditBalanced;
  final bool isSupplierReturnsBalanced;
  final List<FinanceDiscrepancy> discrepancies;

  const FinanceReconciliationReport({
    required this.businessId,
    required this.auditedAt,
    required this.isRevenueBalanced,
    required this.isCogsBalanced,
    required this.isReturnsBalanced,
    required this.isCustomerCreditBalanced,
    required this.isSupplierReturnsBalanced,
    required this.discrepancies,
  });

  bool get isFullyReconciled =>
      isRevenueBalanced &&
      isCogsBalanced &&
      isReturnsBalanced &&
      isCustomerCreditBalanced &&
      isSupplierReturnsBalanced &&
      discrepancies.isEmpty;

  bool get hasDiscrepancies => discrepancies.isNotEmpty;
}
