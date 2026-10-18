import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Free OSRM public router — real road geometry (no API key).
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Returns route points along roads, or empty on failure.
  Future<List<LatLng>> fetchRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'DriveForWomen/1.0'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [from, to];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [from, to];

      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return [from, to];

      return coords.map((c) {
        final pair = c as List;
        return LatLng(
          (pair[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [from, to];
    }
  }

  /// Distance in km from OSRM, or haversine fallback.
  Future<double> fetchDistanceKm(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}'
        '?overview=false',
      );
      final res = await http
          .get(uri, headers: {'User-Agent': 'DriveForWomen/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _haversineKm(from, to);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _haversineKm(from, to);
      final meters = (routes.first['distance'] as num).toDouble();
      return meters / 1000.0;
    } catch (_) {
      return _haversineKm(from, to);
    }
  }

  double _haversineKm(LatLng a, LatLng b) {
    const d = Distance();
    return d.as(LengthUnit.Kilometer, a, b);
  }
}
