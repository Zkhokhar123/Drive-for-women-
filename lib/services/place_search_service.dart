import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// One place result.
class PlaceResult {
  final String title;
  final String subtitle;
  final LatLng point;
  final String kind;

  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.point,
    this.kind = 'place',
  });

  String get fullLabel =>
      subtitle.isEmpty ? title : '$title, $subtitle';
}

/// Google Places Autocomplete + Geocoding for Pakistan.
class PlaceSearchService {
  PlaceSearchService._();
  static final PlaceSearchService instance = PlaceSearchService._();

  static const _apiKey = 'AIzaSyBSBfH0HAJzItY_EtJRkN9M5e-EJODrvc0';
  // Karachi center bias
  static const _locationBias = '24.8607,67.0011';
  static const _radius = '50000';

  final _client = http.Client();

  Future<List<PlaceResult>> search(
    String query, {
    LatLng? near,
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    try {
      final lat = near?.latitude.toString() ?? _locationBias.split(',')[0];
      final lng = near?.longitude.toString() ?? _locationBias.split(',')[1];

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(q)}'
        '&location=$lat,$lng'
        '&radius=$_radius'
        '&components=country:pk'
        '&key=$_apiKey',
      );

      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        return [];
      }

      final predictions = data['predictions'] as List? ?? [];
      final results = <PlaceResult>[];

      for (final p in predictions.take(limit)) {
        final map = p as Map<String, dynamic>;
        final desc = map['description'] as String? ?? '';
        final terms = map['terms'] as List? ?? [];
        final title = terms.isNotEmpty
            ? (terms.first['value'] as String? ?? desc)
            : desc;
        final subtitle = desc.contains(',')
            ? desc.substring(desc.indexOf(',') + 1).trim()
            : '';
        final placeId = map['place_id'] as String? ?? '';

        // Get coordinates from place_id
        final coords = await _getCoordinates(placeId);
        if (coords == null) continue;

        results.add(PlaceResult(
          title: title,
          subtitle: subtitle,
          point: coords,
          kind: (map['types'] as List?)?.firstOrNull?.toString() ?? 'place',
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<LatLng?> _getCoordinates(String placeId) async {
    if (placeId.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_apiKey',
      );
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final loc =
          data['result']['geometry']['location'] as Map<String, dynamic>;
      return LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> reverse(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=$_apiKey',
      );
      final res = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) {
        return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
      return results.first['formatted_address'] as String? ??
          'Pin ($lat, $lng)';
    } catch (_) {
      return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
    }
  }

  Future<LatLng?> geocodeFirst(String query) async {
    final results = await search(query, limit: 1);
    return results.isEmpty ? null : results.first.point;
  }
}
