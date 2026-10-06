import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// --- أصناف التنسيق والألوان (كما في كودك الأصلي) ---

class PlaceStyle {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const PlaceStyle({required this.icon, required this.color, required this.backgroundColor});
}

class PlaceColors {
  static const Color food = Color(0xFFFF9800);
  static const Color shopping = Color(0xFF42A5F5);
  static const Color health = Color(0xFFEF5350);
  static const Color education = Color(0xFF7E57C2);
  static const Color services = Color(0xFF5C6BC0);
  static const Color park = Color(0xFF66BB6A);
  static const Color worship = Color(0xFF26A69A);
  static const Color transport = Color(0xFF8D6E63);
  static const Color government = Color(0xFF607D8B);
  static const Color def = Color(0xFF78909C);
}

final Map<String, PlaceStyle> placeStyles = {
  'mosque': const PlaceStyle(
    icon: Icons.mosque,
    color: Colors.white,
    backgroundColor: PlaceColors.worship,
  ),
  'worship': const PlaceStyle(
    icon: Icons.star_rate_rounded,
    color: Colors.white,
    backgroundColor: PlaceColors.worship,
  ),
  'restaurant': const PlaceStyle(
    icon: Icons.restaurant,
    color: Colors.white,
    backgroundColor: PlaceColors.food,
  ),
  'cafe': const PlaceStyle(
    icon: Icons.local_cafe,
    color: Colors.white,
    backgroundColor: Color(0xFF795548),
  ),
  'food': const PlaceStyle(
    icon: Icons.fastfood,
    color: Colors.white,
    backgroundColor: PlaceColors.food,
  ),
  'hospital': const PlaceStyle(
    icon: Icons.local_hospital,
    color: Colors.white,
    backgroundColor: PlaceColors.health,
  ),
  'pharmacy': const PlaceStyle(
    icon: Icons.medication,
    color: Colors.white,
    backgroundColor: PlaceColors.health,
  ),
  'doctor': const PlaceStyle(
    icon: Icons.person_pin_circle,
    color: Colors.white,
    backgroundColor: PlaceColors.health,
  ),
  'school': const PlaceStyle(
    icon: Icons.school,
    color: Colors.white,
    backgroundColor: PlaceColors.education,
  ),
  'university': const PlaceStyle(
    icon: Icons.account_balance,
    color: Colors.white,
    backgroundColor: PlaceColors.education,
  ),
  'market': const PlaceStyle(
    icon: Icons.shopping_cart,
    color: Colors.white,
    backgroundColor: PlaceColors.shopping,
  ),
  'mall': const PlaceStyle(
    icon: Icons.local_mall,
    color: Colors.white,
    backgroundColor: PlaceColors.shopping,
  ),
  'store': const PlaceStyle(
    icon: Icons.storefront,
    color: Colors.white,
    backgroundColor: PlaceColors.shopping,
  ),
  'fuel': const PlaceStyle(
    icon: Icons.local_gas_station,
    color: Colors.white,
    backgroundColor: PlaceColors.transport,
  ),
  'parking': const PlaceStyle(
    icon: Icons.local_parking,
    color: Colors.white,
    backgroundColor: PlaceColors.transport,
  ),
  'mechanic': const PlaceStyle(
    icon: Icons.car_repair,
    color: Colors.white,
    backgroundColor: PlaceColors.transport,
  ),
  'bank': const PlaceStyle(
    icon: Icons.account_balance_wallet,
    color: Colors.white,
    backgroundColor: PlaceColors.services,
  ),
  'police': const PlaceStyle(
    icon: Icons.local_police,
    color: Colors.white,
    backgroundColor: PlaceColors.government,
  ),
  'government': const PlaceStyle(
    icon: Icons.location_city,
    color: Colors.white,
    backgroundColor: PlaceColors.government,
  ),
  'park': const PlaceStyle(
    icon: Icons.park,
    color: Colors.white,
    backgroundColor: PlaceColors.park,
  ),
  'gym': const PlaceStyle(
    icon: Icons.fitness_center,
    color: Colors.white,
    backgroundColor: PlaceColors.park,
  ),
  'landmark': const PlaceStyle(
    icon: Icons.flag,
    color: Colors.white,
    backgroundColor: Color(0xFFE91E63),
  ),
  'home': const PlaceStyle(
    icon: Icons.home,
    color: Colors.white,
    backgroundColor: Color(0xFF1E88E5),
  ),
  'work': const PlaceStyle(
    icon: Icons.work,
    color: Colors.white,
    backgroundColor: Color(0xFF546E7A),
  ),
  'default': const PlaceStyle(
    icon: Icons.place,
    color: Colors.white,
    backgroundColor: PlaceColors.def,
  ),
};

PlaceStyle getPlaceStyle(String text) {
  final query = text.toLowerCase();
  for (final entry in placeStyles.entries) {
    if (query.contains(entry.key)) return entry.value;
  }
  if (query.contains('نافورة') || query.contains('تمثال') || query.contains('نصب')) {
    return placeStyles['landmark']!;
  }
  if (query.contains('مطعم') || query.contains('اكل') || query.contains('برجر')) {
    return placeStyles['restaurant']!;
  }
  if (query.contains('كوفي') || query.contains('مقهى') || query.contains('شاي')) {
    return placeStyles['cafe']!;
  }
  if (query.contains('مستشفى') || query.contains('عيادة') || query.contains('صيدلية')) {
    return placeStyles['hospital']!;
  }

  return placeStyles['default']!;
}

// --- بناء العلامة (Marker) ---

Marker buildPoiMarker({
  required String markerId,
  required LatLng position,
  required String type,
  String? name,
  VoidCallback? onTap,
}) {
  final style = getPlaceStyle(type);

  return Marker(
    markerId: MarkerId(markerId),
    position: position,
    infoWindow: name != null ? InfoWindow(title: name) : InfoWindow.noText,
    onTap: onTap,
    icon: BitmapDescriptor.defaultMarkerWithHue(_getHueFromColor(style.backgroundColor)),
  );
}

double _getHueFromColor(Color color) {
  if (color == PlaceColors.food) return BitmapDescriptor.hueCyan;
  if (color == PlaceColors.shopping) return BitmapDescriptor.hueAzure;
  if (color == PlaceColors.health) return BitmapDescriptor.hueRed;
  if (color == PlaceColors.education) return BitmapDescriptor.hueViolet;
  if (color == PlaceColors.services) return BitmapDescriptor.hueBlue;
  if (color == PlaceColors.park) return BitmapDescriptor.hueGreen;
  if (color == PlaceColors.worship) return BitmapDescriptor.hueCyan;
  if (color == PlaceColors.transport) return BitmapDescriptor.hueRose;
  if (color == PlaceColors.government) return BitmapDescriptor.hueBlue;
  return BitmapDescriptor.hueRed;
}
