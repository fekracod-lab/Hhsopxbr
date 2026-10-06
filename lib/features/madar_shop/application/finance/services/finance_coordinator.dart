// المنسق المركزي للعمليات المالية وتكلفة المخزون وهوامش الأرباح (MADAR SHOP Finance Coordinator)
// Pure Dart — Zero UI Dependencies

import 'dart:async';

import '../../../domain/audit/contracts/shop_audit_repository.dart';
import '../../../domain/audit/entities/shop_audit_entry.dart';
import '../../../domain/finance/calculators/cogs_calculator.dart';
import '../../../domain/finance/calculators/gross_profit_calculator.dart';
import '../../../domain/finance/calculators/revenue_calculator.dart';
import '../../../domain/finance/entities/financial_entry.dart';
import '../../../domain/finance/enums/costing_method.dart';
import '../../../domain/finance/enums/financial_direction.dart';
import '../../../domain/finance/enums/financial_entry_type.dart';
import '../../../domain/finance/repositories/i_finance_idempotency_store.dart';
import '../../../domain/finance/repositories/i_financial_entry_repository.dart';
import '../../../domain/finance/repositories/i_inventory_cost_layer_repository.dart';
import '../../../domain/finance/value_objects/gross_profit_result.dart';
import '../../../domain/finance/value_objects/inventory_cost_layer.dart';
import '../../../domain/finance/value_objects/inventory_valuation_item.dart';
import '../../../domain/finance/value_objects/inventory_valuation_report.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/identity/rbac/shop_permission_matrix.dart';
import '../../../domain/identity/rbac/shop_role.dart';
import '../../../domain/inventory/repositories/i_inventory_repository.dart';
import '../../../domain/inventory/value_objects/stock_quantity.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../commands/finance_commands.dart';
import '../events/finance_domain_events.dart';
import '../failures/finance_failures.dart';
import '../results/finance_operation_results.dart';

class FinanceCoordinator {
  final IFinancialEntryRepository _financialEntryRepo;
  final IInventoryCostLayerRepository _costLayerRepo;
  final IFinanceIdempotencyStore _idempotencyStore;
  final IShopPosRepository _posRepo;
  final IInventoryRepository _inventoryRepo;
  final IShopAuditRepository _auditRepo;
  final void Function(FinanceDomainEvent)? _eventSink;

  // سياق الصلاحيات والعزل المتعدد
  final String currentBusinessId;
  final String currentBranchId;
  final ShopRole currentRole;
  final Set<ShopPermission>? customPermissions;

  // أقفال التزامن لمنع التضارب
  final Map<String, Completer<void>> _locks = {};

  FinanceCoordinator({
    required IFinancialEntryRepository financialEntryRepo,
    required IInventoryCostLayerRepository costLayerRepo,
    required IFinanceIdempotencyStore idempotencyStore,
    required IShopPosRepository posRepo,
    required IInventoryRepository inventoryRepo,
    required IShopAuditRepository auditRepo,
    void Function(FinanceDomainEvent)? eventSink,
    required this.currentBusinessId,
    required this.currentBranchId,
    required this.currentRole,
    this.customPermissions,
  })  : _financialEntryRepo = financialEntryRepo,
        _costLayerRepo = costLayerRepo,
        _idempotencyStore = idempotencyStore,
        _posRepo = posRepo,
        _inventoryRepo = inventoryRepo,
        _auditRepo = auditRepo,
        _eventSink = eventSink;

  Future<void> _acquireLock(String key) async {
    while (_locks.containsKey(key)) {
      await _locks[key]!.future;
    }
    _locks[key] = Completer<void>();
  }

  void _releaseLock(String key) {
    if (_locks.containsKey(key)) {
      final completer = _locks.remove(key);
      completer?.complete();
    }
  }

  void _assertBusinessMatches(String businessId) {
    if (businessId != currentBusinessId) {
      throw const FinanceBusinessMismatchFailure();
    }
  }

  void _assertBranchMatches(String branchId) {
    if (branchId != currentBranchId) {
      throw const FinanceBranchMismatchFailure();
    }
  }

