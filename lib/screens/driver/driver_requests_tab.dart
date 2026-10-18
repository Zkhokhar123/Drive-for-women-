import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../services/ride_service.dart';
import 'driver_navigation_tab.dart';

class DriverRequestsTab extends StatefulWidget {
  const DriverRequestsTab({super.key});

  @override
  State<DriverRequestsTab> createState() => _DriverRequestsTabState();
}

class _DriverRequestsTabState extends State<DriverRequestsTab> {
  StreamSubscription<Position>? _gpsSub;
  final Set<String> _submitted = {};

  @override
  void initState() {
    super.initState();
    UserSession.instance.addListener(_onSession);
    _maybeStartGps();
  }

  void _onSession() {
    _maybeStartGps();
    if (mounted) setState(() {});
  }

  void _maybeStartGps() {
    final online = UserSession.instance.isOnline;
    if (online && _gpsSub == null) {
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen((p) {
        final uid = UserSession.instance.uid;
        if (uid.isEmpty || !RideService.instance.isReady) return;
        RideService.instance.updateUserGps(uid, p.latitude, p.longitude);
        final rid = UserSession.instance.activeRideId;
        if (rid.isNotEmpty) {
          RideService.instance
              .updateDriverLocation(rid, p.latitude, p.longitude);
        }
      });
    } else if (!online) {
      _gpsSub?.cancel();
      _gpsSub = null;
    }
  }

  @override
  void dispose() {
    UserSession.instance.removeListener(_onSession);
    _gpsSub?.cancel();
    super.dispose();
  }

  List<int> _counterBids(int fare) => [
        fare,
        (fare * 1.1).round(),
        (fare * 1.2).round(),
      ];

