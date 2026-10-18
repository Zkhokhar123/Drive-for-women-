import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ride_map_view.dart';
import '../../services/ride_service.dart';
import '../../services/route_service.dart';
import '../../services/user_session.dart';

class CustomerTrackTab extends StatefulWidget {
  final String rideId;
  final String pickup;
  final String drop;
  final int fare;
  final String driverName;
  final String driverInitials;
  final String vehicleInfo;
  final double driverRating;
  final String rideType;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final List<LatLng>? routePoints;

  const CustomerTrackTab({
    super.key,
    this.rideId = '',
    required this.pickup,
    required this.drop,
    required this.fare,
    this.driverName = '',
    this.driverInitials = '',
    this.vehicleInfo = '',
    this.driverRating = 5.0,
    this.rideType = 'bike',
    this.pickupLat = 24.8607,
    this.pickupLng = 67.0011,
    this.dropLat = 24.8138,
    this.dropLng = 67.0299,
    this.routePoints,
  });

  @override
  State<CustomerTrackTab> createState() => _CustomerTrackTabState();
}

class _CustomerTrackTabState extends State<CustomerTrackTab> {
  bool _isChatOpen = false;
  final _chatInputController = TextEditingController();
  final _mapController = RideMapController();

  late LatLng _riderLatLng;
  LatLng? _driverLatLng;
  List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription? _rideSub;
  String _status = '';
  String _driverName = '';
  String _driverInitials = '';
  String _vehicleInfo = '';
  double _driverRating = 5.0;
  int _fare = 0;
  String _pickup = '';
  String _drop = '';
  String _rideType = 'bike';
  double _pickupLat = 24.8607;
  double _pickupLng = 67.0011;
  double _dropLat = 24.8138;
  double _dropLng = 67.0299;
  bool _completing = false;

  String get _effectiveRideId {
    if (widget.rideId.isNotEmpty) return widget.rideId;
    return UserSession.instance.activeRideId;
  }

  @override
  void initState() {
    super.initState();
    _pickup = widget.pickup;
    _drop = widget.drop;
    _fare = widget.fare;
    _driverName = widget.driverName;
    _driverInitials = widget.driverInitials;
    _vehicleInfo = widget.vehicleInfo;
    _driverRating = widget.driverRating;
    _rideType = widget.rideType;
    _pickupLat = widget.pickupLat;
    _pickupLng = widget.pickupLng;
    _dropLat = widget.dropLat;
    _dropLng = widget.dropLng;
    _riderLatLng = LatLng(_pickupLat, _pickupLng);
    _routePoints = widget.routePoints ?? [];
    _startGps();
    _attachRide();
  }

