// حاسبة وخدمة قواعد نطاق إدارة رحلات التكسي (Taxi Ride Management Calculator)
// Clean Architecture — Pure Dart Domain Service (Deterministic & Zero UI/Firebase)

import '../entities/ride_management_models.dart';

class RideManagementCalculator {
  const RideManagementCalculator._();

  /// حساب مؤشرات الأداء الحية للأسطول والرحلات (Live KPI Metrics)
  static RideManagementKpiMetrics calculateKpiMetrics({
    required List<TaxiDriverAdminEntity> drivers,
    required List<RideAdminEntity> rides,
    DateTime? referenceTime,
  }) {
    final now = referenceTime ?? DateTime.now();

    // 1. الكباتن المتصلون
    final onlineCount = drivers.where((d) => d.isOnline).length;

    // 2. الرحلات قيد التنفيذ (accepted, arrived, in_progress)
    final activeCount = rides.where((r) {
      return r.status == RideStatusEnum.accepted ||
          r.status == RideStatusEnum.arrived ||
          r.status == RideStatusEnum.in_progress;
    }).length;

    // 3. الطلبات المعلقة بانتظار كابتن
    final searchingCount = rides.where((r) => r.status == RideStatusEnum.searching).length;

    // 4. رحلات اليوم المكتملة
    final todayCompletedCount = rides.where((r) {
      if (r.status != RideStatusEnum.completed) return false;
      final t = r.completedAt ?? r.createdAt;
      if (t == null) return false;
      return isSameDay(t, now);
    }).length;

    return RideManagementKpiMetrics(
      onlineDriversCount: onlineCount,
      activeTripsCount: activeCount,
      searchingTripsCount: searchingCount,
      todayCompletedTripsCount: todayCompletedCount,
    );
  }

  /// حساب الإحصائيات المالية والتاريخية للرحلات المكتملة
  static RideHistoryAnalyticsMetrics calculateHistoryAnalytics(
    List<RideAdminEntity> completedRides, {
    double commissionRate = 0.10, // 10% منصة مدار افتراضياً
  }) {
    if (completedRides.isEmpty) {
      return const RideHistoryAnalyticsMetrics();
    }

    double totalGmv = 0.0;
    int validCount = 0;

    for (final r in completedRides) {
      if (r.status == RideStatusEnum.completed || r.fare > 0) {
        totalGmv += r.fare;
        validCount++;
      }
    }

    final totalCommission = totalGmv * commissionRate;
    final averageFare = validCount > 0 ? (totalGmv / validCount) : 0.0;

    return RideHistoryAnalyticsMetrics(
      totalCompletedRides: validCount,
      totalGmv: totalGmv,
      totalPlatformCommission: totalCommission,
      averageFare: averageFare,
    );
  }

  /// تصفية وفلترة الرحلات الحية والتاريخية
  static List<RideAdminEntity> filterRides({
    required List<RideAdminEntity> rides,
    required String statusFilter,
    required String query,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final parsedStatus = RideStatusEnum.fromString(statusFilter);

    return rides.where((ride) {
      // 1. تصفية الحالة
      if (parsedStatus != RideStatusEnum.all && parsedStatus != RideStatusEnum.unknown) {
        if (ride.status != parsedStatus) return false;
      }

      // 2. البحث النصي
      if (cleanQuery.isEmpty) return true;

      final pName = ride.passengerName.toLowerCase();
      final pPhone = ride.passengerPhone.toLowerCase();
      final dName = (ride.driverName ?? '').toLowerCase();
      final dPhone = (ride.driverPhone ?? '').toLowerCase();
      final pickup = ride.pickupAddress.toLowerCase();
      final dropoff = ride.dropoffAddress.toLowerCase();
      final id = ride.id.toLowerCase();

      return pName.contains(cleanQuery) ||
          pPhone.contains(cleanQuery) ||
          dName.contains(cleanQuery) ||
          dPhone.contains(cleanQuery) ||
          pickup.contains(cleanQuery) ||
          dropoff.contains(cleanQuery) ||
          id.contains(cleanQuery);
    }).toList();
  }

  /// تصفية وفلترة قائمة الكباتن والمحافظ
  static List<TaxiDriverAdminEntity> filterDrivers({
    required List<TaxiDriverAdminEntity> drivers,
    required String debtFilter, // 'all', 'blocked', 'exception', 'active'
    required String query,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final filter = debtFilter.trim().toLowerCase();

    return drivers.where((d) {
      // 1. تصفية الديون والحالة
      if (filter == 'blocked') {
        if (!d.isBlockedByDebt) return false;
      } else if (filter == 'exception') {
        if (!d.allowCommissionException) return false;
      } else if (filter == 'active') {
        if (d.status.toLowerCase() != 'active') return false;
      }

      // 2. البحث النصي
      if (cleanQuery.isEmpty) return true;

      final name = d.name.toLowerCase();
      final phone = d.phone.toLowerCase();
      final car = d.carModel.toLowerCase();
      final carNo = d.carNumber.toLowerCase();
      final id = d.id.toLowerCase();

      return name.contains(cleanQuery) ||
          phone.contains(cleanQuery) ||
          car.contains(cleanQuery) ||
          carNo.contains(cleanQuery) ||
          id.contains(cleanQuery);
    }).toList();
  }

  /// تصفية وفلترة تقييمات الكباتن
  static List<DriverReviewAdminEntity> filterReviews({
    required List<DriverReviewAdminEntity> reviews,
    required String starFilter, // 'all', '5_star', '4_star', 'low'
    required String query,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final filter = starFilter.trim().toLowerCase();

    return reviews.where((rev) {
      // 1. تصفية النجوم
      if (filter == '5_star') {
        if (rev.rating < 4.8) return false;
      } else if (filter == '4_star') {
        if (rev.rating < 3.8 || rev.rating >= 4.8) return false;
      } else if (filter == 'low') {
        if (rev.rating >= 3.8) return false;
      }

      // 2. البحث النصي
      if (cleanQuery.isEmpty) return true;

      final dName = rev.driverName.toLowerCase();
      final cName = rev.customerName.toLowerCase();
      final comment = rev.comment.toLowerCase();
      final id = rev.id.toLowerCase();

      return dName.contains(cleanQuery) ||
          cName.contains(cleanQuery) ||
          comment.contains(cleanQuery) ||
          id.contains(cleanQuery);
    }).toList();
  }

  /// تنسيق العملة العراقية بشكل موحد (د.ع)
  static String formatIraqiCurrency(num amount) {
    final integerPart = amount.toInt();
    final str = integerPart.toString();
    final buffer = StringBuffer();
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }

    return '${buffer.toString().split('').reversed.join('')} د.ع';
  }

  /// التحقق من تطابق اليوم
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
