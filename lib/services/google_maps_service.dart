import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:dalal_alqaim/models/route_option.dart';

/// Centralized Google Maps API service.
/// All Google Maps HTTP calls go through this class.
class GoogleMapsService {
  GoogleMapsService._();
  static final instance = GoogleMapsService._();

  static String get apiKey {
    if (!kIsWeb && Platform.isIOS) {
      return 'AIzaSyCzilWUVXoSXZuCmDU4fnQS2iLRCCRoOBg';
    }
    return 'AIzaSyDMK173hA6CPbyTdUkDVQeQSQ2zFpzKba8';
  }
  static const String _packageName = 'com.dalal.alqaimapp';
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client = http.Client();

  // SHA-1 fingerprint cache (fetched once at runtime)
  String? _sha1Fingerprint;

  /// Get SHA-1 fingerprint of the signing certificate at runtime.
  /// This is needed for Android-restricted API keys when making REST calls.
  Future<String?> _getSha1() async {
    if (kIsWeb) return null;
    if (_sha1Fingerprint != null) return _sha1Fingerprint;

    try {
      // Use MethodChannel to call Android's PackageManager
      const channel = MethodChannel('com.dalal.alqaimapp/signing');
      final String? sha1 = await channel.invokeMethod('getSha1');
      _sha1Fingerprint = sha1;
      debugPrint(' SHA-1 fingerprint: $sha1');
      return sha1;
    } catch (e) {
      debugPrint(' Could not get SHA-1 fingerprint: $e');
      return null;
    }
  }

  /// Build platform-specific headers for API key restricted calls.
  Future<Map<String, String>> _androidHeaders() async {
    if (kIsWeb) return <String, String>{}; // No headers on Web
    if (Platform.isIOS) {
      return <String, String>{'X-Ios-Bundle-Identifier': 'com.madaralairaq'};
    }
    final headers = <String, String>{'X-Android-Package': _packageName};
    final sha1 = await _getSha1();
    if (sha1 != null) {
      headers['X-Android-Cert'] = sha1;
    }
    return headers;
  }

  // ─────────────────────────────────────────────
  // 1. PLACES SEARCH (New API primary, legacy fallback)
  // ─────────────────────────────────────────────

  /// Search for places using the **Places API (New)** `searchText` endpoint.
  /// Falls back to legacy Text Search, then Geocoding.
  Future<List<PlaceResult>> searchPlaces(
    String query, {
    LatLng? near,
    int maxResults = 20,
    double radiusMeters = 50000,
  }) async {
    final center = near ?? const LatLng(34.3416, 41.0772); // القائم default

    // ── Try 1: Places API (New) ──
    try {
      final results = await _searchPlacesNew(query, center, maxResults, radiusMeters);
      if (results.isNotEmpty) {
        debugPrint(' Places API (New): ${results.length} results');
        return results;
      }
    } catch (e) {
      debugPrint(' Places API (New) failed: $e');
    }

    // ── Try 2: Legacy Text Search ──
    try {
      final results = await _searchPlacesLegacy(query, center, radiusMeters);
      if (results.isNotEmpty) {
        debugPrint(' Legacy Places API: ${results.length} results');
        return results;
      }
    } catch (e) {
      debugPrint(' Legacy Places API failed: $e');
    }

    // ── Try 3: Geocoding API ──
    try {
      final results = await _searchGeocode(query);
      if (results.isNotEmpty) {
        debugPrint(' Geocoding API: ${results.length} results');
        return results;
      }
    } catch (e) {
      debugPrint(' Geocoding API failed: $e');
    }

    debugPrint(' All search APIs returned empty for: $query');
    return [];
  }

