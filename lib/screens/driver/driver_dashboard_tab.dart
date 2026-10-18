import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';

class DriverDashboardTab extends StatelessWidget {
  const DriverDashboardTab({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final s = UserSession.instance;
        final progressValue = (s.ridesCompleted / 10).clamp(0.0, 1.0);
        final progressPct   = (progressValue * 100).round();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting, ${s.driverName.isEmpty ? 'Driver' : s.driverName.split(' ')[0]} 👋',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Keep up the great work! Safe driving.',
                          style: TextStyle(
                              color: AppTheme.textHint, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // Online status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: s.isOnline
                          ? AppTheme.success.withValues(alpha: 0.15)
                          : AppTheme.bgCard2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: s.isOnline
                            ? AppTheme.success.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.isOnline
                                ? AppTheme.success
                                : AppTheme.textHint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: s.isOnline
                                ? AppTheme.success
                                : AppTheme.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Stat cards ────────────────────────────
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  _StatCard(
                    icon: Icons.payments_rounded,
                    title: "Today's Earnings",
                    value: 'PKR ${s.dailyEarnings.toStringAsFixed(0)}',
                    color: AppTheme.primary,
                  ),
                  _StatCard(
                    icon: Icons.done_all_rounded,
                    title: 'Rides Completed',
                    value: '${s.ridesCompleted}',
                    color: AppTheme.accent,
                  ),
                  _StatCard(
                    icon: Icons.star_rounded,
                    title: 'Your Rating',
                    value: '${s.driverRating} ★',
                    color: Colors.amber,
                  ),
                  _StatCard(
                    icon: Icons.timer_rounded,
                    title: 'Online Time',
                    value: '${s.onlineHours.toStringAsFixed(1)} hrs',
                    color: AppTheme.success,
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Recent earnings log ───────────────────
              if (s.driverEarningsHistory.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Rides',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white)),
                    Text(
                      '${s.driverEarningsHistory.length} total',
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...s.driverEarningsHistory.take(3).toList().asMap().entries.map((e) {
                  final i    = e.key;
                  final ride = e.value;
                  final isBike = ride['rideType'] == 'bike';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isBike
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.accent.withValues(alpha: 0.12),
                          child: Icon(
                            isBike
                                ? Icons.motorcycle_rounded
                                : Icons.local_taxi_rounded,
                            color:
                                isBike ? AppTheme.primary : AppTheme.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride['route'] as String,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              Text(
                                ride['date'] as String,
                                style: const TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'PKR ${ride['fare']}',
                          style: const TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 60).ms, duration: 300.ms);
                }),
                const SizedBox(height: 16),
              ],

              // ── Safety banner ─────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        color: AppTheme.primary, size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your safety is our absolute priority',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.primary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Verified female riders only. Share tracking anytime.',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // ── Daily goal progress ───────────────────
              const Text(
                'Daily Goal Target',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${s.ridesCompleted} / 10 rides',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13),
                        ),
                        Text(
                          '$progressPct%',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        minHeight: 8,
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.bgCard2,
                      ),
                    ),
                    if (s.ridesCompleted >= 10) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.celebration_rounded,
                              color: AppTheme.success, size: 16),
                          SizedBox(width: 6),
                          Text('Daily goal reached! 🎉',
                              style: TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: AppTheme.textHint, size: 12),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}
