// متحكم حالة واجهة نقطة البيع لبيئة ويندوز (MADAR SHOP Windows POS Controller)
// Presentation Layer — Reactive State, Zero Business Logic Duplication

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../application/pos/commands/checkout_command.dart';
import '../../../application/pos/commands/checkout_result.dart';
import '../../../application/pos/services/cart_coordinator.dart';
import '../../../application/pos/services/pos_checkout_coordinator.dart';
import '../../../application/printing/commands/printing_commands.dart';
import '../../../application/printing/services/document_builder_service.dart';
import '../../../application/printing/services/print_coordinator.dart';
import '../../../application/returns/services/returns_coordinator.dart';
import '../../../application/shop_identity_coordinator.dart';
import '../../../application/sync/coordinators/sync_coordinator.dart';
import '../../../domain/contracts/shop_core_repository_contract.dart';
import '../../../domain/identity/rbac/shop_permission.dart';
import '../../../domain/pos/calculators/tax_policy.dart';
import '../../../domain/pos/entities/cart.dart';
import '../../../domain/pos/entities/payment.dart';
import '../../../domain/pos/entities/receipt_snapshot.dart';
import '../../../domain/pos/entities/resolved_product.dart';
import '../../../domain/pos/entities/sale.dart';
import '../../../domain/pos/enums/payment_method.dart';
import '../../../domain/pos/enums/sale_status.dart';
import '../../../domain/pos/services/i_product_resolver.dart';
import '../../../domain/pos/services/i_shop_pos_repository.dart';
import '../../../domain/printing/enums/print_job_status.dart';
import '../../../domain/printing/enums/print_trigger_type.dart';
import '../../../domain/pos/value_objects/currency.dart';
import '../../../domain/pos/value_objects/discount.dart';
import '../../../domain/pos/calculators/pricing_calculator.dart';
import '../../../domain/pos/value_objects/money.dart';
import '../../../domain/printing/enums/printer_status.dart';
import '../../../domain/products/entities/shop_category.dart';
import '../../../domain/products/entities/shop_product.dart';
import '../../../domain/sync/entities/cached_entities.dart';
import '../../../domain/sync/enums/connectivity_state.dart';
import '../../../domain/sync/value_objects/sync_status_snapshot.dart';
import '../../../application/pos/failures/pos_failures.dart';
import '../utils/pos_error_mapper.dart';

class WindowsPosController extends ChangeNotifier {
  final ShopIdentityCoordinator identityCoordinator;
  final PosCheckoutCoordinator checkoutCoordinator;
  final SyncCoordinator syncCoordinator;
  final PrintCoordinator? printCoordinator;
  final ReturnsCoordinator? returnsCoordinator;
  final IProductResolver productResolver;
  final IShopCoreRepository coreRepository;
  final IShopPosRepository posRepository;

  // ─── تعدد السلات المعلقة (Multiple Active Carts: Cart 1, Cart 2, Cart 3) ───
  static const int maxCarts = 3;
  final List<CartCoordinator> _cartSlots = [];
  int _activeCartIndex = 0;

  // ─── كتالوج المنتجات والأقسام ───
  List<ShopProduct> _allProducts = [];
  List<ShopProduct> _filteredProducts = [];
  List<ShopCategory> _categories = [];
  String _selectedCategoryId = 'ALL';
  String _searchQuery = '';
  bool _isLoadingCatalog = false;

  // ─── حالة المزامنة والاتصال والطباعة ───
  SyncStatusSnapshot _syncStatus = const SyncStatusSnapshot(
    connectivityState: ConnectivityState.unknown,
    pendingOutboxCount: 0,
    inFlightCount: 0,
    failedCount: 0,
    conflictCount: 0,
    inboxPendingCount: 0,
    isSyncing: false,
  );
  PrinterStatus _printerState = PrinterStatus.online;
  StreamSubscription? _syncSub;

  // ─── حالة عملية الدفع والنتيجة ───
  bool _isProcessingPayment = false;
  CheckoutResult? _lastCheckoutResult;
  bool _isLastSaleOffline = false;
  String? _errorMessage;

  // ─── العميل المختار ───
  CachedCustomer? _selectedCustomer;

  WindowsPosController({
    required this.identityCoordinator,
    required this.checkoutCoordinator,
    required this.syncCoordinator,
    this.printCoordinator,
    this.returnsCoordinator,
    required this.productResolver,
    required this.coreRepository,
    required this.posRepository,
    Currency currency = Currency.iqd,
  }) {
    for (int i = 0; i < maxCarts; i++) {
      _cartSlots.add(CartCoordinator(
        identityCoordinator: identityCoordinator,
        currency: currency,
      ));
    }

    _initSyncSubscription();
  }

