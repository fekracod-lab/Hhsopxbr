import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreSyncService {
  /// Find all section item references that correspond to a given restaurant ownerId
  static Future<List<DocumentReference>> _findSectionItemRefs(String ownerId) async {
    List<DocumentReference> refs = [];
    try {
      final fb = FirebaseFirestore.instance;
      // 1. Try collectionGroup query first
      final snap = await fb.collectionGroup('items').where('ownerId', isEqualTo: ownerId).get();
      for (var doc in snap.docs) {
        refs.add(doc.reference);
      }
    } catch (e) {
      debugPrint('Error in collectionGroup items query: $e');
    }

    // 2. Fallback if no refs found (or if collectionGroup query failed)
    if (refs.isEmpty) {
      try {
        final fb = FirebaseFirestore.instance;
        final sections = await fb.collection('sections').get();
        for (var sec in sections.docs) {
          final items = await fb
              .collection('sections')
              .doc(sec.id)
              .collection('items')
              .where('ownerId', isEqualTo: ownerId)
              .get();
          for (var doc in items.docs) {
            refs.add(doc.reference);
          }
        }
      } catch (e) {
        debugPrint('Error in fallback section items query: $e');
      }
    }
    return refs;
  }

  /// Sync adding/setting a meal to all section items, restaurants, and stores
  static Future<void> syncAddOrSetMeal(String ownerId, String mealId, Map<String, dynamic> mealData) async {
    try {
      final fb = FirebaseFirestore.instance;

      // 1. Sync to restaurants/{ownerId}/menu/{mealId}
      await fb
          .collection('restaurants')
          .doc(ownerId)
          .collection('menu')
          .doc(mealId)
          .set(mealData, SetOptions(merge: true))
          .catchError((e) {
        debugPrint('Warning syncing to restaurants/$ownerId/menu: $e');
      });

      // 2. Sync to stores/{ownerId}/products/{mealId}
      await fb
          .collection('stores')
          .doc(ownerId)
          .collection('products')
          .doc(mealId)
          .set(mealData, SetOptions(merge: true))
          .catchError((_) {});

      // 3. Sync to section items
      final refs = await _findSectionItemRefs(ownerId);
      for (var itemRef in refs) {
        // Sync meal to the 'menu' subcollection
        await itemRef.collection('menu').doc(mealId).set(mealData, SetOptions(merge: true));

        // Ensure category exists
        final category = mealData['category']?.toString();
        if (category != null && category.isNotEmpty && category != 'الكل') {
          final catsRef = itemRef.collection('categories');
          final catSnap = await catsRef.where('name', isEqualTo: category).limit(1).get();
          if (catSnap.docs.isEmpty) {
            await catsRef.add({
              'name': category,
              'iconCode': 0xe2aa, // Default: fastfood icon
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing add/set meal: $e');
    }
  }

  /// Sync updating a meal in all section items, restaurants, and stores
  static Future<void> syncUpdateMeal(String ownerId, String mealId, Map<String, dynamic> updateData) async {
    try {
      final fb = FirebaseFirestore.instance;

      await fb
          .collection('restaurants')
          .doc(ownerId)
          .collection('menu')
          .doc(mealId)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});

      await fb
          .collection('stores')
          .doc(ownerId)
          .collection('products')
          .doc(mealId)
          .set(updateData, SetOptions(merge: true))
          .catchError((_) {});

      final refs = await _findSectionItemRefs(ownerId);
      for (var itemRef in refs) {
        await itemRef.collection('menu').doc(mealId).set(updateData, SetOptions(merge: true));

        // Ensure category exists (if updated)
        final category = updateData['category']?.toString();
        if (category != null && category.isNotEmpty && category != 'الكل') {
          final catsRef = itemRef.collection('categories');
          final catSnap = await catsRef.where('name', isEqualTo: category).limit(1).get();
          if (catSnap.docs.isEmpty) {
            await catsRef.add({
              'name': category,
              'iconCode': 0xe2aa, // Default: fastfood icon
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing update meal: $e');
    }
  }

  /// Sync deleting a meal from all section items, restaurants, and stores
  static Future<void> syncDeleteMeal(String ownerId, String mealId) async {
    try {
      final fb = FirebaseFirestore.instance;

      await fb
          .collection('restaurants')
          .doc(ownerId)
          .collection('menu')
          .doc(mealId)
          .delete()
          .catchError((_) {});

      await fb
          .collection('stores')
          .doc(ownerId)
          .collection('products')
          .doc(mealId)
          .delete()
          .catchError((_) {});

      final refs = await _findSectionItemRefs(ownerId);
      for (var itemRef in refs) {
        await itemRef.collection('menu').doc(mealId).delete().catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error syncing delete meal: $e');
    }
  }

  /// Sync restaurant profile updates to restaurants collection and sections items
  static Future<void> syncRestaurantProfile(String ownerId, Map<String, dynamic> profileData) async {
    try {
      final fb = FirebaseFirestore.instance;

      // 1. Update the document in 'restaurants' collection
      final restUpdate = {
        if (profileData['restaurantName'] != null) 'name': profileData['restaurantName'],
        if (profileData['phone'] != null) 'phone': profileData['phone'],
        if (profileData['address'] != null) 'address': profileData['address'],
        if (profileData['cuisineType'] != null) 'type': profileData['cuisineType'],
        if (profileData['photoUrl'] != null) 'imageUrl': profileData['photoUrl'],
        if (profileData['coverImageUrl'] != null) 'coverImageUrl': profileData['coverImageUrl'],
      };
      
      if (restUpdate.isNotEmpty) {
        await fb.collection('restaurants').doc(ownerId).update(restUpdate);
      }

      // 2. Update the document in 'sections/{sectionId}/items/{itemId}'
      final itemUpdate = {
        if (profileData['restaurantName'] != null) 'name': profileData['restaurantName'],
        if (profileData['phone'] != null) 'phone': profileData['phone'],
        if (profileData['address'] != null) 'address': profileData['address'],
        if (profileData['cuisineType'] != null) 'specialty': profileData['cuisineType'],
        if (profileData['photoUrl'] != null) 'imageUrl': profileData['photoUrl'],
        if (profileData['coverImageUrl'] != null) 'coverImageUrl': profileData['coverImageUrl'],
      };

      if (itemUpdate.isNotEmpty) {
        final refs = await _findSectionItemRefs(ownerId);
        for (var itemRef in refs) {
          await itemRef.update(itemUpdate);
        }
      }
    } catch (e) {
      debugPrint('Error syncing restaurant profile: $e');
    }
  }
}
