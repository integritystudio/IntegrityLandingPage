import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Typography styles for Integrity Studio
/// Based on Brand Guidelines v1.0
///
/// Type Scale:
/// - Heading XL: 64px (40px mobile)
/// - Heading LG: 48px (32px mobile)
/// - Heading MD: 36px (28px mobile)
/// - Heading SM: 24px
/// - Body LG: 20px
/// - Body MD: 16px
/// - Body SM: 14px
/// - Caption: 12px
class AppTypography {
  AppTypography._();

  static String get _fontFamily => _testFontFamily ?? GoogleFonts.inter().fontFamily!;
  static String get _monoFontFamily => _testMonoFontFamily ?? GoogleFonts.jetBrainsMono().fontFamily!;

  /// Override font families for testing.
  /// @visibleForTesting
  static String? _testFontFamily;
  static String? _testMonoFontFamily;

  /// Set test font families to avoid Google Fonts network loading.
  /// @visibleForTesting
  static void setTestFonts({String fontFamily = 'Inter', String monoFontFamily = 'JetBrainsMono'}) {
    _testFontFamily = fontFamily;
    _testMonoFontFamily = monoFontFamily;
  }

  /// Reset to real Google Fonts.
  /// @visibleForTesting
  static void resetTestFonts() {
    _testFontFamily = null;
    _testMonoFontFamily = null;
  }

  // Headings
  static TextStyle get headingXL => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 64,
        fontWeight: FontWeight.bold,
        height: 1.1,
        letterSpacing: -0.02,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingLG => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 1.15,
        letterSpacing: -0.01,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingMD => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get headingSM => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.textPrimary,
      );

  // Body Text
  static TextStyle get bodyLG => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.normal,
        height: 1.6,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodyMD => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySM => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.textSecondary, // Changed from gray400 for WCAG compliance
      );

  // Special Styles
  static TextStyle get buttonText => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.0,
        letterSpacing: 0.01,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary, // Changed from gray400 for WCAG compliance
      );

  static TextStyle get label => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  static TextStyle get statValue => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.bold,
        height: 1.0,
        color: AppColors.textPrimary,
      );

  static TextStyle get statLabel => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: AppColors.textSecondary,
      );

  // Link Styles
  static TextStyle get link => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textLink,
        decoration: TextDecoration.none,
      );

  static TextStyle get linkHover => link.copyWith(
        decoration: TextDecoration.underline,
      );

  // Code Styles
  static TextStyle get code => TextStyle(
        fontFamily: _monoFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.5,
        color: AppColors.blue400,
      );

  static TextStyle get codeBlock => TextStyle(
        fontFamily: _monoFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        height: 1.6,
        color: AppColors.gray300,
      );

  // Responsive Heading Helpers
  static TextStyle headingXLResponsive(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) {
      return headingXL.copyWith(fontSize: 40);
    } else if (width < 1024) {
      return headingXL.copyWith(fontSize: 52);
    }
    return headingXL;
  }

  static TextStyle headingLGResponsive(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) {
      return headingLG.copyWith(fontSize: 32);
    } else if (width < 1024) {
      return headingLG.copyWith(fontSize: 40);
    }
    return headingLG;
  }

  static TextStyle headingMDResponsive(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) {
      return headingMD.copyWith(fontSize: 28);
    } else if (width < 1024) {
      return headingMD.copyWith(fontSize: 32);
    }
    return headingMD;
  }
}
