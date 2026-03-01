import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/cards.dart';
import '../common/containers.dart';

/// Status section showing platform operational health and metrics.
///
/// Displays:
/// - Overall operational status badge
/// - Key platform metrics (uptime, traces, teams, setup time)
/// - Individual service status indicators
/// - Link to full status page
///
/// Content is externalized via [StatusContent] for easy updates.
class StatusSection extends StatelessWidget {
  /// Content configuration for this section.
  final StatusContent content;

  const StatusSection({
    super.key,
    this.content = const StatusContent(
      title: 'Platform Status',
      subtitle: 'Real-time operational health',
      statusBadge: 'All Systems Operational',
      allOperational: true,
      metrics: [],
      services: [],
      statusPageUrl: '',
      statusPageCta: 'View Status Page',
    ),
  });

  /// Effective content (falls back to AppContent if empty).
  StatusContent get _content =>
      content.metrics.isEmpty ? AppContent.status : content;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return SectionContainer(
      id: 'status',
      backgroundColor: AppColors.gray800,
      child: Column(
        children: [
          _StatusBadge(
            text: _content.statusBadge,
            isOperational: _content.allOperational,
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(
            title: _content.title,
            subtitle: _content.subtitle,
          ),
          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),
          _MetricsGrid(
            metrics: _content.metrics,
            columns: isDesktop ? 4 : 2,
          ),
          const SizedBox(height: AppSpacing.xl),
          _ServicesCard(services: _content.services),
          const SizedBox(height: AppSpacing.lg),
          if (_content.statusPageUrl.isNotEmpty)
            _StatusPageLink(
              url: _content.statusPageUrl,
              label: _content.statusPageCta,
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Private Widgets
// =============================================================================

/// Status badge showing operational state.
class _StatusBadge extends StatelessWidget {
  final String text;
  final bool isOperational;

  const _StatusBadge({
    required this.text,
    required this.isOperational,
  });

  Color get _color => isOperational ? AppColors.success : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: AppDecorations.statusBadge(_color),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIndicator(color: _color, size: 8),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: _color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular status indicator dot.
class _StatusIndicator extends StatelessWidget {
  final Color color;
  final double size;
  final bool showGlow;

  const _StatusIndicator({
    required this.color,
    this.size = 8,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: AppDecorations.dot(color, showGlow: showGlow),
    );
  }
}

/// Responsive grid of metric cards.
class _MetricsGrid extends StatelessWidget {
  final List<StatusMetricContent> metrics;
  final int columns;

  const _MetricsGrid({
    required this.metrics,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.lg;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.center,
          children: metrics.map((metric) {
            return SizedBox(
              width: itemWidth,
              child: _MetricCard(metric: metric),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Individual metric card with value and label.
class _MetricCard extends StatelessWidget {
  final StatusMetricContent metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        metric.isOperational ? AppColors.success : AppColors.warning;

    return GlassCard(
      tier: GlassCardTier.secondary,
      enableHover: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIndicator(color: statusColor, size: 12, showGlow: true),
          const SizedBox(height: AppSpacing.md),
          Text(
            metric.value,
            style: AppTypography.statValue.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metric.label,
            style: AppTypography.statLabel,
            textAlign: TextAlign.center,
          ),
          if (metric.sublabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric.sublabel!,
              style: AppTypography.caption.copyWith(
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Card containing service status rows.
class _ServicesCard extends StatelessWidget {
  final List<StatusServiceContent> services;

  const _ServicesCard({required this.services});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.tertiary,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Service Status', style: AppTypography.headingSM),
          const SizedBox(height: AppSpacing.md),
          ...services.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ServiceStatusRow(service: service),
            ),
          ),
        ],
      ),
    );
  }
}

/// Service status row showing name and operational status.
class _ServiceStatusRow extends StatelessWidget {
  final StatusServiceContent service;

  const _ServiceStatusRow({required this.service});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        service.isOperational ? AppColors.success : AppColors.warning;

    return Semantics(
      label: '${service.name}: ${service.status}',
      child: Row(
        children: [
          _StatusIndicator(color: statusColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(service.name, style: AppTypography.bodyMD),
          ),
          Text(
            service.status,
            style: AppTypography.bodySM.copyWith(color: statusColor),
          ),
        ],
      ),
    );
  }
}

/// Link to external status page.
class _StatusPageLink extends StatelessWidget {
  final String url;
  final String label;

  const _StatusPageLink({
    required this.url,
    required this.label,
  });

  Future<void> _handleTap() async {
    final uri = Uri.parse(url);
    // On web, skip canLaunchUrl check (often returns false) and use platformDefault
    // On native, use externalApplication mode
    const mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;

    if (kIsWeb || await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: mode);
      AnalyticsService.trackExternalLink(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _handleTap,
      icon: const Icon(LucideIcons.externalLink, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: AppColors.blue400),
    );
  }
}
