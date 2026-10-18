import 'package:flutter/material.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import 'customer_book_tab.dart';
import 'customer_track_tab.dart';
import 'customer_history_tab.dart';
import 'customer_wallet_tab.dart';
import 'customer_profile_tab.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _currentIndex = 0;

  // Static tabs that don't need constructor params — built once
  static const List<Widget> _staticTabs = [
    CustomerBookTab(),
    CustomerHistoryTab(),
    CustomerWalletTab(),
    CustomerProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final session = UserSession.instance;

        final trackTab = CustomerTrackTab(
          rideId: session.activeRideId,
          pickup: session.customerCity.isNotEmpty
              ? session.customerCity
              : 'Pickup',
          drop: 'Drop',
          fare: 0,
          driverName: session.driverName,
          driverInitials: session.driverInitials,
          vehicleInfo: session.driverVehicle,
          driverRating: session.driverRating,
          rideType: 'bike',
        );

        // Full ordered tab list
        final tabs = [
          _staticTabs[0], // Book
          trackTab,        // Live Track — always live
          _staticTabs[1], // History
          _staticTabs[2], // Wallet
          _staticTabs[3], // Profile
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: tabs,
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
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled), label: 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.my_location_rounded), label: 'Track'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.receipt_long_rounded), label: 'My Rides'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.wallet_rounded), label: 'Wallet'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
            ),
          ),
        );
      },
    );
  }
}
