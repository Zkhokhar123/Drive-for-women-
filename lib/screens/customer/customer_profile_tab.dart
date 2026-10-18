import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../services/firebase_service.dart';
import '../auth/login_screen.dart';

class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  // ── Edit profile bottom sheet ─────────────────────────────
  void _openEditSheet() {
    final session = UserSession.instance;
    final nameCtrl  = TextEditingController(text: session.customerName);
    final phoneCtrl = TextEditingController(text: session.customerPhone);
    final emailCtrl = TextEditingController(text: session.customerEmail);
    final cityCtrl  = TextEditingController(text: session.customerCity);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            _editField(nameCtrl,  Icons.person_rounded,        'Full Name'),
            const SizedBox(height: 12),
            _editField(phoneCtrl, Icons.phone_android_rounded,  'Phone Number'),
            const SizedBox(height: 12),
            _editField(emailCtrl, Icons.mail_rounded,           'Email Address',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _editField(cityCtrl,  Icons.location_city_rounded,  'City'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name  = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final city  = cityCtrl.text.trim();
                // Update in-memory session immediately
                UserSession.instance.updateProfile(
                  name: name, phone: phone, email: email, city: city,
                );
                final uid = UserSession.instance.uid;
                Navigator.pop(ctx);
                // Persist to Firestore in background
                if (uid.isNotEmpty) {
                  await FirebaseService.instance.updateCustomerProfile(
                    uid: uid,
                    name:  name.isEmpty  ? null : name,
                    phone: phone.isEmpty ? null : phone,
                    email: email.isEmpty ? null : email,
                    city:  city.isEmpty  ? null : city,
                  );
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, IconData icon, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary),
      ),
    );
  }

  // ── Logout confirm ────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Log Out',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textHint)),
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
        final completedRides = session.rideHistory
            .where((r) => r['status'] == 'Completed')
            .length;
        final totalSpent = session.rideHistory
            .where((r) => r['status'] == 'Completed')
            .fold<int>(0, (sum, r) => sum + (int.tryParse(r['fare'] as String) ?? 0));

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: AppTheme.primary),
                onPressed: _openEditSheet,
                tooltip: 'Edit profile',
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // ── Avatar + name ─────────────────────────
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                session.customerInitial.isEmpty
                                    ? '?' : session.customerInitial,
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: _openEditSheet,
                              child: Container(
                                width: 32, height: 32,
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        session.customerName.isEmpty
                            ? 'Guest User' : session.customerName,
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.customerEmail.isEmpty
                            ? 'No email added' : session.customerEmail,
                        style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 24),

                // ── Stats row ─────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.motorcycle_rounded,
                      label: 'Total Rides',
                      value: '${session.rideHistory.length}',
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Completed',
                      value: '$completedRides',
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.payments_rounded,
                      label: 'Total Spent',
                      value: 'PKR $totalSpent',
                      color: AppTheme.accent,
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 20),

                // ── Wallet balance chip ───────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.15),
                        AppTheme.accent.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: AppTheme.primary, size: 22),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Wallet Balance',
                              style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                          Text(
                            'PKR ${session.walletBalance.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: AppTheme.primary, fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 28),

                // ── Profile info items ────────────────────
                _buildProfileItem(Icons.person_rounded,      'Full Name',
                    session.customerName.isEmpty ? '—' : session.customerName),
                _buildProfileItem(Icons.phone_android_rounded, 'Phone Number',
                    session.customerPhone.isEmpty ? '—' : session.customerPhone),
                _buildProfileItem(Icons.location_city_rounded, 'City',
                    session.customerCity.isEmpty ? '—' : session.customerCity),
                _buildProfileItem(Icons.mail_rounded,         'Email Address',
                    session.customerEmail.isEmpty ? 'Not added' : session.customerEmail),

                const SizedBox(height: 32),

                // ── Logout ────────────────────────────────
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    side: const BorderSide(color: AppTheme.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
                  label: const Text('Log Out',
                      style: TextStyle(color: AppTheme.error,
                          fontWeight: FontWeight.bold)),
                  onPressed: _confirmLogout,
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.bgCard,
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card helper ──────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(label,
                style: const TextStyle(color: AppTheme.textHint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