  void _assertHasPermission(ShopPermission permission) {
    final allowed = ShopPermissionMatrix.hasPermission(
      role: currentRole,
      permission: permission,
      customPermissions: customPermissions,
    );
    if (!allowed) {
      throw FinancePermissionDeniedFailure(
        'الدور الحالي (${currentRole.name}) لا يملك الصلاحية (${permission.name}).',
      );
    }
  }

  // ─── تسجيل العمليات المالية وتكلفة المبيعات (Sale Financials & COGS Posting) ───

  /// ترحيل قيود الإيراد وتكلفة البضاعة المباعة (COGS) ذرياً لفاتورة بيع مكتملة
  Future<PostSaleFinancialsResult> postSaleFinancials(PostSaleFinancialsCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertBranchMatches(command.branchId);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
      final cached = await _idempotencyStore.getResult(command.idempotencyKey);
      if (cached is PostSaleFinancialsResult) return cached;
    }

    final lockKey = 'lock:finance_sale:${command.sale.id}';
    await _acquireLock(lockKey);

    try {
      if (await _idempotencyStore.hasKey(command.idempotencyKey)) {
        final cached = await _idempotencyStore.getResult(command.idempotencyKey);
        if (cached is PostSaleFinancialsResult) return cached;
      }

      final existingEntries = await _financialEntryRepo.getEntriesForReference(
        referenceType: 'SALE',
        referenceId: command.sale.id,
      );
      if (existingEntries.isNotEmpty) {
        final rev = existingEntries.cast<FinancialEntry?>().firstWhere(
          (e) => e?.entryType == FinancialEntryType.saleRevenue,
          orElse: () => null,
        );
        final cogs = existingEntries.cast<FinancialEntry?>().firstWhere(
          (e) => e?.entryType == FinancialEntryType.saleCogs,
          orElse: () => null,
        );
        final cachedRes = PostSaleFinancialsResult(
          isSuccess: true,
          revenueEntry: rev,
          cogsEntry: cogs,
          message: 'تم ترحيل القيود المالية للفاتورة مسبقاً.',
        );
        await _idempotencyStore.saveResult(command.idempotencyKey, cachedRes);
        return cachedRes;
      }

      final sale = command.sale;

      // 1. حساب الإيراد وصافي المبيعات من الفاتورة
      final revResult = RevenueCalculator.calculateSaleRevenue(sale);

      // 2. حساب تكلفة البضاعة المباعة (COGS) حسب طريقة التكلفة المحددة
      Money totalCogs = Money.zero(sale.currency);

      for (final item in sale.items) {
        final itemQty = StockQuantity.discrete(item.quantity.toInt());

        if (command.costingMethod == CostingMethod.fifo) {
          // استهلاك طبقات التكلفة FIFO
          final layers = await _costLayerRepo.getLayersForProduct(
            businessId: command.businessId,
            branchId: command.branchId,
            productId: item.productId,
            variantId: item.variantId,
          );

          if (layers.isNotEmpty) {
            final fifoRes = CogsCalculator.consumeFifoCostLayers(
              layers: layers,
              quantityToConsume: itemQty,
            );
            totalCogs += fifoRes.totalCogs;
            await _costLayerRepo.saveLayers(fifoRes.updatedLayers);
          } else {
            // fallback إلى التكلفة المسجلة باللقطة إن لم تكن هناك طبقات سابقة
            totalCogs += item.pricingSnapshot.costPrice * item.quantity;
          }
        } else {
          // طريقة المتوسط المرجح (Weighted Average)
          final unitCost = item.pricingSnapshot.costPrice;
          totalCogs += CogsCalculator.calculateWeightedAverageCogs(
            quantitySold: itemQty,
            averageCost: unitCost,
          );
        }
      }

      // 3. إنشاء قيد الإيراد (Credit / Revenue)
      final revenueEntry = FinancialEntry(
        id: 'FIN-REV-${sale.id}',
        businessId: command.businessId,
        branchId: command.branchId,
        entryType: FinancialEntryType.saleRevenue,
        referenceType: 'SALE',
        referenceId: sale.id,
        amount: revResult.netRevenue,
        currency: sale.currency,
        direction: FinancialDirection.credit,
        actorId: command.actorId,
        createdAt: DateTime.now(),
        idempotencyKey: 'IDEM-FIN-REV-${command.idempotencyKey}',
        metadata: {
          'grossRevenue': revResult.grossRevenue.toAmount(),
          'discount': revResult.discountTotal.toAmount(),
          'tax': revResult.taxTotal.toAmount(),
        },
      );

      // 4. إنشاء قيد تكلفة البضاعة المباعة (Debit / COGS)
      final cogsEntry = FinancialEntry(
        id: 'FIN-COGS-${sale.id}',
        businessId: command.businessId,
        branchId: command.branchId,
        entryType: FinancialEntryType.saleCogs,
        referenceType: 'SALE',
        referenceId: sale.id,
        amount: totalCogs,
        currency: sale.currency,
        direction: FinancialDirection.debit,
        actorId: command.actorId,
        createdAt: DateTime.now(),
        idempotencyKey: 'IDEM-FIN-COGS-${command.idempotencyKey}',
        metadata: {
          'costingMethod': command.costingMethod.name,
          'itemsCount': sale.items.length,
        },
      );

      // 5. حفظ القيدين الماليين ذرياً
      await _financialEntryRepo.appendEntry(revenueEntry);
      await _financialEntryRepo.appendEntry(cogsEntry);

      // 6. حساب مجمل الربح ونسبة الهامش
      final profitRes = GrossProfitCalculator.calculate(
        grossRevenue: revResult.grossRevenue,
        discountTotal: revResult.discountTotal,
        taxTotal: revResult.taxTotal,
        cogs: totalCogs,
        unitsCount: sale.totalUnitsCount,
      );

      await _auditRepo.recordAuditEntry(ShopAuditEntry(
        auditId: 'AUD-FIN-REV-${DateTime.now().microsecondsSinceEpoch}',
        businessId: command.businessId,
        branchId: command.branchId,
        userId: command.actorId,
        userName: 'Finance Poster',
        terminalId: 'SERVER',
        action: ShopAuditAction.saleRevenuePosted,
        referenceId: sale.id,
        timestamp: DateTime.now(),
        metadata: {
          'netRevenue': revResult.netRevenue.toAmount(),
          'cogs': totalCogs.toAmount(),
          'grossProfit': profitRes.grossProfit.toAmount(),
        },
      ));

      _eventSink?.call(SaleRevenuePostedEvent(
        eventId: 'EVT-FIN-REV-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        revenueEntry: revenueEntry,
        saleId: sale.id,
      ));

      _eventSink?.call(SaleCogsPostedEvent(
        eventId: 'EVT-FIN-COGS-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
        cogsEntry: cogsEntry,
        saleId: sale.id,
      ));

      final result = PostSaleFinancialsResult(
        isSuccess: true,
        revenueEntry: revenueEntry,
        cogsEntry: cogsEntry,
        grossProfit: profitRes.grossProfit,
        grossMargin: profitRes.grossMarginPercentage,
        message: 'تم ترحيل قيود الإيراد وتكلفة المبيعات بنجاح.',
      );

      await _idempotencyStore.saveResult(command.idempotencyKey, result);
      return result;
    } finally {
      _releaseLock(lockKey);
    }
  }

  /// عكس القيود المالية (COGS & Revenue Reversal) عند إرجاع بضاعة
  Future<void> reverseSaleFinancialsOnReturn(ReverseSaleFinancialsOnReturnCommand command) async {
    _assertBusinessMatches(command.businessId);

    if (await _idempotencyStore.hasKey(command.idempotencyKey)) return;

    final returnOrder = command.returnOrder;

    // 1. قيد استرداد أموال المرتجع للعميل (Debit / Customer Refund)
    final refundEntry = FinancialEntry(
      id: 'FIN-REFUND-${returnOrder.id}',
      businessId: command.businessId,
      branchId: command.branchId,
      entryType: FinancialEntryType.customerRefund,
      referenceType: 'CUSTOMER_RETURN',
      referenceId: returnOrder.id,
      amount: returnOrder.grandTotalRefund,
      currency: returnOrder.currency,
      direction: FinancialDirection.debit,
      actorId: command.actorId,
      createdAt: DateTime.now(),
      idempotencyKey: 'IDEM-FIN-REFUND-${command.idempotencyKey}',
    );
    await _financialEntryRepo.appendEntry(refundEntry);

    // 2. إذا كانت هناك أصناف صالحة لإعادة التخزين: عكس COGS (Credit / COGS Reversal)
    final reversibleCogs = returnOrder.totalReversibleCogs;
    if (reversibleCogs.minorUnits > 0) {
      final cogsReversalEntry = FinancialEntry(
        id: 'FIN-COGS-REV-${returnOrder.id}',
        businessId: command.businessId,
        branchId: command.branchId,
        entryType: FinancialEntryType.saleCogs,
        referenceType: 'CUSTOMER_RETURN',
        referenceId: returnOrder.id,
        amount: reversibleCogs,
        currency: returnOrder.currency,
        direction: FinancialDirection.credit, // دائن لتخفيض إجمالي COGS
        actorId: command.actorId,
        createdAt: DateTime.now(),
        idempotencyKey: 'IDEM-FIN-COGS-REV-${command.idempotencyKey}',
      );
      await _financialEntryRepo.appendEntry(cogsReversalEntry);

      // إعادة إنشاء طبقة تكلفة للمخزون المسترجع الصالح
      for (final it in returnOrder.items) {
        if (it.isRestockable) {
          final restockLayer = InventoryCostLayer(
            id: 'LAYER-RESTOCK-${returnOrder.id}-${it.id}',
            businessId: command.businessId,
            branchId: command.branchId,
            productId: it.productId,
            variantId: it.variantId,
            sourceType: 'RETURN_RESTOCK',
            sourceId: returnOrder.id,
            quantity: it.quantity,
            remainingQuantity: it.quantity,
            unitCost: it.originalCostBasis,
            currency: it.originalCostBasis.currency,
            createdAt: DateTime.now(),
          );
          await _costLayerRepo.saveLayer(restockLayer);
        }
      }
    }

    await _idempotencyStore.saveResult(command.idempotencyKey, true);
  }

  // ─── استخراج الأرباح وتقييم المخزون (Profit & Inventory Valuation Services) ───

  /// احتساب مجمل الربح وهوامش الأرباح لفترة محددة (Period Gross Profit)
  Future<GrossProfitCalculationResult> calculatePeriodProfit(CalculatePeriodProfitCommand command) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.viewProfitAndMarginReports);

    if (command.from.isAfter(command.to)) {
      throw const FinancialPeriodInvalidFailure();
    }

    final entries = await _financialEntryRepo.getEntries(
      businessId: command.businessId,
      branchId: command.branchId,
      from: command.from,
      to: command.to,
    );

    Money totalRevenue = Money.zero();
    Money totalCogs = Money.zero();
    Money totalRefunds = Money.zero();
    double unitsCount = 0.0;

    for (final e in entries) {
      if (e.entryType == FinancialEntryType.saleRevenue) {
        totalRevenue += e.amount;
      } else if (e.entryType == FinancialEntryType.saleCogs) {
        if (e.direction == FinancialDirection.debit) {
          totalCogs += e.amount;
        } else {
          // COGS Reversal دائن
          totalCogs -= e.amount;
        }
      } else if (e.entryType == FinancialEntryType.customerRefund) {
        totalRefunds += e.amount;
      }
    }

    // الصافي النهائي للإيراد بعد خصم المرتجعات
    final effectiveRevenue = totalRevenue - totalRefunds;

    final profitRes = GrossProfitCalculator.calculate(
      grossRevenue: effectiveRevenue,
      discountTotal: Money.zero(),
      taxTotal: Money.zero(),
      cogs: totalCogs,
      unitsCount: unitsCount,
    );

    _eventSink?.call(GrossProfitCalculatedEvent(
      eventId: 'EVT-PROFIT-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: DateTime.now(),
      businessId: command.businessId,
      branchId: command.branchId,
      result: profitRes,
    ));

    return GrossProfitCalculationResult(
      isSuccess: true,
      result: profitRes,
    );
  }

  /// تقييم المخزون المالي في تاريخ ولحظة محددة (Inventory Valuation AsOf)
  Future<InventoryValuationCalculationResult> calculateInventoryValuation(
    CalculateInventoryValuationCommand command,
  ) async {
    _assertBusinessMatches(command.businessId);
    _assertHasPermission(ShopPermission.viewInventoryValuation);

    final items = <InventoryValuationItem>[];

    if (command.costingMethod == CostingMethod.fifo) {
      final layers = await _costLayerRepo.getAllLayers(
        businessId: command.businessId,
        branchId: command.branchId,
      );

      final layersByProduct = <String, List<InventoryCostLayer>>{};
      for (final l in layers) {
        if (l.createdAt.isAfter(command.asOf)) continue;
        final key = '${l.productId}:${l.variantId ?? ""}';
        layersByProduct.putIfAbsent(key, () => []).add(l);
      }

      for (final entry in layersByProduct.entries) {
        final productLayers = entry.value;
        final totalQty = productLayers.fold(
          StockQuantity.zero(),
          (sum, it) => sum + it.remainingQuantity,
        );
        final totalVal = productLayers.fold(
          Money.zero(productLayers.first.currency),
          (sum, it) => sum + it.remainingTotalValue,
        );
        final unitCost = totalQty.toDouble() > 0
            ? totalVal * (1 / totalQty.toDouble())
            : Money.zero(totalVal.currency);

        items.add(InventoryValuationItem(
          productId: productLayers.first.productId,
          variantId: productLayers.first.variantId,
          sku: 'SKU-${productLayers.first.productId}',
          name: 'Product ${productLayers.first.productId}',
          quantityOnHand: totalQty,
          unitCostBasis: unitCost,
          method: CostingMethod.fifo,
          asOf: command.asOf,
        ));
      }
    } else {
      // Weighted Average Valuation
      final layers = await _costLayerRepo.getAllLayers(
        businessId: command.businessId,
        branchId: command.branchId,
      );

      final layersByProduct = <String, List<InventoryCostLayer>>{};
      for (final l in layers) {
        if (l.createdAt.isAfter(command.asOf)) continue;
        final key = '${l.productId}:${l.variantId ?? ""}';
        layersByProduct.putIfAbsent(key, () => []).add(l);
      }

      for (final entry in layersByProduct.entries) {
        final productLayers = entry.value;
        StockQuantity runningQty = StockQuantity.zero();
        Money runningAvg = Money.zero(productLayers.first.currency);

        for (final layer in productLayers) {
          runningAvg = CogsCalculator.calculateNewWeightedAverageCost(
            existingQuantity: runningQty,
            existingAverageCost: runningAvg,
            receivedQuantity: layer.remainingQuantity,
            receivedCost: layer.unitCost,
          );
          runningQty += layer.remainingQuantity;
        }

        items.add(InventoryValuationItem(
          productId: productLayers.first.productId,
          variantId: productLayers.first.variantId,
          sku: 'SKU-${productLayers.first.productId}',
          name: 'Product ${productLayers.first.productId}',
          quantityOnHand: runningQty,
          unitCostBasis: runningAvg,
          method: CostingMethod.weightedAverage,
          asOf: command.asOf,
        ));
      }
    }

    final report = InventoryValuationReport(
      businessId: command.businessId,
      branchId: command.branchId,
      items: items,
      generatedAt: DateTime.now(),
      asOf: command.asOf,
    );

    await _auditRepo.recordAuditEntry(ShopAuditEntry(
      auditId: 'AUD-VALUATION-${DateTime.now().microsecondsSinceEpoch}',
      businessId: command.businessId,
      branchId: command.branchId ?? 'ALL',
      userId: command.actorId,
      userName: 'Valuation Auditor',
      terminalId: 'SERVER',
      action: ShopAuditAction.inventoryValuationCalculated,
      timestamp: DateTime.now(),
      metadata: {
        'totalValuation': report.totalValuation.toAmount(),
        'unitsCount': report.totalUnitsCount,
        'asOf': command.asOf.toIso8601String(),
      },
    ));

    _eventSink?.call(InventoryValuationCalculatedEvent(
      eventId: 'EVT-VAL-${DateTime.now().microsecondsSinceEpoch}',
      occurredAt: DateTime.now(),
      report: report,
    ));

    return InventoryValuationCalculationResult(
      isSuccess: true,
      report: report,
    );
  }

  /// تسجيل طبقة تكلفة جديدة (عند استلام شراء أو رصيد افتتاحي)
  Future<void> addCostLayer(InventoryCostLayer layer) async {
    await _costLayerRepo.saveLayer(layer);
  }
}
