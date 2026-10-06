// خدمة المطابقة والتسوية وإعادة بناء الأرصدة (MADAR SHOP Purchasing Reconciliation Service)
// Pure Dart — Zero UI Dependencies

import '../../../domain/inventory/enums/inventory_movement_type.dart';
import '../../../domain/inventory/repositories/i_inventory_ledger_repository.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/purchasing/entities/supplier_account.dart';
import '../../../domain/purchasing/repositories/i_purchase_order_repository.dart';
import '../../../domain/purchasing/repositories/i_purchase_receipt_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_ledger_repository.dart';
import '../../../domain/purchasing/repositories/i_supplier_repository.dart';
import '../results/purchasing_reconciliation_report.dart';

class PurchasingReconciliationService {
  final IPurchaseOrderRepository _purchaseOrderRepo;
  final IPurchaseReceiptRepository _receiptRepo;
  final IInventoryLedgerRepository _inventoryLedgerRepo;
  final ISupplierRepository _supplierRepo;
  final ISupplierLedgerRepository _supplierLedgerRepo;

  PurchasingReconciliationService({
    required IPurchaseOrderRepository purchaseOrderRepository,
    required IPurchaseReceiptRepository receiptRepository,
    required IInventoryLedgerRepository inventoryLedgerRepository,
    required ISupplierRepository supplierRepository,
    required ISupplierLedgerRepository supplierLedgerRepository,
  })  : _purchaseOrderRepo = purchaseOrderRepository,
        _receiptRepo = receiptRepository,
        _inventoryLedgerRepo = inventoryLedgerRepository,
        _supplierRepo = supplierRepository,
        _supplierLedgerRepo = supplierLedgerRepository;

  /// مطابقة شاملة للمشتريات والمخزون وحسابات الموردين لنشاط تجاري
  Future<PurchasingReconciliationReport> reconcilePurchasing({
    required String businessId,
  }) async {
    final inventoryDiscrepancies = <InventoryPurchaseDiscrepancy>[];
    final supplierDiscrepancies = <SupplierLedgerDiscrepancy>[];

    // 1. مطابقة الاستلامات الفعلية مقابل حركات المخزون S3
    final orders = await _purchaseOrderRepo.getPurchaseOrders(businessId: businessId);

    // تجميع الحركات المخزنية المسجلة من المشتريات
    final purchaseMovementsByProduct = <String, StockQuantity>{};
    for (final order in orders) {
      final entries = await _inventoryLedgerRepo.getLedgerEntriesForReference(
        referenceType: 'PURCHASE',
        referenceId: order.id,
      );
      for (final entry in entries) {
        if (entry.movementType == InventoryMovementType.purchase) {
          final key = '${entry.productId}:${entry.variantId ?? "main"}';
          final current = purchaseMovementsByProduct[key] ?? StockQuantity.zero(entry.unit);
          purchaseMovementsByProduct[key] = current + entry.quantityDelta;
        }
      }
    }

    // تجميع الكميات المستلمة في إيصالات الشراء
    final receivedByProduct = <String, StockQuantity>{};
    for (final order in orders) {
      final receipts = await _receiptRepo.getReceiptsForPurchaseOrder(
        businessId: businessId,
        purchaseOrderId: order.id,
      );
      for (final r in receipts) {
        for (final item in r.items) {
          final key = '${item.productId}:${item.variantId ?? "main"}';
          final current = receivedByProduct[key] ?? StockQuantity.zero(item.unit);
          receivedByProduct[key] = current + item.quantityReceived;
        }
      }
    }

    // المقارنة
    final allKeys = {...purchaseMovementsByProduct.keys, ...receivedByProduct.keys};
    for (final key in allKeys) {
      final parts = key.split(':');
      final prodId = parts[0];
      final variantId = parts[1] == 'main' ? null : parts[1];

      final recQty = receivedByProduct[key] ?? StockQuantity.zero();
      final invQty = purchaseMovementsByProduct[key] ?? StockQuantity.zero();
      final diff = recQty - invQty;

      if (!diff.isZero) {
        inventoryDiscrepancies.add(InventoryPurchaseDiscrepancy(
          productId: prodId,
          variantId: variantId,
          receivedQuantityInPurchasing: recQty,
          recordedQuantityInInventory: invQty,
          difference: diff,
        ));
      }
    }

    // 2. مطابقة أرصدة الموردين مع دفتر الأستاذ Append-Only
    final suppliers = await _supplierRepo.getSuppliers(businessId: businessId);
    for (final supplier in suppliers) {
      final account = await _supplierRepo.getSupplierAccount(
        businessId: businessId,
        supplierId: supplier.id,
      );
      if (account == null) continue;

      final ledgerEntries = await _supplierLedgerRepo.getEntriesForSupplier(
        businessId: businessId,
        supplierId: supplier.id,
      );

      // حساب الرصيد التراكمي من مجموع الـ Deltas
      var calculatedBalance = Money.zero(account.currency);
      for (final entry in ledgerEntries) {
        calculatedBalance += entry.balanceDelta;
      }

      final discrepancy = account.currentBalance - calculatedBalance;
      if (!discrepancy.isZero) {
        supplierDiscrepancies.add(SupplierLedgerDiscrepancy(
          supplierId: supplier.id,
          accountCurrentBalance: account.currentBalance,
          ledgerCalculatedBalance: calculatedBalance,
          discrepancy: discrepancy,
        ));
      }
    }

    return PurchasingReconciliationReport(
      businessId: businessId,
      auditedAt: DateTime.now(),
      isInventoryBalanced: inventoryDiscrepancies.isEmpty,
      isSupplierLedgerBalanced: supplierDiscrepancies.isEmpty,
      inventoryDiscrepancies: inventoryDiscrepancies,
      supplierDiscrepancies: supplierDiscrepancies,
    );
  }

  /// إعادة بناء رصيد حساب المورد من سجل الحركات التراكمي فقط (Rebuild Balance)
  Future<SupplierAccount> rebuildSupplierAccountBalance({
    required String businessId,
    required String supplierId,
  }) async {
    final account = await _supplierRepo.getSupplierAccount(
      businessId: businessId,
      supplierId: supplierId,
    );
    if (account == null) {
      throw StateError('حساب المورد غير موجود لإعادة بنائه.');
    }

    final entries = await _supplierLedgerRepo.getEntriesForSupplier(
      businessId: businessId,
      supplierId: supplierId,
    );

    var rebuiltBalance = Money.zero(account.currency);
    for (final entry in entries) {
      rebuiltBalance += entry.balanceDelta;
    }

    final updatedAccount = account.copyWith(
      currentBalance: rebuiltBalance,
      version: account.version + 1,
      updatedAt: DateTime.now(),
    );

    await _supplierRepo.saveSupplierAccount(updatedAccount);
    return updatedAccount;
  }
}
