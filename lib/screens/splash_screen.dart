import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../services/firebase_service.dart';
import 'onboarding_screen.dart';
import 'customer/customer_home.dart';
import 'driver/driver_home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Give the animation time to breathe
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // ── If Firebase ready + already signed in → load session ─
    if (FirebaseService.isReady) {
      final fb = FirebaseService.instance;
      if (fb.isSignedIn) {
        try {
          await fb.loadSessionFromFirestore();
          if (!mounted) return;

          final role = fb.currentUser != null
              ? await _fetchRole()
              : '';

          if (role == 'customer') {
            _go(const CustomerHome());
            return;
          } else if (role == 'driver') {
            _go(const DriverHome());
            return;
          }
        } catch (e) {
          debugPrint('SplashScreen: session load failed — $e');
        }
      }
    }

    // ── Not signed in → go to onboarding ───────────────────
    _go(const OnboardingScreen());
  }

  Future<String> _fetchRole() async {
    final uid  = FirebaseService.instance.currentUid;
    if (uid == null) return '';
    final data = await FirebaseService.instance.fetchUser(uid);
    return data?['role'] as String? ?? '';
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
                gradient: AppGradients.primaryVertical),
          ),

          // Blob 1
          Positioned(
            top: -80, left: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE91E8C).withValues(alpha: 0.20),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1),
                    duration: 3000.ms, curve: Curves.easeInOut),
          ),

          // Blob 2
          Positioned(
            bottom: -60, right: -60,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.25),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1.05, 1.05), end: const Offset(0.85, 0.85),
                    duration: 3500.ms, curve: Curves.easeInOut),
          ),

          // Blob 3
          Positioned(
            top: size.height * 0.4, right: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAD1457).withValues(alpha: 0.18),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2),
                    duration: 2800.ms, curve: Curves.easeInOut),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 128, showGlow: true),

                const SizedBox(height: 28),

                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Drive for ',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      TextSpan(
                        text: 'Women',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFB3D9),
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 8),

                Text(
                  'Safe Rides, by Women for Women',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                const SizedBox(height: 64),

                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),

          // Version badge
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Center(
              child: Text(
                'v1.0.0 · Beta',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12, fontWeight: FontWeight.w500,
                    letterSpacing: 1.2),
              ),
            ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),
          ),
        ],
      ),
    );
  }
}
