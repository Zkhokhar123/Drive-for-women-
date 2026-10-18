import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.security_rounded,
      emoji: '🛡️',
      title: 'Ride Safe,\nRide Confident',
      subtitle: 'Drive for Women — Pakistan\'s first women-focused ride app. Verified female drivers ensure your safety every trip.',
      color: const Color(0xFFE91E8C),
    ),
    _OnboardingData(
      icon: Icons.location_on_rounded,
      emoji: '📍',
      title: 'Live Tracking\n& SOS',
      subtitle: 'Share your live location with family. Emergency SOS button available at all times.',
      color: const Color(0xFF7B1FA2),
    ),
    _OnboardingData(
      icon: Icons.payments_rounded,
      emoji: '💳',
      title: 'Easy & Secure\nPayments',
      subtitle: 'Pay securely and conveniently with Cash at the end of your ride.',
      color: const Color(0xFF00BCD4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Page View
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) => _OnboardingPage(data: _pages[i]),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.bgDark.withValues(alpha: 0),
                    AppTheme.bgDark.withValues(alpha: 0.95),
                    AppTheme.bgDark,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pages.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 4,
                      activeDotColor: _pages[_currentPage].color,
                      dotColor: AppTheme.bgCard2,
                      spacing: 6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Next / Get Started button
                  if (_currentPage < _pages.length - 1)
                    _GradientButton(
                      label: 'Next',
                      onPressed: () => _controller.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      ),
                    )
                  else
                    _GradientButton(
                      label: '🚀 Get Started',
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Skip button
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppTheme.textHint,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingData {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  _OnboardingData({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppTheme.bgDark),
      child: Column(
        children: [
          // Hero illustration area
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    data.color.withValues(alpha: 0.3),
                    AppTheme.bgDark,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  // Big emoji / icon
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(
                        color: data.color.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        data.emoji,
                        style: const TextStyle(fontSize: 72),
                      ),
                    ),
                  )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.elasticOut)
                      .fade(),

                  const SizedBox(height: 32),

                  // Decorative circles
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      3,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: 10 + i * 6.0,
                        height: 10 + i * 6.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: data.color.withValues(alpha: 0.2 + i * 0.1),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ),
          ),

          // Text content
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.2,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideX(begin: -0.2),
                  const SizedBox(height: 16),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.7,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 500.ms)
                      .slideX(begin: -0.2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
