import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceData {
  final String id;
  final String name;
  final String category;
  final String address;
  final LatLng position;
  final String imageUrl;
  final double rating;
  final String phone;

  const PlaceData({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.position,
    this.imageUrl = '',
    this.rating = 0.0,
    this.phone = '',
  });

  factory PlaceData.fromJson(Map<String, dynamic> json) {
    return PlaceData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      address: json['address'] ?? '',
      position: LatLng((json['lat'] ?? 0.0).toDouble(), (json['lng'] ?? 0.0).toDouble()),
      imageUrl: json['imageUrl'] ?? '',
      rating: ((json['rating'] ?? 0.0) as num).toDouble(),
      phone: json['phone'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'lat': position.latitude,
      'lng': position.longitude,
      'imageUrl': imageUrl,
      'rating': rating,
      'phone': phone,
    };
  }

  // To maintain compatibility with older code that used PlaceData (if any)
  String get type => category;
}
