import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';

/// Google Maps controller wrapper.
class RideMapController {
  final Completer<GoogleMapController> _completer = Completer();

  Future<void> move(LatLng target, double zoom) async {
    final ctrl = await _completer.future;
    ctrl.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: zoom),
    ));
  }

  Future<void> fitPoints(List<LatLng> points, {double padding = 80}) async {
    if (points.isEmpty) return;
    final ctrl = await _completer.future;
    if (points.length == 1) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.002, minLng - 0.002),
        northeast: LatLng(maxLat + 0.002, maxLng + 0.002),
      ),
      padding,
    ));
  }

  void onMapCreated(GoogleMapController controller) {
    if (!_completer.isCompleted) _completer.complete(controller);
  }

  void dispose() {}
}

/// Google Maps widget — shows real roads, markers, polylines.
class RideMapView extends StatefulWidget {
  final RideMapController controller;
  final LatLng center;
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? rider;
  final LatLng? driver;
  final bool driverIsBike;
  final List<LatLng>? routePoints;
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
  State<RideMapView> createState() => _RideMapViewState();
}

class _RideMapViewState extends State<RideMapView> {
  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Rider marker (blue dot)
    if (widget.rider != null) {
      markers.add(Marker(
        markerId: const MarkerId('rider'),
        position: widget.rider!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ));
    }

    // Pickup marker (green)
    if (widget.pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ));
    }

    // Drop marker (pink/rose)
    if (widget.drop != null) {
      markers.add(Marker(
        markerId: const MarkerId('drop'),
        position: widget.drop!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }

    // Driver marker (violet)
    if (widget.driver != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: widget.driver!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(
          title: widget.driverIsBike ? 'Driver (Bike)' : 'Driver (Car)',
        ),
      ));
    }

    // Route polyline
    final routePts = widget.routePoints;
    if (routePts != null && routePts.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: routePts,
        color: AppTheme.primary,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    } else if (widget.driver != null && widget.rider != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.driver!, widget.rider!],
        color: AppTheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    } else if (widget.pickup != null && widget.drop != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [widget.pickup!, widget.drop!],
        color: AppTheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.center,
        zoom: widget.initialZoom,
      ),
      onMapCreated: widget.controller.onMapCreated,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      onLongPress: widget.onLongPress,
      mapType: MapType.normal,
      style: _darkMapStyle,
    );
  }
}

// Dark map style JSON for Google Maps
const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1a1a2e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8888aa"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1a2e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#222238"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#2d2d4a"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3d3d5c"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#e91e8c", "weight": 0.5}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0d0d1a"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#333355"}]}
]
''';