  @override
  void didUpdateWidget(covariant CustomerTrackTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rideId != widget.rideId ||
        UserSession.instance.activeRideId != _effectiveRideId) {
      _attachRide();
    }
  }

  void _attachRide() {
    _rideSub?.cancel();
    final rid = _effectiveRideId;
    if (rid.isEmpty || !RideService.instance.isReady) return;
    _rideSub = RideService.instance.watchRide(rid).listen((snap) {
      if (!snap.exists || !mounted) return;
      final d = snap.data()!;
      setState(() {
        _status = d['status'] as String? ?? '';
        _driverName = (d['driverName'] as String?)?.isNotEmpty == true
            ? d['driverName'] as String
            : _driverName;
        _vehicleInfo = (d['driverVehicle'] as String?)?.isNotEmpty == true
            ? d['driverVehicle'] as String
            : _vehicleInfo;
        _driverRating =
            (d['driverRating'] as num?)?.toDouble() ?? _driverRating;
        _driverInitials = _driverName.isNotEmpty
            ? _driverName[0].toUpperCase()
            : _driverInitials;
        _fare = (d['agreedFare'] as num?)?.toInt() ??
            (d['proposedFare'] as num?)?.toInt() ??
            _fare;
        _pickup = d['pickup'] as String? ?? _pickup;
        _drop = d['drop'] as String? ?? _drop;
        _rideType = d['rideType'] as String? ?? _rideType;
        _pickupLat = (d['pickupLat'] as num?)?.toDouble() ?? _pickupLat;
        _pickupLng = (d['pickupLng'] as num?)?.toDouble() ?? _pickupLng;
        _dropLat = (d['dropLat'] as num?)?.toDouble() ?? _dropLat;
        _dropLng = (d['dropLng'] as num?)?.toDouble() ?? _dropLng;
        final dLat = (d['driverLat'] as num?)?.toDouble() ?? 0;
        final dLng = (d['driverLng'] as num?)?.toDouble() ?? 0;
        if (dLat != 0 && dLng != 0) {
          _driverLatLng = LatLng(dLat, dLng);
        }
        final cLat = (d['customerLat'] as num?)?.toDouble();
        final cLng = (d['customerLng'] as num?)?.toDouble();
        if (cLat != null && cLng != null && cLat != 0) {
          _riderLatLng = LatLng(cLat, cLng);
        }
        final pts = d['routePoints'] as List?;
        if (pts != null && pts.isNotEmpty && _routePoints.isEmpty) {
          _routePoints = pts.map((p) {
            final pair = p as List;
            return LatLng(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            );
          }).toList();
        }
      });
      if (_driverLatLng != null) {
        _mapController.fitPoints([_driverLatLng!, _riderLatLng]);
      }
      if (_status == 'completed') {
        UserSession.instance.activeRideId = '';
      }
    });
    if (_routePoints.isEmpty) {
      RouteService.instance
          .fetchRoute(LatLng(_pickupLat, _pickupLng),
              LatLng(_dropLat, _dropLng))
          .then((r) {
        if (mounted && r.length >= 2) setState(() => _routePoints = r);
      });
    }
  }

  Future<void> _startGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      if (!mounted) return;
      setState(() => _riderLatLng = LatLng(pos.latitude, pos.longitude));
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 12,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() => _riderLatLng = LatLng(p.latitude, p.longitude));
        final rid = _effectiveRideId;
        if (rid.isNotEmpty && RideService.instance.isReady) {
          RideService.instance
              .updateCustomerLocation(rid, p.latitude, p.longitude);
        }
      });
    } catch (e) {
      debugPrint('GPS error: $e');
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _rideSub?.cancel();
    _chatInputController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _sendChat() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;
    final rid = _effectiveRideId;
    _chatInputController.clear();
    if (rid.isEmpty || !RideService.instance.isReady) return;
    await RideService.instance
        .sendMessage(rideId: rid, text: text, fromCustomer: true);
  }

  Future<void> _triggerSOS() async {
    final rid = _effectiveRideId;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('SOS Alert',
            style:
                TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        content: Text(
          'Send emergency alert with your live GPS '
          '(${_riderLatLng.latitude.toStringAsFixed(4)}, '
          '${_riderLatLng.longitude.toStringAsFixed(4)})?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textHint))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(context);
              if (rid.isNotEmpty && RideService.instance.isReady) {
                await RideService.instance.triggerSos(
                  rideId: rid,
                  lat: _riderLatLng.latitude,
                  lng: _riderLatLng.longitude,
                );
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('SOS sent with your live location'),
                backgroundColor: AppTheme.error,
              ));
            },
            child: const Text('Confirm Dispatch'),
          ),
        ],
      ),
    );
  }

  Future<void> _startRide() async {
    final rid = _effectiveRideId;
    if (rid.isEmpty) return;
    await RideService.instance.startRide(rid);
  }

  Future<void> _completeRide() async {
    final rid = _effectiveRideId;
    if (rid.isEmpty || _completing) return;
    setState(() => _completing = true);
    try {
      await RideService.instance.completeRide(rid);
      UserSession.instance.activeRideId = '';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ride completed — saved to history'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  double get _distanceMeters {
    if (_driverLatLng == null) return 0;
    final target = _status == 'ongoing'
        ? LatLng(_dropLat, _dropLng)
        : _riderLatLng;
    return Geolocator.distanceBetween(
      _driverLatLng!.latitude,
      _driverLatLng!.longitude,
      target.latitude,
      target.longitude,
    );
  }

  int get _etaMinutes {
    final m = _distanceMeters;
    var eta = (m / 300).round();
    if (eta < 1 && m > 20) eta = 1;
    return eta;
  }

  @override
  Widget build(BuildContext context) {
    final rid = _effectiveRideId;
    if (rid.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 56, color: AppTheme.textHint),
              SizedBox(height: 16),
              Text('No active ride',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      fontSize: 16)),
              SizedBox(height: 8),
              Text(
                'Book a ride and accept a driver offer to track live GPS here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textHint, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final arrived = _status == 'accepted' && _distanceMeters > 0 && _distanceMeters <= 40;
    final completed = _status == 'completed';
    final ongoing = _status == 'ongoing';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard.withValues(alpha: 0.93),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded,
                          color: AppTheme.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Live GPS: ${_riderLatLng.latitude.toStringAsFixed(4)}, ${_riderLatLng.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _status.isEmpty ? '…' : _status,
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded,
                          color: AppTheme.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_pickup.split('(')[0].trim()} ➔ $_drop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          completed
                              ? 'Ride completed'
                              : ongoing
                                  ? 'En route to drop · $_etaMinutes min'
                                  : arrived
                                      ? 'Driver has arrived!'
                                      : _driverName.isEmpty
                                          ? 'Waiting for driver...'
                                          : '$_driverName arriving in $_etaMinutes min',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: (arrived || completed)
                                ? AppTheme.success
                                : Colors.white,
                          ),
                        ),
                      ),
                      if (!completed && _driverLatLng != null)
                        Text(
                          '${_distanceMeters.toStringAsFixed(0)} m',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.accent,
                        child: Text(
                          _driverInitials.isNotEmpty ? _driverInitials : 'D',
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
                            Row(
                              children: [
                                Text(
                                    _driverName.isEmpty
                                        ? 'Driver'
                                        : _driverName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppTheme.textPrimary)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Colors.amber, size: 12),
                                      Text(' $_driverRating',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                                _vehicleInfo.isEmpty
                                    ? '—'
                                    : _vehicleInfo,
                                style: const TextStyle(
                                    color: AppTheme.textHint, fontSize: 12)),
                            Text('Fare: PKR $_fare · Cash',
                                style: const TextStyle(
                                    color: AppTheme.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                            backgroundColor: AppTheme.bgCard),
                        icon: const Icon(Icons.chat_bubble_rounded,
                            color: AppTheme.primary),
                        onPressed: () => setState(() => _isChatOpen = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (arrived && !ongoing && !completed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Start Ride',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _startRide,
                      ),
                    ),
                  if (ongoing && !completed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _completing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.flag_rounded),
                        label: const Text('Complete Ride',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _completing ? null : _completeRide,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.warning_amber_rounded,
                              size: 18),
                          label: const Text('SOS',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _triggerSOS,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.15)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: Size.zero,
                          ),
                          onPressed: completed
                              ? null
                              : () async {
                                  await RideService.instance.cancelRide(rid);
                                  UserSession.instance.activeRideId = '';
                                  if (mounted) setState(() {});
                                },
                          child: const Text('Cancel',
                              style: TextStyle(color: AppTheme.textHint)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isChatOpen) _buildChatOverlay(rid),
        ],
      ),
    );
  }

  Widget _buildChatOverlay(String rid) {
    return Container(
      color: AppTheme.bgDark.withValues(alpha: 0.97),
      child: Column(
        children: [
          AppBar(
            title: Text(
                'Chat with ${_driverName.isEmpty ? 'Driver' : _driverName.split(' ').first}'),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _isChatOpen = false),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RideService.instance.isReady
                  ? RideService.instance.watchMessages(rid)
                  : null,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  final empty = snap.connectionState == ConnectionState.waiting;
                  return Center(
                    child: Text(
                        empty ? 'Loading…' : 'Say salam to start the chat',
                        style: const TextStyle(color: AppTheme.textHint)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final text = d['text'] as String? ?? '';
                    final isMe = d['fromCustomer'] == true;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primary : AppTheme.bgCard,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                        ),
                        child: Text(text,
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : AppTheme.textPrimary)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            color: AppTheme.bgSurface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      fillColor: AppTheme.bgCard2,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _sendChat,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return RideMapView(
      controller: _mapController,
      center: _riderLatLng,
      pickup: LatLng(_pickupLat, _pickupLng),
      drop: LatLng(_dropLat, _dropLng),
      rider: _riderLatLng,
      driver: _driverLatLng,
      driverIsBike: _rideType == 'bike',
      routePoints: _routePoints.isEmpty ? null : _routePoints,
      initialZoom: 14,
    );
  }
}
