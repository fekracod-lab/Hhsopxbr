import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../core/database/local_database_service.dart';
import '../../../services/audit_log_service.dart';
import '../../../services/pos_sync_service.dart';
import '../../../services/inventory_deduction_service.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_order.dart';

/// كائن الطلب المعلق مؤقتاً في الكاشير (Parked / Held Order)
class HeldOrder {
  final String id;
  final String label;
  final DateTime heldAt;
  final List<PosCartItem> items;
  final String orderType;
  final String? tableNumber;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String orderNotes;
  final String discountType;
  final double discountValue;
  final double taxOrService;

  HeldOrder({
    required this.id,
    required this.label,
    required this.heldAt,
    required this.items,
    required this.orderType,
    this.tableNumber,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.orderNotes,
    required this.discountType,
    required this.discountValue,
    required this.taxOrService,
  });

  double get total => items.fold(0.0, (sum, i) => sum + i.totalPrice);
}

/// موفر حالة الكاشير وسلة المبيعات (POS State Provider)
class PosProvider extends ChangeNotifier {
  final List<PosCartItem> _cartItems = [];
  final List<HeldOrder> _heldOrders = [];

  String _orderType = 'takeaway'; // 'dine_in', 'takeaway', 'delivery'
  String? _selectedTableNumber;
  String _customerName = '';
  String _customerPhone = '';
  String _deliveryAddress = '';
  String _orderNotes = '';

  // الخصومات
  String _discountType = 'fixed'; // 'fixed' أو 'percent'
  double _discountValue = 0.0;
  double _taxOrService = 0.0;

  bool _isProcessing = false;

  // Getters
  List<PosCartItem> get cartItems => List.unmodifiable(_cartItems);
  List<HeldOrder> get heldOrders => List.unmodifiable(_heldOrders);
  String get orderType => _orderType;
  String? get selectedTableNumber => _selectedTableNumber;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  String get deliveryAddress => _deliveryAddress;
  String get orderNotes => _orderNotes;
  String get discountType => _discountType;
  double get discountValue => _discountValue;
  double get taxOrService => _taxOrService;
  bool get isProcessing => _isProcessing;
  bool get isCartEmpty => _cartItems.isEmpty;
  int get totalItemCount => _cartItems.fold(0, (total, item) => total + item.quantity);

  /// المجموع الفرعي قبل الخصم
  double get subtotal {
    return _cartItems.fold(0.0, (total, item) => total + item.totalPrice);
  }

  /// قيمة الخصم الفعلية
  double get discountAmount {
    if (_discountValue <= 0) return 0.0;
    if (_discountType == 'percent') {
      return (subtotal * (_discountValue / 100)).clamp(0.0, subtotal);
    }
    return _discountValue.clamp(0.0, subtotal);
  }

  /// الإجمالي الصافي النهائي بعد الخصم وإضافة الخدمة
  double get grandTotal {
    final net = (subtotal - discountAmount) + _taxOrService;
    return net < 0 ? 0.0 : net;
  }

  // Setters & Modifiers
  void setOrderType(String type) {
    _orderType = type;
    if (type != 'dine_in') {
      _selectedTableNumber = null;
    }
    notifyListeners();
  }

  void setSelectedTable(String? tableNum) {
    _selectedTableNumber = tableNum;
    if (tableNum != null) {
      _orderType = 'dine_in';
    }
    notifyListeners();
  }

  void setCustomerInfo({String? name, String? phone, String? address, String? notes}) {
    if (name != null) _customerName = name;
    if (phone != null) _customerPhone = phone;
    if (address != null) _deliveryAddress = address;
    if (notes != null) _orderNotes = notes;
    notifyListeners();
  }

  void setDiscount(String type, double val) {
    _discountType = type;
    _discountValue = val;
    notifyListeners();
  }

  void setTaxOrService(double val) {
    _taxOrService = val;
    notifyListeners();
  }

