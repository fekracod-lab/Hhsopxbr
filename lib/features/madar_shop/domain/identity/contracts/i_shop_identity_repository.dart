// عقود مستودع الهوية والجلسات لمنظومة متجر مدار (MADAR SHOP Identity Repository Contract)
// Pure Dart — Zero UI Dependencies

import '../entities/shop_branch.dart';
import '../entities/shop_business.dart';
import '../entities/shop_session.dart';
import '../entities/shop_user.dart';

abstract class IShopIdentityRepository {
  /// استرجاع مستخدم المتجر عبر معرف تسجيل الدخول وكلمة المرور/الرمز السري
  Future<ShopUser?> getUserByCredentials({
    required String loginIdentifier,
    required String secret,
  });

  /// استرجاع مستخدم المتجر عبر معرف المستخدم
  Future<ShopUser?> getUserById(String userId);

  /// استرجاع النشاط التجاري
  Future<ShopBusiness?> getBusinessById(String businessId);

  /// استرجاع فرع محدد تابع لنشاط تجاري
  Future<ShopBranch?> getBranchById({
    required String businessId,
    required String branchId,
  });

  /// حفظ أو تحديث بيانات مستخدم
  Future<void> saveUser(ShopUser user);

  /// حفظ جلسة عمل جديدة
  Future<void> saveSession(ShopSession session);

  /// استرجاع جلسة عمل بالمعرف
  Future<ShopSession?> getSession(String sessionId);

  /// إنهاء جلسة العمل
  Future<void> terminateSession(String sessionId);
}
