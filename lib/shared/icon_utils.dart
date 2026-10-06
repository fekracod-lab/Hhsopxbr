import 'package:flutter/material.dart';

/// A utility class to manage IconData instantiation in a way that satisfies
/// Flutter's icon tree-shaking requirements.
///
/// Tree-shaking requires all [IconData] to be constant. By maintaining a
/// static registry of all possible icons, we ensure they are included in the
/// font bundle while avoiding dynamic IconData(...) calls.
class IconUtils {
  /// A map of code point to constant IconData.
  /// Note: If multiple icons share the same code point, only one is listed here.
  static const Map<int, IconData> _codePointMap = {
    // General
    0xe13d: Icons.category,
    0xe318: Icons.home,
    0xe7ef: Icons.work,
    0xe491: Icons.person,
    0xe57f: Icons.settings,
    0xe3ab: Icons.map,
    0xe8b6: Icons.search,
    0xe838: Icons.star,
    0xe87d: Icons.favorite,
    0xe5d2: Icons.menu,
    0xe5cd: Icons.close,
    0xe145: Icons.add,
    0xe254: Icons.edit,
    0xe872: Icons.delete,
    0xe3f4: Icons.image,
    0xe0b0: Icons.camera_alt,
    0xe0cd: Icons.phone,
    0xe150: Icons.email,
    0xe0c8: Icons.location_on,

    // Food & Drink
    0xe532: Icons.restaurant,
    0xe561: Icons.restaurant_menu,
    0xe57a: Icons.fastfood,
    0xe556: Icons.local_dining,
    0xe541: Icons.local_cafe,
    0xe17a: Icons.coffee,
    0xe540: Icons.local_bar,
    0xe552: Icons.local_pizza,
    0xef96: Icons.bakery_dining,
    0xea0c: Icons.icecream,
    0xea1c: Icons.liquor, // Also sports_rugby
    0xeb91: Icons.set_meal,
    0xeaa4: Icons.outdoor_grill,
    0xefb0: Icons.rice_bowl,
    0xefb3: Icons.soup_kitchen,
    0xe261: Icons.flatware,
    0xef9a: Icons.bento,
    0xf05a: Icons.tapas,
    0xef97: Icons.breakfast_dining,
    0xef9b: Icons.brunch_dining,
    0xef9e: Icons.dinner_dining,
    0xefa6: Icons.lunch_dining,
    0xefab: Icons.ramen_dining,
    0xefb1: Icons.takeout_dining,
    0xe3e7: Icons.cake,
    0xeaac: Icons.cookie,
    0xea23: Icons.emoji_events,
    0xe6c5: Icons.pie_chart,
    0xea3c: Icons.celebration, // Also church
    0xe8f6: Icons.card_giftcard,
    0xe544: Icons.local_drink,
    0xe7a5: Icons.water_drop,
    0xea1b: Icons.emoji_food_beverage, // Also sports_motorsports
    0xeb48: Icons.blender, // Also pool

    // Shopping
    0xf016b: Icons.shopping_bag,
    0xe8cc: Icons.shopping_cart,
    0xe8cb: Icons.shopping_basket,
    0xe8d1: Icons.store,
    0xea39: Icons.storefront,
    0xe55c: Icons.local_grocery_store,
    0xe54e: Icons.local_offer,

    // Services
    0xe548: Icons.local_hospital,
    0xe550: Icons.local_pharmacy,
    0xf016e: Icons.medical_services,
    0xe546: Icons.local_gas_station,
    0xe53e: Icons.local_atm,
    0xe54a: Icons.local_laundry_service,
    0xf048b: Icons.cleaning_services,
    0xe549: Icons.hotel,

    // Education
    0xe80c: Icons.school,
    0xe54b: Icons.local_library,
    0xeea2: Icons.menu_book,

    // Entertainment & Sports
    0xe476: Icons.park,
    0xeb43: Icons.fitness_center,
    0xeb4c: Icons.spa,
    0xea12: Icons.sports_soccer,
    0xe3f0: Icons.movie,
    0xe8da: Icons.theaters,
    0xe338: Icons.videogame_asset,
    0xea14: Icons.sports_basketball,
    0xea15: Icons.sports_golf,
    0xea16: Icons.sports_tennis,
    0xea17: Icons.sports_volleyball,
    0xea18: Icons.sports_handball,
    0xea19: Icons.sports_cricket,
    0xea1a: Icons.sports_mma,
    0xea1d: Icons.sports_football,
    0xea1e: Icons.sports_hockey,
    0xea1f: Icons.sports_kabaddi,

    // Transport
    0xe531: Icons.directions_car,
    0xe559: Icons.local_taxi,
    0xe530: Icons.directions_bus,
    0xe539: Icons.flight,
    0xe190: Icons.directions_bike,
    0xe534: Icons.directions_railway,
    0xe566: Icons.directions_run,
    0xe535: Icons.directions_subway,
    0xe536: Icons.directions_transit,
    0xe538: Icons.directions_walk,
    0xeb41: Icons.airport_shuttle_rounded,

    // Religion
    0xeb4b: Icons.mosque,

    // Trades
    0xe869: Icons.build,
    0xea3d: Icons.construction,
    0xf0088: Icons.plumbing,
    0xf16d: Icons.electrical_services,
  };

