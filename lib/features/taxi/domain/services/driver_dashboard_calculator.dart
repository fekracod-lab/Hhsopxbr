import '../entities/driver_dashboard_models.dart';

/// محرك حسابات وفلترة لوحة تحكم الكابتن المجرد (Pure Dart Driver Dashboard Calculator)
class DriverDashboardCalculator {
  const DriverDashboardCalculator._();

  /// حساب معدل الإلغاء كنسبة مئوية منسقة
  static String calculateCancellationRate({
    required int totalTrips,
    required int cancelledTrips,
  }) {
    if (totalTrips <= 0) return '0%';
    final rate = (cancelledTrips / totalTrips) * 100;
    return '${rate.toStringAsFixed(1)}%';
  }

  /// فلترة الطلبات المعلقة الطازجة وغير المرفوضة
  static List<RideRequestEntity> filterFreshPendingRequests(
    List<RideRequestEntity> requests, {
    Set<String> locallyRejectedIds = const {},
    String? currentDriverUid,
    DateTime? now,
    Duration maxAge = const Duration(seconds: 30),
  }) {
    final currentTime = now ?? DateTime.now();

    return requests.where((req) {
      // 1. استبعاد الطلبات المرفوضة محلياً في هذه الجلسة
      if (locallyRejectedIds.contains(req.id)) return false;

      // 2. استبعاد إذا كان معرّف الكابتن مسجلاً في قائمة rejectedDrivers
      if (currentDriverUid != null && req.rejectedDrivers.contains(currentDriverUid)) {
        return false;
      }

      // 3. التحقق من حداثة الطلب (أقل من 30 ثانية)
      if (req.createdAt != null) {
        final age = currentTime.difference(req.createdAt!);
        if (age > maxAge) return false;
      }

      return true;
    }).toList();
  }

  /// فلترة ميزة "درب الرجعة" (MyWay) حسب وجهة الكابتن
  static List<RideRequestEntity> filterMyWayRequests(
    List<RideRequestEntity> requests,
    String? destinationKeyword,
  ) {
    if (destinationKeyword == null || destinationKeyword.trim().isEmpty) {
      return requests;
    }
    final keyword = destinationKeyword.trim().toLowerCase();

    return requests.where((req) {
      final dest = req.destinationAddress.toLowerCase();
      final pickup = req.pickupAddress.toLowerCase();
      return dest.contains(keyword) || pickup.contains(keyword);
    }).toList();
  }

  /// التحقق مما إذا كان الكابتن محظوراً بسبب تجاوز سقف مديونية العمولة (مثلاً 15,000 د.ع)
  static bool isCommissionBlocked(
    double debtAmount, {
    double maxDebtThreshold = 15000.0,
  }) {
    return debtAmount >= maxDebtThreshold;
  }

  /// حساب نسبة إنجاز الهدف اليومي
  static double calculateTargetProgress(int completedTrips, int dailyTarget) {
    if (dailyTarget <= 0) return 0.0;
    final progress = completedTrips / dailyTarget;
    return progress > 1.0 ? 1.0 : (progress < 0.0 ? 0.0 : progress);
  }

  /// تجميع وتوزيع أرباح الأسبوع على 7 أيام (من السبت إلى الجمعة)
  static List<double> computeWeeklyEarningsArray(List<RideRequestEntity> completedTrips) {
    final earnings = List<double>.filled(7, 0.0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final trip in completedTrips) {
      if (trip.createdAt == null) continue;
      final tripDate = DateTime(trip.createdAt!.year, trip.createdAt!.month, trip.createdAt!.day);
      final differenceInDays = today.difference(tripDate).inDays;

      if (differenceInDays >= 0 && differenceInDays < 7) {
        final dayIndex = 6 - differenceInDays; // 6: اليوم، 0: قبل 6 أيام
        if (dayIndex >= 0 && dayIndex < 7) {
          earnings[dayIndex] += trip.estimatedFare;
        }
      }
    }

    return earnings;
  }
}
