// نتائج عمليات المرتجعات واسترداد الأموال (MADAR SHOP Returns Operation Results)
// Pure Dart — Zero UI Dependencies

import '../../../domain/returns/entities/refund.dart';
import '../../../domain/returns/entities/return_order.dart';
import '../../../domain/returns/entities/supplier_credit_note.dart';
import '../../../domain/returns/entities/supplier_return.dart';

class ReturnOrderOperationResult {
  final bool isSuccess;
  final ReturnOrder? _order;
  final String? message;

  const ReturnOrderOperationResult({
    required this.isSuccess,
    ReturnOrder? order,
    this.message,
  }) : _order = order;

  ReturnOrder? get orderOrNull => _order;
  ReturnOrder get order => _order!;
}

class RefundOperationResult {
  final bool isSuccess;
  final Refund? _refund;
  final ReturnOrder? _order;
  final String? message;

  const RefundOperationResult({
    required this.isSuccess,
    Refund? refund,
    ReturnOrder? order,
    this.message,
  })  : _refund = refund,
        _order = order;

  Refund? get refundOrNull => _refund;
  Refund get refund => _refund!;

  ReturnOrder? get orderOrNull => _order;
  ReturnOrder get order => _order!;
}

class SupplierReturnOperationResult {
  final bool isSuccess;
  final SupplierReturn? _supplierReturn;
  final SupplierCreditNote? _creditNote;
  final String? message;

  const SupplierReturnOperationResult({
    required this.isSuccess,
    SupplierReturn? supplierReturn,
    SupplierCreditNote? creditNote,
    this.message,
  })  : _supplierReturn = supplierReturn,
        _creditNote = creditNote;

  SupplierReturn? get supplierReturnOrNull => _supplierReturn;
  SupplierReturn get supplierReturn => _supplierReturn!;

  SupplierCreditNote? get creditNoteOrNull => _creditNote;
  SupplierCreditNote get creditNote => _creditNote!;
}
