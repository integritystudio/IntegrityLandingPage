import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/info_card.dart';

/// Sources and citations page.
///
/// Displays all statistics with their sources, grouped by type:
/// - Industry reports (external citations)
/// - Customer data (aggregated internal)
/// - Platform metrics (internal measurement)
/// - SLA targets (service commitments)
class SourcesPage extends StatelessWidget {
  final VoidCallback? onBack;

  const SourcesPage({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.gray900,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
            ),
            title: Text(
              'Sources & Citations',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: onBack ?? () => context.go('/'),
                  child: Text(
                    'Back to Home',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: _HeroSection(isMobile: isMobile),
          ),

          // Industry Statistics
          SliverToBoxAdapter(
            child: _StatisticsSection(
              title: 'Industry Statistics',
              subtitle: 'Market data from third-party research reports',
              icon: LucideIcons.barChart2,
              iconColor: AppColors.blue400,
              statistics: AppStatistics.industryStats,
              isMobile: isMobile,
            ),
          ),

          // Customer Results
          SliverToBoxAdapter(
            child: _StatisticsSection(
              title: 'Customer Results',
              subtitle: 'Aggregated and anonymized customer data',
              icon: LucideIcons.users,
              iconColor: AppColors.success,
              statistics: AppStatistics.customerStats,
              isMobile: isMobile,
            ),
          ),

          // Platform Metrics
          SliverToBoxAdapter(
            child: _StatisticsSection(
              title: 'Platform Metrics',
              subtitle: 'Internal platform measurements',
              icon: LucideIcons.activity,
              iconColor: AppColors.purple400,
              statistics: [
                AppStatistics.tracesProcessed,
                AppStatistics.setupTime,
              ],
              isMobile: isMobile,
            ),
          ),

          // SLA Targets
          SliverToBoxAdapter(
            child: _StatisticsSection(
              title: 'Service Level Commitments',
              subtitle: 'Contractual service targets',
              icon: LucideIcons.shield,
              iconColor: AppColors.warning,
              statistics: [AppStatistics.uptimeTarget],
              isMobile: isMobile,
            ),
          ),

          // Methodology Section
          SliverToBoxAdapter(
            child: _MethodologySection(isMobile: isMobile),
          ),

          // Footer spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;

  const _HeroSection({required this.isMobile});

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
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.fileCheck,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Transparency & Accountability',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.blue400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'Sources & Citations',
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 32)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                'We believe in transparency. Every statistic on our website is backed by '
                'verifiable sources. This page documents our data sources, methodology, '
                'and how we calculate customer metrics.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<CitedStatistic> statistics;
  final bool isMobile;

  const _StatisticsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.statistics,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: isMobile
                          ? AppTypography.headingSM
                          : AppTypography.headingMD,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // Statistics cards
          if (isMobile)
            Column(
              children: statistics
                  .map((stat) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _StatisticCard(statistic: stat),
                      ))
                  .toList(),
            )
          else
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: statistics
                  .map((stat) => SizedBox(
                        width: 380,
                        child: _StatisticCard(statistic: stat),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  final CitedStatistic statistic;

  const _StatisticCard({required this.statistic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value and label
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              Text(
                statistic.value,
                style: AppTypography.headingLG.copyWith(
                  color: AppColors.blue400,
                  fontSize: 36,
                ),
              ),
              Text(
                statistic.label,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.gray300,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.gray700, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Source info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _getTypeIcon(statistic.type),
                size: 14,
                color: AppColors.gray500,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getTypeLabel(statistic.type),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      statistic.source,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    if (statistic.sourceUrl != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SelectableText(
                        statistic.sourceUrl!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.blue400,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(StatisticType type) {
    switch (type) {
      case StatisticType.industry:
        return LucideIcons.fileText;
      case StatisticType.customerData:
        return LucideIcons.users;
      case StatisticType.platformMetric:
        return LucideIcons.activity;
      case StatisticType.slaTarget:
        return LucideIcons.shield;
    }
  }

  String _getTypeLabel(StatisticType type) {
    switch (type) {
      case StatisticType.industry:
        return 'INDUSTRY REPORT';
      case StatisticType.customerData:
        return 'CUSTOMER DATA';
      case StatisticType.platformMetric:
        return 'PLATFORM METRIC';
      case StatisticType.slaTarget:
        return 'SLA TARGET';
    }
  }
}

class _MethodologySection extends StatelessWidget {
  final bool isMobile;

  const _MethodologySection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray800.withValues(alpha: 0.5),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Methodology',
              style: isMobile
                  ? AppTypography.headingMD
                  : AppTypography.headingLG.copyWith(fontSize: 32),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _MethodologyCard(
              title: 'Customer Data Collection',
              description:
                  'Customer metrics are collected through platform telemetry with explicit consent. '
                  'Data is aggregated and anonymized before analysis. Individual customer data is '
                  'never disclosed. Reported improvements represent median values across our customer base.',
              icon: LucideIcons.database,
            ),
            const SizedBox(height: AppSpacing.md),
            const _MethodologyCard(
              title: 'Industry Statistics',
              description:
                  'Market data is sourced from reputable third-party research firms. We cite the '
                  'original source and publication date. When reports are updated, we update our '
                  'citations accordingly.',
              icon: LucideIcons.bookOpen,
            ),
            const SizedBox(height: AppSpacing.md),
            const _MethodologyCard(
              title: 'Platform Metrics',
              description:
                  'Platform metrics are calculated from our internal monitoring systems. Setup time '
                  'represents the median time from SDK installation to first trace received. Traces '
                  'processed is measured daily at UTC midnight.',
              icon: LucideIcons.lineChart,
            ),
            const SizedBox(height: AppSpacing.md),
            const _MethodologyCard(
              title: 'SLA Commitments',
              description:
                  'Service Level Agreement targets represent contractual commitments, not historical '
                  'performance. Actual uptime is monitored continuously and reported on our status page.',
              icon: LucideIcons.fileCheck,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Contact info
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.gray900,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                border: Border.all(color: AppColors.gray700),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.messageCircle,
                    size: 24,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Questions about our data?',
                          style: AppTypography.bodyMD.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Contact us at ${CompanyInfo.email} for detailed methodology '
                          'documentation or to request source verification.',
                          style: AppTypography.bodySM.copyWith(
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodologyCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _MethodologyCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      icon: icon,
      title: title,
      description: description,
      iconColor: AppColors.blue400,
      iconBackgroundColor: AppColors.blue500.withValues(alpha: 0.2),
      iconContainerPadding: const EdgeInsets.all(AppSpacing.sm),
      iconContainerBorderRadius: AppSpacing.radiusSM,
      iconSpacing: AppSpacing.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: AppColors.gray900,
      borderColor: AppColors.gray700,
      borderRadius: AppSpacing.radiusLG,
      descriptionStyle: AppTypography.bodyMD.copyWith(color: AppColors.gray400),
    );
  }
}
