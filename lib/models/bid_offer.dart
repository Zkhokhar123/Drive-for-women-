enum BidOfferStatus { pending, accepted, rejected }

class BidOffer {
  final String driverId;
  final String driverName;
  final String vehicleInfo;
  final double rating;
  final int offeredFare;
  final DateTime timestamp;
  BidOfferStatus status;

  BidOffer({
    required this.driverId,
    required this.driverName,
    required this.vehicleInfo,
    required this.rating,
    required this.offeredFare,
    BidOfferStatus? status,
    DateTime? timestamp,
  })  : status = status ?? BidOfferStatus.pending,
        timestamp = timestamp ?? DateTime.now();
}
