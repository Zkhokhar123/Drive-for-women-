import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ───────────────────────────────────────────
  static const Color primary = Color(0xFFE91E8C);
  static const Color primaryLight = Color(0xFFFF6B9D);
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color secondary = Color(0xFF7B1FA2);
  static const Color accent = Color(0xFF9C27B0);

  // ── Background Colors ──────────────────────────────────────
  static const Color bgDark = Color(0xFF080812);
  static const Color bgSurface = Color(0xFF12121E);
  static const Color bgCard = Color(0xFF1A1A2E);
  static const Color bgCard2 = Color(0xFF222238);

  // ── Text Colors ────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF0F0F8);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF8888AA);

  // ── Status Colors ──────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ── Glass morphism helper ─────────────────────────────────
  static BoxDecoration glassMorphism({double radius = 20}) {
    return BoxDecoration(
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: bgCard,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(
        ThemeData.dark().textTheme.copyWith(
          headlineLarge: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: GoogleFonts.inter(
            color: textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: const TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: const TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
          bodySmall: const TextStyle(
            color: textHint,
            fontSize: 12,
          ),
          labelLarge: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
        // Subtle gradient flex space and bottom border glow
        shape: Border(
          bottom: BorderSide(
            color: primary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSurface,
        selectedItemColor: primary,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
        // Top border glow applied via decoration in each screen
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 54),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: primary.withValues(alpha: 0.08),
          ),
        ),
      ),
    );
  }
}

// ── Gradient helpers ────────────────────────────────────────
class AppGradients {
  /// Two-color brand gradient (pink → purple)
  static const LinearGradient primary = LinearGradient(
    colors: [AppTheme.primary, AppTheme.secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Two-color vertical gradient
  static const LinearGradient primaryVertical = LinearGradient(
    colors: [AppTheme.primary, AppTheme.secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Three-color brand gradient: pink → deep rose → deep purple
  static const LinearGradient tripleGradient = LinearGradient(
    colors: [
      Color(0xFFE91E8C),
      Color(0xFFAD1457),
      Color(0xFF6A1B9A),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle glow gradient: pink → purple
  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0xFFE91E8C), Color(0xFF7B1FA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark background gradient
  static const LinearGradient dark = LinearGradient(
    colors: [AppTheme.bgDark, AppTheme.bgSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
