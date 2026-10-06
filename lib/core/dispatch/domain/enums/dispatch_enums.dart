/// نوع التوزيع والخدمة في مدار
enum DispatchType {
  food('food'),
  store('store'),
  mersal('mersal'),
  taxi('taxi');

  final String key;
  const DispatchType(this.key);

  static DispatchType fromString(String? val) {
    if (val == null || val.isEmpty) return DispatchType.food;
    final normalized = val.trim().toLowerCase();
    for (final type in DispatchType.values) {
      if (type.key == normalized) return type;
    }
    return DispatchType.food;
  }
}

/// حالة جلسة التوزيع الموحدة
enum DispatchStatus {
  created('created'),
  searching('searching'),
  offering('offering'),
  accepted('accepted'),
  assigned('assigned'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String key;
  const DispatchStatus(this.key);

  static DispatchStatus fromString(String? val) {
    if (val == null || val.isEmpty) return DispatchStatus.created;
    final normalized = val.trim().toLowerCase();
    for (final s in DispatchStatus.values) {
      if (s.key == normalized) return s;
    }
    return DispatchStatus.created;
  }
}

/// حالة عرض الطلب المقدم للسائق
enum DispatchOfferStatus {
  created('created'),
  sent('sent'),
  viewed('viewed'),
  accepted('accepted'),
  rejected('rejected'),
  expired('expired'),
  cancelled('cancelled');

  final String key;
  const DispatchOfferStatus(this.key);

  static DispatchOfferStatus fromString(String? val) {
    if (val == null || val.isEmpty) return DispatchOfferStatus.created;
    final normalized = val.trim().toLowerCase();
    for (final s in DispatchOfferStatus.values) {
      if (s.key == normalized) return s;
    }
    return DispatchOfferStatus.created;
  }
}

/// حالة أهلية السائق لاستقبال الطلب
enum DriverEligibilityStatus {
  eligible('eligible'),
  offline('offline'),
  unapproved('unapproved'),
  suspended('suspended'),
  busy('busy'),
  staleGps('stale_gps'),
  invalidLocation('invalid_location'),
  incompatibleService('incompatible_service'),
  outOfRange('out_of_range');

  final String key;
  const DriverEligibilityStatus(this.key);

  bool get isEligible => this == DriverEligibilityStatus.eligible;
}

/// أسباب تعذر أو فشل التوزيع
enum DispatchFailureReason {
  none('none'),
  noDriversAvailable('no_drivers_available'),
  allDriversRejected('all_drivers_rejected'),
  allOffersExpired('all_offers_expired'),
  orderAlreadyAssigned('order_already_assigned'),
  orderCancelled('order_cancelled'),
  sessionTimeout('session_timeout'),
  networkError('network_error');

  final String key;
  const DispatchFailureReason(this.key);

  static DispatchFailureReason fromString(String? val) {
    if (val == null || val.isEmpty) return DispatchFailureReason.none;
    final normalized = val.trim().toLowerCase();
    for (final r in DispatchFailureReason.values) {
      if (r.key == normalized) return r;
    }
    return DispatchFailureReason.none;
  }
}
