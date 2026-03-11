import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/navigation/shared_app_bar.dart';
import '../widgets/sections/footer_section.dart';

/// Careers page - displays open positions and recruitment info.
class CareersPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const CareersPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  State<CareersPage> createState() => _CareersPageState();
}

class _CareersPageState extends State<CareersPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('careers');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SharedAppBar.subPage(onBack: widget.onBack),
            const SliverToBoxAdapter(child: _CareersHeroSection()),
            const SliverToBoxAdapter(child: _NoOpeningsSection()),
            const SliverToBoxAdapter(child: _SubmitResumeSection()),
            SliverToBoxAdapter(
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareersHeroSection extends StatelessWidget {
  const _CareersHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: isMobile ? 48 : 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray800,
            AppColors.gray900,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue500.withValues(alpha: 0.2),
                  AppColors.purple500.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AppColors.blue500.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Join Our Team',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.blue400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Careers at Integrity Studio',
            style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Help us build the future of AI observability and empower teams to ship reliable AI applications.',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
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

class _SubmitResumeSection extends StatelessWidget {
  const _SubmitResumeSection();

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
                'Send us your resume and a brief introduction. We\'ll keep you in mind for future opportunities that match your skills and interests.',
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                text: 'Submit Your Resume',
                onPressed: () {
                  AnalyticsService.trackCTAClick(
                    buttonName: 'Submit Resume',
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
