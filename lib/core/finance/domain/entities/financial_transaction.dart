import 'package:flutter/foundation.dart';
import '../enums/financial_enums.dart';
import 'ledger_entry.dart';

/// المعاملة المالية الموثقة متوازنة القيود (Balanced Financial Transaction)
@immutable
class FinancialTransaction {
  final String id;
  final String idempotencyKey;
  final TransactionCategory category;
  final FinancialTransactionStatus status;
  final String? orderId;
  final String? orderSource;
  final List<LedgerEntry> entries;
  final int totalAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? failureReason;
  final Map<String, dynamic> metadata;

  const FinancialTransaction({
    required this.id,
    required this.idempotencyKey,
    required this.category,
    this.status = FinancialTransactionStatus.pending,
    this.orderId,
    this.orderSource,
    required this.entries,
    required this.totalAmount,
    this.currency = 'IQD',
    required this.createdAt,
    this.completedAt,
    this.failureReason,
    this.metadata = const {},
  });

  /// مجموع المبالغ المدينة
  int get totalDebits => entries
      .where((e) => e.isDebit)
      .fold<int>(0, (sum, e) => sum + e.amount);

  /// مجموع المبالغ الدائنة
  int get totalCredits => entries
      .where((e) => e.isCredit)
      .fold<int>(0, (sum, e) => sum + e.amount);

  /// هل المعاملة متوازنة محاسبياً تماماً؟
  bool get isBalanced => totalDebits == totalCredits && totalDebits > 0;

  FinancialTransaction copyWith({
    String? id,
    String? idempotencyKey,
    TransactionCategory? category,
    FinancialTransactionStatus? status,
    String? orderId,
    String? orderSource,
    List<LedgerEntry>? entries,
    int? totalAmount,
    String? currency,
    DateTime? createdAt,
    DateTime? completedAt,
    String? failureReason,
    Map<String, dynamic>? metadata,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      category: category ?? this.category,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      orderSource: orderSource ?? this.orderSource,
      entries: entries ?? this.entries,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      failureReason: failureReason ?? this.failureReason,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idempotencyKey': idempotencyKey,
      'category': category.key,
      'status': status.key,
      'orderId': orderId,
      'orderSource': orderSource,
      'entries': entries.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'failureReason': failureReason,
      'metadata': metadata,
    };
  }

  factory FinancialTransaction.fromMap(Map<String, dynamic> map, String docId) {
    final rawEntries = map['entries'] as List? ?? [];
    final entries = rawEntries
        .map((e) => LedgerEntry.fromMap(Map<String, dynamic>.from(e as Map), e['id']?.toString() ?? ''))
        .toList();

    return FinancialTransaction(
      id: docId,
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      category: TransactionCategory.fromString(map['category']?.toString()),
      status: FinancialTransactionStatus.fromString(map['status']?.toString()),
      orderId: map['orderId']?.toString(),
      orderSource: map['orderSource']?.toString(),
      entries: entries,
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      currency: map['currency']?.toString() ?? 'IQD',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
      failureReason: map['failureReason']?.toString(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
