import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteStep {
  final LatLng location; // Maneuver point
  final double distance; // Step distance (meters)
  final double duration; // Step duration (seconds)
  final String name; // Street name
  final String type; // maneuver.type
  final String? modifier; // maneuver.modifier: right/left/straight/uturn...

  RouteStep({
    required this.location,
    required this.distance,
    required this.duration,
    required this.name,
    required this.type,
    required this.modifier,
  });
}

class RouteResult {
  final List<LatLng> points; // polyline decoded points
  final List<RouteStep> steps; // turn-by-turn steps
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

class OsrmRouteService {
  static const String _base = 'https://router.project-osrm.org';

  static Future<RouteResult> getDrivingRoute({
    required LatLng start,
    required LatLng end,
    String overview = 'full',
    bool includeSteps = true,
  }) async {
    final url = Uri.parse(
      '$_base/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=$overview&geometries=polyline6&steps=$includeSteps&annotations=false',
    );

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('OSRM request failed: ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') {
      throw Exception('OSRM error: ${json['code']}');
    }

    final routes = (json['routes'] as List);
    if (routes.isEmpty) throw Exception('No routes returned');

    final route0 = routes.first as Map<String, dynamic>;
    final geom = route0['geometry'] as String;
    final distance = (route0['distance'] as num).toDouble();
    final duration = (route0['duration'] as num).toDouble();

    final points = _decodePolyline6(geom);

    // steps parsing
    final legs = (route0['legs'] as List);
    final steps = <RouteStep>[];
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final legSteps = (legMap['steps'] as List);
      for (final s in legSteps) {
        final m = s as Map<String, dynamic>;
        final maneuver = (m['maneuver'] as Map<String, dynamic>);
        final loc = (maneuver['location'] as List);
        final step = RouteStep(
          location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          distance: (m['distance'] as num).toDouble(),
          duration: (m['duration'] as num).toDouble(),
          name: (m['name'] ?? '').toString(),
          type: (maneuver['type'] ?? '').toString(),
          modifier: maneuver['modifier']?.toString(),
        );
        steps.add(step);
      }
    }

    return RouteResult(
      points: points,
      steps: steps,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  // polyline6 decode (OSRM default with geometries=polyline6)
  static List<LatLng> _decodePolyline6(String encoded) {
    int index = 0;
    int lat = 0;
    int lng = 0;
    final List<LatLng> coordinates = [];

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      // OSRM use 1e6 for polyline6
      coordinates.add(LatLng(lat / 1000000, lng / 1000000));
    }

    return coordinates;
  }
}
