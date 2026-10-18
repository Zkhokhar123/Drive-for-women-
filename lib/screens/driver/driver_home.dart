import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';
import 'driver_dashboard_tab.dart';
import 'driver_requests_tab.dart';
import 'driver_earnings_tab.dart';
import 'driver_vehicle_tab.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _currentIndex = 0;

  // Tabs are stateless — all data comes from UserSession via ListenableBuilder
  static const List<Widget> _tabs = [
    DriverDashboardTab(),
    DriverRequestsTab(),
    DriverEarningsTab(),
    DriverVehicleTab(),
  ];

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Log Out',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textHint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              final nav = Navigator.of(context);
              await FirebaseService.instance.signOut();
              UserSession.instance.logout();
              nav.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final session = UserSession.instance;

        return Scaffold(
          appBar: AppBar(
            title: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                      text: 'Drive for ',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  TextSpan(
                      text: 'Women',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  TextSpan(
                      text: ' · Driver',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textHint)),
                ],
              ),
            ),
            actions: [
              // ── Online toggle ───────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        session.isOnline ? 'ONLINE' : 'OFFLINE',
                        key: ValueKey(session.isOnline),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: session.isOnline
                              ? AppTheme.success
                              : AppTheme.textHint,
                        ),
                      ),
                    ),
                    Switch(
                      value: session.isOnline,
                      activeThumbColor: AppTheme.success,
                      activeTrackColor:
                          AppTheme.success.withValues(alpha: 0.3),
                      inactiveThumbColor: AppTheme.textHint,
                      inactiveTrackColor: AppTheme.bgCard2,
                      onChanged: (val) async {
                        UserSession.instance.toggleOnline(val);
                        final messenger = ScaffoldMessenger.of(context);
                        // Persist online status to Firestore
                        final uid = UserSession.instance.uid;
                        if (uid.isNotEmpty) {
                          await FirebaseService.instance
                              .setDriverOnline(uid, val);
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(val
                                ? '✅ You are now Online! Receiving requests.'
                                : '⏸️ You are now Offline'),
                            backgroundColor: val
                                ? AppTheme.success
                                : AppTheme.textHint,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded,
                          color: AppTheme.textHint, size: 20),
                      onPressed: _confirmLogout,
                      tooltip: 'Log out',
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: session.driverRequests.isNotEmpty &&
                        session.isOnline,
                    label: Text('${session.driverRequests.length}'),
                    child: const Icon(
                        Icons.notifications_active_rounded),
                  ),
                  label: 'Requests',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.payments_rounded),
                  label: 'Earnings',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.motorcycle_rounded),
                  label: 'Vehicle',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
