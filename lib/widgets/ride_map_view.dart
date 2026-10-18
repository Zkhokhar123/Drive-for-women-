import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

/// Map camera helper — works with OpenStreetMap (no Google API key).
class RideMapController {
  final MapController _inner = MapController();

  MapController get raw => _inner;

  Future<void> move(LatLng target, double zoom) async {
    try {
      _inner.move(target, zoom);
    } catch (_) {}
  }

  Future<void> fitPoints(List<LatLng> points, {double padding = 80}) async {
    if (points.isEmpty) return;
    try {
      if (points.length == 1) {
        _inner.move(points.first, 15);
        return;
      }
      final bounds = LatLngBounds.fromPoints(points);
      _inner.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: EdgeInsets.all(padding),
        ),
      );
    } catch (_) {
      _inner.move(points.first, 14);
    }
  }

  void dispose() {
    _inner.dispose();
  }
}

/// Visible map tiles via CartoCDN / OSM — shows roads without Google billing.
class RideMapView extends StatelessWidget {
  final RideMapController controller;
  final LatLng center;
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? rider;
  final LatLng? driver;
  final bool driverIsBike;
  final List<LatLng>? routePoints; // real road route from OSRM
  final void Function(LatLng point)? onLongPress;
  final double initialZoom;

  const RideMapView({
    super.key,
    required this.controller,
    required this.center,
    this.pickup,
    this.drop,
    this.rider,
    this.driver,
    this.driverIsBike = true,
    this.routePoints,
    this.onLongPress,
    this.initialZoom = 14,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final route = <LatLng>[];

    if (routePoints != null && routePoints!.length >= 2) {
      route.addAll(routePoints!);
    } else if (driver != null && rider != null) {
      route.addAll([driver!, rider!]);
    } else if (pickup != null && drop != null) {
      route.addAll([pickup!, drop!]);
    } else if (driver != null && pickup != null) {
      route.addAll([driver!, pickup!]);
    }

    if (rider != null) {
      markers.add(
        Marker(
          point: rider!,
          width: 52,
          height: 52,
          child: const _RiderDot(),
        ),
      );
    }
    if (pickup != null) {
      final sameAsRider = rider != null &&
          pickup!.latitude == rider!.latitude &&
          pickup!.longitude == rider!.longitude;
      if (!sameAsRider) {
        markers.add(
          Marker(
            point: pickup!,
            width: 40,
            height: 40,
            child: const Icon(Icons.location_on,
                color: AppTheme.success, size: 36),
          ),
        );
      }
    }
    if (drop != null) {
      markers.add(
        Marker(
          point: drop!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on,
              color: AppTheme.primary, size: 36),
        ),
      );
    }
    if (driver != null) {
      markers.add(
        Marker(
          point: driver!,
          width: 48,
          height: 48,
          child: _DriverPin(isBike: driverIsBike),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xFFE8EEF2),
      child: FlutterMap(
        mapController: controller.raw,
        options: MapOptions(
          initialCenter: center,
          initialZoom: initialZoom,
          minZoom: 4,
          maxZoom: 18,
          onLongPress:
              onLongPress == null ? null : (_, p) => onLongPress!(p),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.driveforwomen',
            maxNativeZoom: 18,
            keepBuffer: 2,
            panBuffer: 1,
            errorTileCallback: (tile, error, stack) {},
          ),
          if (route.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: route,
                  color: AppTheme.primary.withValues(alpha: 0.9),
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _RiderDot extends StatelessWidget {
  const _RiderDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3).withValues(alpha: 0.25),
          ),
        ),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2196F3),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverPin extends StatelessWidget {
  final bool isBike;
  const _DriverPin({required this.isBike});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isBike ? Icons.motorcycle_rounded : Icons.local_taxi_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
