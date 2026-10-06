// حاسبة العمليات وقواعد النطاق للوحة تحكم المندوب (Delivery Dashboard Pure Calculator)
// Pure Dart — Zero Flutter / Firebase Dependencies

import 'dart:math' as math;
import '../entities/delivery_dashboard_models.dart';

/// فئة الخدمات الحسابية الصافية للوحة المندوب
class DeliveryDashboardCalculator {
  const DeliveryDashboardCalculator._();

  /// 1. حساب أرباح طلب توصيل فردي
  static double calculateOrderEarnings(DeliveryOrderEntity order) {
    if (order.deliveryFee.isNaN || order.deliveryFee.isInfinite || order.deliveryFee < 0) {
      return 0.0;
    }
    return order.deliveryFee;
  }

  /// 2. حساب إجمالي الأرباح لجميع الطلبات المكتملة
  static double calculateTotalEarnings(List<DeliveryOrderEntity> orders) {
    if (orders.isEmpty) return 0.0;
    return orders.fold(0.0, (sum, o) {
      if (o.status == DeliveryOrderStatus.completed) {
        final fee = calculateOrderEarnings(o);
        return sum + fee;
      }
      return sum;
    });
  }

  /// 3. حساب أرباح اليوم فقط بناءً على التاريخ المرجعي
  static double calculateTodayEarnings({
    required List<DeliveryOrderEntity> orders,
    required DateTime referenceDate,
  }) {
    if (orders.isEmpty) return 0.0;
    return orders.fold(0.0, (sum, o) {
      if (o.status == DeliveryOrderStatus.completed && isSameDay(o.completedAt ?? o.createdAt, referenceDate)) {
        final fee = calculateOrderEarnings(o);
        return sum + fee;
      }
      return sum;
    });
  }

  /// 4. حساب عدد الطلبات المكتملة
  static int calculateCompletedCount(List<DeliveryOrderEntity> orders) {
    return orders.where((o) => o.status == DeliveryOrderStatus.completed).length;
  }

  /// 5. حساب عدد الطلبات المكتملة اليوم
  static int calculateTodayCompletedCount({
    required List<DeliveryOrderEntity> orders,
    required DateTime referenceDate,
  }) {
    return orders.where((o) =>
        o.status == DeliveryOrderStatus.completed &&
        isSameDay(o.completedAt ?? o.createdAt, referenceDate)).length;
  }

  /// 6. حساب نسبة إنجاز المهام
  static double calculateCompletionRate({
    required int completed,
    required int total,
  }) {
    if (total <= 0 || completed < 0) return 0.0;
    final rate = completed / total;
    return rate.clamp(0.0, 1.0);
  }

  /// 7. حساب تقدم تحدي الهدف اليومي والمكافأة
  static DeliveryQuestProgress calculateQuestProgress({
    required int completedCount,
    int targetTrips = 8,
    double bonusAmount = 5000.0,
  }) {
    final validTarget = targetTrips > 0 ? targetTrips : 8;
    final validCompleted = math.max(0, completedCount);
    final validBonus = bonusAmount > 0 ? bonusAmount : 5000.0;

    final double progress = (validCompleted / validTarget).clamp(0.0, 1.0);
    final int percentage = (progress * 100).toInt();
    final bool isCompleted = validCompleted >= validTarget;
    final int remaining = math.max(0, validTarget - validCompleted);

    return DeliveryQuestProgress(
      targetTrips: validTarget,
      completedTrips: validCompleted,
      progress: progress,
      progressPercentage: percentage,
      bonusAmount: validBonus,
      isCompleted: isCompleted,
      remainingTrips: remaining,
    );
  }

