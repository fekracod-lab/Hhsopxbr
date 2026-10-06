import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/shift_models.dart';

/// خدمة إدارة الورديات والصندوق وحساب Z-Report لكاشير مدار
class ShiftService extends ChangeNotifier {
  static final ShiftService instance = ShiftService._();
  ShiftService._();

  ShiftSession? _currentShift;
  final List<ShiftExpense> _expenses = [];

  ShiftSession? get currentShift => _currentShift;
  bool get hasActiveShift => _currentShift != null && _currentShift!.isActive;
  List<ShiftExpense> get expenses => List.unmodifiable(_expenses);

  /// تحميل آخر وردية نشطة من الذاكرة
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('active_shift_session');
      if (saved != null && saved.isNotEmpty) {
        _currentShift = ShiftSession.fromMap(jsonDecode(saved));
        notifyListeners();
      }
    } catch (_) {}
  }

  /// فتح وردية جديدة برصيد افتتاحي
  Future<void> openShift({
    required String storeId,
    required String cashierName,
    required double openingCash,
  }) async {
    final shift = ShiftSession(
      id: const Uuid().v4(),
      storeId: storeId,
      cashierName: cashierName,
      openingCash: openingCash,
      openedAt: DateTime.now(),
    );
    _currentShift = shift;
    _expenses.clear();
    await _saveCurrentShift();
    notifyListeners();
  }

  /// إضافة عملية بيع إلى إحصائيات الوردية
  Future<void> recordSale({
    required double amount,
    required String paymentMethod,
  }) async {
    if (_currentShift == null || !_currentShift!.isActive) return;

    if (paymentMethod == 'cash') {
      _currentShift!.totalCashSales += amount;
    } else {
      _currentShift!.totalCardSales += amount;
    }
    _currentShift!.transactionCount += 1;
    await _saveCurrentShift();
    notifyListeners();
  }

  /// تسجيل سند صرف / مصروف نثري من الصندوق
  Future<void> addExpense({
    required double amount,
    required String title,
    String notes = '',
  }) async {
    if (_currentShift == null || !_currentShift!.isActive) return;

    final expense = ShiftExpense(
      id: const Uuid().v4(),
      shiftId: _currentShift!.id,
      amount: amount,
      title: title,
      notes: notes,
      createdAt: DateTime.now(),
    );
    _expenses.add(expense);
    _currentShift!.totalExpenses += amount;
    await _saveCurrentShift();
    notifyListeners();
  }

  /// إغلاق الوردية وجرد الصندوق وحساب العجز أو الزيادة
  Future<ShiftSession?> closeShift(double closingCash) async {
    if (_currentShift == null) return null;

    _currentShift!.closingCash = closingCash;
    _currentShift!.closedAt = DateTime.now();
    _currentShift!.status = 'closed';

    final closed = _currentShift;
    _currentShift = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_shift_session');

    notifyListeners();
    return closed;
  }

  Future<void> _saveCurrentShift() async {
    if (_currentShift == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_shift_session', jsonEncode(_currentShift!.toMap()));
    } catch (_) {}
  }
}
