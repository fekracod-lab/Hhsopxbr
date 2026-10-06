// خدمة المطابقة والتدقيق المالي وتكاليف المخزون (MADAR SHOP Finance Reconciliation Service)
// Pure Dart — Zero UI Dependencies

import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/enums/financial_direction.dart';
import '../../../domain/finance/enums/financial_entry_type.dart';
import '../../../domain/finance/repositories/i_financial_entry_repository.dart';
import '../../../domain/finance/repositories/i_inventory_cost_layer_repository.dart';
import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/repositories/i_inventory_ledger_repository.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/returns/repositories/i_refund_repository.dart';
import '../../../domain/returns/repositories/i_return_order_repository.dart';
import '../../../domain/returns/repositories/i_supplier_credit_note_repository.dart';
import '../../../domain/returns/repositories/i_supplier_return_repository.dart';
import '../results/finance_operation_results.dart';

class FinanceReconciliationService {
  final IFinancialEntryRepository _financialEntryRepo;
  final IInventoryCostLayerRepository _costLayerRepo;
  final IShopPosRepository _posRepo;
  final IInventoryLedgerRepository _inventoryLedgerRepo;
  final IReturnOrderRepository _returnOrderRepo;
  final IRefundRepository _refundRepo;
  final ISupplierReturnRepository _supplierReturnRepo;
  final ISupplierCreditNoteRepository _supplierCreditNoteRepo;

  const FinanceReconciliationService({
    required IFinancialEntryRepository financialEntryRepo,
    required IInventoryCostLayerRepository costLayerRepo,
    required IShopPosRepository posRepo,
    required IInventoryLedgerRepository inventoryLedgerRepo,
    required IReturnOrderRepository returnOrderRepo,
    required IRefundRepository refundRepo,
    required ISupplierReturnRepository supplierReturnRepo,
    required ISupplierCreditNoteRepository supplierCreditNoteRepo,
  })  : _financialEntryRepo = financialEntryRepo,
        _costLayerRepo = costLayerRepo,
        _posRepo = posRepo,
        _inventoryLedgerRepo = inventoryLedgerRepo,
        _returnOrderRepo = returnOrderRepo,
        _refundRepo = refundRepo,
        _supplierReturnRepo = supplierReturnRepo,
        _supplierCreditNoteRepo = supplierCreditNoteRepo;