  Future<void> _submitBid(
      BuildContext context, Map<String, dynamic> req, int bid) async {
    final rideId = req['id'] as String;
    if (!RideService.instance.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Firebase not connected'),
        backgroundColor: AppTheme.error,
      ));
      return;
    }
    try {
      await RideService.instance.submitOffer(rideId: rideId, fare: bid);
      _submitted.add(rideId);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Offer PKR $bid sent to ${req['rider']}'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  void _watchAccepted(String rideId, Map<String, dynamic> req) {
    RideService.instance.watchRide(rideId).listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      if (data['status'] == 'accepted' &&
          data['driverId'] == UserSession.instance.uid) {
        UserSession.instance.activeRideId = rideId;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DriverNavigationTab(
            rideId: rideId,
            riderId: req['customerId'] as String? ?? rideId,
            riderName: req['rider'] as String,
            pickup: req['pickup'] as String,
            drop: req['drop'] as String,
            fare: (data['agreedFare'] as num?)?.toInt() ??
                (req['proposedFare'] as int),
            riderLat: (req['pickupLat'] as num?)?.toDouble() ?? 24.8607,
            riderLng: (req['pickupLng'] as num?)?.toDouble() ?? 67.0011,
            dropLat: (req['dropLat'] as num?)?.toDouble(),
            dropLng: (req['dropLng'] as num?)?.toDouble(),
          ),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession.instance;

    if (!session.isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.bgCard,
              child: Icon(Icons.wifi_off_rounded,
                  size: 40, color: AppTheme.textHint),
            ),
            const SizedBox(height: 20),
            const Text("You're Offline",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Go online to start receiving\nride requests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textHint, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('Go Online',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => UserSession.instance.toggleOnline(true),
            ),
          ],
        ),
      );
    }

    if (!RideService.instance.isReady) {
      return const Center(
        child: Text('Firebase not connected.\nCannot load live requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textHint)),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: RideService.instance.watchOpenRides(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load rides.\n${snap.error}\n\n'
                'If this mentions an index, open the link in the error '
                'to create the Firestore composite index.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final uid = session.uid;
        final requests = snap.data!.docs
            .where((d) {
              final data = d.data();
              final status = data['status'] as String? ?? '';
              if (status != 'searching' && status != 'offered') return false;
              if (data['customerId'] == uid) return false;
              return true;
            })
            .map((d) {
              final data = d.data();
              return {
                'id': d.id,
                'customerId': data['customerId'] ?? '',
                'rider': data['customerName'] ?? 'Customer',
                'pickup': data['pickup'] ?? '',
                'drop': data['drop'] ?? '',
                'pickupLat': data['pickupLat'],
                'pickupLng': data['pickupLng'],
                'dropLat': data['dropLat'],
                'dropLng': data['dropLng'],
                'distance': _fmtDist(data),
                'rideType': data['rideType'] ?? 'bike',
                'proposedFare':
                    (data['proposedFare'] as num?)?.toInt() ?? 0,
              };
            })
            .toList();

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_find_rounded,
                        size: 54, color: AppTheme.textHint)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                        begin: 0.85,
                        end: 1.15,
                        duration: 1500.ms,
                        curve: Curves.easeInOut),
                const SizedBox(height: 20),
                const Text('Searching for Requests...',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        fontSize: 16)),
                const SizedBox(height: 6),
                const Text(
                  'New customer requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textHint, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (ctx, i) {
            final req = requests[i];
            final proposed = req['proposedFare'] as int;
            final bids = _counterBids(proposed);
            final isBike = req['rideType'] == 'bike';
            final already = _submitted.contains(req['id']);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            (req['rider'] as String)[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(req['rider'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary)),
                              Text('ID: ${req['id']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppTheme.textHint, fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBike
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isBike
                                    ? Icons.motorcycle_rounded
                                    : Icons.local_taxi_rounded,
                                color: isBike
                                    ? AppTheme.primary
                                    : AppTheme.accent,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                req['distance'] as String,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isBike
                                        ? AppTheme.primary
                                        : AppTheme.accent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _RouteRow(
                        pickup: req['pickup'] as String,
                        drop: req['drop'] as String),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer_rounded,
                              color: AppTheme.success, size: 16),
                          const SizedBox(width: 8),
                          const Text('Customer is offering:',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12)),
                          const Spacer(),
                          Text(
                            'PKR $proposed',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (already)
                      const Text('Offer sent — waiting for customer...',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13))
                    else ...[
                      const Text('Accept or Counter-Offer:',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: bids.asMap().entries.map((e) {
                          final idx = e.key;
                          final bid = e.value;
                          final isBase = idx == 0;
                          return Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.only(right: idx < 2 ? 8 : 0),
                              child: GestureDetector(
                                onTap: () async {
                                  await _submitBid(context, req, bid);
                                  _watchAccepted(req['id'] as String, req);
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isBase
                                        ? AppTheme.success
                                            .withValues(alpha: 0.12)
                                        : AppTheme.bgCard2,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isBase
                                          ? AppTheme.success
                                              .withValues(alpha: 0.5)
                                          : AppTheme.primary
                                              .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'PKR $bid',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isBase
                                                ? AppTheme.success
                                                : AppTheme.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        idx == 0
                                            ? 'Accept'
                                            : idx == 1
                                                ? '+10%'
                                                : '+20%',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: isBase
                                                ? AppTheme.success
                                                : AppTheme.textHint),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: (i * 100).ms, duration: 400.ms);
          },
        );
      },
    );
  }

  String _fmtDist(Map<String, dynamic> data) {
    final plat = (data['pickupLat'] as num?)?.toDouble();
    final plng = (data['pickupLng'] as num?)?.toDouble();
    final dlat = (data['dropLat'] as num?)?.toDouble();
    final dlng = (data['dropLng'] as num?)?.toDouble();
    if (plat == null || plng == null || dlat == null || dlng == null) {
      return '—';
    }
    final m = Geolocator.distanceBetween(plat, plng, dlat, dlng);
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}

class _RouteRow extends StatelessWidget {
  final String pickup;
  final String drop;
  const _RouteRow({required this.pickup, required this.drop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.fiber_manual_record_rounded,
                color: AppTheme.success, size: 13),
            const SizedBox(width: 10),
            Expanded(
              child: Text(pickup,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ],
        ),
        Container(
            margin: const EdgeInsets.only(left: 5),
            height: 14,
            width: 1.5,
            color: Colors.white24),
        Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppTheme.primary, size: 13),
            const SizedBox(width: 10),
            Expanded(
              child: Text(drop,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }
}
