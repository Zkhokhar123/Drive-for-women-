import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/ride_map_view.dart';
import '../../services/user_session.dart';
import '../../services/place_search_service.dart';
import '../../services/route_service.dart';
import 'customer_bid_tab.dart';

class CustomerBookTab extends StatefulWidget {
  const CustomerBookTab({super.key});

  @override
  State<CustomerBookTab> createState() => _CustomerBookTabState();
}

class _CustomerBookTabState extends State<CustomerBookTab> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _fareController = TextEditingController();
  final _mapController = RideMapController();
  final _places = PlaceSearchService.instance;

  String _selectedRideType = 'bike';
  int _estimatedFare = 0;
  double _distanceKm = 0;
  bool _isLoadingGPS = false;
  bool _isGeocoding = false;

  LatLng _pickupLatLng = const LatLng(24.8607, 67.0011);
  LatLng? _dropLatLng;
  List<LatLng> _routePoints = [];
  final _riderNotifier = ValueNotifier<LatLng?>(null);
  StreamSubscription<Position>? _riderSub;

  int get _suggestLow => (_estimatedFare * 0.85).round().clamp(20, 99999);
  int get _suggestMid => _estimatedFare;
  int get _suggestHigh => (_estimatedFare * 1.2).round();
  int get _currentProposedFare => int.tryParse(_fareController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchLiveGPSCoordinates();
    _startRiderTracking();
  }

  @override
  void dispose() {
    _riderSub?.cancel();
    _riderNotifier.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _fareController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startRiderTracking() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _riderSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((pos) {
        _riderNotifier.value = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<String> _reverseGeocode(double lat, double lng) =>
      _places.reverse(lat, lng);

  Future<LatLng?> _forwardGeocode(String query) =>
      _places.geocodeFirst(query);

  Future<void> _fetchLiveGPSCoordinates() async {
    setState(() => _isLoadingGPS = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _pickupController.text = 'Tap to enter pickup location';
            _isLoadingGPS = false;
          });
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _pickupController.text = 'Enable GPS, then tap location icon';
            _isLoadingGPS = false;
          });
          _showError('Please turn on Location / GPS');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      final label = await _reverseGeocode(position.latitude, position.longitude);

      setState(() {
        _pickupLatLng = latLng;
        _riderNotifier.value = latLng;
        _pickupController.text = label;
        _isLoadingGPS = false;
      });
      _mapController.move(latLng, 15.5);
      _recalculateFare();
      _fitMap();
    } catch (_) {
      if (mounted) {
        setState(() {
          _pickupController.text = 'Tap to enter pickup location';
          _isLoadingGPS = false;
        });
        _showError('Could not get GPS. Tap pickup to search any Pakistan address.');
      }
    }
  }

  Future<void> _openLocationEditor({required bool isPickup}) async {
    final result = await showModalBottomSheet<_LocationPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSearchSheet(
        title: isPickup ? 'Pickup Location' : 'Where to?',
        initialText: isPickup ? _pickupController.text : _dropController.text,
        hint: isPickup
            ? 'Road, area, landmark — anywhere in Pakistan'
            : 'Search any city / road in Pakistan…',
        showGpsOption: isPickup,
        near: _riderNotifier.value ?? _pickupLatLng,
      ),
    );

    if (result == null || !mounted) return;

    if (result.useGps) {
      await _fetchLiveGPSCoordinates();
      return;
    }

    setState(() => _isGeocoding = true);
    final query = result.query.trim();
    LatLng? coords = result.latLng;
    coords ??= await _forwardGeocode(query);

    if (!mounted) return;
    setState(() => _isGeocoding = false);

    if (coords == null) {
      _showError(
          'Location not found. Try road + city e.g. "Mall Road, Lahore"');
      return;
    }

    final label = result.displayLabel.isNotEmpty
        ? result.displayLabel
        : await _reverseGeocode(coords.latitude, coords.longitude);

    setState(() {
      if (isPickup) {
        _pickupLatLng = coords!;
        _pickupController.text = label;
      } else {
        _dropLatLng = coords;
        _dropController.text = label;
      }
    });
    _mapController.move(coords, 15);
    _recalculateFare();
    _fitMap();
  }

  void _fitMap() {
    final points = <LatLng>[_pickupLatLng];
    if (_dropLatLng != null) points.add(_dropLatLng!);
    _mapController.fitPoints(points);
  }

  Future<void> _recalculateFare() async {
    if (_dropLatLng == null) {
      setState(() {
        _estimatedFare = 0;
        _distanceKm = 0;
        _routePoints = [];
      });
      return;
    }

    final drop = _dropLatLng!;
    final distKm = (await RouteService.instance
            .fetchDistanceKm(_pickupLatLng, drop))
        .clamp(0.5, 200.0);
    final route =
        await RouteService.instance.fetchRoute(_pickupLatLng, drop);

    final base = _selectedRideType == 'car' ? 120 : 40;
    final rateKm = _selectedRideType == 'car' ? 75 : 30;
    final fare = base + (distKm * rateKm).round();

    if (!mounted) return;
    setState(() {
      _distanceKm = double.parse(distKm.toStringAsFixed(1));
      _estimatedFare = fare;
      _fareController.text = fare.toString();
      _routePoints = route;
    });
  }

  void _updateRideType(String type) {
    setState(() => _selectedRideType = type);
    _recalculateFare();
  }

  void _findDrivers() {
    final fare = _currentProposedFare;

    if (_pickupController.text.trim().isEmpty ||
        _pickupController.text.contains('Tap to enter') ||
        _pickupController.text.contains('Enable GPS')) {
      _showError('Please set your pickup location');
      return;
    }
    if (_dropLatLng == null || _dropController.text.trim().isEmpty) {
      _showError('Please set your destination (Where to?)');
      return;
    }
    if (fare <= 0) {
      _showError('Please enter your fare offer');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerBidTab(
          pickup: _pickupController.text,
          drop: _dropController.text,
          rideType: _selectedRideType,
          proposedFare: fare,
          pickupLat: _pickupLatLng.latitude,
          pickupLng: _pickupLatLng.longitude,
          dropLat: _dropLatLng!.latitude,
          dropLng: _dropLatLng!.longitude,
          routePoints: _routePoints,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Emergency alert with GPS '
          '(${_pickupLatLng.latitude.toStringAsFixed(4)}, '
          '${_pickupLatLng.longitude.toStringAsFixed(4)}) '
          'will be shared with contacts.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textHint)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _setQuickDrop(String address) async {
    setState(() => _isGeocoding = true);
    final results = await _places.search(address, near: _pickupLatLng, limit: 1);
    if (!mounted) return;
    setState(() => _isGeocoding = false);
    if (results.isEmpty) {
      _showError('Could not find $address');
      return;
    }
    final place = results.first;
    setState(() {
      _dropLatLng = place.point;
      _dropController.text = place.fullLabel;
    });
    _recalculateFare();
    _fitMap();
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession.instance;
    final fareHigh = (_estimatedFare * 1.4).round();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<LatLng?>(
              valueListenable: _riderNotifier,
              builder: (_, rider, __) {
                return RideMapView(
                  controller: _mapController,
                  center: rider ?? _pickupLatLng,
                  pickup: _pickupLatLng,
                  drop: _dropLatLng,
                  rider: rider,
                  routePoints:
                      _routePoints.isEmpty ? null : _routePoints,
                  onLongPress: (point) async {
                    setState(() => _isGeocoding = true);
                    final label = await _reverseGeocode(
                        point.latitude, point.longitude);
                    if (!mounted) return;
                    setState(() {
                      _dropLatLng = point;
                      _dropController.text = label;
                      _isGeocoding = false;
                    });
                    _recalculateFare();
                    _fitMap();
                  },
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Material(
              color: AppTheme.bgCard,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                tooltip: 'My location',
                onPressed: _isLoadingGPS ? null : _fetchLiveGPSCoordinates,
                icon: _isLoadingGPS
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded,
                        color: AppTheme.primary),
              ),
            ),
          ),
          if (_isGeocoding)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                color: AppTheme.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.18,
            maxChildSize: 0.93,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const AppLogo(
                            size: 44, animate: false, showGlow: false),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Drive for ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Women',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Hi, ${session.customerName.split(' ').first} 👋',
                                style: const TextStyle(
                                    color: AppTheme.textHint, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _triggerSOS,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      AppTheme.error.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.sos_rounded,
                                color: AppTheme.error, size: 22),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        children: [
                          _LocationRow(
                            color: AppTheme.success,
                            label: 'Pickup Location',
                            value: _pickupController.text.isEmpty
                                ? 'Tap to set pickup'
                                : _pickupController.text,
                            trailing: IconButton(
                              icon: const Icon(Icons.my_location_rounded,
                                  color: AppTheme.primary, size: 18),
                              onPressed: _fetchLiveGPSCoordinates,
                            ),
                            onTap: () =>
                                _openLocationEditor(isPickup: true),
                          ),
                          Divider(
                              color: Colors.white.withValues(alpha: 0.08),
                              height: 20),
                          _LocationRow(
                            color: AppTheme.primary,
                            label: 'Where to?',
                            value: _dropController.text.isEmpty
                                ? 'Tap to enter destination'
                                : _dropController.text,
                            onTap: () =>
                                _openLocationEditor(isPickup: false),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    if (_distanceKm > 0) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Distance ≈ $_distanceKm km · long-press map to set drop',
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text(
                      'Select Ride Type',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RideOptionCard(
                            icon: Icons.motorcycle_rounded,
                            title: 'Bike Ride',
                            subtitle: 'Quick & Safe',
                            isSelected: _selectedRideType == 'bike',
                            onTap: () => _updateRideType('bike'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _RideOptionCard(
                            icon: Icons.local_taxi_rounded,
                            title: 'Car Ride',
                            subtitle: 'AC & Comfort',
                            isSelected: _selectedRideType == 'car',
                            onTap: () => _updateRideType('car'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_estimatedFare > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          'Market estimate PKR $_estimatedFare – $fareHigh',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your Offer (inDrive style)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _FareSuggestionChip(
                              pkrValue: _suggestLow,
                              label: 'Budget',
                              chipStyle: _ChipStyle.budget,
                              onTap: () {
                                _fareController.text =
                                    _suggestLow.toString();
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FareSuggestionChip(
                              pkrValue: _suggestMid,
                              label: 'Fair ★',
                              chipStyle: _ChipStyle.fair,
                              onTap: () {
                                _fareController.text =
                                    _suggestMid.toString();
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _FareSuggestionChip(
                              pkrValue: _suggestHigh,
                              label: 'Premium',
                              chipStyle: _ChipStyle.premium,
                              onTap: () {
                                _fareController.text =
                                    _suggestHigh.toString();
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'PKR ',
                              style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _fareController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            _FareAdjustBtn(
                              label: '-10',
                              onTap: () {
                                final cur = int.tryParse(
                                        _fareController.text) ??
                                    0;
                                _fareController.text =
                                    (cur - 10).clamp(20, 99999).toString();
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 6),
                            _FareAdjustBtn(
                              label: '+10',
                              onTap: () {
                                final cur = int.tryParse(
                                        _fareController.text) ??
                                    0;
                                _fareController.text =
                                    (cur + 10).toString();
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Drivers see your offer and can accept or counter',
                        style: TextStyle(
                            color: AppTheme.textHint, fontSize: 11),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Set pickup & destination to see fare and offer your price (inDrive style).',
                          style: TextStyle(
                              color: AppTheme.textHint, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.success.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.payments_rounded,
                              color: AppTheme.success, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Payment Method',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          Spacer(),
                          Text(
                            'Cash only',
                            style: TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.lock_rounded,
                              color: AppTheme.success, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GradientButton(
                      label: 'Find Drivers  →',
                      onPressed: _findDrivers,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Quick Destinations',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _SavedPlaceTile(
                      icon: Icons.home_filled,
                      label: 'Home',
                      address: 'Gulshan-e-Iqbal, Karachi',
                      onTap: () =>
                          _setQuickDrop('Gulshan-e-Iqbal, Karachi'),
                    ),
                    _SavedPlaceTile(
                      icon: Icons.work_rounded,
                      color: AppTheme.accent,
                      label: 'Work',
                      address: 'Clifton, Karachi',
                      onTap: () => _setQuickDrop('Clifton, Karachi'),
                    ),
                    _SavedPlaceTile(
                      icon: Icons.location_city_rounded,
                      color: AppTheme.info,
                      label: 'Lahore',
                      address: 'Mall Road, Lahore',
                      onTap: () => _setQuickDrop('Mall Road, Lahore'),
                    ),
                    _SavedPlaceTile(
                      icon: Icons.account_balance_rounded,
                      color: Colors.teal,
                      label: 'Islamabad',
                      address: 'Blue Area, Islamabad',
                      onTap: () => _setQuickDrop('Blue Area, Islamabad'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LocationPickResult {
  final String query;
  final String displayLabel;
  final LatLng? latLng;
  final bool useGps;

  _LocationPickResult({
    required this.query,
    this.displayLabel = '',
    this.latLng,
    this.useGps = false,
  });

  factory _LocationPickResult.useGps() =>
      _LocationPickResult(query: '', useGps: true);
}

class _LocationSearchSheet extends StatefulWidget {
  final String title;
  final String initialText;
  final String hint;
  final bool showGpsOption;
  final LatLng? near;

  const _LocationSearchSheet({
    required this.title,
    required this.initialText,
    required this.hint,
    this.showGpsOption = false,
    this.near,
  });

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  late final TextEditingController _ctrl;
  bool _searching = false;
  List<PlaceResult> _suggestions = [];
  Timer? _debounce;

  static const _quickPlaces = [
    'Clifton, Karachi',
    'Gulshan-e-Iqbal, Karachi',
    'Mall Road, Lahore',
    'DHA Phase 5, Lahore',
    'Blue Area, Islamabad',
    'F-7 Markaz, Islamabad',
    'Saddar, Rawalpindi',
    'University Road, Peshawar',
    'Gulgasht, Multan',
    'Jinnah Road, Quetta',
    'Clock Tower, Faisalabad',
    'Liaquat Bazaar, Hyderabad',
  ];

  @override
  void initState() {
    super.initState();
    final seed = widget.initialText;
    final dirty = seed.contains('Tap to') ||
        seed.contains('Fetching') ||
        seed.contains('Enable GPS') ||
        seed.contains('My Location (') ||
        seed.startsWith('Pin (');
    _ctrl = TextEditingController(text: dirty ? '' : seed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final list = await PlaceSearchService.instance.search(
        query,
        near: widget.near,
        limit: 12,
      );
      if (mounted) setState(() => _suggestions = list);
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  void _confirmPlace(PlaceResult place) {
    Navigator.pop(
      context,
      _LocationPickResult(
        query: place.fullLabel,
        displayLabel: place.fullLabel,
        latLng: place.point,
      ),
    );
  }

  void _confirmText() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    Navigator.pop(context, _LocationPickResult(query: q, displayLabel: q));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 4),
            const Text(
              'All Pakistan · roads, areas & landmarks',
              style: TextStyle(color: AppTheme.textHint, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _confirmText(),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.textHint),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary),
                        onPressed: _confirmText,
                      ),
              ),
            ),
            if (widget.showGpsOption) ...[
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location_rounded,
                    color: AppTheme.primary),
                title: const Text('Use my live GPS location',
                    style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () => Navigator.pop(
                    context, _LocationPickResult.useGps()),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _suggestions.isNotEmpty
                  ? ListView.separated(
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            s.kind.contains('highway') ||
                                    s.kind.contains('road') ||
                                    s.kind.contains('residential')
                                ? Icons.signpost_rounded
                                : Icons.place_rounded,
                            color: AppTheme.primary,
                          ),
                          title: Text(s.title,
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            s.subtitle.isEmpty ? s.kind : s.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.textHint, fontSize: 12),
                          ),
                          onTap: () => _confirmPlace(s),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Try cities across Pakistan',
                            style: TextStyle(
                                color: AppTheme.textHint, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickPlaces
                                .map((p) => ActionChip(
                                      label: Text(
                                        p.split(',').length > 1
                                            ? '${p.split(',').first.trim()} (${p.split(',').last.trim()})'
                                            : p,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: AppTheme.bgCard,
                                      labelStyle: const TextStyle(
                                          color: AppTheme.textSecondary),
                                      onPressed: () async {
                                        setState(() => _searching = true);
                                        final list = await PlaceSearchService
                                            .instance
                                            .search(p, limit: 1);
                                        if (!context.mounted) return;
                                        setState(() => _searching = false);
                                        if (list.isNotEmpty) {
                                          _confirmPlace(list.first);
                                        } else {
                                          Navigator.of(context).pop(
                                            _LocationPickResult(
                                                query: p, displayLabel: p),
                                          );
                                        }
                                      },
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  const _LocationRow({
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          CircleAvatar(radius: 7, backgroundColor: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.edit_rounded,
                  color: AppTheme.textHint, size: 16),
        ],
      ),
    );
  }
}

enum _ChipStyle { budget, fair, premium }

class _FareSuggestionChip extends StatelessWidget {
  final int pkrValue;
  final String label;
  final _ChipStyle chipStyle;
  final VoidCallback onTap;

  const _FareSuggestionChip({
    required this.pkrValue,
    required this.label,
    required this.chipStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late Color borderColor;
    late Color bgColor;
    late Color textColor;

    switch (chipStyle) {
      case _ChipStyle.budget:
        borderColor = Colors.white.withValues(alpha: 0.12);
        bgColor = AppTheme.bgCard2;
        textColor = AppTheme.textSecondary;
        break;
      case _ChipStyle.fair:
        borderColor = AppTheme.primary.withValues(alpha: 0.6);
        bgColor = AppTheme.primary.withValues(alpha: 0.10);
        textColor = AppTheme.primary;
        break;
      case _ChipStyle.premium:
        borderColor = Colors.amber.withValues(alpha: 0.4);
        bgColor = Colors.amber.withValues(alpha: 0.07);
        textColor = Colors.amber;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text('PKR $pkrValue',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: textColor)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

class _RideOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RideOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color:
                    isSelected ? AppTheme.primary : AppTheme.textPrimary,
                size: 28),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textHint)),
          ],
        ),
      ),
    );
  }
}

class _FareAdjustBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FareAdjustBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.bgCard2,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }
}

class _SavedPlaceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;
  final VoidCallback onTap;

  const _SavedPlaceTile({
    required this.icon,
    this.color = AppTheme.primary,
    required this.label,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppTheme.bgCard, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color),
      ),
      title: Text(label,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(address,
          style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          color: AppTheme.textHint, size: 14),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