  /// فحص شامل وتدقيق مالي لمطابقة الإيراد والتكلفة والمرتجعات والمخزون
  Future<FinanceReconciliationReport> reconcileFinance({
    required String businessId,
    String? branchId,
    DateTime? from,
    DateTime? to,
  }) async {
    final discrepancies = <FinanceDiscrepancy>[];

    // 1. مطابقة الإيرادات المسجلة مقابل فواتير المبيعات المكتملة (Sales vs Revenue)
    final sales = await _posRepo.getSales(
      businessId: businessId,
      branchId: branchId,
      from: from,
      to: to,
    );
    final completedSales = sales.where((s) => s.status.name == 'completed').toList();

    final financialEntries = await _financialEntryRepo.getEntries(
      businessId: businessId,
      branchId: branchId,
      from: from,
      to: to,
    );

    final revenueEntries = financialEntries.where((e) => e.entryType == FinancialEntryType.saleRevenue).toList();

    final totalSalesNet = completedSales.fold(
      Money.zero(),
      (sum, s) => sum + (s.subtotal - s.discountTotal),
    );
    final totalRevenuePosted = revenueEntries.fold(
      Money.zero(),
      (sum, e) => sum + e.amount,
    );

    final isRevenueBalanced = totalSalesNet == totalRevenuePosted;
    if (!isRevenueBalanced) {
      discrepancies.add(FinanceDiscrepancy(
        checkType: 'SALES_REVENUE_MISMATCH',
        entityId: businessId,
        description: 'فارق بين صافي فواتير المبيعات المكتملة وقيود الإيراد المرحلة.',
        expectedAmount: totalSalesNet,
        actualAmount: totalRevenuePosted,
        discrepancy: totalRevenuePosted - totalSalesNet,
      ));
    }

    // 2. مطابقة تكلفة البضاعة المباعة مقابل حركات صرف المبيعات في المخزون (COGS vs Inventory Movements)
    final cogsEntries = financialEntries.where((e) => e.entryType == FinancialEntryType.saleCogs).toList();
    final netCogsPosted = cogsEntries.fold(
      Money.zero(),
      (sum, e) => e.direction == FinancialDirection.debit ? sum + e.amount : sum - e.amount,
    );

    // قيود دفتر أستاذ المخزون للمبيعات
    final inventorySaleMovements = await _inventoryLedgerRepo.getLedgerEntries(
      businessId: businessId,
      branchId: branchId,
      movementType: InventoryMovementType.sale,
      from: from,
      to: to,
    );

    final cogsSaleIds = cogsEntries.map((e) => e.referenceId).toSet();
    final unpostedMovements = inventorySaleMovements
        .where((m) => !cogsSaleIds.contains(m.referenceId))
        .toList();

    final isCogsBalanced = unpostedMovements.isEmpty;
    if (!isCogsBalanced) {
      discrepancies.add(FinanceDiscrepancy(
        checkType: 'COGS_INVENTORY_MISMATCH',
        entityId: businessId,
        description: 'توجد حركات بيع مخزنية لم يتم ترحيل قيود COGS لها (عدد الحركات غير المرحلة: ${unpostedMovements.length}).',
        expectedAmount: netCogsPosted,
        actualAmount: netCogsPosted,
        discrepancy: Money.zero(),
      ));
    }

    // 3. مطابقة أوامر المرتجعات المكتملة مقابل وثائق استرداد الأموال (Returns vs Refunds)
    final returnOrders = await _returnOrderRepo.getReturnOrders(
      businessId: businessId,
      branchId: branchId,
      from: from,
      to: to,
    );
    final completedReturns = returnOrders.where((r) => r.status.isCompleted).toList();
    final totalExpectedRefunds = completedReturns.fold(
      Money.zero(),
      (sum, r) => sum + r.grandTotalRefund,
    );

    Money totalActualRefunds = Money.zero();
    for (final ret in completedReturns) {
      final refunds = await _refundRepo.getRefundsForReturn(returnId: ret.id);
      for (final ref in refunds) {
        if (ref.isCompleted) {
          totalActualRefunds += ref.amount;
        }
      }
    }

    final isReturnsBalanced = totalExpectedRefunds == totalActualRefunds;
    if (!isReturnsBalanced) {
      discrepancies.add(FinanceDiscrepancy(
        checkType: 'RETURNS_REFUND_MISMATCH',
        entityId: businessId,
        description: 'فارق بين إجمالي مبالغ المرتجعات المعتمدة ومبالغ الاسترداد المنفذة فعلياً.',
        expectedAmount: totalExpectedRefunds,
        actualAmount: totalActualRefunds,
        discrepancy: totalActualRefunds - totalExpectedRefunds,
      ));
    }

    // 4. مطابقة مرتجعات الموردين مقابل إشعارات الدائن (Supplier Returns vs Credit Notes)
    final supplierReturns = await _supplierReturnRepo.getSupplierReturns(
      businessId: businessId,
      branchId: branchId,
      from: from,
      to: to,
    );
    final completedSupplierReturns = supplierReturns.where((r) => r.status.isCompleted).toList();

    final totalExpectedCreditNotes = completedSupplierReturns.fold(
      Money.zero(),
      (sum, r) => sum + r.totalAmount,
    );

    final actualCreditNotes = <Money>[];
    for (final supRet in completedSupplierReturns) {
      final note = await _supplierCreditNoteRepo.getCreditNoteById(
        businessId: businessId,
        creditNoteId: 'CN-${supRet.id}',
      );
      if (note != null) actualCreditNotes.add(note.amount);
    }
    final totalActualCreditNotes = actualCreditNotes.fold(
      Money.zero(),
      (sum, amt) => sum + amt,
    );

    final isSupplierReturnsBalanced = totalExpectedCreditNotes == totalActualCreditNotes;
    if (!isSupplierReturnsBalanced) {
      discrepancies.add(FinanceDiscrepancy(
        checkType: 'SUPPLIER_RETURNS_CREDIT_NOTE_MISMATCH',
        entityId: businessId,
        description: 'فارق بين إجمالي مرتجعات الموردين وقيمة إشعارات الدائن الصادرة.',
        expectedAmount: totalExpectedCreditNotes,
        actualAmount: totalActualCreditNotes,
        discrepancy: totalActualCreditNotes - totalExpectedCreditNotes,
      ));
    }

    return FinanceReconciliationReport(
      businessId: businessId,
      auditedAt: DateTime.now(),
      isRevenueBalanced: isRevenueBalanced,
      isCogsBalanced: isCogsBalanced,
      isReturnsBalanced: isReturnsBalanced,
      isCustomerCreditBalanced: true,
      isSupplierReturnsBalanced: isSupplierReturnsBalanced,
      discrepancies: discrepancies,
    );
  }
}
