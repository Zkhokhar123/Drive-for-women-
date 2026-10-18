import 'package:flutter/material.dart';

/// Singleton holding all in-memory session data.
/// Extends ChangeNotifier — every mutation calls notifyListeners()
/// so ListenableBuilder widgets rebuild automatically.
///
/// Firebase sync happens through FirebaseService, which calls the
/// setCustomerFromFirestore / setDriverFromFirestore methods below.
class UserSession extends ChangeNotifier {
  static final UserSession _instance = UserSession._();
  static UserSession get instance => _instance;
  UserSession._();

  // ── Auth ───────────────────────────────────────────────────
  bool   isLoggedIn = false;
  String role       = ''; // 'customer' | 'driver'
  String uid        = ''; // Firebase UID

  // ── Customer ───────────────────────────────────────────────
  String customerName    = '';
  String customerInitial = '';
  String customerPhone   = '';
  String customerEmail   = '';
  String customerCity    = 'Karachi, Pakistan';
  double walletBalance   = 0.0;

  List<Map<String, dynamic>> rideHistory        = [];
  List<Map<String, dynamic>> walletTransactions = [];

  // ── Driver ─────────────────────────────────────────────────
  String driverName     = '';
  String driverInitials = '';
  String driverVehicle  = '';
  double driverRating   = 5.0;
  double driverBalance  = 0.0;
  int    ridesCompleted = 0;
  double onlineHours    = 0.0;
  double dailyEarnings  = 0.0;
  bool   isOnline       = false;

  // ── Driver documents ───────────────────────────────────────
  String vehicleModel  = '';
  String vehicleReg    = '';
  String vehicleColor  = '';
  String vehicleYear   = '';
  String cnicImagePath = '';    // local path or remote URL
  String licenceImagePath = '';
  String bikeImagePath    = '';
  bool   documentsSubmitted = false;

  // ── Driver runtime data ────────────────────────────────────
  List<Map<String, dynamic>> driverEarningsHistory = [];
  List<double>               weeklyEarnings        = List.filled(7, 0.0);

  // ── Pending ride requests (filled from Firestore stream) ───
  List<Map<String, dynamic>> driverRequests = [];

