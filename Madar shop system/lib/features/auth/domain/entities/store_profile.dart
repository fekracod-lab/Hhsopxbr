import 'package:cloud_firestore/cloud_firestore.dart';

/// بيانات ملف المتجر في منظومة مدار (Store Profile Entity)
class StoreProfile {
  final String storeId;
  final String name;
  final String category;
  final String phone;
  final String address;
  final String logoUrl;
  final String coverUrl;
  final double deliveryFee;
  final bool isOpen;
  final bool isFeatured;
  final String ownerId;

  const StoreProfile({
    required this.storeId,
    required this.name,
    this.category = 'متجر عام',
    this.phone = '',
    this.address = '',
    this.logoUrl = '',
    this.coverUrl = '',
    this.deliveryFee = 0.0,
    this.isOpen = true,
    this.isFeatured = false,
    this.ownerId = '',
  });

  factory StoreProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawFee = data['deliveryFee'];
    return StoreProfile(
      storeId: doc.id,
      name: (data['name'] ?? 'متجر مدار').toString(),
      category: (data['category'] ?? 'عام').toString(),
      phone: (data['phone'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      logoUrl: (data['logoUrl'] ?? data['image'] ?? '').toString(),
      coverUrl: (data['coverUrl'] ?? '').toString(),
      deliveryFee: (rawFee is num) ? rawFee.toDouble() : 0.0,
      isOpen: data['isOpen'] == true || data['isOpen'] == null,
      isFeatured: data['isFeatured'] == true,
      ownerId: (data['ownerId'] ?? '').toString(),
    );
  }

  factory StoreProfile.fromMap(Map<String, dynamic> map) {
    return StoreProfile(
      storeId: (map['storeId'] ?? '').toString(),
      name: (map['name'] ?? 'متجر مدار').toString(),
      category: (map['category'] ?? 'عام').toString(),
      phone: (map['phone'] ?? '').toString(),
      address: (map['address'] ?? '').toString(),
      logoUrl: (map['logoUrl'] ?? '').toString(),
      coverUrl: (map['coverUrl'] ?? '').toString(),
      deliveryFee: (map['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      isOpen: map['isOpen'] == true,
      isFeatured: map['isFeatured'] == true,
      ownerId: (map['ownerId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'category': category,
      'phone': phone,
      'address': address,
      'logoUrl': logoUrl,
      'coverUrl': coverUrl,
      'deliveryFee': deliveryFee,
      'isOpen': isOpen,
      'isFeatured': isFeatured,
      'ownerId': ownerId,
    };
  }
}
