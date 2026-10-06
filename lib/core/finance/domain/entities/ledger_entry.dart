import 'package:flutter/foundation.dart';
import '../enums/financial_enums.dart';

/// قيد دفتر الأستاذ غير القابل للتعديل (Immutable Double-Entry Ledger Record)
@immutable
class LedgerEntry {
  final String id;
  final String transactionId;
  final String accountId;
  final String ownerId;
  final FinancialAccountType accountType;
  final LedgerEntryType entryType; // Debit or Credit
  final int amount; // Positive integer in IQD minor units
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  const LedgerEntry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.ownerId,
    required this.accountType,
    required this.entryType,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.metadata = const {},
  });

  bool get isDebit => entryType == LedgerEntryType.debit;
  bool get isCredit => entryType == LedgerEntryType.credit;

  LedgerEntry copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    String? ownerId,
    FinancialAccountType? accountType,
    LedgerEntryType? entryType,
    int? amount,
    String? description,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      ownerId: ownerId ?? this.ownerId,
      accountType: accountType ?? this.accountType,
      entryType: entryType ?? this.entryType,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transactionId': transactionId,
      'accountId': accountId,
      'ownerId': ownerId,
      'accountType': accountType.key,
      'entryType': entryType.key,
      'amount': amount,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map, String docId) {
    return LedgerEntry(
      id: docId,
      transactionId: map['transactionId']?.toString() ?? '',
      accountId: map['accountId']?.toString() ?? '',
      ownerId: map['ownerId']?.toString() ?? '',
      accountType: FinancialAccountType.fromString(map['accountType']?.toString()),
      entryType: LedgerEntryType.fromString(map['entryType']?.toString()),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      description: map['description']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      metadata: map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : {},
    );
  }
}
