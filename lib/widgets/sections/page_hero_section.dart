import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../common/containers.dart';

/// Shared hero section used by content/compliance pages.
///
/// Renders: dark gradient background → centered badge (icon + text) → headline
/// → subheadline → optional [extraContent] (e.g. stat cards, timeline chips).
///
/// Usage:
/// ```dart
/// PageHeroSection(
///   isMobile: isMobile,
///   accentColor: AppColors.purple400,
///   badgeIcon: LucideIcons.shieldCheck,
///   badgeText: 'Enterprise Compliance',
///   headline: 'Compliance & Governance',
///   subheadline: 'Meet regulatory requirements...',
/// )
/// ```
class PageHeroSection extends StatelessWidget {
  const PageHeroSection({
    super.key,
    required this.isMobile,
    required this.accentColor,
    required this.badgeIcon,
    required this.badgeText,
    required this.headline,
    required this.subheadline,
    this.subheadlineMaxWidth = 700,
    this.mobileHeadlineFontSize = 28,
    this.extraContent,
  });

  final bool isMobile;

  /// Accent color applied to badge background (at 15% opacity), badge border
  /// (at 50% opacity), badge icon, and badge text.
  final Color accentColor;

  final IconData badgeIcon;
  final String badgeText;
  final String headline;
  final String subheadline;

  /// Max width constraint on the subheadline text. Defaults to 700.
  final double subheadlineMaxWidth;

  /// Font size applied to the headline on mobile. Defaults to 28. Pass a
  /// different value when a page's design calls for a larger mobile headline.
  final double mobileHeadlineFontSize;

  /// Optional widget rendered below the subheadline (e.g. stat cards, chips).
  /// When provided, an [AppSpacing.xl] gap is inserted above it.
  final Widget? extraContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray900,
            AppColors.gray800.withValues(alpha: 0.5),
            AppColors.gray900,
          ],
        ),
      ),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 16, color: accentColor),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    badgeText,
                    style: AppTypography.bodySM.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              headline,
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: mobileHeadlineFontSize)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: subheadlineMaxWidth),
              child: Text(
                subheadline,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            if (extraContent != null) ...[
              const SizedBox(height: AppSpacing.xl),
              extraContent!,
            ],
          ],
        ),
      ),
    );
  }
}
