import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Shared hero used by marketing sub-pages (Features, Status, etc.).
///
/// Renders a dark gradient background with a centered [badge] widget,
/// headline, and subheadline. Supply the page-specific [badge] (icon +
/// label row) as a child; everything else is parameterized.
///
/// Usage:
/// ```dart
/// MarketingHeroSection(
///   isMobile: isMobile,
///   badge: _MyBadge(),
///   headline: 'Platform Features',
///   subheadline: 'Everything you need...',
/// )
/// ```
class MarketingHeroSection extends StatelessWidget {
  const MarketingHeroSection({
    super.key,
    required this.isMobile,
    required this.badge,
    required this.headline,
    required this.subheadline,
    this.subheadlineMaxWidth = 600,
  });

  final bool isMobile;

  /// Badge widget rendered at the top of the hero (icon + label row).
  final Widget badge;

  final String headline;
  final String subheadline;

  /// Max width constraint on the subheadline. Defaults to 600.
  final double subheadlineMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: isMobile ? 48 : 80,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gray800, AppColors.gray900],
        ),
      ),
      child: Column(
        children: [
          badge,
          const SizedBox(height: AppSpacing.lg),
          Text(
            headline,
            style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
                .copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: subheadlineMaxWidth),
            child: Text(
              subheadline,
              style: AppTypography.bodyLG.copyWith(color: AppColors.gray400),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
