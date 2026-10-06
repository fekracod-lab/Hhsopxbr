import '../entities/restaurant_models.dart';

/// محرك حسابات وفلترة المطاعم والسلة المجرد (Pure Dart Restaurant Calculator)
class RestaurantCalculator {
  const RestaurantCalculator._();

  /// استخراج مدة التوصيل بالدقائق كقيمة رقمية (مطابق لدالة _parseTime الأصلية)
  static int parseDeliveryTime(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return 35;
    final numOnly = RegExp(r'\d+').firstMatch(timeStr)?.group(0);
    return int.tryParse(numOnly ?? '35') ?? 35;
  }

  /// فلترة وترتيب قائمة المطاعم وفق الشروط المحددة
  /// فلترة وترتيب قائمة المطاعم وفق الشروط المحددة
  static List<RestaurantEntity> filterAndSortRestaurants({
    required List<RestaurantEntity> restaurants,
    String selectedCategory = 'الكل',
    bool onlyOpen = false,
    bool onlyFreeDelivery = false,
    bool sortByRating = false,
    bool sortByDeliveryTime = false,
  }) {
    // 1. فلترة التصنيف بمطابقة ذكية
    var filtered = restaurants.where((r) {
      return _matchesCategory(r, selectedCategory);
    }).toList();

    // إذا لم يطابق أي مطعم التصنيف، نعرض القائمة لتفادي تصفير الشاشة
    if (filtered.isEmpty && selectedCategory != 'الكل') {
      filtered = List.from(restaurants);
    }

    // 2. فلترة المفتوح فقط
    if (onlyOpen) {
      final openList = filtered.where((r) => r.isOpen).toList();
      if (openList.isNotEmpty) filtered = openList;
    }

    // 3. فلترة التوصيل المجاني
    if (onlyFreeDelivery) {
      final freeList = filtered.where((r) => r.deliveryFee == 0.0).toList();
      if (freeList.isNotEmpty) filtered = freeList;
    }

    // 4. الترتيب
    if (sortByRating) {
      filtered.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (sortByDeliveryTime) {
      filtered.sort((a, b) {
        final timeA = parseDeliveryTime(a.deliveryTime);
        final timeB = parseDeliveryTime(b.deliveryTime);
        return timeA.compareTo(timeB);
      });
    } else {
      // الترتيب الافتراضي: الأحدث أولاً
      filtered.sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
    }

    return filtered;
  }

  static bool _matchesCategory(RestaurantEntity r, String selectedCategory) {
    if (selectedCategory == 'الكل' || selectedCategory.trim().isEmpty) {
      return true;
    }

    final sel = selectedCategory.trim().toLowerCase();
    final cat = r.category.trim().toLowerCase();
    final allCats = r.categories.map((c) => c.trim().toLowerCase()).toList();

    // 1. تطابق مباشر
    if (cat == sel || allCats.contains(sel)) return true;

    // 2. تطابق مجموعات الكلمات المفتاحية الذكية
    if (sel.contains('سريع') || sel.contains('فاست')) {
      if (cat.contains('سريع') || cat.contains('برغر') || cat.contains('صاج') || cat.contains('شاورما') || cat.contains('كرسبي') || cat.contains('فاست')) return true;
      if (allCats.any((c) => c.contains('سريع') || c.contains('برغر') || c.contains('صاج') || c.contains('شاورما') || c.contains('كرسبي') || c.contains('فاست'))) return true;
    }
    if (sel.contains('شاورما') || sel.contains('صاج')) {
      if (cat.contains('شاورما') || cat.contains('صاج') || cat.contains('سندويش') || cat.contains('قص')) return true;
      if (allCats.any((c) => c.contains('شاورما') || c.contains('صاج') || c.contains('سندويش') || c.contains('قص'))) return true;
    }
    if (sel.contains('برغر') || sel.contains('سندويش')) {
      if (cat.contains('برغر') || cat.contains('سندويش') || cat.contains('سريع') || cat.contains('همبرغر') || cat.contains('شاورما')) return true;
      if (allCats.any((c) => c.contains('برغر') || c.contains('سندويش') || c.contains('سريع') || c.contains('همبرغر') || c.contains('شاورما'))) return true;
    }
    if (sel.contains('مشاو') || sel.contains('كباب') || sel.contains('لحم')) {
      if (cat.contains('مشاو') || cat.contains('كباب') || cat.contains('تكة') || cat.contains('لحم') || cat.contains('شرق') || cat.contains('شواء')) return true;
      if (allCats.any((c) => c.contains('مشاو') || c.contains('كباب') || c.contains('تكة') || c.contains('لحم') || c.contains('شرق') || c.contains('شواء'))) return true;
    }
    if (sel.contains('بيتزا') || sel.contains('معجن') || sel.contains('فطائر')) {
      if (cat.contains('بيتزا') || cat.contains('معجن') || cat.contains('فطائر') || cat.contains('صمون') || cat.contains('إيطالي') || cat.contains('لحم بعجين')) return true;
      if (allCats.any((c) => c.contains('بيتزا') || c.contains('معجن') || c.contains('فطائر') || cat.contains('صمون') || c.contains('إيطالي') || c.contains('لحم بعجين'))) return true;
    }
    if (sel.contains('دجاج') || sel.contains('مقرمش') || sel.contains('كرسبي')) {
      if (cat.contains('دجاج') || cat.contains('مقرمش') || cat.contains('كرسبي') || cat.contains('بروستد') || cat.contains('كنتاكي') || cat.contains('زنجر')) return true;
      if (allCats.any((c) => c.contains('دجاج') || c.contains('مقرمش') || c.contains('كرسبي') || c.contains('بروستد') || c.contains('كنتاكي') || c.contains('زنجر'))) return true;
    }
    if (sel.contains('عصائر') || sel.contains('مشروب') || sel.contains('كولا') || sel.contains('ببسي') || sel.contains('عصير')) {
      if (cat.contains('عصير') || cat.contains('عصائر') || cat.contains('مشروب') || cat.contains('كافيه') || cat.contains('كوكتيل')) return true;
      if (allCats.any((c) => c.contains('عصير') || c.contains('عصائر') || c.contains('مشروب') || c.contains('كافيه') || c.contains('كوكتيل'))) return true;
    }
    if (sel.contains('حلويات') || sel.contains('كافيه') || sel.contains('كيك') || sel.contains('حلى') || sel.contains('وافل')) {
      if (cat.contains('حلويات') || cat.contains('حلى') || cat.contains('كافيه') || cat.contains('كيك') || cat.contains('وافل') || cat.contains('ايس كريم') || cat.contains('كنافة')) return true;
      if (allCats.any((c) => c.contains('حلويات') || c.contains('حلى') || c.contains('كافيه') || c.contains('كيك') || cat.contains('وافل') || c.contains('ايس كريم') || c.contains('كنافة'))) return true;
    }
    if (sel.contains('شرقي') || sel.contains('شعب') || sel.contains('قوزي') || sel.contains('برياني')) {
      if (cat.contains('شرقي') || cat.contains('شعب') || cat.contains('قوزي') || cat.contains('برياني') || cat.contains('طباخ') || cat.contains('رز') || cat.contains('دولمة') || cat.contains('فلافل')) return true;
      if (allCats.any((c) => c.contains('شرقي') || c.contains('شعب') || c.contains('قوزي') || cat.contains('برياني') || c.contains('طباخ') || c.contains('رز') || c.contains('دولمة') || c.contains('فلافل'))) return true;
    }
    if (sel.contains('سمك') || sel.contains('بحري')) {
      if (cat.contains('سمك') || cat.contains('بحري') || cat.contains('روبيان') || cat.contains('مسكوف')) return true;
      if (allCats.any((c) => c.contains('سمك') || c.contains('بحري') || c.contains('روبيان') || c.contains('مسكوف'))) return true;
    }
    if (sel.contains('فطور') || sel.contains('صباح')) {
      if (cat.contains('فطور') || cat.contains('صباح') || cat.contains('أجبان') || cat.contains('بيض') || cat.contains('قيمر')) return true;
      if (allCats.any((c) => c.contains('فطور') || c.contains('صباح') || c.contains('أجبان') || c.contains('بيض') || c.contains('قيمر'))) return true;
    }

    // 3. تطابق جزئي
    return cat.contains(sel) || sel.contains(cat);
  }

  /// حساب ملخص عناصر وسعر سلة التسوق
  static CartSummaryEntity computeCartSummary(List<CartItemEntity> items) {
    int totalCount = 0;
    double totalPrice = 0.0;

    for (final item in items) {
      totalCount += item.quantity;
      totalPrice += (item.price * item.quantity);
    }

    return CartSummaryEntity(
      totalCount: totalCount,
      totalPrice: totalPrice,
    );
  }

  /// تحديد ما إذا كانت حالة الطلب نشطة وتستوجب الظهور في شريط التتبع المباشر
  static bool isActiveOrderStatus(String? status) {
    if (status == null) return false;
    final normalized = status.toLowerCase().trim();
    return normalized == 'pending' ||
        normalized == 'placed' ||
        normalized == 'accepted' ||
        normalized == 'preparing' ||
        normalized == 'ready' ||
        normalized == 'delivering' ||
        normalized == 'on_the_way' ||
        normalized == 'picked_up';
  }

  /// تحديد ما إذا كانت حالة الطلب نهائية ومكتملة أو ملغاة
  static bool isTerminalOrderStatus(String? status) {
    if (status == null) return false;
    final normalized = status.toLowerCase().trim();
    return normalized == 'delivered' ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'completed';
  }

  /// تحديد معرّف السلة الفعّال (سواء سلة شخصية أو سلة جماعية)
  static String getEffectiveCartId({
    required String userUid,
    String? groupCartId,
  }) {
    if (groupCartId != null && groupCartId.trim().isNotEmpty) {
      return groupCartId.trim();
    }
    return userUid.trim();
  }

  /// نصوص التوصيات الذكية للأكلات العراقية (Skozmy Food Recommendations)
  static String getIraqiRecommendation(String food) {
    final clean = food.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '').trim();
    switch (clean) {
      case 'قوزي عراقي':
        return 'قوزي عراقي معدل! يذوب بالفم ويسر خاطرك اليوم.';
      case 'برجر فحم':
        return 'برجر على الفحم! جبنة سايحة وطعم لا يفوتك اليوم.';
      case 'شاورما دجاج':
        return 'لفة شاورما دجاج ويا الثومية المضبوطة! تسعد يومك.';
      case 'كباب عراقي':
        return 'كباب عراقي حار ويا الخبز الحار والبصل! طعم الأصالة العراقية.';
      case 'بيتزا إيطالية':
        return 'بيتزا إيطالية مليانة جبنة ونكهات مميزة اليوم.';
      case 'فلافل مشكل':
        return 'لفة فلافل مشكل دافية من قلب القائم! مقرمشة وطيبة.';
      case 'سمك مسكوف':
        return 'سمك مسكوف عراقي مشوي على الحطب! فد شي فاخر.';
      case 'منسف لحم':
        return 'منسف لحم فاخر! وجبة طيبة ومشبعة.';
      case 'كنافة نابلسية':
        return 'كنافة نابلسية دافية وطعم جبنة خيالي.';
      case 'كريب نوتيلا':
        return 'كريب مليان نوتيلا غنية وفواكه طازجة.';
      case 'وافل فواكه':
        return 'وافل مقرمش ومغطى بالكراميل والشوكولاتة والفواكه.';
      case 'كيكة الشوكولاتة':
        return 'قطعة كيكة الشوكولاتة الهشة والغنية لعشاق الحلى.';
      case 'عصير كوكتيل':
        return 'كوب عصير كوكتيل طازج ومنعش يروي عطشك.';
      case 'موهيتو رمان':
        return 'موهيتو رمان مثلج وبارد مع النعناع والليمون المنعش.';
      case 'عصير مانجو طبيعي':
        return 'عصير مانجو طبيعي مكثف وبارد يملأ يومك بالانتعاش.';
      case 'ميلك شيك أوريو':
        return 'ميلك شيك أوريو بالكريمة والشوكولاتة.';
      default:
        return 'وجبة $clean طيبة ومميزة من القائم! جربها اليوم.';
    }
  }

