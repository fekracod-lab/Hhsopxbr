// أنواع حركات المخزون المعيارية (MADAR SHOP Inventory Movement Type Enum)
// Pure Dart — Zero UI Dependencies

enum InventoryMovementType {
  sale,               // بيع (صرف مخزني)
  purchase,           // شراء وتوريد بضاعة (إدخال مخزني)
  customerReturn,     // إرجاع مبيعات من الزبون
  supplierReturn,     // إرجاع مشتريات للمورد (صرف مخزني)
  adjustmentIn,       // تسوية جردية بالزيادة
  adjustmentOut,      // تسوية جردية بالنقصان
  transferOut,        // تحويل صادر إلى فرع آخر
  transferIn,         // تحويل وارد من فرع آخر
  reservation,        // حجز بضاعة (للطلبات أو الماركت بليس)
  releaseReservation, // فك الحجز وإعادة الإتاحة
  damage,             // تلف بضاعة
  expired,            // انتهاء صلاحية
  initialBalance,     // رصيد افتتاحي
  correction;         // تصحيح قيد

  static InventoryMovementType fromString(String? val) {
    if (val == null) return InventoryMovementType.sale;
    switch (val.trim().toLowerCase()) {
      case 'purchase':
        return InventoryMovementType.purchase;
      case 'return':
      case 'customer_return':
        return InventoryMovementType.customerReturn;
      case 'supplier_return':
        return InventoryMovementType.supplierReturn;
      case 'adjustment_in':
      case 'adjustmentin':
        return InventoryMovementType.adjustmentIn;
      case 'adjustment_out':
      case 'adjustmentout':
        return InventoryMovementType.adjustmentOut;
      case 'transfer_out':
      case 'transferout':
        return InventoryMovementType.transferOut;
      case 'transfer_in':
      case 'transferin':
        return InventoryMovementType.transferIn;
      case 'reservation':
        return InventoryMovementType.reservation;
      case 'release_reservation':
      case 'releasereservation':
        return InventoryMovementType.releaseReservation;
      case 'damage':
        return InventoryMovementType.damage;
      case 'expired':
        return InventoryMovementType.expired;
      case 'initial_balance':
      case 'initialbalance':
        return InventoryMovementType.initialBalance;
      case 'correction':
        return InventoryMovementType.correction;
      case 'sale':
      default:
        return InventoryMovementType.sale;
    }
  }

  String toDbString() {
    switch (this) {
      case InventoryMovementType.sale:
        return 'sale';
      case InventoryMovementType.purchase:
        return 'purchase';
      case InventoryMovementType.customerReturn:
        return 'customer_return';
      case InventoryMovementType.supplierReturn:
        return 'supplier_return';
      case InventoryMovementType.adjustmentIn:
        return 'adjustment_in';
      case InventoryMovementType.adjustmentOut:
        return 'adjustment_out';
      case InventoryMovementType.transferOut:
        return 'transfer_out';
      case InventoryMovementType.transferIn:
        return 'transfer_in';
      case InventoryMovementType.reservation:
        return 'reservation';
      case InventoryMovementType.releaseReservation:
        return 'release_reservation';
      case InventoryMovementType.damage:
        return 'damage';
      case InventoryMovementType.expired:
        return 'expired';
      case InventoryMovementType.initialBalance:
        return 'initial_balance';
      case InventoryMovementType.correction:
        return 'correction';
    }
  }

  String get displayNameAr {
    switch (this) {
      case InventoryMovementType.sale:
        return 'بيع مبيعات';
      case InventoryMovementType.purchase:
        return 'توريد شراء';
      case InventoryMovementType.customerReturn:
        return 'مرتجع مبيعات';
      case InventoryMovementType.supplierReturn:
        return 'مرتجع لمورد';
      case InventoryMovementType.adjustmentIn:
        return 'تسوية جردية (إدخال)';
      case InventoryMovementType.adjustmentOut:
        return 'تسوية جردية (إخراج)';
      case InventoryMovementType.transferOut:
        return 'تحويل صادر لفرع';
      case InventoryMovementType.transferIn:
        return 'تحويل وارد من فرع';
      case InventoryMovementType.reservation:
        return 'حجز بضاعة';
      case InventoryMovementType.releaseReservation:
        return 'فك حجز بضاعة';
      case InventoryMovementType.damage:
        return 'إتلاف بضاعة';
      case InventoryMovementType.expired:
        return 'انتهاء صلاحية';
      case InventoryMovementType.initialBalance:
        return 'رصيد افتتاحي';
      case InventoryMovementType.correction:
        return 'تصحيح قيد';
    }
  }

  /// هل تؤثر الحركة على الرصيد الفعلي في اليد (OnHand)
  bool get affectsOnHand {
    switch (this) {
      case InventoryMovementType.reservation:
      case InventoryMovementType.releaseReservation:
        return false;
      default:
        return true;
    }
  }

  /// هل الحركة إضافة للمخزون الفعلي (OnHand)
  bool get isPositiveOnHandDelta {
    switch (this) {
      case InventoryMovementType.purchase:
      case InventoryMovementType.customerReturn:
      case InventoryMovementType.adjustmentIn:
      case InventoryMovementType.transferIn:
      case InventoryMovementType.initialBalance:
        return true;
      default:
        return false;
    }
  }
}
