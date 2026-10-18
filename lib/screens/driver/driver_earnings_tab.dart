import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../services/firebase_service.dart';

class DriverEarningsTab extends StatelessWidget {
  const DriverEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final s            = UserSession.instance;
        final weeklyTotal  = s.weeklyEarnings.fold<double>(0, (a, b) => a + b);
        final monthlyEst   = (s.dailyEarnings * 26).round();
        final maxBar       = s.weeklyEarnings.reduce((a, b) => a > b ? a : b);
        const days         = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final todayIdx     = (DateTime.now().weekday - 1).clamp(0, 6);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Balance card ──────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppGradients.tripleGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Available Balance',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Text(
                      'PKR ${s.driverBalance.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.ridesCompleted} rides completed',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.output_rounded),
                      onPressed: s.driverBalance > 0
                          ? () => _cashOut(context)
                          : null,
                      label: const Text('Cashout to JazzCash / EasyPaisa',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 24),

              // ── Metric cards ──────────────────────────
              Row(
                children: [
                  Expanded(
                      child: _MetricCard(
                          label: 'Today',
                          value:
                              'PKR ${s.dailyEarnings.toStringAsFixed(0)}')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _MetricCard(
                          label: 'This Week',
                          value: 'PKR ${_fmt(weeklyTotal.round())}')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _MetricCard(
                          label: 'Est. Month',
                          value: 'PKR ${_fmt(monthlyEst)}')),
                ],
              ).animate().fadeIn(delay: 150.ms),

              const SizedBox(height: 20),

              // ── Driver stats ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.star_rounded,
                      color: Colors.amber,
                      label: 'Rating',
                      value: '${s.driverRating} ⭐',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.timer_rounded,
                      color: AppTheme.success,
                      label: 'Online',
                      value: '${s.onlineHours.toStringAsFixed(1)} hrs',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.done_all_rounded,
                      color: AppTheme.accent,
                      label: 'Rides',
                      value: '${s.ridesCompleted}',
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 220.ms),

              const SizedBox(height: 24),

              // ── Weekly bar chart ──────────────────────
              const Text('Weekly Analytics',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 14),
              Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final earnings = s.weeklyEarnings[i];
                    final pct = maxBar > 0
                        ? (earnings / maxBar).clamp(0.05, 1.0)
                        : 0.05;
                    final isToday = i == todayIdx;
                    return _DynamicBar(
                      day: days[i],
                      pct: pct.toDouble(),
                      isActive: isToday,
                      label: earnings > 0
                          ? 'PKR ${_fmt(earnings.round())}'
                          : '',
                    );
                  }),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 28),

              // ── Earnings history list ─────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ride History',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white)),
                  Text('${s.driverEarningsHistory.length} rides',
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              if (s.driverEarningsHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 48,
                            color:
                                AppTheme.textHint.withValues(alpha: 0.25)),
                        const SizedBox(height: 10),
                        const Text('No rides yet',
                            style: TextStyle(
                                color: AppTheme.textHint, fontSize: 14)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: s.driverEarningsHistory.length,
                  separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.05)),
                  itemBuilder: (ctx, i) {
                    final ride   = s.driverEarningsHistory[i];
                    final isBike = ride['rideType'] == 'bike';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isBike
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.accent.withValues(alpha: 0.12),
                            child: Icon(
                              isBike
                                  ? Icons.motorcycle_rounded
                                  : Icons.local_taxi_rounded,
                              color: isBike
                                  ? AppTheme.primary
                                  : AppTheme.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ride['route'] as String,
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 3),
                                Text(ride['date'] as String,
                                    style: const TextStyle(
                                        color: AppTheme.textHint,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                            '+ PKR ${ride['fare']}',
                            style: const TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 350.ms),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _cashOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Cashout Request',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'PKR ${UserSession.instance.driverBalance.toStringAsFixed(0)} will be transferred to your JazzCash / EasyPaisa account within 24 hours.',
          style: const TextStyle(
              color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textHint)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              UserSession.instance.driverCashout();
              // Persist to Firestore
              final uid = UserSession.instance.uid;
              if (uid.isNotEmpty) {
                await FirebaseService.instance.driverCashout(uid);
              }
              nav.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Cashout request submitted! ✓'),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Confirm Cashout'),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 11)),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textHint, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DynamicBar extends StatelessWidget {
  final String day;
  final double pct;
  final bool isActive;
  final String label;
  const _DynamicBar(
      {required this.day,
      required this.pct,
      this.isActive = false,
      this.label = ''});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label.isNotEmpty)
          Text(label,
              style: TextStyle(
                  fontSize: 8,
                  color: isActive ? AppTheme.primary : AppTheme.textHint,
                  fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          height: 110 * pct,
          width: 22,
          decoration: BoxDecoration(
            gradient: isActive ? AppGradients.tripleGradient : null,
            color: isActive
                ? null
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(day,
            style: TextStyle(
                fontSize: 10,
                color: isActive
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                fontWeight: isActive
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ],
    );
  }
}
