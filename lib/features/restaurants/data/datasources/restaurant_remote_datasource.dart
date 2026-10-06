import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// مصدر البيانات البعيد لخدمات المطاعم والسلة (Remote Datasource for Restaurants & Cart)
class RestaurantRemoteDatasource {
  final FirebaseFirestore? _customFirestore;

  RestaurantRemoteDatasource({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// جلب كافة المطاعم من مجموعة restaurants مع دمج تلقائي لعناصر sections/items وبيانات تجريبية عند خلو قاعدة البيانات
  Future<List<Map<String, dynamic>>> fetchRestaurants() async {
    final List<Map<String, dynamic>> results = [];
    final Set<String> seenIds = {};

    try {
      // 1. جلب من مجموعة restaurants الرئيسية
      final snap = await _firestore.collection('restaurants').get();
      for (var doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['name'] = data['name'] ?? data['restaurantName'] ?? data['title'] ?? data['pageName'] ?? 'مطعم مدار';
        data['imageUrl'] = data['imageUrl'] ?? data['logoUrl'] ?? data['image'] ?? data['coverUrl'] ?? '';
        data['coverUrl'] = data['coverUrl'] ?? data['imageUrl'] ?? data['logoUrl'] ?? data['image'] ?? '';
        data['rating'] = (data['rating'] as num?)?.toDouble() ?? 4.9;
        data['deliveryTime'] = data['deliveryTime']?.toString() ?? '25 - 35 دقيقة';
        data['deliveryFee'] = (data['deliveryFee'] as num?)?.toDouble() ?? 1500.0;
        data['isOpen'] = data['isOpen'] as bool? ?? true;
        data['category'] = data['category'] ?? data['type'] ?? data['specialty'] ?? 'وجبات سريعة';

        final catList = <String>[];
        if (data['categories'] is List) {
          catList.addAll((data['categories'] as List).map((e) => e.toString()));
        } else {
          catList.add(data['category'].toString());
        }
        data['categories'] = catList;

        seenIds.add(doc.id);
        results.add(data);
      }
    } catch (_) {}

    return results;
  }



  /// جلب بيانات مطعم محدد بالمعرّف
  Future<Map<String, dynamic>?> fetchRestaurantById(String restaurantId) async {
    if (restaurantId.trim().isEmpty) return null;
    final doc = await _firestore.collection('restaurants').doc(restaurantId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    return data;
  }

  /// جلب الوجبات المميزة من منيو المطاعم الحقيقي (restaurants/{id}/menu)
  Future<List<Map<String, dynamic>>> fetchPopularMeals() async {
    final List<Map<String, dynamic>> allMeals = [];
    try {
      final restaurantsSnap = await _firestore.collection('restaurants').limit(24).get();
      for (final restDoc in restaurantsSnap.docs) {
        final restData = restDoc.data();
        final restName = (restData['name'] ??
                restData['restaurantName'] ??
                restData['fullName'] ??
                'مطعم مدار')
            .toString();
        QuerySnapshot<Map<String, dynamic>> menuSnap;
        try {
          menuSnap = await restDoc.reference.collection('menu').limit(4).get();
        } catch (_) {
          continue;
        }
        var meals = menuSnap.docs;
        if (meals.isEmpty) {
          try {
            final products = await _firestore
                .collection('merchant_products')
                .doc(restDoc.id)
                .collection('products')
                .limit(4)
                .get();
            meals = products.docs;
          } catch (_) {}
        }
        for (final mealDoc in meals) {
          allMeals.add(
            _normalizeMealMap(
              mealDoc.id,
              mealDoc.data(),
              restaurantId: restDoc.id,
              restaurantName: restName,
            ),
          );
        }
      }
      if (allMeals.isNotEmpty) return allMeals;
    } catch (_) {}

    // توافق قديم: sections/items/menu إن لم يوجد منيو في مجموعة المطاعم
    final secQ = await _firestore
        .collection('sections')
        .where('label', isEqualTo: 'مطاعم')
        .limit(1)
        .get();

    if (secQ.docs.isEmpty) return allMeals;

    final sectionId = secQ.docs.first.id;
    final itemsSnap = await _firestore
        .collection('sections')
        .doc(sectionId)
        .collection('items')
        .get();

    final futures = itemsSnap.docs.map((itemDoc) async {
      final itemData = itemDoc.data();
      final restaurantName = itemData['pageName']?.toString() ??
          itemData['name']?.toString() ??
          'مطعم';
      final restaurantId = itemData['ownerId']?.toString() ?? itemDoc.id;

      try {
        final restFuture = _firestore.collection('restaurants').doc(restaurantId).get();
        final menuFuture = itemDoc.reference.collection('menu').limit(3).get();

        final results = await Future.wait([restFuture, menuFuture]);
        final restDoc = results[0] as DocumentSnapshot;
        final menuSnap = results[1] as QuerySnapshot;

        String restaurantImageUrl = '';
        if (restDoc.exists && restDoc.data() != null) {
          final restData = restDoc.data() as Map<String, dynamic>;
          restaurantImageUrl = (restData['imageUrl'] ?? restData['logoUrl'] ?? '').toString();
        }

        final List<Map<String, dynamic>> restaurantMeals = [];
        for (var mealDoc in menuSnap.docs) {
          final mealData = mealDoc.data() as Map<String, dynamic>? ?? {};
          restaurantMeals.add({
            'mealId': mealDoc.id,
            'mealName': mealData['name']?.toString() ?? mealData['mealName']?.toString() ?? 'وجبة',
            'mealImage': mealData['imageUrl']?.toString() ?? mealData['mealImage']?.toString() ?? '',
            'mealPrice': (mealData['price'] ?? mealData['mealPrice'] as num?)?.toDouble() ?? 0.0,
            'restaurantName': restaurantName,
            'restaurantId': restaurantId,
            'restaurantImageUrl': restaurantImageUrl,
            'category': (mealData['category']?.toString() ?? 'المطاعم'),
            'isAvailable': mealData['isAvailable'] as bool? ?? true,
            'rawData': mealData,
          });
        }
        return restaurantMeals;
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    });

    final nestedResults = await Future.wait(futures);
    for (var mealsList in nestedResults) {
      allMeals.addAll(mealsList);
    }
    return allMeals;
  }

  /// مراقبة عناصر سلة التسوق الفعالة (carts/{effectiveCartId}/items)
  Stream<List<Map<String, dynamic>>> watchCartItems(String effectiveCartId) {
    if (effectiveCartId.trim().isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return _firestore
        .collection('carts')
        .doc(effectiveCartId)
        .collection('items')
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// مراقبة طلبات المستخدم (madar_orders/{uid}/orders)
  Stream<List<Map<String, dynamic>>> watchUserOrders(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
    return _firestore
        .collection('madar_orders')
        .doc(uid)
        .collection('orders')
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// جلب آخر طلب للمستخدم (madar_orders/{uid}/orders orderBy createdAt limit 1)
  Future<Map<String, dynamic>?> fetchLatestOrder(String uid) async {
    if (uid.trim().isEmpty) return null;
    final snap = await _firestore
        .collection('madar_orders')
        .doc(uid)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final data = Map<String, dynamic>.from(snap.docs.first.data());
    data['id'] = snap.docs.first.id;

    final restId = data['restaurantId']?.toString();
    if (restId != null && restId.isNotEmpty) {
      final restDoc = await _firestore.collection('restaurants').doc(restId).get();
      if (restDoc.exists && restDoc.data() != null) {
        final restData = restDoc.data() as Map<String, dynamic>;
        data['restaurantName'] = restData['name']?.toString() ?? restData['fullName']?.toString();
      }
    }

    return data;
  }

  /// مراقبة السلة الجماعية الحية (group_carts/{code})
  Stream<Map<String, dynamic>?> watchGroupCart(String code) {
    if (code.trim().isEmpty) return Stream.value(null);
    return _firestore.collection('group_carts').doc(code).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      final data = Map<String, dynamic>.from(snap.data()!);
      data['code'] = snap.id;
      return data;
    });
  }

  /// جلب مستند السلة الجماعية (group_carts/{code})
  Future<Map<String, dynamic>?> getGroupCart(String code) async {
    if (code.trim().isEmpty) return null;
    final doc = await _firestore.collection('group_carts').doc(code).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['code'] = doc.id;
    return data;
  }

  /// إنشاء سلة جماعية جديدة برمز فريد
  Future<void> createGroupCart({
    required String code,
    required String hostId,
    required String hostName,
  }) async {
    await _firestore.collection('group_carts').doc(code).set({
      'hostId': hostId,
      'hostName': hostName,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
  }

  /// إلغاء تفعيل السلة الجماعية (group_carts/{code} update active: false)
  Future<void> deactivateGroupCart(String code) async {
    if (code.trim().isEmpty) return;
    await _firestore.collection('group_carts').doc(code).update({
      'active': false,
    });
  }

  /// جلب تصنيفات المطعم مع اكتشاف وثيقة المطعم في الأقسام (Sections Discovery)
  Future<Map<String, dynamic>?> discoverRestaurantMenuContext(String restaurantId) async {
    if (restaurantId.trim().isEmpty) return null;
    DocumentSnapshot? restaurantItemDoc;
    String sectionId = '';

    // 1) البحث أولاً في سكشن "مطاعم"
    try {
      final secQ = await _firestore
          .collection('sections')
          .where('label', isEqualTo: 'مطاعم')
          .limit(1)
          .get();

      if (secQ.docs.isNotEmpty) {
        final secDocId = secQ.docs.first.id;
        final itemsQ = await _firestore
            .collection('sections')
            .doc(secDocId)
            .collection('items')
            .where('ownerId', isEqualTo: restaurantId)
            .limit(1)
            .get();

        if (itemsQ.docs.isNotEmpty) {
          restaurantItemDoc = itemsQ.docs.first;
          sectionId = secDocId;
        }
      }
    } catch (_) {}

    // 2) Fallback: البحث في كافة الأقسام إذا لم نجده
    if (restaurantItemDoc == null) {
      try {
        final allSections = await _firestore.collection('sections').get();
        for (var sec in allSections.docs) {
          final data = sec.data();
          if (data['label'] == 'مطاعم') continue;

          final itemsQ = await _firestore
              .collection('sections')
              .doc(sec.id)
              .collection('items')
              .where('ownerId', isEqualTo: restaurantId)
              .limit(1)
              .get();

          if (itemsQ.docs.isNotEmpty) {
            restaurantItemDoc = itemsQ.docs.first;
            sectionId = sec.id;
            break;
          }
        }
      } catch (_) {}
    }

    if (restaurantItemDoc == null) return null;

    final itemId = restaurantItemDoc.id;
    final catsSnap = await restaurantItemDoc.reference
        .collection('categories')
        .orderBy('createdAt')
        .get();

    final List<Map<String, dynamic>> categories = catsSnap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
      return data;
    }).toList();

    return {
      'sectionId': sectionId,
      'itemId': itemId,
      'categories': categories,
    };
  }

  /// مراقبة وجبات المنيو لقسم معين وتصنيف معين (sections/{sectionId}/items/{itemId}/menu)
  Stream<List<Map<String, dynamic>>> watchMenuItems({
    required String sectionId,
    required String itemId,
    String? category,
    String? sortBy,
  }) {
    if (sectionId.isEmpty || itemId.isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    Query query = _firestore
        .collection('sections')
        .doc(sectionId)
        .collection('items')
        .doc(itemId)
        .collection('menu');

    if (category != null && category.isNotEmpty && category != 'الكل') {
      query = query.where('category', isEqualTo: category);
    }

    if (sortBy == 'price_low') {
      query = query.orderBy('price', descending: false);
    } else if (sortBy == 'price_high') {
      query = query.orderBy('price', descending: true);
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// مراقبة وجبات المنيو مباشرة من مسار المطعم الجديد
  /// يبحث أولاً في restaurants/{restaurantId}/menu
  /// ثم merchant_products/{restaurantId}/products كبديل
  Stream<List<Map<String, dynamic>>> watchMenuItemsDirect({
    required String restaurantId,
    String? category,
    String? sortBy,
  }) {
    if (restaurantId.trim().isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    // نبني stream مركّب يبحث في المسارين
    return _watchMergedMenuStreams(restaurantId, category, sortBy);
  }

  Stream<List<Map<String, dynamic>>> _watchMergedMenuStreams(
    String restaurantId,
    String? category,
    String? sortBy,
  ) async* {
    // 1. حاول restaurants/{id}/menu أولاً
    Query restaurantMenuQuery = _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('menu');

    if (category != null && category.isNotEmpty && category != 'الكل') {
      restaurantMenuQuery = restaurantMenuQuery.where('category', isEqualTo: category);
    }

    if (sortBy == 'price_low') {
      restaurantMenuQuery = restaurantMenuQuery.orderBy('price', descending: false);
    } else if (sortBy == 'price_high') {
      restaurantMenuQuery = restaurantMenuQuery.orderBy('price', descending: true);
    }

    // تجربة القراءة الأولى لتحديد المسار الصحيح
    List<Map<String, dynamic>> firstResult = [];
    bool useRestaurantMenu = false;

    try {
      final firstSnap = await restaurantMenuQuery.get();
      if (firstSnap.docs.isNotEmpty) {
        useRestaurantMenu = true;
        firstResult = firstSnap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;
          return data;
        }).toList();
      }
    } catch (_) {}

    // 2. إذا restaurants/menu فارغ، جرّب merchant_products
    if (!useRestaurantMenu) {
      try {
        Query merchantQuery = _firestore
            .collection('merchant_products')
            .doc(restaurantId)
            .collection('products');

        if (category != null && category.isNotEmpty && category != 'الكل') {
          merchantQuery = merchantQuery.where('category', isEqualTo: category);
        }

        final merchantSnap = await merchantQuery.get();
        if (merchantSnap.docs.isNotEmpty) {
          firstResult = merchantSnap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return data;
          }).toList();

          // اشترك في merchant_products لأنها المصدر النشط
          yield firstResult;
          yield* merchantQuery.snapshots().map((snap) {
            return snap.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              data['id'] = doc.id;
              return data;
            }).toList();
          });
          return;
        }
      } catch (_) {}
    }

    // إصدار النتيجة الأولى ثم الاشتراك بالتحديثات
    yield firstResult;
    yield* restaurantMenuQuery.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// إضافة عنصر أو تعديل كميته داخل سلة التسوق (carts/{cartId}/items/{itemId})
  Future<void> addCartItem({
    required String cartId,
    required String itemId,
    required String name,
    required double price,
    required int quantity,
    required String restaurantId,
    required String restaurantName,
    String? imageUrl,
    String size = '',
    String options = '',
    String notes = '',
    String? addedByName,
  }) async {
    if (cartId.trim().isEmpty || itemId.trim().isEmpty) return;

    final cartRef = _firestore
        .collection('carts')
        .doc(cartId)
        .collection('items')
        .doc(itemId);

    final doc = await cartRef.get();
    if (doc.exists) {
      await cartRef.update({
        'quantity': FieldValue.increment(quantity),
        'price': price,
        if (size.isNotEmpty) 'size': size,
        if (options.isNotEmpty) 'options': options,
        if (notes.isNotEmpty) 'notes': notes,
        if (addedByName != null && addedByName.isNotEmpty) 'addedByName': addedByName,
      });
    } else {
      await cartRef.set({
        'itemId': itemId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'imageUrl': imageUrl ?? '',
        'restaurantId': restaurantId,
        'restaurant': restaurantName,
        'size': size,
        'options': options,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        if (addedByName != null && addedByName.isNotEmpty) 'addedByName': addedByName,
      });
    }
  }

  /// إنقاص كمية العنصر أو حذفه إذا أصبحت الكمية صفر (carts/{cartId}/items/{itemId})
  Future<void> removeCartItem({
    required String cartId,
    required String itemId,
  }) async {
    if (cartId.trim().isEmpty || itemId.trim().isEmpty) return;

    final cartRef = _firestore
        .collection('carts')
        .doc(cartId)
        .collection('items')
        .doc(itemId);

    final doc = await cartRef.get();
    if (doc.exists && doc.data() != null) {
      final currentQty = (doc.data()?['quantity'] as num? ?? 0).toInt();
      if (currentQty > 1) {
        await cartRef.update({'quantity': FieldValue.increment(-1)});
      } else {
        await cartRef.delete();
      }
    }
  }

  /// مراقبة تقييمات ومراجعات المطعم (restaurants/{restaurantId}/reviews)
  Stream<List<Map<String, dynamic>>> watchRestaurantReviews(String restaurantId) {
    if (restaurantId.trim().isEmpty) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// إضافة تقييم ومراجعة جديدة للمطعم (restaurants/{restaurantId}/reviews)
  Future<void> addRestaurantReview({
    required String restaurantId,
    required double rating,
    required String comment,
    required String userId,
    required String userName,
  }) async {
    if (restaurantId.trim().isEmpty) return;

    await _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('reviews')
        .add({
      'rating': rating,
      'comment': comment,
      'userId': userId,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// حذف تقييم المطعم (restaurants/{restaurantId}/reviews/{reviewId})
  Future<void> deleteRestaurantReview({
    required String restaurantId,
    required String reviewId,
  }) async {
    if (restaurantId.trim().isEmpty || reviewId.trim().isEmpty) return;

    await _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('reviews')
        .doc(reviewId)
        .delete();
  }

  /// تطبيع بيانات وجبة خام إلى خريطة موحدة للعرض
  Map<String, dynamic> _normalizeMealMap(
    String mealId,
    Map<String, dynamic> mealData, {
    required String restaurantId,
    required String restaurantName,
  }) {
    return {
      'mealId': mealId,
      'id': mealId,
      'mealName': mealData['name']?.toString() ?? mealData['mealName']?.toString() ?? mealData['title']?.toString() ?? 'وجبة',
      'name': mealData['name']?.toString() ?? mealData['mealName']?.toString() ?? mealData['title']?.toString() ?? 'وجبة',
      'mealImage': mealData['imageUrl']?.toString() ?? mealData['mealImage']?.toString() ?? mealData['photoUrl']?.toString() ?? '',
      'imageUrl': mealData['imageUrl']?.toString() ?? mealData['mealImage']?.toString() ?? mealData['photoUrl']?.toString() ?? '',
      'mealPrice': (mealData['price'] ?? mealData['mealPrice'] as num?)?.toDouble() ?? 0.0,
      'price': (mealData['price'] ?? mealData['mealPrice'] as num?)?.toDouble() ?? 0.0,
      'restaurantName': restaurantName,
      'restaurantId': restaurantId,
      'category': (mealData['category']?.toString() ?? 'المطاعم'),
      'description': mealData['description']?.toString() ?? '',
      'isAvailable': mealData['isAvailable'] as bool? ?? true,
      'rawData': mealData,
    };
  }
}
