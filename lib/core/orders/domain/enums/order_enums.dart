/// نوع الطلب الموحد في مدار
enum OrderType {
  food('food'),
  store('store'),
  mersal('mersal');

  final String key;
  const OrderType(this.key);

  static OrderType fromString(String? val) {
    if (val == null || val.isEmpty) return OrderType.food;
    final normalized = val.trim().toLowerCase();
    for (final type in OrderType.values) {
      if (type.key == normalized) return type;
    }
    return OrderType.food;
  }
}

/// حالات دورة حياة الطلب الموحدة في مدار
enum UnifiedOrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  ready('ready'),
  assigned('assigned'),
  delivering('delivering'),
  pickedUp('picked_up'),
  completed('completed'),
  cancelled('cancelled'),
  failed('failed');

  final String key;
  const UnifiedOrderStatus(this.key);

  static UnifiedOrderStatus fromString(String? val) {
    if (val == null || val.isEmpty) return UnifiedOrderStatus.pending;
    final normalized = val.trim().toLowerCase();
    
    // Normalization for legacy alias states
    if (normalized == 'pickedup' || normalized == 'picked_up') return UnifiedOrderStatus.pickedUp;
    if (normalized == 'heading_to_customer' || normalized == 'headingtocustomer') return UnifiedOrderStatus.delivering;
    if (normalized == 'delivered' || normalized == 'done') return UnifiedOrderStatus.completed;
    if (normalized == 'canceled') return UnifiedOrderStatus.cancelled;
    if (normalized == 'in_kitchen' || normalized == 'accepted') return UnifiedOrderStatus.preparing;

    for (final status in UnifiedOrderStatus.values) {
      if (status.key == normalized) return status;
    }
    return UnifiedOrderStatus.pending;
  }
}

/// طريقة دفع الطلب
enum OrderPaymentMethod {
  wallet('wallet'),
  cash('cash'),
  online('online');

  final String key;
  const OrderPaymentMethod(this.key);

  static OrderPaymentMethod fromString(String? val) {
    if (val == null || val.isEmpty) return OrderPaymentMethod.cash;
    final normalized = val.trim().toLowerCase();
    for (final method in OrderPaymentMethod.values) {
      if (method.key == normalized) return method;
    }
    return OrderPaymentMethod.cash;
  }
}

/// حالة حجز المخزون
enum ReservationStatus {
  reserved('reserved'),
  committed('committed'),
  released('released'),
  expired('expired');

  final String key;
  const ReservationStatus(this.key);

  static ReservationStatus fromString(String? val) {
    if (val == null || val.isEmpty) return ReservationStatus.reserved;
    final normalized = val.trim().toLowerCase();
    for (final status in ReservationStatus.values) {
      if (status.key == normalized) return status;
    }
    return ReservationStatus.reserved;
  }
}
