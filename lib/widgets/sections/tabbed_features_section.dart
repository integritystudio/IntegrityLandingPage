import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/containers.dart';

/// Tabbed feature explorer with hover preview (AiSDR-inspired)
///
/// Features:
/// - Tab-based navigation with icon states (default/hover/active)
/// - Dynamic content preview on hover
/// - Animated transitions between features
/// - Benefit-focused messaging
///
/// Usage:
/// ```dart
/// TabbedFeaturesSection()
/// ```
class TabbedFeaturesSection extends StatefulWidget {
  const TabbedFeaturesSection({super.key});

  @override
  State<TabbedFeaturesSection> createState() => _TabbedFeaturesSectionState();
}

class _TabbedFeaturesSectionState extends State<TabbedFeaturesSection> {
  int _selectedIndex = 0;
  int? _hoveredIndex;

  static const List<_FeatureTab> _features = [
    _FeatureTab(
      icon: LucideIcons.activity,
      title: 'Real-Time Tracing',
      shortTitle: 'Tracing',
      headline: 'See every decision your AI makes',
      description:
          'Full visibility into LLM calls, latencies, and outputs. '
          'Debug issues in minutes, not days.',
      benefits: [
        '73% faster issue resolution',
        'Complete request/response logging',
        'Token usage analytics',
        'Custom trace attributes',
      ],
      stat: '73%',
      statLabel: 'faster debugging',
    ),
    _FeatureTab(
      icon: LucideIcons.dollarSign,
      title: 'Cost Analytics',
      shortTitle: 'Costs',
      headline: 'Stop overpaying for AI infrastructure',
      description:
          'Track spending across models, optimize token usage, '
          'and set budget alerts before costs spiral.',
      benefits: [
        '30-50% typical cost reduction',
        'Per-model cost breakdown',
        'Usage forecasting',
        'Budget alerts',
      ],
      stat: '40%',
      statLabel: 'avg cost savings',
    ),
    _FeatureTab(
      icon: LucideIcons.shieldCheck,
      title: 'EU AI Act Tools',
      shortTitle: 'Compliance',
      headline: 'Compliance preparation, simplified',
      description:
          'Risk assessment templates, audit-ready documentation, '
          'and traceability aligned with Article 12 requirements.',
      benefits: [
        'Risk category assessment',
        'Automated documentation',
        'Audit trail exports',
        'EU data residency option',
      ],
      stat: '100%',
      statLabel: 'traceability coverage',
    ),
    _FeatureTab(
      icon: LucideIcons.barChart3,
      title: 'Quality Metrics',
      shortTitle: 'Quality',
      headline: 'Measure what matters for AI quality',
      description:
          'Track response quality, hallucination rates, and user satisfaction. '
          'Catch regressions before they impact users.',
      benefits: [
        'Quality scoring',
        'Hallucination detection',
        'A/B testing support',
        'Alerting on quality drops',
      ],
      stat: '5x',
      statLabel: 'faster QA cycles',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final displayIndex = _hoveredIndex ?? _selectedIndex;

    return SectionContainer(
      id: 'features-explorer',
      backgroundColor: AppColors.gray900,
      child: Column(
        children: [
          // Section header
          const SectionTitle(
            title: 'Everything you need for AI observability',
            subtitle: 'Purpose-built tools for LLM applications',
          ),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Feature tabs
          _buildTabs(isMobile),

          const SizedBox(height: AppSpacing.xl),

          // Feature content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildFeatureContent(
              _features[displayIndex],
              isMobile,
              isTablet,
              key: ValueKey(displayIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _features.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(
                right: entry.key < _features.length - 1 ? AppSpacing.sm : 0,
              ),
              child: _FeatureTabButton(
                feature: entry.value,
                isSelected: _selectedIndex == entry.key,
                isHovered: _hoveredIndex == entry.key,
                useShortTitle: true,
                onTap: () {
                  setState(() => _selectedIndex = entry.key);
                  AnalyticsService.trackFeatureInteraction(entry.value.title);
                },
                onHover: (hovering) {
                  setState(() => _hoveredIndex = hovering ? entry.key : null);
                },
              ),
            );
          }).toList(),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: _features.asMap().entries.map((entry) {
        return _FeatureTabButton(
          feature: entry.value,
          isSelected: _selectedIndex == entry.key,
          isHovered: _hoveredIndex == entry.key,
          onTap: () {
            setState(() => _selectedIndex = entry.key);
            AnalyticsService.trackFeatureInteraction(entry.value.title);
          },
          onHover: (hovering) {
            setState(() => _hoveredIndex = hovering ? entry.key : null);
          },
        );
      }).toList(),
    );
  }

  Widget _buildFeatureContent(
    _FeatureTab feature,
    bool isMobile,
    bool isTablet, {
    Key? key,
  }) {
    if (isMobile) {
      return Column(
        key: key,
        children: [
          _buildStatCard(feature),
          const SizedBox(height: AppSpacing.lg),
          _buildTextContent(feature),
        ],
      );
    }

    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildTextContent(feature),
        ),
        const SizedBox(width: AppSpacing.xxl),
        Expanded(
          flex: 4,
          child: _buildStatCard(feature),
        ),
      ],
    );
  }

  Widget _buildTextContent(_FeatureTab feature) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          feature.headline,
          style: AppTypography.headingMD.copyWith(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          feature.description,
          style: AppTypography.bodyLG.copyWith(
            color: AppColors.gray300,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        BulletList.checks(
          items: feature.benefits,
          textStyle: AppTypography.bodyMD.copyWith(
            color: AppColors.gray300,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(_FeatureTab feature) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppDecorations.card(
        borderColor: AppColors.gray700.withValues(alpha: 0.5),
        radius: AppSpacing.radiusLG,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large stat display
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.blue400, AppColors.purple400],
            ).createShader(bounds),
            child: Text(
              feature.stat,
              style: AppTypography.headingXL.copyWith(
                fontSize: 72,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            feature.statLabel,
            style: AppTypography.bodyLG.copyWith(
              color: AppColors.gray300,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Feature icon
          GradientIconContainer(
            icon: feature.icon,
            size: 56,
            iconSize: 32,
            borderRadius: AppSpacing.radiusMD,
          ),
        ],
      ),
    );
  }
}

class _FeatureTab {
  final IconData icon;
  final String title;
  final String shortTitle;
  final String headline;
  final String description;
  final List<String> benefits;
  final String stat;
  final String statLabel;

  const _FeatureTab({
    required this.icon,
    required this.title,
    required this.shortTitle,
    required this.headline,
    required this.description,
    required this.benefits,
    required this.stat,
    required this.statLabel,
  });
}

class _FeatureTabButton extends StatelessWidget {
  final _FeatureTab feature;
  final bool isSelected;
  final bool isHovered;
  final bool useShortTitle;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  const _FeatureTabButton({
    required this.feature,
    required this.isSelected,
    required this.isHovered,
    this.useShortTitle = false,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = isSelected || isHovered;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        label: useShortTitle ? feature.shortTitle : feature.title,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.gray800
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: isSelected
                  ? AppColors.blue500
                  : isHovered
                      ? AppColors.gray600
                      : AppColors.gray700,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                feature.icon,
                size: 20,
                color: isActive ? AppColors.blue400 : AppColors.gray400,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                useShortTitle ? feature.shortTitle : feature.title,
                style: AppTypography.bodySM.copyWith(
                  color: isActive ? Colors.white : AppColors.gray300,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
