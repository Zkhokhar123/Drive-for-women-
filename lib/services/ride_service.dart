import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_service.dart';
import 'user_session.dart';

/// Live ride marketplace on Firestore.
///
/// Collections:
///   rides/{rideId}
///   rides/{rideId}/offers/{offerId}
///   rides/{rideId}/messages/{msgId}
///   users/{uid}  (+ lat/lng when driver is online)
class RideService {
  RideService._();
  static final RideService instance = RideService._();

  FirebaseFirestore get _db {
    if (!FirebaseService.isReady) {
      throw StateError('Firebase not ready');
    }
    return FirebaseFirestore.instance;
  }

  CollectionReference<Map<String, dynamic>> get _rides =>
      _db.collection('rides');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  bool get isReady => FirebaseService.isReady;

  // ── Create ride (customer Find Drivers) ────────────────────

  Future<String> createRide({
    required String pickup,
    required String drop,
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
    required String rideType,
    required int proposedFare,
    List<List<double>>? routePoints, // [[lat,lng], ...]
  }) async {
    final session = UserSession.instance;
    final uid = session.uid.isNotEmpty
        ? session.uid
        : FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw StateError('Please login with Phone OTP or Google first');
    }

    final doc = await _rides.add({
      'customerId': session.uid.isNotEmpty ? session.uid : uid,
      'customerName': session.customerName,
      'customerPhone': session.customerPhone,
      'pickup': pickup,
      'drop': drop,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropLat': dropLat,
      'dropLng': dropLng,
      'rideType': rideType,
      'proposedFare': proposedFare,
      'paymentMode': 'cash',
      'status': 'searching', // searching | offered | accepted | ongoing | completed | cancelled
      'driverId': '',
      'driverName': '',
      'driverPhone': '',
      'driverVehicle': '',
      'driverRating': 0.0,
      'agreedFare': proposedFare,
      'customerLat': pickupLat,
      'customerLng': pickupLng,
      'driverLat': 0.0,
      'driverLng': 0.0,
      'routePoints': routePoints ?? [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> cancelRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRide(String rideId) =>
      _rides.doc(rideId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOffers(String rideId) =>
      _rides
          .doc(rideId)
          .collection('offers')
          .orderBy('createdAt', descending: false)
          .snapshots();

  // ── Driver: open searching rides ───────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOpenRides() => _rides
      .where('status', whereIn: ['searching', 'offered'])
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots();

  /// Driver submits bid / accept at [fare].
  Future<void> submitOffer({
    required String rideId,
    required int fare,
  }) async {
    final session = UserSession.instance;
    final uid = session.uid;
    if (uid.isEmpty) throw StateError('Driver not logged in');

    final offerRef = _rides.doc(rideId).collection('offers').doc(uid);
    await offerRef.set({
      'driverId': uid,
      'driverName': session.driverName,
      'initials': session.driverInitials,
      'vehicle': session.driverVehicle,
      'rating': session.driverRating,
      'fare': fare,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _rides.doc(rideId).update({
      'status': 'offered',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Customer accepts a driver offer → ride becomes accepted.
  Future<void> acceptOffer({
    required String rideId,
    required String offerId,
    required Map<String, dynamic> offer,
  }) async {
    final batch = _db.batch();
    final rideRef = _rides.doc(rideId);
    batch.update(rideRef, {
      'status': 'accepted',
      'driverId': offer['driverId'],
      'driverName': offer['driverName'],
      'driverVehicle': offer['vehicle'],
      'driverRating': offer['rating'] ?? 5.0,
      'agreedFare': offer['fare'],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(
      rideRef.collection('offers').doc(offerId),
      {'status': 'accepted'},
    );
    await batch.commit();
  }

  Future<void> declineOffer({
    required String rideId,
    required String offerId,
  }) async {
    await _rides.doc(rideId).collection('offers').doc(offerId).update({
      'status': 'declined',
    });
  }

  // ── Live GPS on ride ───────────────────────────────────────

  Future<void> updateCustomerLocation(
      String rideId, double lat, double lng) async {
    await _rides.doc(rideId).update({
      'customerLat': lat,
      'customerLng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDriverLocation(
      String rideId, double lat, double lng) async {
    await _rides.doc(rideId).update({
      'driverLat': lat,
      'driverLng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Persist driver's last known location on user doc (for discovery).
  Future<void> updateUserGps(String uid, double lat, double lng) async {
    await _users.doc(uid).set({
      'lat': lat,
      'lng': lng,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> startRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': 'ongoing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Complete ride → history for customer + earnings for driver.
  Future<void> completeRide(String rideId) async {
    final snap = await _rides.doc(rideId).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final fare = (data['agreedFare'] as num?)?.toInt() ??
        (data['proposedFare'] as num?)?.toInt() ??
        0;
    final route = '${data['pickup']} → ${data['drop']}';
    final rideType = data['rideType'] as String? ?? 'bike';
    final customerId = data['customerId'] as String? ?? '';
    final driverId = data['driverId'] as String? ?? '';
    final driverName = data['driverName'] as String? ?? 'Driver';

    await _rides.doc(rideId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final fb = FirebaseService.instance;
    final session = UserSession.instance;
    if (customerId.isNotEmpty) {
      await fb.addRideToHistory(
        uid: customerId,
        route: route,
        driverName: driverName,
        rideType: rideType,
        fare: fare,
        status: 'Completed',
      );
      if (session.uid == customerId) {
        session.addCompletedRide(
          route:      route,
          driverName: driverName,
          rideType:   rideType,
          fare:       fare,
        );
      }
    }
    if (driverId.isNotEmpty) {
      final driverDoc = await _users.doc(driverId).get();
      final d = driverDoc.data() ?? {};
      final daily = ((d['dailyEarnings'] as num?)?.toDouble() ?? 0) + fare;
      final bal = ((d['driverBalance'] as num?)?.toDouble() ?? 0) + fare;
      final rides = ((d['ridesCompleted'] as num?)?.toInt() ?? 0) + 1;
      await fb.updateDriverEarnings(
        uid: driverId,
        dailyEarnings: daily,
        driverBalance: bal,
        ridesCompleted: rides,
        onlineHours: (d['onlineHours'] as num?)?.toDouble() ?? 0,
      );
      await fb.addDriverEarning(
        uid: driverId,
        route: route,
        fare: fare,
        rideType: rideType,
      );
      if (session.uid == driverId) {
        session.dailyEarnings = daily;
        session.driverBalance = bal;
        session.ridesCompleted = rides;
        session.notifyListeners();
      }
    }
  }

  // ── Chat ───────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String rideId) =>
      _rides
          .doc(rideId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots();

  Future<void> sendMessage({
    required String rideId,
    required String text,
    required bool fromCustomer,
  }) async {
    final session = UserSession.instance;
    await _rides.doc(rideId).collection('messages').add({
      'text': text.trim(),
      'fromCustomer': fromCustomer,
      'senderId': session.uid,
      'senderName': fromCustomer ? session.customerName : session.driverName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── SOS ────────────────────────────────────────────────────

  Future<void> triggerSos({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    final session = UserSession.instance;
    await _rides.doc(rideId).collection('sos').add({
      'lat': lat,
      'lng': lng,
      'uid': session.uid,
      'name': session.role == 'driver'
          ? session.driverName
          : session.customerName,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _rides.doc(rideId).update({
      'sosTriggered': true,
      'sosLat': lat,
      'sosLng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Auth helpers (Google / Email) ──────────────────────────

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
    required bool isRegister,
    required String name,
    required String role,
  }) async {
    final auth = FirebaseAuth.instance;
    UserCredential cred;
    if (isRegister) {
      cred = await auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
    } else {
      cred = await auth.signInWithEmailAndPassword(
          email: email, password: password);
    }
    final uid = cred.user!.uid;
    final existing = await FirebaseService.instance.fetchUser(uid);
    if (existing == null) {
      if (role == 'driver') {
        await _users.doc(uid).set({
          'uid': uid,
          'role': 'driver',
          'name': name,
          'phone': '',
          'email': email,
          'vehicleModel': '',
          'vehicleReg': '',
          'vehicleColor': '',
          'vehicleYear': '',
          'isOnline': false,
          'driverRating': 5.0,
          'ridesCompleted': 0,
          'onlineHours': 0.0,
          'dailyEarnings': 0.0,
          'driverBalance': 0.0,
          'walletBalance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseService.instance.saveCustomer(
          uid: uid,
          name: name,
          phone: '',
          email: email,
        );
      }
    }
    await FirebaseService.instance.loadSessionFromFirestore();
    return cred;
  }

  Future<UserCredential?> signInWithGoogle({required String role}) async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();
    final googleUser = await signIn.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw StateError('Google Sign-In did not return an ID token');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final uid = cred.user!.uid;
    final existing = await FirebaseService.instance.fetchUser(uid);
    final name = cred.user!.displayName ?? googleUser.displayName ?? 'User';
    final email = cred.user!.email ?? googleUser.email;
    if (existing == null) {
      if (role == 'driver') {
        await _users.doc(uid).set({
          'uid': uid,
          'role': 'driver',
          'name': name,
          'phone': cred.user!.phoneNumber ?? '',
          'email': email,
          'vehicleModel': '',
          'vehicleReg': '',
          'vehicleColor': '',
          'vehicleYear': '',
          'isOnline': false,
          'driverRating': 5.0,
          'ridesCompleted': 0,
          'onlineHours': 0.0,
          'dailyEarnings': 0.0,
          'driverBalance': 0.0,
          'walletBalance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await FirebaseService.instance.saveCustomer(
          uid: uid,
          name: name,
          phone: cred.user!.phoneNumber ?? '',
          email: email,
        );
      }
    }
    await FirebaseService.instance.loadSessionFromFirestore();
    return cred;
  }
}
