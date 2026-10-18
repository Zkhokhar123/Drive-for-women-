import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ride_map_view.dart';
import '../../services/ride_service.dart';
import '../../services/user_session.dart';

class DriverNavigationTab extends StatefulWidget {
  final String rideId;
  final String riderId;
  final String riderName;
  final String pickup;
  final String drop;
  final int fare;
  final double riderLat;
  final double riderLng;
  final double? dropLat;
  final double? dropLng;

  const DriverNavigationTab({
    super.key,
    this.rideId = '',
    required this.riderId,
    required this.riderName,
    required this.pickup,
    required this.drop,
    required this.fare,
    this.riderLat = 24.8607,
    this.riderLng = 67.0011,
    this.dropLat,
    this.dropLng,
  });

  @override
  State<DriverNavigationTab> createState() => _DriverNavigationTabState();
}

class _DriverNavigationTabState extends State<DriverNavigationTab> {
  final _mapController = RideMapController();

  late LatLng _customerLatLng;
  late LatLng _driverLatLng;

  double _distanceRemainingMeters = 0;
  int _etaMinutes = 0;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription? _rideSub;
  bool _arrived = false;
  bool _rideStarted = false;

  @override
  void initState() {
    super.initState();
    _customerLatLng = LatLng(widget.riderLat, widget.riderLng);
    _driverLatLng = LatLng(widget.riderLat, widget.riderLng);
    _updateDistance();
    _startLiveGps();
    _watchCustomer();
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _rideSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _updateDistance() {
    final target = _rideStarted && widget.dropLat != null
        ? LatLng(widget.dropLat!, widget.dropLng ?? widget.riderLng)
        : _customerLatLng;
    _distanceRemainingMeters = Geolocator.distanceBetween(
      _driverLatLng.latitude,
      _driverLatLng.longitude,
      target.latitude,
      target.longitude,
    );
    _etaMinutes = (_distanceRemainingMeters / 300).round();
    if (_etaMinutes < 1 && _distanceRemainingMeters > 20) _etaMinutes = 1;
    if (_distanceRemainingMeters <= 40 && !_rideStarted) _arrived = true;
  }

  Future<void> _startLiveGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _driverLatLng = LatLng(pos.latitude, pos.longitude);
        _updateDistance();
      });
      _fitMapToBounds();
      _pushDriverLoc(pos.latitude, pos.longitude);

      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _driverLatLng = LatLng(p.latitude, p.longitude);
          _updateDistance();
        });
        _fitMapToBounds();
        _pushDriverLoc(p.latitude, p.longitude);
      });
    } catch (_) {}
  }

  void _pushDriverLoc(double lat, double lng) {
    final rid = widget.rideId.isNotEmpty
        ? widget.rideId
        : UserSession.instance.activeRideId;
    if (rid.isEmpty || !RideService.instance.isReady) return;
    RideService.instance.updateDriverLocation(rid, lat, lng);
  }

  void _watchCustomer() {
    final rid = widget.rideId.isNotEmpty
        ? widget.rideId
        : UserSession.instance.activeRideId;
    if (rid.isEmpty || !RideService.instance.isReady) return;
    _rideSub = RideService.instance.watchRide(rid).listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      final cLat = (d['customerLat'] as num?)?.toDouble() ?? 0;
      final cLng = (d['customerLng'] as num?)?.toDouble() ?? 0;
      setState(() {
        if (cLat != 0 && cLng != 0) {
          _customerLatLng = LatLng(cLat, cLng);
        }
        final st = d['status'] as String? ?? '';
        if (st == 'ongoing') _rideStarted = true;
        if (st == 'completed') {
          UserSession.instance.activeRideId = '';
        }
        _updateDistance();
      });
    });
  }

  void _fitMapToBounds() {
    _mapController.fitPoints([_driverLatLng, _customerLatLng], padding: 70);
  }

  void _onArrivedAtPickup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Ride Start',
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You are at the pickup location.\nRider: ${widget.riderName}\nDrop: ${widget.drop}',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Wait',
                style: TextStyle(color: AppTheme.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success),
            onPressed: () async {
              final rid = widget.rideId.isNotEmpty
                  ? widget.rideId
                  : UserSession.instance.activeRideId;
              if (rid.isNotEmpty && RideService.instance.isReady) {
                await RideService.instance.startRide(rid);
              }
              if (!mounted) return;
              Navigator.pop(context);
              setState(() {
                _rideStarted = true;
                _arrived = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Ride Started! Navigate to ${widget.drop}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Start Ride'),
          ),
        ],
      ),
    );
  }

  void _callCustomer() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling ${widget.riderName}...'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text(
          'SOS Alert',
          style: TextStyle(
              color: AppTheme.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Send emergency alert with GPS '
          '(${_driverLatLng.latitude.toStringAsFixed(4)}, '
          '${_driverLatLng.longitude.toStringAsFixed(4)})?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              final rid = widget.rideId.isNotEmpty
                  ? widget.rideId
                  : UserSession.instance.activeRideId;
              if (rid.isNotEmpty && RideService.instance.isReady) {
                await RideService.instance.triggerSos(
                  rideId: rid,
                  lat: _driverLatLng.latitude,
                  lng: _driverLatLng.longitude,
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────
          Positioned.fill(child: _buildMap()),

          // ── Top status overlay ────────────────────────────
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.navigation_rounded,
                            color: AppTheme.success, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Navigating to pickup',
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded,
                            color: AppTheme.textHint, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        widget.riderName,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Icon(
                        _arrived
                            ? Icons.check_circle_rounded
                            : Icons.directions_car_rounded,
                        color:
                            _arrived ? AppTheme.success : AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _arrived
                            ? 'Arrived!'
                            : '${_distanceRemainingMeters.toStringAsFixed(0)} m',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _arrived
                                ? AppTheme.success
                                : AppTheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),

          // ── Bottom sheet ──────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 14),

                  // Rider name + pickup
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          widget.riderName.isNotEmpty
                              ? widget.riderName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.riderName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.pickup,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textHint, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Call button
                      IconButton(
                        style: IconButton.styleFrom(
                            backgroundColor: AppTheme.bgCard),
                        icon: const Icon(Icons.call_rounded,
                            color: AppTheme.success),
                        onPressed: _callCustomer,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Distance / ETA / Fare row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoTile(
                          icon: Icons.social_distance_rounded,
                          value:
                              '${(_distanceRemainingMeters / 1000).toStringAsFixed(1)} km',
                          label: 'Distance',
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.08)),
                        _InfoTile(
                          icon: Icons.timer_rounded,
                          value: _arrived ? 'Now' : '$_etaMinutes min',
                          label: 'ETA',
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withValues(alpha: 0.08)),
                        _InfoTile(
                          icon: Icons.local_offer_rounded,
                          value: 'PKR ${widget.fare}',
                          label: 'Agreed',
                          valueColor: AppTheme.success,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (_arrived && !_rideStarted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Arrived at Pickup',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _onArrivedAtPickup,
                      ).animate().fadeIn(duration: 300.ms).scaleXY(
                            begin: 0.92,
                            end: 1.0,
                            curve: Curves.easeOut,
                            duration: 300.ms,
                          ),
                    ),

                  if (_rideStarted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text(
                          'Complete Ride',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () async {
                          final rid = widget.rideId.isNotEmpty
                              ? widget.rideId
                              : UserSession.instance.activeRideId;
                          if (rid.isNotEmpty &&
                              RideService.instance.isReady) {
                            await RideService.instance.completeRide(rid);
                          }
                          UserSession.instance.activeRideId = '';
                          if (!mounted) return;
                          Navigator.pop(context);
                        },
                      ),
                    ),

                  // SOS button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const Text('SOS',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _triggerSOS,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return RideMapView(
      controller: _mapController,
      center: _driverLatLng,
      rider: _customerLatLng,
      driver: _driverLatLng,
      driverIsBike: true,
      initialZoom: 14,
    );
  }
}


// ── Info tile ─────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textHint, fontSize: 10)),
      ],
    );
  }
}