  void _initSyncSubscription() {
    _syncSub = syncCoordinator.events.listen((_) async {
      await refreshSyncStatus();
    });
    refreshSyncStatus();
  }

  // ─── Getters ───
  int get activeCartIndex => _activeCartIndex;
  Cart get currentCart => _cartSlots[_activeCartIndex].currentCart;
  int get cartItemCount => currentCart.items.length;
  List<CartCoordinator> get cartSlots => List.unmodifiable(_cartSlots);
  List<ShopProduct> get filteredProducts => _filteredProducts;
  List<ShopProduct> get searchResults => _filteredProducts;
  List<ShopCategory> get categories => _categories;
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoadingCatalog => _isLoadingCatalog;
  SyncStatusSnapshot get syncStatus => _syncStatus;
  bool get isOffline =>
      _syncStatus.connectivityState == ConnectivityState.offline ||
      _syncStatus.connectivityState == ConnectivityState.unstable;
  PrinterStatus get printerState => _printerState;
  OrderTotalsCalculation get totals => PricingCalculator.calculateCartTotals(cart: currentCart);
  bool get isProcessingPayment => _isProcessingPayment;
  CheckoutResult? get lastCheckoutResult => _lastCheckoutResult;
  bool get isLastSaleOffline => _isLastSaleOffline;
  String? get errorMessage => _errorMessage;
  CachedCustomer? get selectedCustomer => _selectedCustomer;

  String get businessId => identityCoordinator.currentSession?.businessId ?? '';
  String get branchId => identityCoordinator.currentSession?.activeBranchId ?? '';
  String get terminalId => identityCoordinator.currentSession?.terminalId ?? 'POS-01';
  String get sessionId => identityCoordinator.currentSession?.sessionId ?? '';
  String get cashierName => identityCoordinator.currentUser?.fullName ?? 'كاشير';

  // ─── إدارة السلات المعلقة ───
  void switchCartSlot(int index) {
    if (index >= 0 && index < maxCarts && index != _activeCartIndex) {
      _activeCartIndex = index;
      notifyListeners();
    }
  }

  void switchCart(int index) => switchCartSlot(index);

  void holdCurrentCart() {
    // الانتقال لأول سلة فارغة متاحة
    for (int i = 0; i < maxCarts; i++) {
      if (i != _activeCartIndex && _cartSlots[i].currentCart.isEmpty) {
        _activeCartIndex = i;
        notifyListeners();
        return;
      }
    }
  }

  // ─── تحميل الكتالوج والبحث ───
  Future<void> initCatalog() => loadCatalog();

  Future<void> searchProducts(String query) async {
    setSearchQuery(query);
  }

  void incrementItem(String itemId) {
    final item = currentCart.items.firstWhere((it) => it.itemId == itemId);
    updateItemQuantity(itemId, item.quantity + 1);
  }

  void decrementItem(String itemId) {
    final item = currentCart.items.firstWhere((it) => it.itemId == itemId);
    if (item.quantity <= 1) {
      removeItem(itemId);
    } else {
      updateItemQuantity(itemId, item.quantity - 1);
    }
  }



  // ─── تحميل الكتالوج ───
  Future<void> loadCatalog() async {
    _isLoadingCatalog = true;
    notifyListeners();

    try {
      final products = await coreRepository.getProducts(
        businessId: businessId,
        branchId: branchId,
      );
      _allProducts = products;
      _applyProductFilters();
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
    } finally {
      _isLoadingCatalog = false;
      notifyListeners();
    }
  }