  Future<List<PlaceResult>> _searchPlacesNew(
    String query,
    LatLng center,
    int maxResults,
    double radius,
  ) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
    final response = await _client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'places.id,places.displayName,places.formattedAddress,places.location,places.types',
            'Accept-Language': 'ar',
            ...androidH,
          },
          body: json.encode({
            'textQuery': query,
            'maxResultCount': maxResults,
            'locationBias': {
              'circle': {
                'center': {'latitude': center.latitude, 'longitude': center.longitude},
                'radius': radius,
              },
            },
          }),
        )
        .timeout(_timeout);

    debugPrint(' Places (New) status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List? places = data['places'];
      if (places == null || places.isEmpty) return [];

      return places.where((p) => p['location'] != null).map((p) {
        final loc = p['location'];
        return PlaceResult(
          id: p['id'] ?? 'new_${loc['latitude']}_${loc['longitude']}',
          name:
              p['displayName']?['text'] ??
              p['formattedAddress']?.toString().split(',').first ??
              query,
          address: p['formattedAddress'] ?? '',
          location: LatLng(
            (loc['latitude'] as num).toDouble(),
            (loc['longitude'] as num).toDouble(),
          ),
          source: 'google_new',
          category: (p['types'] as List?)?.firstOrNull?.toString(),
        );
      }).toList();
    } else {
      debugPrint(' Places (New) error body: ${response.body}');
    }
    return [];
  }

  Future<List<PlaceResult>> _searchPlacesLegacy(String query, LatLng center, double radius) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json'
      '?query=${Uri.encodeComponent(query)}'
      '&key=$apiKey'
      '&language=ar'
      '&location=${center.latitude},${center.longitude}'
      '&radius=${radius.toInt()}',
    );

    final response = await _client.get(url, headers: androidH).timeout(_timeout);
    debugPrint(' Places (Legacy) status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint(' Places (Legacy) API status: ${data['status']}');
      final List? results = data['results'];
      if (results == null || results.isEmpty) return [];

      return results.where((r) => r['geometry']?['location'] != null).map((r) {
        final geo = r['geometry']['location'];
        return PlaceResult(
          id: r['place_id'] ?? 'legacy_${geo['lat']}_${geo['lng']}',
          name: r['name'] ?? r['formatted_address']?.toString().split(',').first ?? query,
          address: r['formatted_address'] ?? '',
          location: LatLng((geo['lat'] as num).toDouble(), (geo['lng'] as num).toDouble()),
          source: 'google_legacy',
          category: (r['types'] as List?)?.firstOrNull?.toString(),
        );
      }).toList();
    }
    return [];
  }

  Future<List<PlaceResult>> _searchGeocode(String query) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?address=${Uri.encodeComponent(query)}'
      '&key=$apiKey'
      '&language=ar',
    );

    final response = await _client.get(url, headers: androidH).timeout(_timeout);
    debugPrint(' Geocoding status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint(' Geocoding API status: ${data['status']}');
      final List? results = data['results'];
      if (results == null || results.isEmpty) return [];

      return results.where((r) => r['geometry']?['location'] != null).map((r) {
        final geo = r['geometry']['location'];
        return PlaceResult(
          id: r['place_id'] ?? 'geo_${geo['lat']}_${geo['lng']}',
          name: r['formatted_address']?.toString().split(',').first ?? query,
          address: r['formatted_address'] ?? '',
          location: LatLng((geo['lat'] as num).toDouble(), (geo['lng'] as num).toDouble()),
          source: 'geocode',
        );
      }).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────
  // 2. REVERSE GEOCODE
  // ─────────────────────────────────────────────

  /// Reverse geocode a location to a human-readable address.
  Future<String> reverseGeocode(LatLng location) async {
    // ── Try 1: Nearby Search (Places New API) — find real POIs ──
    try {
      final name = await _nearbySearchNew(location);
      if (name != null) {
        debugPrint(' Nearby (New): $name');
        return name;
      }
    } catch (e) {
      debugPrint(' Nearby (New) failed: $e');
    }

    // ── Try 2: Legacy Nearby Search ──
    try {
      final name = await _nearbySearchLegacy(location);
      if (name != null) {
        debugPrint(' Nearby (Legacy): $name');
        return name;
      }
    } catch (e) {
      debugPrint(' Nearby (Legacy) failed: $e');
    }

    // ── Try 3: Geocoding API ──
    try {
      final name = await _reverseGeocodeApi(location);
      if (name != null) {
        debugPrint(' Reverse Geocode: $name');
        return name;
      }
    } catch (e) {
      debugPrint(' Reverse Geocode failed: $e');
    }

    return 'موقع غير معروف';
  }

  /// Get structured regional administrative data (Governorate, City).
  Future<({String? governorate, String? city, String? district})> getRegionalDetails(LatLng location) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=${location.latitude},${location.longitude}'
      '&language=ar'
      '&key=$apiKey',
    );

    try {
      final response = await _client.get(url, headers: androidH).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];

        if (results.isNotEmpty) {
          final components = results.first['address_components'] as List? ?? [];

          String? governorate;
          String? city;
          String? district;

          for (final c in components) {
            final name = c['long_name'] as String?;
            final types = List<String>.from(c['types'] ?? []);
            if (name == null || name.contains('+')) continue;

            // administrative_area_level_1 = Governorate (e.g. Al-Anbar)
            if (types.contains('administrative_area_level_1')) governorate = name;
            
            // locality = City (e.g. Al-Qaim, Ramadi)
            if (types.contains('locality')) city = name;
            
            // neighborhood or sublocality_level_1 = District (e.g. Al-Obaidi)
            if (types.contains('sublocality_level_1') || 
                types.contains('neighborhood') ||
                types.contains('sublocality')) {
              district ??= name;
            }
          }
          return (governorate: governorate, city: city, district: district);
        }
      }
    } catch (e) {
      debugPrint(' getRegionalDetails failed: $e');
    }
    return (governorate: null, city: null, district: null);
  }

  Future<String?> _nearbySearchNew(LatLng location) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final response = await _client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'places.displayName,places.formattedAddress,places.types',
            'Accept-Language': 'ar',
            ...androidH,
          },
          body: json.encode({
            'maxResultCount': 5,
            'locationRestriction': {
              'circle': {
                'center': {'latitude': location.latitude, 'longitude': location.longitude},
                'radius': 200,
              },
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List? places = data['places'];
      if (places != null && places.isNotEmpty) {
        for (final p in places) {
          final name = p['displayName']?['text'] as String?;
          final address = p['formattedAddress'] as String?;
          final types = List<String>.from(p['types'] ?? []);

          if (name == null || name.contains('+') || name.length < 3) continue;
          if (types.contains('political') || types.contains('plus_code')) continue;

          if (address != null && !address.contains('+')) {
            return '$name، ${address.split(',').first}';
          }
          return name;
        }
      }
    }
    return null;
  }

  Future<String?> _nearbySearchLegacy(LatLng location) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${location.latitude},${location.longitude}'
      '&rankby=distance'
      '&language=ar'
      '&key=$apiKey',
    );

    final response = await _client.get(url, headers: androidH).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];

      for (final p in results) {
        final name = p['name'] as String?;
        final vicinity = p['vicinity'] as String?;
        final types = List<String>.from(p['types'] ?? []);

        if (name == null || name.contains('+') || name.length < 3) continue;
        if (types.contains('political') || types.contains('plus_code')) continue;

        if (vicinity != null && !vicinity.contains('+')) {
          return '$name، $vicinity';
        }
        return name;
      }
    }
    return null;
  }

  Future<String?> _reverseGeocodeApi(LatLng location) async {
    final androidH = await _androidHeaders();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=${location.latitude},${location.longitude}'
      '&language=ar'
      '&key=$apiKey',
    );

    final response = await _client.get(url, headers: androidH).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];

      if (results.isNotEmpty) {
        final components = results.first['address_components'] as List? ?? [];

        String? street;
        String? subLocality;
        String? locality;
        String? admin;

        for (final c in components) {
          final name = c['long_name'] as String?;
          final types = List<String>.from(c['types'] ?? []);
          if (name == null || name.contains('+')) continue;

          if (types.contains('route')) street = name;
          if (types.contains('sublocality') ||
              types.contains('sublocality_level_1') ||
              types.contains('neighborhood')) {
            subLocality ??= name;
          }
          if (types.contains('locality')) locality = name;
          if (types.contains('administrative_area_level_1')) admin = name;
        }

        final parts = <String>[];
        if (street != null) parts.add(street);
        if (subLocality != null) parts.add(subLocality);
        if (locality != null) parts.add(locality);
        if (admin != null && parts.length < 2) parts.add(admin);

        if (parts.isNotEmpty) return parts.join('،');
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // 3. PLACE DETAILS
  // ─────────────────────────────────────────────

  /// Get place details by place ID using Places API (New).
  Future<String?> getPlaceName(String placeId) async {
    // ── Try 1: Places API (New) ──
    try {
      final androidH = await _androidHeaders();
      final url = Uri.parse('https://places.googleapis.com/v1/places/$placeId');
      final response = await _client
          .get(
            url,
            headers: {
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'displayName,formattedAddress',
              'Accept-Language': 'ar',
              ...androidH,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final name = data['displayName']?['text'] as String?;
        final address = data['formattedAddress'] as String?;

        if (name != null && !name.contains('+')) {
          if (address != null && !address.contains('+')) {
            return '$name، ${address.split(',').first}';
          }
          return name;
        }
      }
    } catch (e) {
      debugPrint(' Place Details (New) failed: $e');
    }

    // ── Try 2: Legacy Place Details ──
    try {
      final androidH = await _androidHeaders();
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,vicinity,address_component'
        '&language=ar'
        '&key=$apiKey',
      );

      final response = await _client.get(url, headers: androidH).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        if (result != null) {
          final name = result['name'] as String?;
          final vicinity = result['vicinity'] as String?;

          if (name != null && vicinity != null && !vicinity.contains('+')) {
            return '$name، $vicinity';
          }
          if (name != null && !name.contains('+')) return name;
        }
      }
    } catch (e) {
      debugPrint(' Place Details (Legacy) failed: $e');
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // 4. DIRECTIONS (أقصر وأرخص مسار)
  // ─────────────────────────────────────────────

  /// Get the shortest/cheapest route between two points using Directions API.
  /// Requests alternative routes and picks the one with minimum distance.
  Future<({List<LatLng> points, double distance, double duration})> getDirections(
    LatLng start,
    LatLng end,
  ) async {
    final androidH = await _androidHeaders();
    int retries = 3;
    while (retries > 0) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${end.latitude},${end.longitude}'
          '&key=$apiKey'
          '&language=ar'
          '&alternatives=true',
        );

        final response = await _client
            .get(url, headers: androidH)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'OK' &&
              data['routes'] != null &&
              (data['routes'] as List).isNotEmpty) {
            final routes = data['routes'] as List;

            // ── اختيار أقصر مسار (الأرخص) ──
            Map<String, dynamic>? bestRoute;
            double bestDistance = double.infinity;

            for (final route in routes) {
              final leg = route['legs'][0];
              final dist = (leg['distance']['value'] as num).toDouble();
              if (dist < bestDistance) {
                bestDistance = dist;
                bestRoute = route;
              }
            }

            if (bestRoute != null) {
              final leg = bestRoute['legs'][0];
              final distance = (leg['distance']['value'] as num).toDouble();
              final duration = (leg['duration']['value'] as num).toDouble();
              final points = _decodePolyline(bestRoute['overview_polyline']['points']);

              if (routes.length > 1) {
                debugPrint(
                  'تم العثور على ${routes.length} مسارات، تم اختيار الأقصر: ${(distance / 1000).toStringAsFixed(1)} كم',
                );
              }

              return (points: points, distance: distance, duration: duration);
            }
          } else {
            debugPrint(' Directions status: ${data['status']}');
            if (data['status'] == 'ZERO_RESULTS' || data['status'] == 'OVER_QUERY_LIMIT') break;
          }
        }
      } catch (e) {
        debugPrint(' Directions attempt failed (${4 - retries}): $e');
      }
      retries--;
      if (retries > 0) await Future.delayed(const Duration(seconds: 2));
    }
    return (points: <LatLng>[], distance: 0.0, duration: 0.0);
  }

  /// Get all route alternatives between two points.
  /// Returns a list of [RouteOption] classified as fastest, cheapest, shortest.
  Future<List<RouteOption>> getDirectionsAlternatives(
    LatLng start,
    LatLng end,
  ) async {
    final androidH = await _androidHeaders();
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${start.latitude},${start.longitude}'
        '&destination=${end.latitude},${end.longitude}'
        '&key=$apiKey'
        '&language=ar'
        '&alternatives=true',
      );

      final response = await _client
          .get(url, headers: androidH)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final routes = data['routes'] as List;
          final List<RouteOption> results = [];

          for (final route in routes) {
            final leg = route['legs'][0];
            final dist = (leg['distance']['value'] as num).toDouble();
            final dur = (leg['duration']['value'] as num).toDouble();
            final pts = _decodePolyline(route['overview_polyline']['points']);

            results.add(RouteOption(
              points: pts,
              distanceMeters: dist,
              durationSeconds: dur,
              tag: 'google_alt',
              label: 'مسار مقترح',
            ));
          }

          debugPrint('تم العثور على ${routes.length} مسارات من Google');
          return results;
        }
      }
    } catch (e) {
      debugPrint(' getDirectionsAlternatives failed: $e');
    }
    return [];
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ─────────────────────────────────────────────
  // 5. ADDRESS VALIDATION (New)
  // ─────────────────────────────────────────────

  /// Validate an address using the Address Validation API.
  /// NOTE: This API must be enabled in Google Cloud Console.
  Future<Map<String, dynamic>?> validateAddress(String address) async {
    try {
      final androidH = await _androidHeaders();
      final url = Uri.parse(
        'https://addressvalidation.googleapis.com/v1:validateAddress'
        '?key=$apiKey',
      );

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json', ...androidH},
            body: json.encode({
              'address': {
                'regionCode': 'IQ', // Iraq
                'addressLines': [address],
              },
              'enableUspsCass': false,
            }),
          )
          .timeout(_timeout);

      debugPrint(' Address Validation status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint(' Address Validation error: ${response.body}');
      }
    } catch (e) {
      debugPrint(' Address Validation failed: $e');
    }
    return null;
  }
}

/// A lightweight place result model.
class PlaceResult {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final String source;
  final String? category;

  const PlaceResult({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.source,
    this.category,
  });
}
