// كيان جلسة العمل وعقد نبضات القلب (MADAR SHOP Session & Heartbeat Lease Entity)
// Pure Dart — Zero UI Dependencies

enum ShopSessionStatus {
  active,     // الجلسة نشطة وعقد النبض سليم
  stale,      // تأخر نبض القلب عن الحد المتوقع
  expired,    // انتهت مهلة الجلسة القانونية
  terminated; // تم إنهاء الجلسة عمداً بتسجيل الخروج

  static ShopSessionStatus fromString(String? val) {
    if (val == null) return ShopSessionStatus.active;
    switch (val.trim().toLowerCase()) {
      case 'active':
        return ShopSessionStatus.active;
      case 'stale':
        return ShopSessionStatus.stale;
      case 'expired':
        return ShopSessionStatus.expired;
      case 'terminated':
        return ShopSessionStatus.terminated;
      default:
        return ShopSessionStatus.active;
    }
  }
}

class ShopSession {
  final String sessionId;
  final String installationId; // معرف تنصيب التطبيق المثبت على جهاز الكاشير
  final String terminalId;     // معرف محطة نقطة البيع مثل "POS-WIN-01"
  final String userId;
  final String businessId;
  final String activeBranchId;
  final String? activeShiftId;
  final DateTime startedAt;
  final DateTime lastHeartbeatAt;
  final DateTime expiresAt;
  final ShopSessionStatus status;
  final Map<String, dynamic> clientDeviceInfo;

  const ShopSession({
    required this.sessionId,
    required this.installationId,
    required this.terminalId,
    required this.userId,
    required this.businessId,
    required this.activeBranchId,
    this.activeShiftId,
    required this.startedAt,
    required this.lastHeartbeatAt,
    required this.expiresAt,
    this.status = ShopSessionStatus.active,
    this.clientDeviceInfo = const {},
  });

  /// هل الجلسة منتهية الصلاحية
  bool get isExpired {
    if (status == ShopSessionStatus.expired || status == ShopSessionStatus.terminated) {
      return true;
    }
    return DateTime.now().isAfter(expiresAt);
  }

  /// هل نبضات القلب متأخرة عن فترة السماح (مثلاً 90 ثانية)
  bool isHeartbeatOverdue({
    Duration tolerance = const Duration(seconds: 90),
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return current.difference(lastHeartbeatAt) > tolerance;
  }

  /// هل نبضات القلب راكدة أو متأخرة (Stale Detection)
  bool isHeartbeatStale({
    Duration tolerance = const Duration(seconds: 90),
    DateTime? now,
  }) => isHeartbeatOverdue(tolerance: tolerance, now: now);

  /// تسجيل نبضة قلب جديدة وتمديد عقد الجلسة (Heartbeat Lease Extension)
  ShopSession recordHeartbeat({
    DateTime? heartbeatTime,
    Duration leaseExtension = const Duration(minutes: 5),
  }) {
    final now = heartbeatTime ?? DateTime.now();
    return copyWith(
      lastHeartbeatAt: now,
      expiresAt: now.add(leaseExtension),
      status: ShopSessionStatus.active,
    );
  }

  ShopSession copyWith({
    String? sessionId,
    String? installationId,
    String? terminalId,
    String? userId,
    String? businessId,
    String? activeBranchId,
    String? activeShiftId,
    DateTime? startedAt,
    DateTime? lastHeartbeatAt,
    DateTime? expiresAt,
    ShopSessionStatus? status,
    Map<String, dynamic>? clientDeviceInfo,
  }) {
    return ShopSession(
      sessionId: sessionId ?? this.sessionId,
      installationId: installationId ?? this.installationId,
      terminalId: terminalId ?? this.terminalId,
      userId: userId ?? this.userId,
      businessId: businessId ?? this.businessId,
      activeBranchId: activeBranchId ?? this.activeBranchId,
      activeShiftId: activeShiftId ?? this.activeShiftId,
      startedAt: startedAt ?? this.startedAt,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      clientDeviceInfo: clientDeviceInfo ?? this.clientDeviceInfo,
    );
  }
}