  void setCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    _applyProductFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyProductFilters();
    notifyListeners();
  }

  void _applyProductFilters() {
    _filteredProducts = _allProducts.where((product) {
      final matchesCategory = _selectedCategoryId == 'ALL' ||
          product.categoryId == _selectedCategoryId;

      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          product.name.toLowerCase().contains(q) ||
          product.sku.toLowerCase().contains(q) ||
          (product.barcode != null && product.barcode!.contains(q));

      return matchesCategory && matchesSearch;
    }).toList();
  }

  // ─── إضافة منتج بالباركود المباشر (Keyboard Wedge Scan) ───
  Future<bool> scanBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;

    try {
      final resolved = await productResolver.resolveProduct(
        query: clean,
        businessId: businessId,
        branchId: branchId,
      );

      if (resolved != null) {
        if (!resolved.isAvailable || resolved.stockQuantity <= 0) {
          _errorMessage = 'الكمية المطلوبة غير متوفرة بالمخزون: ${resolved.name}';
          notifyListeners();
          return false;
        }
        addProductToCart(resolved, quantity: 1.0);
        return true;
      } else {
        _errorMessage = 'المنتج غير موجود في الكتالوج: $clean';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
      return false;
    }
  }

  // ─── عمليات السلة ───
  void addProductToCart(
    ResolvedProduct product, {
    double quantity = 1.0,
    Money? manualOverridePrice,
    String? overrideReason,
    Discount discount = const Discount.none(),
  }) {
    try {
      _errorMessage = null;
      if (!product.isAvailable || product.stockQuantity <= 0) {
        throw ProductUnavailableFailure('المنتج "${product.name}" غير متوفر للبيع حالياً.');
      }
      _cartSlots[_activeCartIndex].addResolvedProduct(
        product: product,
        quantity: quantity,
        manualOverridePrice: manualOverridePrice,
        overrideReason: overrideReason,
        discount: discount,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  void updateItemQuantity(String itemId, double newQuantity) {
    try {
      _errorMessage = null;
      if (newQuantity <= 0) {
        _errorMessage = 'الكمية يجب أن تكون أكبر من صفر.';
        notifyListeners();
        return;
      }
      _cartSlots[_activeCartIndex].updateQuantity(itemId, newQuantity);
      notifyListeners();
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _cartSlots[_activeCartIndex].removeItem(itemId);
    notifyListeners();
  }

  void clearCurrentCart() {
    _cartSlots[_activeCartIndex].clear();
    _selectedCustomer = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setCustomer(CachedCustomer? customer) {
    _selectedCustomer = customer;
    _cartSlots[_activeCartIndex].setCustomer(
      customerId: customer?.id,
      customerName: customer?.name,
    );
    notifyListeners();
  }

  void applyItemDiscount(String itemId, Discount discount) {
    try {
      _errorMessage = null;
      _cartSlots[_activeCartIndex].applyItemDiscount(itemId, discount);
      notifyListeners();
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  void applyCartDiscount(Discount discount) {
    try {
      _errorMessage = null;
      _cartSlots[_activeCartIndex].applyCartDiscount(discount);
      notifyListeners();
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  // ─── تنفيذ الدفع والـ Checkout (أونلاين أو أوفلاين بأمان) ───
  Future<bool> processPayment({
    required List<Payment> payments,
    String? notes,
    bool autoPrint = true,
  }) async {
    if (_isProcessingPayment) return false; // حماية ضد النقر المزدوج (Double Click Prevention)
    if (currentCart.isEmpty) {
      _errorMessage = 'السلة فارغة؛ يرجى إضافة منتجات قبل الدفع.';
      notifyListeners();
      return false;
    }

    _isProcessingPayment = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final isOffline = _syncStatus.connectivityState == ConnectivityState.offline ||
          _syncStatus.connectivityState == ConnectivityState.unstable;

      if (!isOffline) {
        // 1. مسار المعالجة المتصلة (Online POS Engine)
        final command = CheckoutCommand(
          commandId: 'CMD-${DateTime.now().microsecondsSinceEpoch}',
          businessId: businessId,
          branchId: branchId,
          terminalId: terminalId,
          sessionId: sessionId,
          idempotencyKey: 'IDEMP-POS-${DateTime.now().microsecondsSinceEpoch}',
          cart: currentCart,
          payments: payments,
          customerId: _selectedCustomer?.id,
          customerName: _selectedCustomer?.name,
          taxPolicy: TaxPolicy.none(),
          notes: notes,
          createdAt: DateTime.now(),
        );

        final result = await checkoutCoordinator.processCheckout(command);
        _lastCheckoutResult = result;
        _isLastSaleOffline = false;

        // إطلاق الطباعة التلقائية إذا طلبت
        if (autoPrint && printCoordinator != null) {
          try {
            final doc = const DocumentBuilderService().buildFromReceiptSnapshot(result.receipt);
            final job = await printCoordinator!.submitPrintJob(SubmitPrintJobCommand(
              businessId: businessId,
              branchId: branchId,
              document: doc,
              triggerType: PrintTriggerType.autoPrint,
              requestedBy: identityCoordinator.currentUser?.userId ?? 'cashier',
              idempotencyKey: 'PRINT-${result.sale.id}',
            ));
            if (job.status == PrintJobStatus.failed) {
              _printerState = PrinterStatus.offline;
            }
          } catch (_) {
            _printerState = PrinterStatus.offline;
          }
        }
      } else {
        // 2. مسار المعالجة غير المتصلة (Offline Engine + Outbox Envelope)
        final isCashOnly = payments.every((p) => p.method == PaymentMethod.cash);
        final saleId = 'OFFLINE-SALE-${DateTime.now().microsecondsSinceEpoch}';

        final Map<String, double> itemsQty = {};
        for (final item in currentCart.items) {
          itemsQty[item.productId] = item.quantity;
        }

        await syncCoordinator.checkoutOffline(
          commandId: 'CMD-OFFLINE-${DateTime.now().microsecondsSinceEpoch}',
          saleId: saleId,
          businessId: businessId,
          branchId: branchId,
          terminalId: terminalId,
          sessionId: sessionId,
          idempotencyKey: 'IDEMP-$saleId',
          isCash: isCashOnly,
          cartPayload: {
            'itemCount': currentCart.items.length,
            'subtotal': totals.subtotal.minorUnits,
            'grandTotal': totals.grandTotal.minorUnits,
          },
          itemsQuantity: itemsQty,
          autoPrint: autoPrint,
        );

        // إنشاء نتيجة لقطة أوفلاين
        final offlineSale = Sale(
          id: saleId,
          businessId: businessId,
          branchId: branchId,
          terminalId: terminalId,
          sessionId: sessionId,
          cashierId: identityCoordinator.currentUser?.userId ?? '',
          cashierName: cashierName,
          saleNumber: 'OFF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
          status: SaleStatus.completed,
          items: const [],
          subtotal: totals.subtotal,
          discountTotal: totals.discountTotal,
          taxTotal: totals.taxTotal,
          grandTotal: totals.grandTotal,
          paidTotal: totals.grandTotal,
          remainingTotal: Money.zero(currentCart.currency),
          changeTotal: Money.zero(currentCart.currency),
          payments: payments,
          currency: currentCart.currency,
          createdAt: DateTime.now(),
          idempotencyKey: 'IDEMP-$saleId',
        );

        final receipt = ReceiptSnapshot.fromSale(
          sale: offlineSale,
          businessName: businessId,
          branchName: branchId,
        );

        _lastCheckoutResult = CheckoutResult(
          sale: offlineSale,
          receipt: receipt,
          inventoryIntents: const [],
          isIdempotentReplay: false,
          processedAt: DateTime.now(),
        );
        _isLastSaleOffline = true;
      }

      // تفريغ السلة الحالية بعد نجاح العملية
      _cartSlots[_activeCartIndex].clear();
      _selectedCustomer = null;
      await refreshSyncStatus();
      return true;
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      return false;
    } finally {
      _isProcessingPayment = false;
      notifyListeners();
    }
  }

  // ─── استرجاع مبيعات الفرع ───
  Future<List<Sale>> lookupSales({String? query}) async {
    try {
      final sales = await posRepository.getSalesForSession(
        businessId: businessId,
        branchId: branchId,
        sessionId: sessionId,
      );

      if (query == null || query.trim().isEmpty) return sales;
      final q = query.trim().toLowerCase();
      return sales.where((s) {
        return s.saleNumber.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q) ||
            (s.customerName != null && s.customerName!.toLowerCase().contains(q));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── إعادة الطباعة اليدوية المدققة ───
  Future<bool> reprintSaleReceipt({
    required Sale sale,
    required String reason,
  }) async {
    if (printCoordinator == null) return false;
    try {
      final receipt = ReceiptSnapshot.fromSale(
        sale: sale,
        businessName: businessId,
        branchName: branchId,
      );
      final doc = const DocumentBuilderService().buildFromReceiptSnapshot(receipt);
      final job = await printCoordinator!.reprintDocument(ReprintCommand(
        businessId: businessId,
        branchId: branchId,
        originalJobIdOrDocumentId: sale.id,
        document: doc,
        requestedBy: identityCoordinator.currentUser?.userId ?? 'cashier',
        reason: reason,
        idempotencyKey: 'REPRINT-${sale.id}-${DateTime.now().millisecondsSinceEpoch}',
      ));
      return job.status != PrintJobStatus.failed;
    } catch (e) {
      _errorMessage = PosErrorMapper.toArabicMessage(e);
      notifyListeners();
      return false;
    }
  }

  // ─── تحديث حالة المزامنة ───
  Future<void> refreshSyncStatus() async {
    try {
      _syncStatus = await syncCoordinator.getSyncStatusSnapshot();
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }
}