  /// 8. تجميع إحصائيات اللوحة الشاملة بدقة وحيادية تامة
  static DeliveryDashboardStatistics calculateDashboardStatistics({
    required List<DeliveryOrderEntity> orders,
    required DateTime referenceDate,
    double appDebt = 0.0,
    int questTargetTrips = 8,
    double questBonusAmount = 5000.0,
  }) {
    int completed = 0;
    int active = 0;
    int pending = 0;
    int cancelled = 0;
    double totalEarnings = 0.0;
    double todayEarnings = 0.0;
    int todayCompleted = 0;

    for (final o in orders) {
      switch (o.status) {
        case DeliveryOrderStatus.completed:
          completed++;
          final fee = calculateOrderEarnings(o);
          totalEarnings += fee;
          if (isSameDay(o.completedAt ?? o.createdAt, referenceDate)) {
            todayEarnings += fee;
            todayCompleted++;
          }
          break;
        case DeliveryOrderStatus.delivering:
        case DeliveryOrderStatus.accepted:
          active++;
          break;
        case DeliveryOrderStatus.pending:
        case DeliveryOrderStatus.ready:
          pending++;
          break;
        case DeliveryOrderStatus.cancelled:
          cancelled++;
          break;
        case DeliveryOrderStatus.unknown:
          break;
      }
    }

    final int total = orders.length;
    final double completionRate = calculateCompletionRate(completed: completed, total: total);
    final questProgress = calculateQuestProgress(
      completedCount: todayCompleted,
      targetTrips: questTargetTrips,
      bonusAmount: questBonusAmount,
    );

    return DeliveryDashboardStatistics(
      totalOrders: total,
      completedOrders: completed,
      activeOrders: active,
      pendingOrders: pending,
      cancelledOrders: cancelled,
      totalEarnings: totalEarnings,
      todayEarnings: todayEarnings,
      todayCompletedCount: todayCompleted,
      completionRate: completionRate,
      appDebt: appDebt < 0 ? 0.0 : appDebt,
      questProgress: questProgress,
    );
  }

  /// 9. فلترة وتصنيف قائمة الطلبات
  static List<DeliveryOrderEntity> filterOrders({
    required List<DeliveryOrderEntity> orders,
    required DeliveryFilterType filter,
    String searchQuery = '',
  }) {
    if (orders.isEmpty) return const [];

    var result = orders;

    // 1. فلترة حسب المصدر
    switch (filter) {
      case DeliveryFilterType.food:
        result = result.where((o) => o.source == DeliveryOrderSource.food).toList();
        break;
      case DeliveryFilterType.mersal:
        result = result.where((o) => o.source == DeliveryOrderSource.mersal).toList();
        break;
      case DeliveryFilterType.store:
        result = result.where((o) => o.source == DeliveryOrderSource.store).toList();
        break;
      case DeliveryFilterType.all:
        break;
    }

    // 2. فلترة حسب البحث النصي
    final query = searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((o) {
        final matchesSource = o.sourceName.toLowerCase().contains(query);
        final matchesDropoff = o.dropoffName.toLowerCase().contains(query);
        final matchesCustomer = o.customerName.toLowerCase().contains(query);
        final matchesId = o.id.toLowerCase().contains(query);
        return matchesSource || matchesDropoff || matchesCustomer || matchesId;
      }).toList();
    }

    return List.unmodifiable(result);
  }

  /// 10. التحقق من أهلية وإمكانية قبول الطلب بواسطة المندوب
  static bool canAcceptOrder({
    required DriverAvailabilityState availability,
    required DeliveryOrderEntity order,
    bool allowMultipleActiveTasks = false,
    int currentActiveTasksCount = 0,
  }) {
    // 1. يجب أن يكون المندوب متصلاً
    if (availability != DriverAvailabilityState.online && availability != DriverAvailabilityState.onTrip) {
      return false;
    }

    // 2. يجب أن يكون الطلب متاحاً للقبول
    if (!order.status.isAvailableForPickup) {
      return false;
    }

    // 3. التحقق من المهام النشطة إذا لم يُسمح بتعدد المهام
    if (!allowMultipleActiveTasks && currentActiveTasksCount > 0 && availability == DriverAvailabilityState.onTrip) {
      return false;
    }

    return true;
  }

  /// 11. تبديل حالة اتصال المندوب (Online / Offline Toggle)
  static DriverAvailabilityState getNextAvailabilityState(DriverAvailabilityState current) {
    switch (current) {
      case DriverAvailabilityState.online:
      case DriverAvailabilityState.onTrip:
        return DriverAvailabilityState.offline;
      case DriverAvailabilityState.offline:
      case DriverAvailabilityState.unknown:
        return DriverAvailabilityState.online;
    }
  }

  /// دالة مساعدة نقية للتحقق من تطابق اليوم
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
