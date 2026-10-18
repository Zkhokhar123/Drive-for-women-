import 'bid_offer.dart';

enum RideStatus { pending, negotiating, confirmed, inProgress, completed, cancelled }

class RideRequest {
  static int _counter = 0;

  final String id;
  final String riderId;
  final String riderName;
  final String pickup;
  final String drop;
  final double pickupLat;
  final double pickupLng;
  final double dropLat;
  final double dropLng;
  final String rideType; // 'bike' or 'car'
  final int proposedFare;
  RideStatus status;
  final List<BidOffer> offers;

  RideRequest({
    required this.riderId,
    required this.riderName,
    required this.pickup,
    required this.drop,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropLat,
    required this.dropLng,
    required this.rideType,
    required this.proposedFare,
    this.status = RideStatus.pending,
    List<BidOffer>? offers,
  })  : id = 'DFW-${(++_counter).toString().padLeft(3, '0')}',
        offers = offers ?? [];
}
