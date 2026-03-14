import 'package:flutter/material.dart';

/// Spacing system for Integrity Studio
/// Based on 4px grid system
///
/// Usage:
/// - AppSpacing.md for standard spacing (16px)
/// - AppSpacing.section for vertical section padding (80px)
/// - AppSpacing.containerPadding(context) for responsive container padding
class AppSpacing {
  AppSpacing._();

  // Base spacing values (4px grid)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double section = 80;

  // Container constraints
  static const double containerMaxWidth = 1280;
  static const double containerPaddingMobile = 16;
  static const double containerPaddingTablet = 24;
  static const double containerPaddingDesktop = 32;

  // Section spacing
  static const double sectionVertical = 80;
  static const double sectionVerticalMobile = 48;

  // Card spacing
  static const double cardPadding = 24;
  static const double cardPaddingMobile = 16;
  static const double cardGap = 24;
  static const double cardGapMobile = 16;

  // Form spacing
  static const double formFieldGap = 16;
  static const double formSectionGap = 32;

  // Footer layout
  static const double footerMobileLinkColumnWidth = 150;
  static const double footerBrandColumnMaxWidth = 280;

  // Icon sizes
  static const double iconSM = 16;
  static const double iconMD = 20;
  static const double iconLG = 24;

  // Border radius
  static const double radiusSM = 4;
  static const double radiusMD = 8;
  static const double radiusLG = 12;
  static const double radiusXL = 16;
  static const double radiusFull = 9999;

  // Responsive helpers
  static double containerPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 768) return containerPaddingMobile;
    if (width < 1024) return containerPaddingTablet;
    return containerPaddingDesktop;
  }

  static double sectionPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 768 ? sectionVerticalMobile : sectionVertical;
  }

  static double cardPaddingResponsive(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 768 ? cardPaddingMobile : cardPadding;
  }

  static double cardGapResponsive(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < 768 ? cardGapMobile : cardGap;
  }

  // EdgeInsets helpers
  static EdgeInsets get paddingXS => const EdgeInsets.all(xs);
  static EdgeInsets get paddingSM => const EdgeInsets.all(sm);
  static EdgeInsets get paddingMD => const EdgeInsets.all(md);
  static EdgeInsets get paddingLG => const EdgeInsets.all(lg);
  static EdgeInsets get paddingXL => const EdgeInsets.all(xl);

  static EdgeInsets get horizontalMD =>
      const EdgeInsets.symmetric(horizontal: md);
  static EdgeInsets get horizontalLG =>
      const EdgeInsets.symmetric(horizontal: lg);
  static EdgeInsets get verticalMD => const EdgeInsets.symmetric(vertical: md);
  static EdgeInsets get verticalLG => const EdgeInsets.symmetric(vertical: lg);
  static EdgeInsets get verticalSection =>
      const EdgeInsets.symmetric(vertical: section);
}

/// Breakpoints for responsive design
class Breakpoints {
  Breakpoints._();

  static const double mobile = 0;
  static const double mobileLarge = 480;
  static const double tablet = 768;
  static const double tabletLarge = 900;
  static const double desktop = 1024;
  static const double wide = 1440;
  static const double ultraWide = 1920;
}

/// Responsive utilities
class ResponsiveUtils {
  ResponsiveUtils._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.tablet;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.tablet &&
      MediaQuery.of(context).size.width < Breakpoints.desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.desktop;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.wide;

  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? wide,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= Breakpoints.wide && wide != null) return wide;
    if (width >= Breakpoints.desktop && desktop != null) return desktop;
    if (width >= Breakpoints.tablet && tablet != null) return tablet;
    return mobile;
  }

  static int gridColumns(BuildContext context) {
    return responsive(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      wide: 4,
    );
  }
}
