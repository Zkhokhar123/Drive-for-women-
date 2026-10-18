import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Brand logo — cartoon girl portrait with soft float animation.
class AppLogo extends StatelessWidget {
  final double size;
  final bool animate;
  final bool showGlow;

  const AppLogo({
    super.key,
    this.size = 88,
    this.animate = true,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.28;

    Widget logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.45),
                  blurRadius: size * 0.28,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo_girl.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: AppGradients.tripleGradient,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(Icons.female_rounded,
                size: size * 0.55, color: Colors.white),
          ),
        ),
      ),
    );

    if (!animate) return logo;

    return logo
        .animate()
        .scale(duration: 650.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 400.ms)
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -7,
          duration: 1600.ms,
          curve: Curves.easeInOut,
        );
  }
}
