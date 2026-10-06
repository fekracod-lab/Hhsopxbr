import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/icon_utils.dart';

class RideType {
  final String id;
  final String title;
  final String desc;
  final String imageUrl; // Kept for backward compatibility if needed
  final IconData icon;
  final double baseFare;
  final double pricePerKm;
  final double pricePerMinute; // New: Time-based pricing
  final double minFare; // New: Minimum fare for this type
  final int capacity;
  final double multiplier; // New: multiplier for price calculations

  // Getters for backward compatibility with local RideType definitions
  String get name => title;
  String get description => desc;
  String get image => imageUrl;

  RideType({
    required this.id,
    required this.title,
    required this.desc,
    required this.imageUrl,
    required this.icon,
    required this.baseFare,
    required this.pricePerKm,
    required this.pricePerMinute,
    required this.minFare,
    required this.capacity,
    this.multiplier = 1.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'imageUrl': imageUrl,
      'iconCode': icon.codePoint,
      'baseFare': baseFare,
      'pricePerKm': pricePerKm,
      'pricePerMinute': pricePerMinute,
      'minFare': minFare,
      'capacity': capacity,
      'multiplier': multiplier,
    };
  }

  /// Maps ride type id to its local asset path
  static String _defaultImageForId(String id) {
    switch (id) {
      case 'saver':
        return 'assets/cars/standard.png';
      case 'comfort':
        return 'assets/cars/premium.png';
      case 'family':
        return 'assets/cars/family.png';
      default:
        return 'assets/cars/standard.png';
    }
  }

  factory RideType.fromMap(Map<String, dynamic> map) {
    final id = map['id'] ?? '';
    final rawImage = map['imageUrl'] as String? ?? '';
    return RideType(
      id: id,
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      imageUrl: rawImage.isNotEmpty ? rawImage : _defaultImageForId(id),
      icon: IconUtils.getIconByCode(map['iconCode'] ?? Icons.directions_car.codePoint),
      baseFare: (map['baseFare'] ?? 0.0).toDouble(),
      pricePerKm: (map['pricePerKm'] ?? 0.0).toDouble(),
      pricePerMinute: (map['pricePerMinute'] ?? 0.0).toDouble(),
      minFare: (map['minFare'] ?? 0.0).toDouble(),
      capacity: map['capacity'] ?? 4,
      multiplier: (map['multiplier'] ?? 1.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideType && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class RideTypes {
  static final list = [
    RideType(
      id: 'saver',
      title: 'توفير',
      desc: 'الأرخص للمشاوير اليومية',
      imageUrl: 'assets/cars/standard.png',
      icon: Icons.local_taxi_rounded,
      baseFare: 500.0,
      pricePerKm: 250.0,
      pricePerMinute: 15.0,
      minFare: 750.0,
      capacity: 4,
      multiplier: 1.0,
    ),
    RideType(
      id: 'comfort',
      title: 'راحة',
      desc: 'سيارات حديثة ومريحة',
      imageUrl: 'assets/cars/premium.png',
      icon: Icons.directions_car_filled_rounded,
      baseFare: 1000.0,
      pricePerKm: 400.0,
      pricePerMinute: 30.0,
      minFare: 1500.0,
      capacity: 4,
      multiplier: 1.5,
    ),
    RideType(
      id: 'family',
      title: 'عائلي',
      desc: 'سيارات واسعة للعوائل',
      imageUrl: 'assets/cars/family.png',
      icon: Icons.airport_shuttle_rounded,
      baseFare: 2000.0,
      pricePerKm: 600.0,
      pricePerMinute: 50.0,
      minFare: 3000.0,
      capacity: 6,
      multiplier: 1.8,
    ),
  ];
}
