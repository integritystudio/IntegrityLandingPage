import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content/constants.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/gradient_pill_badge.dart';
import '../widgets/navigation/sub_page_shell.dart';
import '../widgets/sections/marketing_hero_section.dart';

/// Careers page - displays open positions and recruitment info.
class CareersPage extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const CareersPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SubPageShell(
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
      analyticsPageName: 'careers',
      slivers: [
        SliverToBoxAdapter(
          child: MarketingHeroSection(
            isMobile: ResponsiveUtils.isMobile(context),
            badge: const GradientPillBadge(label: 'Join Our Team'),
            headline: 'Careers at Integrity Studio',
            subheadline:
                'Help us build the future of AI observability and empower teams to ship reliable AI applications.',
          ),
        ),
        const SliverToBoxAdapter(child: _NoOpeningsSection()),
        const SliverToBoxAdapter(child: _KeepInTouchSection()),
      ],
    );
  }
}

class _NoOpeningsSection extends StatelessWidget {
  const _NoOpeningsSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: EdgeInsets.all(isMobile ? AppSpacing.xl : AppSpacing.xxl),
          decoration: BoxDecoration(
            color: AppColors.gray800,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            border: Border.all(color: AppColors.gray700),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blue500.withValues(alpha: 0.2),
                      AppColors.purple500.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
                child: const Icon(
                  LucideIcons.briefcase,
                  color: AppColors.blue400,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No Open Positions',
                style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'We don\'t have any open roles at the moment, but we\'re always interested in connecting with talented individuals who are passionate about AI and developer tools.',
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.gray400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepInTouchSection extends StatelessWidget {
  const _KeepInTouchSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      color: AppColors.gray800,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: EdgeInsets.all(isMobile ? AppSpacing.xl : AppSpacing.xxl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blue600.withValues(alpha: 0.2),
                AppColors.purple600.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(
              color: AppColors.blue500.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Icon(
                LucideIcons.mailPlus,
                color: AppColors.blue400,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Stay on Our Radar',
                style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Send us a brief introduction. We\'ll keep you in mind for future opportunities that match your skills and interests.',
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                text: CTAText.keepInTouch,
                onPressed: () {
                  AnalyticsService.trackCTAClick(
                    buttonName: CTAText.keepInTouch,
                    location: 'careers_page',
                  );
                  context.go('/contact?ref=careers');
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.info,
                    color: AppColors.gray500,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'We typically respond within 5 business days',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
