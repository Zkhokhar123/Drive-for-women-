import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ride_map_view.dart';
import '../../services/user_session.dart';
import '../../services/ride_service.dart';
import '../../services/route_service.dart';
import 'customer_track_tab.dart';

class CustomerBidTab extends StatefulWidget {
  final String pickup;
  final String drop;
  final String rideType;
  final int proposedFare;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final List<LatLng>? routePoints;

  const CustomerBidTab({
    super.key,
    required this.pickup,
    required this.drop,
    required this.rideType,
    required this.proposedFare,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    this.routePoints,
  });

  @override
  State<CustomerBidTab> createState() => _CustomerBidTabState();
}

class _CustomerBidTabState extends State<CustomerBidTab> {
  String? _rideId;
  String? _error;
  bool _creating = true;
  int _searchSeconds = 0;
  Timer? _searchTimer;
  StreamSubscription? _offersSub;
  final List<Map<String, dynamic>> _offers = [];
  final _mapController = RideMapController();
  LatLng? _riderLatLng;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _riderSub;

  @override
  void initState() {
    super.initState();
    _routePoints = widget.routePoints ?? [];
    _loadRider();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _searchSeconds++);
    });
    _createAndListen();
  }

  Future<void> _createAndListen() async {
    if (!RideService.instance.isReady) {
      setState(() {
        _creating = false;
        _error = 'Firebase not connected. Cannot find live drivers.';
      });
      return;
    }
    try {
      if (_routePoints.length < 2) {
        _routePoints = await RouteService.instance.fetchRoute(
          LatLng(widget.pickupLat, widget.pickupLng),
          LatLng(widget.dropLat, widget.dropLng),
        );
      }
      final routePayload = _routePoints
          .map((p) => [p.latitude, p.longitude])
          .toList();
      final id = await RideService.instance.createRide(
        pickup: widget.pickup,
        drop: widget.drop,
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        dropLat: widget.dropLat,
        dropLng: widget.dropLng,
        rideType: widget.rideType,
        proposedFare: widget.proposedFare,
        routePoints: routePayload,
      );
      if (!mounted) return;
      setState(() {
        _rideId = id;
        _creating = false;
      });
      UserSession.instance.activeRideId = id;
      _offersSub = RideService.instance.watchOffers(id).listen((snap) {
        if (!mounted) return;
        final list = <Map<String, dynamic>>[];
        for (final doc in snap.docs) {
          final d = doc.data();
          if (d['status'] == 'declined') continue;
          list.add({
            'id': doc.id,
            'driverId': d['driverId'] ?? doc.id,
            'name': d['driverName'] ?? 'Driver',
            'initials': d['initials'] ??
                ((d['driverName'] as String?)?.isNotEmpty == true
                    ? (d['driverName'] as String)[0].toUpperCase()
                    : 'D'),
            'vehicle': d['vehicle'] ?? '',
            'rating': (d['rating'] as num?)?.toDouble() ?? 5.0,
            'fare': (d['fare'] as num?)?.toInt() ?? widget.proposedFare,
          });
        }
        setState(() {
          _offers
            ..clear()
            ..addAll(list);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = e.toString().replaceFirst('StateError: ', '');
      });
    }
  }

  Future<void> _loadRider() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _riderLatLng = LatLng(pos.latitude, pos.longitude));
      _riderSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _riderLatLng = LatLng(p.latitude, p.longitude));
        final rid = _rideId;
        if (rid != null && RideService.instance.isReady) {
          RideService.instance
              .updateCustomerLocation(rid, p.latitude, p.longitude);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _riderLatLng = LatLng(widget.pickupLat, widget.pickupLng));
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _offersSub?.cancel();
    _riderSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = _searchSeconds ~/ 60;
    final s = _searchSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    final rid = _rideId;
    if (rid == null) return;
    try {
      await RideService.instance.acceptOffer(
        rideId: rid,
        offerId: offer['id'] as String,
        offer: offer,
      );
      _searchTimer?.cancel();
      final session = UserSession.instance;
      session.driverName = offer['name'] as String;
      session.driverInitials = offer['initials'] as String;
      session.driverVehicle = offer['vehicle'] as String;
      session.driverRating = offer['rating'] as double;
      session.activeRideId = rid;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerTrackTab(
            rideId: rid,
            pickup: widget.pickup,
            drop: widget.drop,
            fare: offer['fare'] as int,
            driverName: offer['name'] as String,
            driverInitials: offer['initials'] as String,
            vehicleInfo: offer['vehicle'] as String,
            driverRating: offer['rating'] as double,
            rideType: widget.rideType,
            pickupLat: widget.pickupLat,
            pickupLng: widget.pickupLng,
            dropLat: widget.dropLat,
            dropLng: widget.dropLng,
            routePoints: _routePoints,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Accept failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _declineOffer(String offerId) async {
    final rid = _rideId;
    if (rid != null) {
      try {
        await RideService.instance
            .declineOffer(rideId: rid, offerId: offerId);
      } catch (_) {}
    }
    setState(() => _offers.removeWhere((o) => o['id'] == offerId));
  }

  Future<void> _cancelSearch() async {
    _searchTimer?.cancel();
    final rid = _rideId;
    if (rid != null && RideService.instance.isReady) {
      try {
        await RideService.instance.cancelRide(rid);
      } catch (_) {}
    }
    UserSession.instance.activeRideId = '';
    if (mounted) Navigator.pop(context);
  }

  LatLng get _pickupLatLng => LatLng(widget.pickupLat, widget.pickupLng);
  LatLng get _dropLatLng => LatLng(widget.dropLat, widget.dropLng);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _cancelSearch,
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        color: AppTheme.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _creating
                              ? 'Creating ride...'
                              : _error != null
                                  ? 'Search failed'
                                  : 'Finding Drivers...',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        Text(
                          '${widget.pickup.split('(')[0].trim()} → ${widget.drop}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (_error == null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_rounded,
                              color: AppTheme.primary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _timerLabel,
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 90,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_rounded,
                      color: AppTheme.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Your offer: PKR ${widget.proposedFare}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _error != null
                              ? 'Error'
                              : _offers.isEmpty
                                  ? 'Waiting for drivers...'
                                  : '${_offers.length} driver${_offers.length > 1 ? 's' : ''} responded',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimary),
                        ),
                        TextButton(
                          onPressed: _cancelSearch,
                          child: const Text('Cancel',
                              style: TextStyle(color: AppTheme.error)),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.error, fontSize: 13)),
                    )
                  else if (_creating || _offers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_find_rounded,
                                  size: 48, color: AppTheme.textHint)
                              .animate(
                                  onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(
                                  begin: 0.9,
                                  end: 1.1,
                                  duration: 1000.ms,
                                  curve: Curves.easeInOut),
                          const SizedBox(height: 12),
                          Text(
                              _creating
                                  ? 'Posting your ride to nearby drivers...'
                                  : 'Looking for nearby female drivers...',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _offers.length,
                        itemBuilder: (context, i) {
                          final offer = _offers[i];
                          final isAcceptFare =
                              offer['fare'] == widget.proposedFare;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: isAcceptFare
                                      ? AppTheme.success
                                          .withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppTheme.primary,
                                      child: Text(
                                        offer['initials'] as String,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                offer['name'] as String,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppTheme
                                                        .textPrimary),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 14),
                                              Text(
                                                ' ${offer['rating']}',
                                                style: const TextStyle(
                                                    color: Colors.amber,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            offer['vehicle'] as String,
                                            style: const TextStyle(
                                                color: AppTheme.textHint,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'PKR ${offer['fare']}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              color: isAcceptFare
                                                  ? AppTheme.success
                                                  : AppTheme.textPrimary),
                                        ),
                                        if (!isAcceptFare)
                                          const Text('counter',
                                              style: TextStyle(
                                                  color: AppTheme.textHint,
                                                  fontSize: 10)),
                                        if (isAcceptFare)
                                          const Text('your price ✓',
                                              style: TextStyle(
                                                  color: AppTheme.success,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.success,
                                          foregroundColor: Colors.white,
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () =>
                                            _acceptOffer(offer),
                                        child: Text(
                                            'Accept  PKR ${offer['fare']}',
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.15)),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        minimumSize: Size.zero,
                                      ),
                                      onPressed: () => _declineOffer(
                                          offer['id'] as String),
                                      child: const Text('Decline',
                                          style: TextStyle(
                                              color: AppTheme.textHint)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ).animate().fadeIn(
                              delay: (i * 100).ms, duration: 400.ms);
                        },
                      ),
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
      center: _pickupLatLng,
      pickup: _pickupLatLng,
      drop: _dropLatLng,
      rider: _riderLatLng,
      routePoints: _routePoints.isEmpty ? null : _routePoints,
      initialZoom: 13,
    );
  }
}
