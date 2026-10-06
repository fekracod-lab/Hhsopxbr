import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../products/domain/entities/shop_product.dart';
import '../../products/data/services/products_firestore_service.dart';
import '../../auth/domain/entities/store_profile.dart';
import '../domain/entities/cart_item.dart';
import '../domain/entities/hold_cart.dart';
import '../domain/entities/pos_transaction.dart';

/// متحكم نقطة البيع السحابية والمحلية لكاشير مدار (POS Controller)
class PosController extends ChangeNotifier {
  final List<PosCartItem> _cart = [];
  final List<HoldCart> _holdCarts = [];
  
  double _generalDiscount = 0.0;
  String _selectedCategory = 'الكل';
  String _searchQuery = '';
  
  List<ShopProduct> _allProducts = [];
  StreamSubscription<List<ShopProduct>>? _productsSub;
  StoreProfile? _activeStore;

  // ── Getters ──
  List<PosCartItem> get cart => List.unmodifiable(_cart);
  List<HoldCart> get holdCarts => List.unmodifiable(_holdCarts);
  double get generalDiscount => _generalDiscount;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  StoreProfile? get activeStore => _activeStore;

  int get totalItemsCount => _cart.fold(0, (acc, it) => acc + it.quantity);

  double get subtotal => _cart.fold(0.0, (acc, it) => acc + it.subtotal);

  double get totalDiscounts =>
      _cart.fold(0.0, (acc, it) => acc + it.discount) + _generalDiscount;

  double get netTotal {
    final t = subtotal - totalDiscounts;
    return t < 0 ? 0.0 : t;
  }

  /// قائمة المنتجات المفلترة حسب القسم والبحث
  List<ShopProduct> get filteredProducts {
    var list = _allProducts;
    if (_selectedCategory != 'الكل' && _selectedCategory.trim().isNotEmpty) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.barcode.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  /// ربط المتجر النشط وبدء المزامنة الفورية للمنتجات
  void bindStore(StoreProfile store) {
    if (_activeStore?.storeId == store.storeId) return;
    _activeStore = store;
    _productsSub?.cancel();
    _productsSub = ProductsFirestoreService.instance
        .watchProducts(store.storeId)
        .listen((prods) {
      _allProducts = prods;
      notifyListeners();
    });
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// مسح ضوئي لباركود عبر الماسح الضوئي (Barcode Scanner Scan)
  bool scanBarcode(String barcode) {
    final clean = barcode.trim();
    if (clean.isEmpty) return false;

    // البحث عن المنتج بالباركود أو المعرف
    final found = _allProducts.firstWhere(
      (p) => p.barcode.trim() == clean || p.id == clean,
      orElse: () => const ShopProduct(id: '', name: '', price: 0),
    );

    if (found.id.isNotEmpty) {
      addToCart(found);
      return true;
    }
    return false;
  }

  /// إضافة منتج إلى السلة
  void addToCart(ShopProduct product, [int quantity = 1]) {
    final idx = _cart.indexWhere((it) => it.product.id == product.id);
    if (idx >= 0) {
      _cart[idx].quantity += quantity;
    } else {
      _cart.add(PosCartItem(
        product: product,
        quantity: quantity,
      ));
    }
    notifyListeners();
  }

  /// تحديث كمية عنصر
  void updateQuantity(String productId, int newQty) {
    final idx = _cart.indexWhere((it) => it.product.id == productId);
    if (idx >= 0) {
      if (newQty <= 0) {
        _cart.removeAt(idx);
      } else {
        _cart[idx].quantity = newQty;
      }
      notifyListeners();
    }
  }

  /// تطبيق خصم على عنصر محدد
  void setItemDiscount(String productId, double discount) {
    final idx = _cart.indexWhere((it) => it.product.id == productId);
    if (idx >= 0) {
      _cart[idx].discount = discount < 0 ? 0.0 : discount;
      notifyListeners();
    }
  }

  /// حذف عنصر من السلة
  void removeFromCart(String productId) {
    _cart.removeWhere((it) => it.product.id == productId);
    notifyListeners();
  }

  /// مسح محتويات السلة
  void clearCart() {
    _cart.clear();
    _generalDiscount = 0.0;
    notifyListeners();
  }

  /// تطبيق خصم عام على الفاتورة
  void setGeneralDiscount(double discount) {
    _generalDiscount = discount < 0 ? 0.0 : discount;
    notifyListeners();
  }

  /// تعليق السلة الحالية لخدمة زبون آخر في الطابور
  bool holdCurrentCart([String? customerName]) {
    if (_cart.isEmpty) return false;
    final name = customerName?.trim().isNotEmpty == true
        ? customerName!.trim()
        : 'زبون ${_holdCarts.length + 1}';

    _holdCarts.add(HoldCart(
      id: const Uuid().v4(),
      customerName: name,
      items: List.from(_cart),
      discount: _generalDiscount,
      savedAt: DateTime.now(),
    ));

    clearCart();
    return true;
  }

  /// استرجاع سلة معلقة
  void resumeHoldCart(HoldCart holdCart) {
    clearCart();
    _cart.addAll(holdCart.items);
    _generalDiscount = holdCart.discount;
    _holdCarts.removeWhere((it) => it.id == holdCart.id);
    notifyListeners();
  }

  /// حذف سلة معلقة
  void deleteHoldCart(String holdCartId) {
    _holdCarts.removeWhere((it) => it.id == holdCartId);
    notifyListeners();
  }

  /// إتمام عملية البيع وتسجيل الفاتورة وخصم المخزون
  Future<PosTransaction?> checkout({
    required double paidAmount,
    required String paymentMethod,
    String cashierName = 'كاشير مدار',
    String customerName = 'زبون نقدي',
    String customerPhone = '',
  }) async {
    if (_cart.isEmpty || _activeStore == null) return null;

    final store = _activeStore!;
    final now = DateTime.now();
    final invoiceNumber = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final change = (paidAmount - netTotal) < 0 ? 0.0 : (paidAmount - netTotal);

    final transaction = PosTransaction(
      id: const Uuid().v4(),
      invoiceNumber: invoiceNumber,
      storeId: store.storeId,
      storeName: store.name,
      items: List.from(_cart),
      subtotal: subtotal,
      discount: totalDiscounts,
      tax: 0.0,
      total: netTotal,
      paidAmount: paidAmount,
      changeAmount: change,
      paymentMethod: paymentMethod,
      cashierName: cashierName,
      customerName: customerName,
      customerPhone: customerPhone,
      createdAt: now,
    );

    // 1. تسجيل الفاتورة في Firestore في مجموعة فواتير المتجر
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(store.storeId)
          .collection('pos_transactions')
          .doc(transaction.id)
          .set(transaction.toMap());
    } catch (e) {
      debugPrint('[PosController] Firestore transaction save error: $e');
    }

    // 2. خصم المخزون التلقائي للمنتجات
    for (final it in _cart) {
      if (it.product.id.isNotEmpty && it.quantity > 0) {
        unawaited(ProductsFirestoreService.instance
            .deductStock(store.storeId, it.product.id, it.quantity));
      }
    }

    // 3. تفريغ السلة
    clearCart();

    return transaction;
  }

  @override
  void dispose() {
    _productsSub?.cancel();
    super.dispose();
  }
}
