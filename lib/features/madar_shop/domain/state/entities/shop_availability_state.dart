// كيان حالة توفر المتجر والحمل التشغيلي (MADAR SHOP Availability & Operational Load)
// Pure Dart — Zero UI Dependencies

/// حالات التوفر الأساسية للمتجر (Availability Dimension)
enum ShopAvailability {
  open,        // المتجر مفتوح ويستقبل الطلبات
  closed,      // المتجر مغلق بقرار يدوي أو جدول زمني
  paused,      // إيقاف مؤقت يدوي (صلاة / استراحة)
  autoClosed;  // إغلاق آلي بسبب انقطاع الجلسة أو نبضات القلب (Lease Expiry)

  static ShopAvailability fromString(String? val) {
    if (val == null) return ShopAvailability.closed;
    switch (val.trim().toLowerCase()) {
      case 'open':
        return ShopAvailability.open;
      case 'closed':
        return ShopAvailability.closed;
      case 'paused':
        return ShopAvailability.paused;
      case 'auto_closed':
      case 'autoclosed':
        return ShopAvailability.autoClosed;
      default:
        return ShopAvailability.closed;
    }
  }

  String toDbString() {
    switch (this) {
      case ShopAvailability.open:
        return 'open';
      case ShopAvailability.closed:
        return 'closed';
      case ShopAvailability.paused:
        return 'paused';
      case ShopAvailability.autoClosed:
        return 'auto_closed';
    }
  }

  String get displayNameAr {
    switch (this) {
      case ShopAvailability.open:
        return 'مفتوح';
      case ShopAvailability.closed:
        return 'مغلق';
      case ShopAvailability.paused:
        return 'إيقاف مؤقت';
      case ShopAvailability.autoClosed:
        return 'إغلاق تلقائي (انقطاع الاتصال)';
    }
  }
}

/// مستوى الحمل والضغط التشغيلي للمتجر (Operational Load Dimension - Orthogonal)
enum ShopOperationalLoad {
  normal,  // ضغط طبيعي وسلس
  busy,    // ضغط طلبات متوسط (+15 دقيقة وقت تحضير)
  high;    // ذروة وضغط استثنائي مكثف (+30 دقيقة وقت تحضير)

  static ShopOperationalLoad fromString(String? val) {
    if (val == null) return ShopOperationalLoad.normal;
    switch (val.trim().toLowerCase()) {
      case 'normal':
        return ShopOperationalLoad.normal;
      case 'busy':
      case 'medium':
        return ShopOperationalLoad.busy;
      case 'high':
      case 'surge':
      case 'peak':
        return ShopOperationalLoad.high;
      default:
        return ShopOperationalLoad.normal;
    }
  }

  String toDbString() {
    switch (this) {
      case ShopOperationalLoad.normal:
        return 'normal';
      case ShopOperationalLoad.busy:
        return 'busy';
      case ShopOperationalLoad.high:
        return 'high';
    }
  }

  String get displayNameAr {
    switch (this) {
      case ShopOperationalLoad.normal:
        return 'طبيعي';
      case ShopOperationalLoad.busy:
        return 'مزدحم';
      case ShopOperationalLoad.high:
        return 'ذروة وضغط عالي';
    }
  }
}

class ShopAvailabilityState {
  final String branchId;
  final ShopAvailability availability;
  final ShopOperationalLoad operationalLoad;
  final String? pauseReason;
  final DateTime? pauseUntil;
  final DateTime? lastHeartbeatAt;
  final bool autoAcceptMarketplaceOrders;
  final int basePrepTimeMinutes;
  final int busyLoadBufferMinutes;
  final int highLoadBufferMinutes;
  final bool acceptingCash;
  final bool acceptingOnlinePayment;
  final DateTime updatedAt;
  final String updatedByUserId;

  const ShopAvailabilityState({
    required this.branchId,
    required this.availability,
    this.operationalLoad = ShopOperationalLoad.normal,
    this.pauseReason,
    this.pauseUntil,
    this.lastHeartbeatAt,
    this.autoAcceptMarketplaceOrders = false,
    this.basePrepTimeMinutes = 20,
    this.busyLoadBufferMinutes = 15,
    this.highLoadBufferMinutes = 30,
    this.acceptingCash = true,
    this.acceptingOnlinePayment = true,
    required this.updatedAt,
    required this.updatedByUserId,
  });

  /// الحساب الفعلي للوقت المقدر لتجهيز الطلب بناءً على الحمل التشغيلي المستقل
  int get effectivePrepTimeMinutes {
    switch (operationalLoad) {
      case ShopOperationalLoad.normal:
        return basePrepTimeMinutes;
      case ShopOperationalLoad.busy:
        return basePrepTimeMinutes + busyLoadBufferMinutes;
      case ShopOperationalLoad.high:
        return basePrepTimeMinutes + highLoadBufferMinutes;
    }
  }

  /// هل المتجر جاهز ومتاح لاستقبال طلبات الزبائن حالياً
  bool get isReadyToReceiveOrders {
    if (availability == ShopAvailability.closed ||
        availability == ShopAvailability.autoClosed) {
      return false;
    }
    if (availability == ShopAvailability.paused) {
      if (pauseUntil != null && DateTime.now().isAfter(pauseUntil!)) {
        return true; // انتهت فترة الإيقاف المؤقت تلقائياً
      }
      return false;
    }
    return true;
  }

  /// التحقق مما إذا كان عقد الجلسة (Heartbeat Lease) منتهياً ويستوجب Auto-Closed
  bool isHeartbeatStale({
    Duration leaseTimeout = const Duration(minutes: 3),
    DateTime? now,
  }) {
    if (availability != ShopAvailability.open) return false;
    if (lastHeartbeatAt == null) return true;
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(lastHeartbeatAt!) > leaseTimeout;
  }

  ShopAvailabilityState copyWith({
    String? branchId,
    ShopAvailability? availability,
    ShopOperationalLoad? operationalLoad,
    String? pauseReason,
    DateTime? pauseUntil,
    DateTime? lastHeartbeatAt,
    bool? autoAcceptMarketplaceOrders,
    int? basePrepTimeMinutes,
    int? busyLoadBufferMinutes,
    int? highLoadBufferMinutes,
    bool? acceptingCash,
    bool? acceptingOnlinePayment,
    DateTime? updatedAt,
    String? updatedByUserId,
  }) {
    return ShopAvailabilityState(
      branchId: branchId ?? this.branchId,
      availability: availability ?? this.availability,
      operationalLoad: operationalLoad ?? this.operationalLoad,
      pauseReason: pauseReason ?? this.pauseReason,
      pauseUntil: pauseUntil ?? this.pauseUntil,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      autoAcceptMarketplaceOrders:
          autoAcceptMarketplaceOrders ?? this.autoAcceptMarketplaceOrders,
      basePrepTimeMinutes: basePrepTimeMinutes ?? this.basePrepTimeMinutes,
      busyLoadBufferMinutes:
          busyLoadBufferMinutes ?? this.busyLoadBufferMinutes,
      highLoadBufferMinutes:
          highLoadBufferMinutes ?? this.highLoadBufferMinutes,
      acceptingCash: acceptingCash ?? this.acceptingCash,
      acceptingOnlinePayment:
          acceptingOnlinePayment ?? this.acceptingOnlinePayment,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUserId: updatedByUserId ?? this.updatedByUserId,
    );
  }
}
