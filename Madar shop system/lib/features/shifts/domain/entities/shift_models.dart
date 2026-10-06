/// نموذج وردية الكاشير وحساب الصندوق (Cashier Shift Entity)
class ShiftSession {
  final String id;
  final String storeId;
  final String cashierName;
  final double openingCash;
  double closingCash;
  double totalCashSales;
  double totalCardSales;
  double totalExpenses;
  int transactionCount;
  final DateTime openedAt;
  DateTime? closedAt;
  String status; // 'active', 'closed'

  ShiftSession({
    required this.id,
    required this.storeId,
    required this.cashierName,
    required this.openingCash,
    this.closingCash = 0.0,
    this.totalCashSales = 0.0,
    this.totalCardSales = 0.0,
    this.totalExpenses = 0.0,
    this.transactionCount = 0,
    required this.openedAt,
    this.closedAt,
    this.status = 'active',
  });

  bool get isActive => status == 'active';
  double get totalSales => totalCashSales + totalCardSales;
  double get expectedCash => openingCash + totalCashSales - totalExpenses;
  double get cashDifference => closingCash - expectedCash; // موجب = زيادة، سالب = عجز

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'cashierName': cashierName,
      'openingCash': openingCash,
      'closingCash': closingCash,
      'totalCashSales': totalCashSales,
      'totalCardSales': totalCardSales,
      'totalExpenses': totalExpenses,
      'transactionCount': transactionCount,
      'openedAt': openedAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory ShiftSession.fromMap(Map<String, dynamic> map) {
    return ShiftSession(
      id: (map['id'] ?? '').toString(),
      storeId: (map['storeId'] ?? '').toString(),
      cashierName: (map['cashierName'] ?? 'كاشير').toString(),
      openingCash: (map['openingCash'] as num?)?.toDouble() ?? 0.0,
      closingCash: (map['closingCash'] as num?)?.toDouble() ?? 0.0,
      totalCashSales: (map['totalCashSales'] as num?)?.toDouble() ?? 0.0,
      totalCardSales: (map['totalCardSales'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      openedAt: DateTime.tryParse(map['openedAt']?.toString() ?? '') ?? DateTime.now(),
      closedAt: map['closedAt'] != null ? DateTime.tryParse(map['closedAt'].toString()) : null,
      status: (map['status'] ?? 'active').toString(),
    );
  }
}

/// سند صرف / مصروف نثري من الصندوق
class ShiftExpense {
  final String id;
  final String shiftId;
  final double amount;
  final String title;
  final String notes;
  final DateTime createdAt;

  const ShiftExpense({
    required this.id,
    required this.shiftId,
    required this.amount,
    required this.title,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shiftId': shiftId,
      'amount': amount,
      'title': title,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
