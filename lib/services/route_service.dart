import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Google Directions API â€” real road routes.
/// Falls back to straight line if API fails.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  static const _apiKey = 'AIzaSyA_SDOzgQJshq7dLqWyR47Yhi4ZOBEst4s';

  /// Returns decoded polyline points along real roads.
  Future<List<LatLng>> fetchRoute(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving'
        '&key=$_apiKey',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return [from, to];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status != 'OK') {
        debugPrint('Directions API: $status');
        return [from, to];
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return [from, to];

      final encodedPolyline =
          routes.first['overview_polyline']['points'] as String?;
      if (encodedPolyline == null || encodedPolyline.isEmpty) return [from, to];

      return _decodePolyline(encodedPolyline);
    } catch (e) {
      debugPrint('RouteService error: $e');
      return [from, to];
    }
  }

  /// Distance in km via Google Directions.
  Future<double> fetchDistanceKm(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving'
        '&key=$_apiKey',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _haversineKm(from, to);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return _haversineKm(from, to);

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _haversineKm(from, to);

      final legs = routes.first['legs'] as List?;
      if (legs == null || legs.isEmpty) return _haversineKm(from, to);

      final meters =
          (legs.first['distance']['value'] as num).toDouble();
      return meters / 1000.0;
    } catch (_) {
      return _haversineKm(from, to);
    }
  }

  /// ETA in minutes via Google Directions.
  Future<int> fetchEtaMinutes(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving'
        '&departure_time=now'
        '&key=$_apiKey',
      );
      final res = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _estimateMinutes(from, to);

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return _estimateMinutes(from, to);

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _estimateMinutes(from, to);

      final legs = routes.first['legs'] as List?;
      if (legs == null || legs.isEmpty) return _estimateMinutes(from, to);

      final leg = legs.first as Map<String, dynamic>;
      // Use duration_in_traffic if available, else duration
      final durationMap = leg['duration_in_traffic'] ?? leg['duration'];
      final seconds = (durationMap['value'] as num).toInt();
      return (seconds / 60).ceil();
    } catch (_) {
      return _estimateMinutes(from, to);
    }
  }

  // â”€â”€ Private helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = (dLat / 2 * (dLat / 2)).abs() +
        (dLng / 2 * (dLng / 2)).abs() *
            (a.latitude * 3.14159 / 180).abs() *
            (b.latitude * 3.14159 / 180).abs();
    return 2 * r * (h < 1 ? h : 1);
  }

  double _rad(double deg) => deg * 3.14159265358979 / 180;

  int _estimateMinutes(LatLng from, LatLng to) {
    final km = _haversineKm(from, to);
    return (km / 0.5).ceil().clamp(1, 120);
  }
}