  /// A map of icon names to constant IconData.
  static const Map<String, IconData> _nameMap = {
    'category': Icons.category,
    'home': Icons.home,
    'work': Icons.work,
    'person': Icons.person,
    'settings': Icons.settings,
    'map': Icons.map,
    'search': Icons.search,
    'star': Icons.star,
    'favorite': Icons.favorite,
    'menu': Icons.menu,
    'close': Icons.close,
    'add': Icons.add,
    'edit': Icons.edit,
    'delete': Icons.delete,
    'image': Icons.image,
    'camera': Icons.camera_alt,
    'phone': Icons.phone,
    'email': Icons.email,
    'location': Icons.location_on,
    'restaurant': Icons.restaurant,
    'fastfood': Icons.fastfood,
    'local_dining': Icons.local_dining,
    'local_cafe': Icons.local_cafe,
    'coffee': Icons.coffee,
    'local_bar': Icons.local_bar,
    'local_pizza': Icons.local_pizza,
    'bakery_dining': Icons.bakery_dining,
    'icecream': Icons.icecream,
    'liquor': Icons.liquor,
    'shopping_bag': Icons.shopping_bag,
    'shopping_cart': Icons.shopping_cart,
    'shopping_basket': Icons.shopping_basket,
    'store': Icons.store,
    'storefront': Icons.storefront,
    'local_hospital': Icons.local_hospital,
    'local_pharmacy': Icons.local_pharmacy,
    'local_gas_station': Icons.local_gas_station,
    'local_atm': Icons.local_atm,
    'hotel': Icons.hotel,
    'school': Icons.school,
    'park': Icons.park,
    'fitness_center': Icons.fitness_center,
    'pool': Icons.pool,
    'spa': Icons.spa,
    'sports_soccer': Icons.sports_soccer,
    'directions_car': Icons.directions_car,
    'local_taxi': Icons.local_taxi,
    'taxi': Icons.local_taxi,
    'directions_bus': Icons.directions_bus,
    'flight': Icons.flight,
    'mosque': Icons.mosque,
    'build': Icons.build,
    'construction': Icons.construction,
    'plumbing': Icons.plumbing,
    'electrical_services': Icons.electrical_services,
  };

  /// Returns a constant [IconData] for the given code point.
  /// If the code is not in the registry, it returns a default icon to satisfy
  /// the compiler while allowing the build to proceed.
  static IconData getIconByCode(int? code) {
    if (code == null) return Icons.help_outline;
    return _codePointMap[code] ?? Icons.help_outline;
  }

  /// Returns a constant [IconData] for the given name.
  static IconData getIconByName(String? name) {
    if (name == null) return Icons.help_outline;
    return _nameMap[name.toLowerCase().trim()] ?? Icons.help_outline;
  }

  /// Checks if a string is a numeric code point and returns the icon,
  /// otherwise tries to match by name.
  static IconData getIconFromString(String? value) {
    if (value == null || value.isEmpty) return Icons.help_outline;

    final int? code = int.tryParse(value);
    if (code != null) {
      return _codePointMap[code] ?? Icons.help_outline;
    }

    return getIconByName(value);
  }
}
