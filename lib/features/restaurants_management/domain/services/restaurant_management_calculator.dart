import '../entities/restaurant_management_models.dart';

/// محرك حسابات وفلترة إدارة المطاعم المجرد (Pure Dart Restaurant Management Calculator)
class RestaurantManagementCalculator {
  const RestaurantManagementCalculator._();

  /// فلترة قائمة المطاعم حسب نص البحث (الاسم أو معرّف المالك)
  static List<RestaurantRecord> filterRestaurants(
    List<RestaurantRecord> restaurants,
    String searchQuery,
  ) {
    if (searchQuery.trim().isEmpty) return restaurants;
    final query = searchQuery.trim().toLowerCase();

    return restaurants.where((item) {
      final name = item.name.toLowerCase();
      final ownerId = item.ownerId.toLowerCase();
      return name.contains(query) || ownerId.contains(query);
    }).toList();
  }

  /// التحقق من صحة كلمة المرور (6 أحرف على الأقل)
  static bool validatePassword(String? password) {
    if (password == null) return false;
    final trimmed = password.trim();
    return trimmed.isNotEmpty && trimmed.length >= 6;
  }

  /// استخراج وتقييم التقييم بأمان
  static double parseRating(dynamic rawRating) {
    if (rawRating == null) return 0.0;
    if (rawRating is num) return rawRating.toDouble();
    if (rawRating is String) {
      return double.tryParse(rawRating) ?? 0.0;
    }
    return 0.0;
  }
}
