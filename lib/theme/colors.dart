import 'package:flutter/material.dart';

/// Brand colors for Integrity Studio
/// Based on Brand Guidelines v1.0
///
/// ACCESSIBILITY NOTE:
/// - Gray 400 (#9CA3AF) on Gray 900 = 3.2:1 contrast (FAILS WCAG AA)
/// - Gray 300 (#D1D5DB) on Gray 900 = 4.8:1 contrast (PASSES WCAG AA)
/// - Always use gray300 or lighter for body text on dark backgrounds
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue900 = Color(0xFF1E3A8A);

  // Secondary Colors
  static const Color indigo400 = Color(0xFF818CF8);
  static const Color indigo500 = Color(0xFF6366F1);
  static const Color indigo600 = Color(0xFF4F46E5);

  // Accent Colors
  static const Color cyan400 = Color(0xFF22D3EE);
  static const Color cyan500 = Color(0xFF06B6D4);
  static const Color purple400 = Color(0xFFC084FC);
  static const Color purple500 = Color(0xFFA855F7);
  static const Color purple600 = Color(0xFF9333EA);

  // Neutrals (Dark Theme)
  static const Color gray900 = Color(0xFF111827);
  static const Color gray800 = Color(0xFF1F2937);
  static const Color gray700 = Color(0xFF374151);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray400 = Color(0xFF9CA3AF); // DO NOT use for body text
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);

  // Semantic Colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFF87171);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors (WCAG AA Compliant)
  static const Color textPrimary = Colors.white; // 21:1 on gray900
  static const Color textSecondary = gray300; // 4.8:1 on gray900
  static const Color textTertiary = gray300; // 4.8:1 on gray900
  static const Color textDisabled = gray500; // Use only for disabled states
  static const Color textLink = blue400; // 4.6:1 on gray900

  // Background Colors
  static const Color backgroundPrimary = gray900;
  static const Color backgroundSecondary = gray800;
  static const Color backgroundElevated = gray800;
  static const Color backgroundCard = Color(0xF2111827); // gray900 at 95%

  // Border Colors
  static const Color borderDefault = Color(0x80374151); // gray700 at 50%
  static const Color borderHover = Color(0x803B82F6); // blue500 at 50%
  static const Color borderFocus = blue500;
  static const Color borderError = error;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, indigo600],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, indigo500, purple600],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gray900, gray800, gray900],
  );

  static const LinearGradient disabledGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gray600, gray700],
  );

  // Orb Colors (decorative)
  static Color orbBlue = blue500.withValues(alpha: 0.15);
  static Color orbIndigo = indigo500.withValues(alpha: 0.15);
  static Color orbPurple = purple500.withValues(alpha: 0.15);

  // Shadow Colors
  static Color shadowDefault = gray900.withValues(alpha: 0.3);
  static Color shadowBlue = blue500.withValues(alpha: 0.3);
}