  /// وصف كوبونات الحظ الفائزة (Lucky Wheel Coupons)
  static String getCouponWinDescription(String couponName) {
    final clean = couponName.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '').trim();
    switch (clean) {
      case 'توصيل بلاش':
      case 'توصيل مجاني':
        return 'ألف مبروك! حصلت على توصيل بلاش لطلبك القادم من القائم.';
      case 'خصم 10%':
        return 'مبروك! خصم 10% على طلبك القادم.';
      case 'خصم 2,000 د.ع':
        return 'تم تفعيل خصم 2,000 دينار يخصم مباشرة من طلبك القادم.';
      case 'كوبون حظ 50%':
      case 'خصم 50%':
        return 'خصم 50% على أجور التوصيل لجميع مناطق القائم.';
      case 'مشروب بلاش':
      case 'مشروب مجاني':
        return 'مشروب بارد مجاني ويا وجبتك القادمة، بالعافية.';
      case 'تحلية بلاش':
      case 'تحلية مجانية':
        return 'قطعة تحلية مجانية هدية ويا طلبك القادم.';
      case 'خصم 1,500 د.ع':
        return 'خصم بقيمة 1,500 دينار لطلبك القادم.';
      case 'حظ أوفر':
        return 'حظ أوفر، جرب مرة ثانية باجر والربح أكيد.';
      default:
        return 'كوبون جائزة مميزة بقيمة رائعة من مدار!';
    }
  }
}
