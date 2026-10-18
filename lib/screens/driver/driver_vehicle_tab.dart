import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';

class DriverVehicleTab extends StatelessWidget {
  const DriverVehicleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final session = UserSession.instance;
        final isBike  = session.vehicleModel.toLowerCase().contains('honda') ||
            session.vehicleModel.toLowerCase().contains('yamaha') ||
            session.vehicleModel.toLowerCase().contains('suzuki') ||
            session.vehicleModel.toLowerCase().contains('70') ||
            session.vehicleModel.toLowerCase().contains('bike');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Driver profile summary ────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.15),
                      AppTheme.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        session.driverInitials.isEmpty
                            ? '?' : session.driverInitials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.driverName.isEmpty
                                ? 'Driver' : session.driverName,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(session.customerPhone,
                              style: const TextStyle(
                                  color: AppTheme.textHint, fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${session.driverRating}  ·  ${session.ridesCompleted} rides',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 20),

              // ── Vehicle card ──────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isBike
                            ? Icons.motorcycle_rounded
                            : Icons.directions_car_rounded,
                        color: AppTheme.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.vehicleModel.isEmpty
                                ? 'Vehicle Not Set'
                                : session.vehicleModel,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          _VehicleInfoRow(
                              icon: Icons.confirmation_number_rounded,
                              text: session.vehicleReg.isEmpty
                                  ? '—'
                                  : session.vehicleReg),
                          const SizedBox(height: 2),
                          _VehicleInfoRow(
                              icon: Icons.palette_rounded,
                              text:
                                  '${session.vehicleColor.isEmpty ? '—' : session.vehicleColor}'
                                  '  ·  ${session.vehicleYear.isEmpty ? '—' : session.vehicleYear}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 28),

              // ── Document status ───────────────────────
              const Text(
                'Document & Verification Status',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),

              _DocItem(
                icon: Icons.assignment_ind_rounded,
                name: 'CNIC Identification Card',
                status: session.cnicImagePath.isNotEmpty
                    ? 'Verified' : 'Pending Upload',
                color: session.cnicImagePath.isNotEmpty
                    ? AppTheme.success : Colors.amber,
              ),
              _DocItem(
                icon: Icons.badge_rounded,
                name: 'Driving Licence',
                status: session.licenceImagePath.isNotEmpty
                    ? 'Verified' : 'Pending Upload',
                color: session.licenceImagePath.isNotEmpty
                    ? AppTheme.success : Colors.amber,
              ),
              _DocItem(
                icon: Icons.motorcycle_rounded,
                name: 'Vehicle / Bike Photo',
                status: session.bikeImagePath.isNotEmpty
                    ? 'Uploaded' : 'Pending Upload',
                color: session.bikeImagePath.isNotEmpty
                    ? AppTheme.success : Colors.amber,
              ),
              const _DocItem(
                icon: Icons.description_rounded,
                name: 'Vehicle Registration Book',
                status: 'Pending Review',
                color: Colors.amber,
              ),
              _DocItem(
                icon: Icons.security_rounded,
                name: 'Background Verification',
                status: session.documentsSubmitted
                    ? 'Verified' : 'Not Started',
                color: session.documentsSubmitted
                    ? AppTheme.success : AppTheme.error,
              ),

              const SizedBox(height: 28),

              // ── Account status summary ────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.success, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Account Active',
                            style: TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.documentsSubmitted
                                ? 'All documents submitted. You can accept rides.'
                                : 'Please complete your profile to start riding.',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable doc status row ───────────────────────────────────
class _DocItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final Color color;
  const _DocItem({
    required this.icon,
    required this.name,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.bgSurface,
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppTheme.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _VehicleInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _VehicleInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textHint, size: 13),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 13)),
        ),
      ],
    );
  }
}
