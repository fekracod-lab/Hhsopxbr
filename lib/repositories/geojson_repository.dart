import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/place_data.dart';

class GeoJsonRepository {
  static List<PlaceData>? _cachedPlaces;

  Future<List<PlaceData>> loadPlaces(String assetPath) async {
    if (_cachedPlaces != null) return _cachedPlaces!;

    try {
      final String jsonString = await rootBundle
          .loadString(assetPath)
          .timeout(const Duration(seconds: 5));
      final Map<String, dynamic> data = json.decode(jsonString);
      if (!data.containsKey('features')) return [];

      final features = data['features'] as List;
      List<PlaceData> loadedPlaces = [];

      for (var feature in features) {
        final geometry = feature['geometry'];
        final properties = feature['properties'];

        if (geometry['type'] == 'Point') {
          final List coords = geometry['coordinates'];
          loadedPlaces.add(
            PlaceData(
              id: properties['id']?.toString() ?? '',
              name: properties['name']?.toString() ?? 'مكان',
              position: LatLng(coords[1].toDouble(), coords[0].toDouble()),
              category: properties['type']?.toString() ?? 'default',
              address: properties['address']?.toString() ?? 'القائم',
            ),
          );
        }
      }
      _cachedPlaces = loadedPlaces;
      return loadedPlaces;
    } catch (e) {
      debugPrint("Error loading GeoJSON: $e");
      return [];
    }
  }
}
