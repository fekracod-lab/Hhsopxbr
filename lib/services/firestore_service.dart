import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream for top rated items (general)
  Stream<List<Map<String, dynamic>>> streamTopRated({int limit = 10}) {
    return _db
        .collectionGroup('items')
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'image': data['imageUrl'] ?? '',
              'rating': data['rating'] ?? 0.0,
              'isOpen': data['isOpen'] ?? true,
              ...data,
            };
          }).toList();
        });
  }

  // Stream for famous merchants (restaurants/cafes)
  Stream<List<Map<String, dynamic>>> streamFamousMerchants() {
    return _db
        .collectionGroup('items')
        .where('type', whereIn: ['restaurant', 'cafe']) // Assuming there's a type field or similar
        .orderBy('rating', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'image': data['imageUrl'] ?? '',
              'rating': data['rating'] ?? 0.0,
              'isOpen': data['isOpen'] ?? true,
              ...data,
            };
          }).toList();
        });
  }

  // Stream for popular items (dishes)
  Stream<List<Map<String, dynamic>>> streamPopularItems() {
    return _db
        .collectionGroup('menu') // Assuming dishes are in 'menu' subcollection
        .orderBy('orderCount', descending: true) // Assuming there's an orderCount
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'image': data['imageUrl'] ?? '',
              'price': data['price'] ?? 0,
              'rating': data['rating'] ?? 0.0,
              ...data,
            };
          }).toList();
        });
  }

  // Stream for categories (sections)
  Stream<List<String>> streamCategories() {
    return _db.collection('sections').orderBy('order').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => (doc.data()['label'] ?? '') as String).toList();
    });
  }

  // Stream for items by category (simple)
  Stream<List<Map<String, dynamic>>> streamItemsByCategorySimple(String sectionId) {
    return _db.collection('sections').doc(sectionId).collection('items').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    });
  }
}
