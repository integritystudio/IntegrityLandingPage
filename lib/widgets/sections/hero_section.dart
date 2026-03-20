import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/buttons.dart';
import '../common/containers.dart';
import '../common/trust_badge.dart';
import '../decorative/animated_orb.dart';

/// Hero section with gradient background and decorative orbs
///
/// Features:
/// - Animated gradient orbs (respects reduced motion)
/// - Responsive typography
/// - CTA buttons with analytics tracking
/// - Semantic structure with h1 heading
/// - Externalized content via HeroContent (supports A/B testing)
///
/// Usage:
/// ```dart
/// HeroSection(
///   content: HeroContent.current, // or AppContent.hero
///   onGetStarted: () => scrollTo('pricing'),
///   onWatchDemo: () => openDemo(),
/// )
/// ```
class HeroSection extends StatelessWidget {
  final HeroContent content;
  final VoidCallback? onGetStarted;
  final VoidCallback? onWatchDemo;

  const HeroSection({
    super.key,
    this.content = const HeroContent(
      badge: 'EU AI Act Ready',
      headline: 'AI Observability That\nProves Compliance',
      subheadline:
          'Full traceability for every LLM decision. '
          'Automated risk documentation. Audit-ready from day one. '
          'Enterprise-grade monitoring with compliance built-in.',
      primaryCTA: 'Start Free Trial',
      secondaryCTA: 'Request Demo',
      trustIndicators: [
        'EU AI Act Ready',
        'Enterprise Security',
        '99.9% Uptime',
        '15-min Setup',
      ],
    ),
    this.onGetStarted,
    this.onWatchDemo,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      decoration: AppDecorations.gradientBackground,
      child: Stack(
        children: [
          // Decorative orbs
          const DecorativeOrbs(),

          // Content
          SectionContainer(
            id: 'hero',
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 80 : 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge
                _buildBadge(),

                SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

                // Headline
                _buildHeadline(context, isMobile),

                SizedBox(height: isMobile ? AppSpacing.md : AppSpacing.lg),

                // Subheadline
                _buildSubheadline(context, isMobile, isTablet),

                SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

                // CTAs
                _buildCTAs(context, isMobile),

                SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

                // Trust indicators
                _buildTrustIndicators(context, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: AppDecorations.statusBadge(AppColors.blue500, opacity: 0.1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: AppDecorations.successDot,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            content.badge,
            style: AppTypography.caption.copyWith(
              color: AppColors.blue400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline(BuildContext context, bool isMobile) {
    return Semantics(
      header: true,
      child: Text(
        content.headline,
        style: isMobile
            ? AppTypography.headingXL.copyWith(fontSize: 36)
            : AppTypography.headingXL,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSubheadline(BuildContext context, bool isMobile, bool isTablet) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: isMobile ? double.infinity : (isTablet ? 500 : 600),
      ),
      child: Text(
        content.subheadline,
        style: AppTypography.bodyLG,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCTAs(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientButton(
            text: content.primaryCTA,
            icon: LucideIcons.arrowRight,
            onPressed: () {
              AnalyticsService.trackCTAClick(
                buttonName: content.primaryCTA,
                location: 'hero',
                ctaType: 'primary',
              );
              onGetStarted?.call();
            },
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlineButton(
            text: content.secondaryCTA,
            icon: LucideIcons.play,
            onPressed: () {
              AnalyticsService.trackCTAClick(
                buttonName: content.secondaryCTA,
                location: 'hero',
                ctaType: 'secondary',
              );
              onWatchDemo?.call();
            },
            fullWidth: true,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GradientButton(
          text: content.primaryCTA,
          icon: LucideIcons.arrowRight,
          onPressed: () {
            AnalyticsService.trackCTAClick(
              buttonName: content.primaryCTA,
              location: 'hero',
              ctaType: 'primary',
            );
            onGetStarted?.call();
          },
        ),
        const SizedBox(width: AppSpacing.md),
        OutlineButton(
          text: content.secondaryCTA,
          icon: LucideIcons.play,
          onPressed: () {
            AnalyticsService.trackCTAClick(
              buttonName: content.secondaryCTA,
              location: 'hero',
              ctaType: 'secondary',
            );
            onWatchDemo?.call();
          },
        ),
      ],
    );
  }

  Widget _buildTrustIndicators(BuildContext context, bool isMobile) {
    final indicators = content.trustIndicators;
    final isTablet = ResponsiveUtils.isTablet(context);

    // Mobile: Stack vertically
    if (isMobile) {
      return Column(
        children: indicators
            .map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: TrustBadge(label: text),
                ))
            .toList(),
      );
    }

    // Tablet and Desktop: Use Wrap for flexible layout
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: isTablet ? AppSpacing.sm : 0,
      children: indicators.asMap().entries.map((entry) {
        final isLast = entry.key == indicators.length - 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TrustBadge(label: entry.value),
            if (!isLast) ...[
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 4,
                height: 4,
                decoration: AppDecorations.separatorDot,
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}
