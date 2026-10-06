import 'package:flutter/foundation.dart';
import '../enums/financial_enums.dart';

/// الحساب المالي الموحد في مدار (Unified Financial Account)
@immutable
class FinancialAccount {
  final String accountId;
  final String ownerId;
  final FinancialAccountType accountType;
  final int availableBalance; // Minor units (IQD)
  final int pendingBalance;
  final int heldBalance;
  final int debt;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinancialAccount({
    required this.accountId,
    required this.ownerId,
    required this.accountType,
    this.availableBalance = 0,
    this.pendingBalance = 0,
    this.heldBalance = 0,
    this.debt = 0,
    this.currency = 'IQD',
    required this.createdAt,
    required this.updatedAt,
  });

  /// إجمالي الأصول المملوكة في الحساب
  int get totalFunds => availableBalance + heldBalance;

  /// هل الرصيد المتاح يغطي المبلغ المطلوب؟
  bool hasSufficientFunds(int amount) {
    if (amount <= 0) return false;
    return availableBalance >= amount;
  }

  FinancialAccount copyWith({
    String? accountId,
    String? ownerId,
    FinancialAccountType? accountType,
    int? availableBalance,
    int? pendingBalance,
    int? heldBalance,
    int? debt,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialAccount(
      accountId: accountId ?? this.accountId,
      ownerId: ownerId ?? this.ownerId,
      accountType: accountType ?? this.accountType,
      availableBalance: availableBalance ?? this.availableBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      heldBalance: heldBalance ?? this.heldBalance,
      debt: debt ?? this.debt,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'ownerId': ownerId,
      'accountType': accountType.key,
      'availableBalance': availableBalance,
      'pendingBalance': pendingBalance,
      'heldBalance': heldBalance,
      'debt': debt,
      'currency': currency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory FinancialAccount.fromMap(Map<String, dynamic> map, String docId) {
    return FinancialAccount(
      accountId: docId,
      ownerId: map['ownerId']?.toString() ?? '',
      accountType: FinancialAccountType.fromString(map['accountType']?.toString()),
      availableBalance: (map['availableBalance'] as num?)?.toInt() ?? 0,
      pendingBalance: (map['pendingBalance'] as num?)?.toInt() ?? 0,
      heldBalance: (map['heldBalance'] as num?)?.toInt() ?? 0,
      debt: (map['debt'] as num?)?.toInt() ?? 0,
      currency: map['currency']?.toString() ?? 'IQD',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