  /// إضافة وجبة إلى سلة الكاشير
  void addToCart({
    required String mealId,
    required String name,
    required double unitPrice,
    String? selectedSize,
    List<Map<String, dynamic>> selectedAddons = const [],
    String? notes,
    String? imageUrl,
  }) {
    // توليد معرف فريد للمطابقة (إذا كان نفس الصنف بنفس الحجم والإضافات)
    final signature = '$mealId-$selectedSize-${selectedAddons.map((e) => e['name']).join(',')}';

    final existingIndex = _cartItems.indexWhere((item) {
      final itemSig = '${item.mealId}-${item.selectedSize}-${item.selectedAddons.map((e) => e['name']).join(',')}';
      return itemSig == signature;
    });

    if (existingIndex >= 0) {
      _cartItems[existingIndex].quantity += 1;
    } else {
      _cartItems.add(
        PosCartItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          mealId: mealId,
          name: name,
          unitPrice: unitPrice,
          quantity: 1,
          selectedSize: selectedSize,
          selectedAddons: selectedAddons,
          notes: notes,
          imageUrl: imageUrl,
        ),
      );
    }
    notifyListeners();
  }

  void incrementQuantity(String itemId) {
    final idx = _cartItems.indexWhere((e) => e.id == itemId);
    if (idx >= 0) {
      _cartItems[idx].quantity += 1;
      notifyListeners();
    }
  }

  void decrementQuantity(String itemId) {
    final idx = _cartItems.indexWhere((e) => e.id == itemId);
    if (idx >= 0) {
      if (_cartItems[idx].quantity > 1) {
        _cartItems[idx].quantity -= 1;
      } else {
        _cartItems.removeAt(idx);
      }
      notifyListeners();
    }
  }

  void removeItem(String itemId) {
    _cartItems.removeWhere((e) => e.id == itemId);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _discountValue = 0.0;
    _taxOrService = 0.0;
    _customerName = '';
    _customerPhone = '';
    _deliveryAddress = '';
    _orderNotes = '';
    _selectedTableNumber = null;
    notifyListeners();
  }

  /// تعليق الطلب الحالي في قائمة الانتظار المؤقتة
  bool holdCurrentOrder({String? customLabel}) {
    if (_cartItems.isEmpty) return false;
    final id = const Uuid().v4().substring(0, 6);
    final label = customLabel ??
        (_orderType == 'dine_in' && _selectedTableNumber != null
            ? 'طاولة $_selectedTableNumber'
            : 'معلق #${_heldOrders.length + 1}');

    _heldOrders.add(HeldOrder(
      id: id,
      label: label,
      heldAt: DateTime.now(),
      items: List.from(_cartItems),
      orderType: _orderType,
      tableNumber: _selectedTableNumber,
      customerName: _customerName,
      customerPhone: _customerPhone,
      deliveryAddress: _deliveryAddress,
      orderNotes: _orderNotes,
      discountType: _discountType,
      discountValue: _discountValue,
      taxOrService: _taxOrService,
    ));

    clearCart();
    notifyListeners();
    return true;
  }

  /// استرجاع طلب معلق إلى السلة النشطة
  void restoreHeldOrder(String heldId) {
    final index = _heldOrders.indexWhere((o) => o.id == heldId);
    if (index < 0) return;
    final held = _heldOrders.removeAt(index);

    _cartItems.clear();
    _cartItems.addAll(held.items);
    _orderType = held.orderType;
    _selectedTableNumber = held.tableNumber;
    _customerName = held.customerName;
    _customerPhone = held.customerPhone;
    _deliveryAddress = held.deliveryAddress;
    _orderNotes = held.orderNotes;
    _discountType = held.discountType;
    _discountValue = held.discountValue;
    _taxOrService = held.taxOrService;

    notifyListeners();
  }

  /// حذف طلب معلق نهائياً
  void removeHeldOrder(String heldId) {
    _heldOrders.removeWhere((o) => o.id == heldId);
    notifyListeners();
  }

  /// إتمام الطلب محلياً في SQLite فوراً (Local-First Transaction < 15ms)
  /// ثم جدولته للمزامنة السحابية غير المحظورة
  Future<PosOrder?> checkout({
    required String paymentMethod,
    required double amountPaid,
    String cashierName = 'كاشير رئيسي',
  }) async {
    if (_cartItems.isEmpty) return null;

    _isProcessing = true;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest_pos';
      // توليد معرف طلب فريد ومحلي
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}-${const Uuid().v4().substring(0, 4).toUpperCase()}';
      final now = DateTime.now();

      final change = (amountPaid - grandTotal) > 0 ? (amountPaid - grandTotal) : 0.0;

      final posOrder = PosOrder(
        orderId: orderId,
        restaurantId: uid,
        orderType: _orderType,
        tableNumber: _selectedTableNumber,
        customerName: _customerName.isNotEmpty ? _customerName : 'زبون مباشر',
        customerPhone: _customerPhone,
        deliveryAddress: _deliveryAddress,
        items: List.from(_cartItems),
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxOrService: _taxOrService,
        totalAmount: grandTotal,
        paymentMethod: paymentMethod,
        amountPaid: amountPaid,
        changeAmount: change,
        status: 'completed',
        createdAt: now,
        cashierName: cashierName,
      );

      // 1. الحفظ الذري الفوري في قاعدة بيانات SQLite المحلية (< 15ms)
      // يضمن أن البيع لا يتوقف أبداً حتى في حال انقطاع الإنترنت التام
      await LocalDatabaseService.instance.saveLocalOrder({
        ...posOrder.toMap(),
        'localId': orderId,
        'syncStatus': 'pending',
      });

      // 2. توثيق الخصم في سجل التدقيق التجاري إذا وُجد
      if (discountAmount > 0) {
        await AuditLogService.instance.log(
          action: AuditLogAction.discountApplied,
          targetType: 'order',
          targetId: orderId,
          beforeState: {'subtotal': subtotal},
          afterState: {'discountAmount': discountAmount, 'total': grandTotal},
          reason: 'خصم مطبق في الكاشير ($_discountType: $_discountValue)',
          customCashierName: cashierName,
        );
      }

      // 3. جدولة المزامنة السحابية غير المحظورة في الخلفية
      unawaited(PosSyncService.instance.triggerSync());

      // 4. خصم المخزون التلقائي وفحص التنبيهات
      unawaited(InventoryDeductionService.instance.processOrderDeduction(
        restaurantId: uid,
        orderItems: _cartItems.map((e) => e.toMap()).toList(),
      ));

      clearCart();
      _isProcessing = false;
      notifyListeners();
      return posOrder;
    } catch (e) {
      debugPrint('[PosProvider] Error during local POS checkout: $e');
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }
}
