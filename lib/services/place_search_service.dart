import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One place result — street / landmark / area anywhere in Pakistan.
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

/// OpenStreetMap Nominatim + Photon — place search for Pakistan.
class PlaceSearchService {
  PlaceSearchService._();
  static final PlaceSearchService instance = PlaceSearchService._();

  static const _userAgent = 'DriveForWomen/1.0 (manoride; contact@local)';
  static const _pkBbox = '60.8,23.5,77.8,37.2';

  final _client = http.Client();

  Future<List<PlaceResult>> search(
    String query, {
    LatLng? near,
    int limit = 12,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final photon = await _searchPhoton(q, near: near, limit: limit);
    if (photon.isNotEmpty) return photon;

    return _searchNominatim(q, near: near, limit: limit);
  }

  Future<List<PlaceResult>> _searchPhoton(
    String query, {
    LatLng? near,
    int limit = 12,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'limit': '$limit',
        'lang': 'en',
        'bbox': _pkBbox,
      };
      if (near != null) {
        params['lat'] = near.latitude.toString();
        params['lon'] = near.longitude.toString();
      }

      final uri = Uri.https('photon.komoot.io', '/api/', params);
      final res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List? ?? [];
      final out = <PlaceResult>[];

      for (final f in features) {
        final map = f as Map<String, dynamic>;
        final props = map['properties'] as Map<String, dynamic>? ?? {};
        final geom = map['geometry'] as Map<String, dynamic>? ?? {};
        final coords = geom['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;

        final country = (props['country'] ?? props['countrycode'] ?? '')
            .toString()
            .toLowerCase();
        if (country.isNotEmpty &&
            country != 'pakistan' &&
            country != 'pk') {
          continue;
        }

        final name = (props['name'] ?? props['street'] ?? query).toString();
        final parts = <String>[
          if ((props['street'] ?? '').toString().isNotEmpty &&
              props['street'].toString() != name)
            props['street'].toString(),
          if ((props['housenumber'] ?? '').toString().isNotEmpty)
            'H#${props['housenumber']}',
          if ((props['district'] ?? props['suburb'] ?? '')
              .toString()
              .isNotEmpty)
            (props['district'] ?? props['suburb']).toString(),
          if ((props['city'] ?? props['town'] ?? props['county'] ?? '')
              .toString()
              .isNotEmpty)
            (props['city'] ?? props['town'] ?? props['county']).toString(),
          if ((props['state'] ?? '').toString().isNotEmpty)
            props['state'].toString(),
        ];

        out.add(PlaceResult(
          title: name,
          subtitle: parts.join(', '),
          point: LatLng(
            (coords[1] as num).toDouble(),
            (coords[0] as num).toDouble(),
          ),
          kind: (props['osm_value'] ?? props['type'] ?? 'place').toString(),
        ));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<PlaceResult>> _searchNominatim(
    String query, {
    LatLng? near,
    int limit = 12,
  }) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '$limit',
        'countrycodes': 'pk',
        'dedupe': '1',
      };
      if (near != null) {
        params['viewbox'] =
            '${near.longitude - 0.8},${near.latitude + 0.8},${near.longitude + 0.8},${near.latitude - 0.8}';
        params['bounded'] = '0';
      }

      final uri =
          Uri.https('nominatim.openstreetmap.org', '/search', params);
      final res = await _client
          .get(uri, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'en',
          })
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final list = jsonDecode(res.body) as List;
      return list.map((raw) {
        final m = raw as Map<String, dynamic>;
        final addr = m['address'] as Map<String, dynamic>? ?? {};
        final road = (addr['road'] ??
                addr['pedestrian'] ??
                addr['path'] ??
                '')
            .toString();
        final name = (m['name'] ?? road).toString();
        final display = (m['display_name'] ?? '').toString();
        final title = name.isNotEmpty
            ? name
            : display.split(',').first.trim();
        final subtitle = display.contains(',')
            ? display.substring(display.indexOf(',') + 1).trim()
            : [
                if ((addr['suburb'] ?? addr['neighbourhood'] ?? '')
                    .toString()
                    .isNotEmpty)
                  (addr['suburb'] ?? addr['neighbourhood']).toString(),
                if ((addr['city'] ??
                        addr['town'] ??
                        addr['village'] ??
                        '')
                    .toString()
                    .isNotEmpty)
                  (addr['city'] ?? addr['town'] ?? addr['village'])
                      .toString(),
                if ((addr['state'] ?? '').toString().isNotEmpty)
                  addr['state'].toString(),
              ].join(', ');

        return PlaceResult(
          title: title,
          subtitle: subtitle,
          point: LatLng(
            double.parse(m['lat'].toString()),
            double.parse(m['lon'].toString()),
          ),
          kind: (m['type'] ?? m['class'] ?? 'place').toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String> reverse(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'json',
        'addressdetails': '1',
        'zoom': '18',
      });
      final res = await _client
          .get(uri, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'en',
          })
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = m['address'] as Map<String, dynamic>? ?? {};
      final parts = <String>[
        if ((addr['road'] ?? '').toString().isNotEmpty) addr['road'].toString(),
        if ((addr['house_number'] ?? '').toString().isNotEmpty)
          'H#${addr['house_number']}',
        if ((addr['suburb'] ??
                addr['neighbourhood'] ??
                addr['quarter'] ??
                '')
            .toString()
            .isNotEmpty)
          (addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'])
              .toString(),
        if ((addr['city'] ?? addr['town'] ?? addr['village'] ?? '')
            .toString()
            .isNotEmpty)
          (addr['city'] ?? addr['town'] ?? addr['village']).toString(),
        if ((addr['state'] ?? '').toString().isNotEmpty)
          addr['state'].toString(),
      ];
      if (parts.isNotEmpty) return parts.join(', ');
      final display = (m['display_name'] ?? '').toString();
      if (display.isNotEmpty) return display;
    } catch (_) {}
    return 'Pin (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
  }

  Future<LatLng?> geocodeFirst(String query) async {
    final results = await search(query, limit: 1);
    return results.isEmpty ? null : results.first.point;
  }
}