  /// Active ride being tracked (customer or driver).
  String _activeRideId = '';
  String get activeRideId => _activeRideId;
  set activeRideId(String id) {
    _activeRideId = id;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  //  SET FROM FIREBASE (called by FirebaseService.loadSession)
  // ════════════════════════════════════════════════════════════

  void setCustomerFromFirestore({
    required String uid,
    required String name,
    required String phone,
    required String email,
    required String city,
    required double walletBalance,
  }) {
    this.uid        = uid;
    customerName    = name;
    customerInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    customerPhone   = phone;
    customerEmail   = email;
    customerCity    = city.isNotEmpty ? city : 'Karachi, Pakistan';
    this.walletBalance = walletBalance;
    role       = 'customer';
    isLoggedIn = true;
    notifyListeners();
  }

  void setDriverFromFirestore({
    required String uid,
    required String name,
    required String phone,
    required String vehicleModel,
    required String vehicleReg,
    required String vehicleColor,
    required String vehicleYear,
    required String cnicUrl,
    required String licenceUrl,
    required String bikeUrl,
    required bool   isOnline,
    required double driverRating,
    required int    ridesCompleted,
    required double onlineHours,
    required double dailyEarnings,
    required double driverBalance,
    required bool   documentsSubmitted,
  }) {
    this.uid          = uid;
    driverName        = name;
    driverInitials    = _initials(name);
    driverVehicle     = '$vehicleModel · $vehicleReg';
    this.vehicleModel = vehicleModel;
    this.vehicleReg   = vehicleReg;
    this.vehicleColor = vehicleColor;
    this.vehicleYear  = vehicleYear;
    cnicImagePath     = cnicUrl;
    licenceImagePath  = licenceUrl;
    bikeImagePath     = bikeUrl;
    this.isOnline          = isOnline;
    this.driverRating      = driverRating;
    this.ridesCompleted    = ridesCompleted;
    this.onlineHours       = onlineHours;
    this.dailyEarnings     = dailyEarnings;
    this.driverBalance     = driverBalance;
    this.documentsSubmitted = documentsSubmitted;
    customerPhone = phone;
    role       = 'driver';
    isLoggedIn = true;
    _seedWeeklyFromEarnings();
    notifyListeners();
  }

  /// Bulk-load ride history from Firestore (replaces in-memory list).
  void loadRideHistory(List<Map<String, dynamic>> history) {
    rideHistory = history.map((r) {
      final type = r['rideType'] as String? ?? r['type'] as String? ?? 'bike';
      return {
        ...r,
        'type': type,
        'icon': type == 'bike'
            ? Icons.motorcycle_rounded
            : Icons.local_taxi_rounded,
        'driver': r['driverName'] ?? r['driver'] ?? '—',
        'fare':   r['fare']?.toString() ?? '0',
        'status': r['status'] ?? 'Completed',
        'route':  r['route'] ?? '—',
        'date':   _firestoreTimestampToString(r['createdAt']),
      };
    }).toList();
    notifyListeners();
  }

  /// Bulk-load wallet transactions from Firestore.
  void loadWalletTransactions(List<Map<String, dynamic>> txns) {
    walletTransactions = txns.map((t) {
      final isCredit = t['type'] == 'credit';
      final amount   = (t['amount'] as num?)?.toDouble() ?? 0.0;
      return {
        ...t,
        'amount': isCredit
            ? '+ PKR ${amount.toStringAsFixed(0)}'
            : '- PKR ${amount.toStringAsFixed(0)}',
        'date': _firestoreTimestampToString(t['createdAt']),
      };
    }).toList();
    notifyListeners();
  }

  /// Bulk-load driver earnings history from Firestore.
  void loadDriverEarnings(List<Map<String, dynamic>> earnings) {
    driverEarningsHistory = earnings.map((e) => {
      'route':    e['route']    ?? '—',
      'fare':     (e['fare'] as num?)?.toInt() ?? 0,
      'rideType': e['rideType'] ?? 'bike',
      'date':     _firestoreTimestampToString(e['createdAt']),
    }).toList();
    _seedWeeklyFromEarnings();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  //  LOCAL-ONLY SETTERS (used when Firebase not yet configured
  //  or for demo/fallback)
  // ════════════════════════════════════════════════════════════

  void setCustomer({
    required String name,
    required String phone,
    String email = '',
    String city  = 'Karachi, Pakistan',
    String firebaseUid = '',
  }) {
    uid            = firebaseUid;
    customerName   = name;
    customerInitial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    customerPhone  = phone.startsWith('+') ? phone : '+92 $phone';
    customerEmail  = email;
    customerCity   = city;
    walletBalance  = 0.0;
    role       = 'customer';
    isLoggedIn = true;
    rideHistory = [];
    walletTransactions = [];
    notifyListeners();
  }

  void setDriver({
    required String name,
    required String phone,
    required String vModel,
    required String vReg,
    required String vColor,
    required String vYear,
    required String cnicPath,
    required String licencePath,
    required String bikePath,
    String firebaseUid = '',
  }) {
    uid              = firebaseUid;
    driverName       = name;
    driverInitials   = _initials(name);
    driverVehicle    = '$vModel · $vReg';
    vehicleModel     = vModel;
    vehicleReg       = vReg;
    vehicleColor     = vColor;
    vehicleYear      = vYear;
    cnicImagePath    = cnicPath;
    licenceImagePath = licencePath;
    bikeImagePath    = bikePath;
    documentsSubmitted = true;
    driverBalance    = 0.0;
    driverRating     = 5.0;
    ridesCompleted   = 0;
    onlineHours      = 0.0;
    dailyEarnings    = 0.0;
    isOnline         = false;
    customerPhone    = phone.startsWith('+') ? phone : '+92 $phone';
    role       = 'driver';
    isLoggedIn = true;
    driverEarningsHistory = [];
    weeklyEarnings = List.filled(7, 0.0);
    driverRequests = [];
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  //  MUTATIONS — all notify listeners
  // ════════════════════════════════════════════════════════════

  void updateProfile({String? name, String? phone, String? email, String? city}) {
    if (name  != null && name.isNotEmpty)  { customerName = name; customerInitial = name[0].toUpperCase(); }
    if (phone != null && phone.isNotEmpty)   customerPhone = phone;
    if (email != null)                       customerEmail = email;
    if (city  != null && city.isNotEmpty)    customerCity  = city;
    notifyListeners();
  }

  void toggleOnline(bool value) {
    isOnline = value;
    if (value) onlineHours = double.parse((onlineHours + 0.5).toStringAsFixed(1));
    notifyListeners();
  }

  void acceptRideRequest(String id, int agreedFare, String route, String rideType) {
    driverRequests.removeWhere((r) => r['id'] == id);
    dailyEarnings  += agreedFare;
    driverBalance  += agreedFare;
    ridesCompleted += 1;

    final now     = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day} · ${_timeStr(now)}';
    driverEarningsHistory.insert(0, {
      'route': route, 'fare': agreedFare,
      'date': dateStr, 'rideType': rideType,
    });

    final dayIdx = (now.weekday - 1).clamp(0, 6);
    weeklyEarnings[dayIdx] += agreedFare;
    notifyListeners();
  }

  void declineRideRequest(String id) {
    driverRequests.removeWhere((r) => r['id'] == id);
    notifyListeners();
  }

  void driverCashout() {
    driverBalance = 0;
    notifyListeners();
  }

  /// Update driver stats after a ride completes — called from RideService.
  void updateDriverStats({
    required double dailyEarnings,
    required double driverBalance,
    required int    ridesCompleted,
  }) {
    this.dailyEarnings  = dailyEarnings;
    this.driverBalance  = driverBalance;
    this.ridesCompleted = ridesCompleted;
    notifyListeners();
  }

  void addCompletedRide({
    required String route,
    required String driverName,
    required String rideType,
    required int    fare,
  }) {
    final now     = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year} · ${_timeStr(now)}';
    rideHistory.insert(0, {
      'type':   rideType,
      'icon':   rideType == 'bike' ? Icons.motorcycle_rounded : Icons.local_taxi_rounded,
      'route':  route,
      'date':   dateStr,
      'driver': driverName,
      'status': 'Completed',
      'fare':   fare.toString(),
    });
    walletBalance -= fare;
    walletTransactions.insert(0, {
      'title':  '${rideType == 'bike' ? 'Bike' : 'Car'} Ride – $route',
      'date':   dateStr,
      'amount': '- PKR $fare',
      'type':   'debit',
    });
    notifyListeners();
  }

  void addMoney(double amount) {
    walletBalance += amount;
    final now = DateTime.now();
    walletTransactions.insert(0, {
      'title':  'Added via JazzCash',
      'date':   '${_monthName(now.month)} ${now.day} · ${_timeStr(now)}',
      'amount': '+ PKR ${amount.toStringAsFixed(0)}',
      'type':   'credit',
    });
    notifyListeners();
  }

  bool withdrawMoney(double amount) {
    if (walletBalance < amount) return false;
    walletBalance -= amount;
    final now = DateTime.now();
    walletTransactions.insert(0, {
      'title':  'Withdrawal to JazzCash',
      'date':   '${_monthName(now.month)} ${now.day} · ${_timeStr(now)}',
      'amount': '- PKR ${amount.toStringAsFixed(0)}',
      'type':   'debit',
    });
    notifyListeners();
    return true;
  }

  void logout() {
    isLoggedIn = false; role = ''; uid = '';
    customerName = ''; customerInitial = ''; customerPhone = '';
    customerEmail = ''; customerCity = 'Karachi, Pakistan';
    walletBalance = 0.0; rideHistory = []; walletTransactions = [];
    driverName = ''; driverInitials = ''; driverVehicle = '';
    documentsSubmitted = false; driverBalance = 0.0;
    ridesCompleted = 0; dailyEarnings = 0.0; onlineHours = 0.0;
    isOnline = false; driverEarningsHistory = [];
    weeklyEarnings = List.filled(7, 0.0);
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _monthName(int m) {
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m];
  }

  String _timeStr(DateTime dt) {
    final h    = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m    = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _firestoreTimestampToString(dynamic ts) {
    if (ts == null) return 'Recently';
    // Firestore Timestamp has a toDate() method
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      return '${_monthName(dt.month)} ${dt.day} · ${_timeStr(dt)}';
    } catch (_) {
      return 'Recently';
    }
  }

  void _seedWeeklyFromEarnings() {
    weeklyEarnings = List.filled(7, 0.0);
    // Seed today's slot with current dailyEarnings
    final todayIdx = (DateTime.now().weekday - 1).clamp(0, 6);
    weeklyEarnings[todayIdx] = dailyEarnings;
  }

}
