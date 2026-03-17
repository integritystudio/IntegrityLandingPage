import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/gradient_pill_badge.dart';
import '../widgets/navigation/sub_page_shell.dart';
import '../widgets/sections/marketing_hero_section.dart';

/// Features page displaying detailed platform capabilities.
///
/// Content sourced from observability-toolkit audit documentation.
class FeaturesPage extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const FeaturesPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SubPageShell(
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
      analyticsPageName: 'features',
      slivers: [
        SliverToBoxAdapter(child: _HeroSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _ScoresSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _TracingSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _LogsSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _MetricsSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _QuerySection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _ScalabilitySection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _IntegrationsSection(isMobile: isMobile)),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;

  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return MarketingHeroSection(
      isMobile: isMobile,
      headline: FeaturesContentVariants.pageTitle,
      subheadline: FeaturesContentVariants.pageSubtitle,
      badge: GradientPillBadge(
        icon: LucideIcons.checkCircle,
        iconColor: AppColors.success,
        label: FeaturesContentVariants.complianceBadge,
      ),
    );
  }
}

class _ScoresSection extends StatelessWidget {
  final bool isMobile;

  const _ScoresSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        alignment: WrapAlignment.center,
        children: FeaturesContentVariants.scores.map((score) {
          return _ScoreCard(
            dimension: score.$1,
            score: score.$2,
            note: score.$3,
          );
        }).toList(),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String dimension;
  final String score;
  final String note;

  const _ScoreCard({
    required this.dimension,
    required this.score,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score,
            style: AppTypography.headingMD.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            dimension,
            style: AppTypography.bodyMD.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            note,
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
    );
  }
}

class _TracingSection extends StatelessWidget {
  final bool isMobile;

  const _TracingSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return _FeatureSection(
      icon: LucideIcons.gitBranch,
      title: FeaturesContentVariants.tracingTitle,
      description: FeaturesContentVariants.tracingDescription,
      features: FeaturesContentVariants.tracingFeatures,
      isMobile: isMobile,
    );
  }
}

class _LogsSection extends StatelessWidget {
  final bool isMobile;

  const _LogsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return _FeatureSection(
      icon: LucideIcons.fileText,
      title: FeaturesContentVariants.logsTitle,
      description: FeaturesContentVariants.logsDescription,
      features: FeaturesContentVariants.logsFeatures,
      isMobile: isMobile,
      backgroundColor: AppColors.gray800,
    );
  }
}

class _MetricsSection extends StatelessWidget {
  final bool isMobile;

  const _MetricsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return _FeatureSection(
      icon: LucideIcons.barChart2,
      title: FeaturesContentVariants.metricsTitle,
      description: FeaturesContentVariants.metricsDescription,
      features: FeaturesContentVariants.metricsFeatures,
      isMobile: isMobile,
    );
  }
}

class _QuerySection extends StatelessWidget {
  final bool isMobile;

  const _QuerySection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.gray800,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          _SectionHeader(
            icon: LucideIcons.search,
            title: FeaturesContentVariants.queryTitle,
            description: FeaturesContentVariants.queryDescription,
          ),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              alignment: WrapAlignment.center,
              children: [
                _QueryCard(
                  title: 'Trace Queries',
                  features: FeaturesContentVariants.traceQueryFeatures,
                ),
                _QueryCard(
                  title: 'Log Queries',
                  features: FeaturesContentVariants.logQueryFeatures,
                ),
                _QueryCard(
                  title: 'Metric Aggregations',
                  features: FeaturesContentVariants.metricAggregations,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueryCard extends StatelessWidget {
  final String title;
  final List<(String, String)> features;

  const _QueryCard({required this.title, required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingSM.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.check, size: 14, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        f.$1,
                        style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ScalabilitySection extends StatelessWidget {
  final bool isMobile;

  const _ScalabilitySection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return _FeatureSection(
      icon: LucideIcons.zap,
      title: FeaturesContentVariants.scalabilityTitle,
      description: FeaturesContentVariants.scalabilityDescription,
      features: FeaturesContentVariants.scalabilityFeatures,
      isMobile: isMobile,
    );
  }
}

class _IntegrationsSection extends StatelessWidget {
  final bool isMobile;

  const _IntegrationsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.gray800,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          _SectionHeader(
            icon: LucideIcons.plug,
            title: FeaturesContentVariants.integrationsTitle,
            description: FeaturesContentVariants.integrationsDescription,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: FeaturesContentVariants.integrations.map((integration) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray900,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(color: AppColors.gray700),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.check, size: 16, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      integration,
                      style: AppTypography.bodyMD.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<(String, String)> features;
  final bool isMobile;
  final Color? backgroundColor;

  const _FeatureSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.isMobile,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: backgroundColor,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          _SectionHeader(icon: icon, title: title, description: description),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: features.map((f) => _FeatureItem(name: f.$1, desc: f.$2)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blue500.withValues(alpha: 0.2),
                AppColors.purple500.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          child: Icon(icon, color: AppColors.blue400, size: 28),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: AppTypography.headingMD.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            description,
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray400),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String name;
  final String desc;

  const _FeatureItem({required this.name, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.checkCircle, size: 18, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyMD.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  desc,
                  style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
