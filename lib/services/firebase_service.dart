import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'user_session.dart';

/// Central Firebase service — Auth, Firestore, Storage.
/// All methods return typed results or throw [FirebaseException].
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  /// False when no real Firebase project is configured (local demo mode).
  static bool isReady = false;

  // ── Lazy accessors (safe when Firebase failed to init) ─────
  FirebaseAuth get _auth {
    _ensureReady();
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _db {
    _ensureReady();
    return FirebaseFirestore.instance;
  }

  FirebaseStorage get _storage {
    _ensureReady();
    return FirebaseStorage.instance;
  }

  void _ensureReady() {
    if (!isReady) {
      throw StateError(
        'Firebase is not configured. Use Email / Google demo login, '
        'or add a real google-services.json from Firebase Console.',
      );
    }
  }

  // ── Convenience getters ────────────────────────────────────
  User? get currentUser        => isReady ? _auth.currentUser : null;
  String? get currentUid       => isReady ? _auth.currentUser?.uid : null;
  bool   get isSignedIn        => isReady && _auth.currentUser != null;
  Stream<User?> get authState  => isReady ? _auth.authStateChanges() : const Stream.empty();

  // ── Collection references ──────────────────────────────────
  CollectionReference get _users => _db.collection('users');

  // ════════════════════════════════════════════════════════════
  //  AUTH — Phone OTP
  // ════════════════════════════════════════════════════════════

  String? _verificationId;
  int?    _resendToken;

  /// Send OTP to [phoneNumber] (full E.164 format, e.g. +923001234567).
  /// Calls [onCodeSent] when SMS is dispatched.
  /// Calls [onAutoVerified] if the phone auto-verifies (Android only).
  /// Calls [onError] on failure.
  Future<void> sendOTP({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-verification
        onAutoVerified?.call(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken    = resendToken;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Verify [smsCode] against the last sent OTP.
  /// Returns the [UserCredential] on success.
  Future<UserCredential> verifyOTP(String smsCode) async {
    if (_verificationId == null) {
      throw FirebaseAuthException(
          code: 'no-verification-id',
          message: 'No OTP sent yet. Call sendOTP first.');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign out from Firebase Auth.
  Future<void> signOut() async {
    if (!isReady) return;
    await _auth.signOut();
  }

  // ════════════════════════════════════════════════════════════
  //  FIRESTORE — Users
  // ════════════════════════════════════════════════════════════

  /// Check if a user doc already exists in Firestore.
  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }

  /// Fetch user document. Returns null if not found.
  Future<Map<String, dynamic>?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data() as Map<String, dynamic>;
  }

  /// Create or update customer profile in Firestore.
  Future<void> saveCustomer({
    required String uid,
    required String name,
    required String phone,
    String email = '',
    String city  = 'Karachi, Pakistan',
  }) async {
    await _users.doc(uid).set({
      'uid':       uid,
      'role':      'customer',
      'name':      name,
      'phone':     phone,
      'email':     email,
      'city':      city,
      'walletBalance': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update specific customer profile fields.
  Future<void> updateCustomerProfile({
    required String uid,
    String? name,
    String? phone,
    String? email,
    String? city,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name  != null) data['name']  = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (city  != null) data['city']  = city;
    await _users.doc(uid).update(data);
  }

  /// Create or update driver profile in Firestore.
  Future<void> saveDriver({
    required String uid,
    required String name,
    required String phone,
    required String vehicleModel,
    required String vehicleReg,
    required String vehicleColor,
    required String vehicleYear,
    required String cnicNumber,
    required String cnicUrl,
    required String licenceNumber,
    required String licenceUrl,
    required String bikeUrl,
    required String numberPlate,
    String numberPlateUrl = '',
  }) async {
    await _users.doc(uid).set({
      'uid':            uid,
      'role':           'driver',
      'name':           name,
      'phone':          phone,
      'vehicleModel':   vehicleModel,
      'vehicleReg':     vehicleReg,
      'vehicleColor':   vehicleColor,
      'vehicleYear':    vehicleYear,
      'cnicNumber':     cnicNumber,
      'cnicUrl':        cnicUrl,
      'licenceNumber':  licenceNumber,
      'licenceUrl':     licenceUrl,
      'bikeUrl':        bikeUrl,
      'numberPlate':    numberPlate,
      'numberPlateUrl': numberPlateUrl,
      'documentsSubmitted': true,
      'isOnline':       false,
      'driverRating':   5.0,
      'ridesCompleted': 0,
      'onlineHours':    0.0,
      'dailyEarnings':  0.0,
      'driverBalance':  0.0,
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update driver online status.
  Future<void> setDriverOnline(String uid, bool isOnline) async {
    await _users.doc(uid).update({
      'isOnline':  isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update driver earnings after completing a ride.
  Future<void> updateDriverEarnings({
    required String uid,
    required double dailyEarnings,
    required double driverBalance,
    required int    ridesCompleted,
    required double onlineHours,
  }) async {
    await _users.doc(uid).update({
      'dailyEarnings':  dailyEarnings,
      'driverBalance':  driverBalance,
      'ridesCompleted': ridesCompleted,
      'onlineHours':    onlineHours,
      'updatedAt':      FieldValue.serverTimestamp(),
    });
  }

  /// Set driver balance to 0 after cashout.
  Future<void> driverCashout(String uid) async {
    await _users.doc(uid).update({
      'driverBalance': 0.0,
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  // ════════════════════════════════════════════════════════════
  //  FIRESTORE — Wallet
  // ════════════════════════════════════════════════════════════

  Future<void> updateWalletBalance(String uid, double balance) async {
    await _users.doc(uid).update({
      'walletBalance': balance,
      'updatedAt':     FieldValue.serverTimestamp(),
    });
  }

  Future<void> addWalletTransaction({
    required String uid,
    required String title,
    required double amount,
    required String type, // 'credit' | 'debit'
  }) async {
    await _users
        .doc(uid)
        .collection('walletTransactions')
        .add({
      'title':     title,
      'amount':    amount,
      'type':      type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchWalletTransactions(
      String uid) async {
    final snap = await _users
        .doc(uid)
        .collection('walletTransactions')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  FIRESTORE — Ride History
  // ════════════════════════════════════════════════════════════

  Future<void> addRideToHistory({
    required String uid,
    required String route,
    required String driverName,
    required String rideType,
    required int    fare,
    required String status,
  }) async {
    await _users.doc(uid).collection('rideHistory').add({
      'route':      route,
      'driverName': driverName,
      'rideType':   rideType,
      'fare':       fare.toString(),
      'status':     status,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchRideHistory(String uid) async {
    final snap = await _users
        .doc(uid)
        .collection('rideHistory')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  FIRESTORE — Driver Earnings History
  // ════════════════════════════════════════════════════════════

  Future<void> addDriverEarning({
    required String uid,
    required String route,
    required int    fare,
    required String rideType,
  }) async {
    await _users.doc(uid).collection('earningsHistory').add({
      'route':    route,
      'fare':     fare,
      'rideType': rideType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchDriverEarnings(
      String uid) async {
    final snap = await _users
        .doc(uid)
        .collection('earningsHistory')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  FIREBASE STORAGE — Document uploads
  // ════════════════════════════════════════════════════════════

  /// Upload a file from [localPath] to Storage.
  /// Returns the public download URL.
  Future<String> uploadDocument({
    required String uid,
    required String localPath,
    required String docType, // 'cnic' | 'licence' | 'bike' | 'numberPlate'
  }) async {
    final file = File(localPath);
    final ext  = localPath.split('.').last;
    final ref  = _storage.ref('drivers/$uid/$docType.$ext');

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/$ext'),
    );
    return task.ref.getDownloadURL();
  }

  // ════════════════════════════════════════════════════════════
  //  LOAD SESSION — populate UserSession from Firestore doc
  // ════════════════════════════════════════════════════════════

  /// Reads the Firestore user doc and populates [UserSession].
  /// Called from SplashScreen / HomeScreens on startup.
  Future<void> loadSessionFromFirestore() async {
    final uid = currentUid;
    if (uid == null) return;

    final data = await fetchUser(uid);
    if (data == null) return;

    final role = data['role'] as String? ?? '';
    final session = UserSession.instance;

    if (role == 'customer') {
      session.setCustomerFromFirestore(
        uid:           uid,
        name:          data['name']    as String? ?? '',
        phone:         data['phone']   as String? ?? '',
        email:         data['email']   as String? ?? '',
        city:          data['city']    as String? ?? 'Karachi, Pakistan',
        walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      );

      // Load ride history
      final history = await fetchRideHistory(uid);
      session.loadRideHistory(history);

      // Load wallet transactions
      final txns = await fetchWalletTransactions(uid);
      session.loadWalletTransactions(txns);

    } else if (role == 'driver') {
      session.setDriverFromFirestore(
        uid:            uid,
        name:           data['name']           as String? ?? '',
        phone:          data['phone']          as String? ?? '',
        vehicleModel:   data['vehicleModel']   as String? ?? '',
        vehicleReg:     data['vehicleReg']     as String? ?? '',
        vehicleColor:   data['vehicleColor']   as String? ?? '',
        vehicleYear:    data['vehicleYear']    as String? ?? '',
        cnicUrl:        data['cnicUrl']        as String? ?? '',
        licenceUrl:     data['licenceUrl']     as String? ?? '',
        bikeUrl:        data['bikeUrl']        as String? ?? '',
        isOnline:       data['isOnline']       as bool?   ?? false,
        driverRating:   (data['driverRating']  as num?)?.toDouble()  ?? 5.0,
        ridesCompleted: (data['ridesCompleted'] as num?)?.toInt()    ?? 0,
        onlineHours:    (data['onlineHours']   as num?)?.toDouble()  ?? 0.0,
        dailyEarnings:  (data['dailyEarnings'] as num?)?.toDouble()  ?? 0.0,
        driverBalance:  (data['driverBalance'] as num?)?.toDouble()  ?? 0.0,
        documentsSubmitted: data['documentsSubmitted'] as bool? ?? false,
      );

      // Load earnings history
      final earnings = await fetchDriverEarnings(uid);
      session.loadDriverEarnings(earnings);
    }

    debugPrint('✅ Session loaded from Firestore — role: $role uid: $uid');
  }
}
