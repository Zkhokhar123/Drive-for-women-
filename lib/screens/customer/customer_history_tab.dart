import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';

class CustomerHistoryTab extends StatefulWidget {
  const CustomerHistoryTab({super.key});

  @override
  State<CustomerHistoryTab> createState() => _CustomerHistoryTabState();
}

class _CustomerHistoryTabState extends State<CustomerHistoryTab> {
  String _activeFilter = 'All';

  List<Map<String, dynamic>> get _allRides => UserSession.instance.rideHistory;

  List<Map<String, dynamic>> get _filteredRides {
    if (_activeFilter == 'All') return _allRides;
    return _allRides.where((r) => r['status'] == _activeFilter).toList();
  }

  int get _completedCount =>
      _allRides.where((r) => r['status'] == 'Completed').length;

  int get _totalSpent => _allRides
      .where((r) => r['status'] == 'Completed')
      .fold(0, (sum, r) => sum + (int.tryParse(r['fare'] as String? ?? '0') ?? 0));

  // Safe icon resolution — stored as IconData, fall back gracefully
  IconData _rideIcon(Map<String, dynamic> ride) {
    final stored = ride['icon'];
    if (stored is IconData) return stored;
    return ride['type'] == 'bike'
        ? Icons.motorcycle_rounded
        : Icons.local_taxi_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final rides = _filteredRides;

        return Scaffold(
          appBar: AppBar(title: const Text('My Rides')),
          body: Column(
            children: [
              // ── Filter chips ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: ['All', 'Completed', 'Cancelled'].map((f) {
                    final active = _activeFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: active,
                        onSelected: (_) => setState(() => _activeFilter = f),
                        selectedColor: AppTheme.primary,
                        backgroundColor: AppTheme.bgCard,
                        labelStyle: TextStyle(
                          color: active ? Colors.white : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: active
                              ? AppTheme.primary
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Summary banner ───────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _allRides.isEmpty
                              ? 'No rides yet'
                              : 'Total Spent: PKR $_totalSpent',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '$_completedCount completed',
                        style: const TextStyle(
                            color: AppTheme.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Ride list ────────────────────────────────
              Expanded(
                child: rides.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 60,
                                color: AppTheme.textHint
                                    .withValues(alpha: 0.25)),
                            const SizedBox(height: 14),
                            Text(
                              _allRides.isEmpty
                                  ? 'No rides yet.\nBook your first ride!'
                                  : 'No $_activeFilter rides found.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.textHint, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: rides.length,
                        itemBuilder: (ctx, i) {
                          final ride = rides[i];
                          final isCompleted = ride['status'] == 'Completed';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icon circle
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: isCompleted
                                        ? AppTheme.primary
                                            .withValues(alpha: 0.12)
                                        : AppTheme.error
                                            .withValues(alpha: 0.12),
                                    child: Icon(
                                      _rideIcon(ride),
                                      color: isCompleted
                                          ? AppTheme.primary
                                          : AppTheme.error,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Route + date
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ride['route'] as String? ?? '—',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ride['date'] as String? ?? '',
                                          style: const TextStyle(
                                              color: AppTheme.textHint,
                                              fontSize: 12),
                                        ),
                                        if (isCompleted &&
                                            ride['driver'] != null)
                                          Text(
                                            'Driver: ${ride['driver']}',
                                            style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Status + fare
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? AppTheme.success
                                                  .withValues(alpha: 0.15)
                                              : AppTheme.error
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          ride['status'] as String? ??
                                              '—',
                                          style: TextStyle(
                                            color: isCompleted
                                                ? AppTheme.success
                                                : AppTheme.error,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      if (isCompleted)
                                        Text(
                                          'PKR ${ride['fare'] ?? '0'}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        )
                                      else
                                        const Text('—',
                                            style: TextStyle(
                                                color: AppTheme.textHint)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(
                              delay: (i * 60).ms, duration: 300.ms);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
