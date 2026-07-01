import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/common/chip_badge.dart';
import '../widgets/common/status_badge.dart';
import '../widgets/navigation/sub_page_shell.dart';
import '../widgets/sections/marketing_hero_section.dart';

/// Status page displaying platform operational health and internal observability.
///
/// Based on internal-observability.md v1.8.6 (2026-02-01).
/// Covers the observability-toolkit MCP server's self-monitoring capabilities.
class StatusPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const StatusPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final content = StatusContentVariants.current;

    return SubPageShell(
      onBack: widget.onBack,
      onShowCookieSettings: widget.onShowCookieSettings,
      analyticsPageName: 'status',
      slivers: [
        SliverToBoxAdapter(child: _HeroSection(isMobile: isMobile, content: content)),
        SliverToBoxAdapter(child: _MetricsSection(isMobile: isMobile, content: content)),
        SliverToBoxAdapter(child: _ServicesSection(isMobile: isMobile, content: content)),
        SliverToBoxAdapter(child: _WhatWeMonitorSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _PerformanceSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _HealthMonitoringSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _CapabilitiesSection(isMobile: isMobile)),
        SliverToBoxAdapter(child: _DeveloperAppendixSection(isMobile: isMobile)),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;
  final StatusContent content;

  const _HeroSection({required this.isMobile, required this.content});

  @override
  Widget build(BuildContext context) {
    return MarketingHeroSection(
      isMobile: isMobile,
      headline: content.title,
      subheadline: content.subtitle,
      badge: ChipBadge(
        icon: LucideIcons.checkCircle,
        label: content.statusBadge,
        accentColor: AppColors.success,
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  final bool isMobile;
  final StatusContent content;

  const _MetricsSection({required this.isMobile, required this.content});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            content.metricsTitle,
            style: AppTypography.headingMD.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            alignment: WrapAlignment.center,
            children: content.metrics.map((metric) {
              return _MetricCard(metric: metric);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final StatusMetricContent metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        children: [
          Text(
            metric.value,
            style: AppTypography.headingLG.copyWith(
              color: AppColors.blue400,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            metric.label,
            style: AppTypography.bodyMD.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          if (metric.sublabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              metric.sublabel!,
              style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  final bool isMobile;
  final StatusContent content;

  const _ServicesSection({required this.isMobile, required this.content});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.gray800,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            'Service Status',
            style: AppTypography.headingMD.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: content.services.map((service) {
                return _ServiceRow(service: service);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simplified "What We Monitor" section for non-technical readers
class _WhatWeMonitorSection extends StatelessWidget {
  final bool isMobile;

  const _WhatWeMonitorSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: DocSection(
          icon: LucideIcons.eye,
          title: 'What We Monitor',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We monitor our own platform to ensure your data is always available and your queries are fast. '
                'Every component is tracked 24/7 so issues are detected before they affect you.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  DocFeatureCard(
                    icon: LucideIcons.zap,
                    title: 'Response Speed',
                    description: 'Every request is measured to ensure fast, consistent performance.',
                  ),
                  DocFeatureCard(
                    icon: LucideIcons.database,
                    title: 'Smart Caching',
                    description: 'Data is cached intelligently to reduce wait times.',
                  ),
                  DocFeatureCard(
                    icon: LucideIcons.shield,
                    title: 'Automatic Protection',
                    description: 'If an issue occurs, the system prevents cascading problems.',
                  ),
                  DocFeatureCard(
                    icon: LucideIcons.heartPulse,
                    title: 'Continuous Monitoring',
                    description: 'System health is checked constantly and reported in real-time.',
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

/// Simplified Performance section for non-technical readers
class _PerformanceSection extends StatelessWidget {
  final bool isMobile;

  const _PerformanceSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.gray800,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: DocSection(
          icon: LucideIcons.gauge,
          title: 'Performance Guarantees',
          accentColor: AppColors.blue500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We measure how long every data request takes. If something slows down, our team is notified immediately so we can resolve it before it affects your experience.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Response Time Commitment',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Response Time', 'Status'],
                rows: [
                  ['< 500ms', 'Normal - Fast response'],
                  ['500ms - 1s', 'Moderate - Being monitored'],
                  ['> 1s', 'Alert triggered - Team notified'],
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Caching Effectiveness',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Intelligent caching delivers faster query results without sacrificing data freshness.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Cache Performance', 'What It Means'],
                rows: [
                  ['> 80% hit rate', 'Excellent - Most queries are instant'],
                  ['50-80% hit rate', 'Good - System running normally'],
                  ['< 50% hit rate', 'Being optimized'],
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Automatic Safeguards',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Built-in circuit breakers prevent problems from spreading if any component has issues. The system automatically stops sending requests to troubled services until they recover.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  ChipBadge(
                    label: 'Normal',
                    description: 'Everything working',
                    accentColor: AppColors.success,
                    icon: LucideIcons.checkCircle,
                    backgroundColor: AppColors.gray700,
                    borderColor: AppColors.success.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppSpacing.radiusSM,
                  ),
                  ChipBadge(
                    label: 'Recovering',
                    description: 'Testing connection',
                    accentColor: AppColors.warning,
                    icon: LucideIcons.alertCircle,
                    backgroundColor: AppColors.gray700,
                    borderColor: AppColors.warning.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppSpacing.radiusSM,
                  ),
                  ChipBadge(
                    label: 'Protected',
                    description: 'Waiting for resolution',
                    accentColor: AppColors.error,
                    icon: LucideIcons.shieldAlert,
                    backgroundColor: AppColors.gray700,
                    borderColor: AppColors.error.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    borderRadius: AppSpacing.radiusSM,
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

/// Simplified Health Monitoring section for non-technical readers
class _HealthMonitoringSection extends StatelessWidget {
  final bool isMobile;

  const _HealthMonitoringSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: DocSection(
          icon: LucideIcons.heartPulse,
          title: 'Continuous Health Monitoring',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our health monitoring runs continuously to verify all components are functioning correctly. '
                'Here are the systems being actively monitored.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Monitored Components',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: ObservabilityHealthContent.healthComponents.map((component) {
                  return ChipBadge(
                    icon: LucideIcons.check,
                    label: component,
                    accentColor: AppColors.success,
                    backgroundColor: AppColors.gray800,
                    borderColor: AppColors.success.withValues(alpha: 0.3),
                    iconSize: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    borderRadius: AppSpacing.radiusMD,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simplified Capabilities section for non-technical readers
class _CapabilitiesSection extends StatelessWidget {
  final bool isMobile;

  const _CapabilitiesSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      backgroundColor: AppColors.gray800,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: DocSection(
          icon: LucideIcons.sparkles,
          title: 'Platform Capabilities',
          accentColor: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What you get with Integrity Studio\'s observability platform.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.xl),
              const DocBulletList(
                items: [
                  'Industry-standard telemetry support (OpenTelemetry)',
                  'Comprehensive performance metrics',
                  'Efficient memory management',
                  'Detailed performance analysis',
                  'Standards-compliant data handling',
                ],
                bulletColor: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Coming Soon',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Dashboard recommendations',
                  'Alert configuration examples',
                  'Advanced error categorization',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Version',
                message: 'observability-toolkit v1.8.6 (2026-02-01)',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Collapsible Developer Appendix with all technical details
class _DeveloperAppendixSection extends StatefulWidget {
  final bool isMobile;

  const _DeveloperAppendixSection({required this.isMobile});

  @override
  State<_DeveloperAppendixSection> createState() => _DeveloperAppendixSectionState();
}

class _DeveloperAppendixSectionState extends State<_DeveloperAppendixSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: widget.isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            // Expandable header
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.gray800,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(color: AppColors.gray700),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.code2, color: AppColors.purple500, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer Documentation',
                            style: AppTypography.headingSM.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Technical implementation details for development teams',
                            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
              ),
            ),
            // Expandable content
            if (_isExpanded) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildArchitectureDiagram(),
              const SizedBox(height: AppSpacing.lg),
              _buildQueryTimingDetails(),
              const SizedBox(height: AppSpacing.lg),
              _buildCacheDetails(),
              const SizedBox(height: AppSpacing.lg),
              _buildCircuitBreakerDetails(),
              const SizedBox(height: AppSpacing.lg),
              _buildHealthCheckApi(),
              const SizedBox(height: AppSpacing.lg),
              _buildDebuggingGuide(),
              const SizedBox(height: AppSpacing.lg),
              _buildConfiguration(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureDiagram() {
    return _TechSection(
      title: 'Architecture Diagram',
      icon: LucideIcons.layers,
      child: const _ArchitectureDiagramWidget(),
    );
  }

  Widget _buildQueryTimingDetails() {
    return _TechSection(
      title: 'Query Timing Implementation',
      icon: LucideIcons.timer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DocCodeBlock(
            code: '''import { withSpan } from './lib/instrumentation.js';

const result = await withSpan(
  'queryTraces',
  { backend: 'local', filters: 3 },
  async (span) => {
    const data = await backend.query(filters);
    span.setAttribute('result.count', data.length);
    return data;
  }
);''',
          ),
          const SizedBox(height: AppSpacing.md),
          const DocTable(
            headers: ['Backend', 'Methods'],
            rows: [
              ['LocalJsonlBackend', 'queryTraces(), queryLogs(), queryMetrics(), queryLLMEvents()'],
              ['SigNozApiBackend', 'queryTraces(), queryLogs(), queryMetrics()'],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCacheDetails() {
    return _TechSection(
      title: 'Cache Implementation',
      icon: LucideIcons.database,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DocCodeBlock(
            code: '''interface CacheStats {
  hits: number;       // Successful cache lookups
  misses: number;     // Cache misses (not found or TTL expired)
  evictions: number;  // Entries removed due to max size
  size: number;       // Current cached entries count
  hitRate: number;    // hits / (hits + misses)
}''',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tracked Caches',
            style: AppTypography.bodySM.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          const DocBulletList(
            items: ['traceCache', 'logCache', 'metricCache', 'llmEventCache'],
            bulletColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildCircuitBreakerDetails() {
    return _TechSection(
      title: 'Circuit Breaker States',
      icon: LucideIcons.shieldAlert,
      child: const DocTable(
        headers: ['Transition', 'Level', 'Message'],
        rows: [
          ['closed → open', 'WARN', 'Circuit breaker OPENED after N failures'],
          ['open → half-open', 'INFO', 'Entering HALF-OPEN state'],
          ['half-open → closed', 'INFO', 'CLOSED after successful request'],
        ],
      ),
    );
  }

  Widget _buildHealthCheckApi() {
    return _TechSection(
      title: 'Health Check API Response',
      icon: LucideIcons.heartPulse,
      child: const DocCodeBlock(
        code: '''{
  "status": "ok",
  "backends": { "local": { "status": "ok" }, "signoz": { "status": "ok" } },
  "cache": {
    "traces": { "hits": 156, "misses": 23, "hitRate": 0.871 },
    "logs": { "hits": 89, "misses": 34, "hitRate": 0.723 }
  },
  "today": "2026-02-01"
}''',
      ),
    );
  }

  Widget _buildDebuggingGuide() {
    return _TechSection(
      title: 'Debugging Guide',
      icon: LucideIcons.bug,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('High Cache Miss Rate', style: AppTypography.bodySM.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          const DocNumberedList(
            items: ['Check query specificity', 'Check TTL settings', 'Check cache size limits'],
            accentColor: AppColors.purple500,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Slow Queries', style: AppTypography.bodySM.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
          const DocNumberedList(
            items: ['Check telemetry file sizes', 'Narrow date range filters', 'Review regex patterns'],
            accentColor: AppColors.purple500,
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguration() {
    return _TechSection(
      title: 'Environment Configuration',
      icon: LucideIcons.settings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DocTable(
            headers: ['Variable', 'Default'],
            rows: [
              ['OTEL_ENABLED', 'false'],
              ['OTEL_SERVICE_NAME', 'observability-toolkit'],
              ['CACHE_TTL_MS', '60000'],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const DocTable(
            headers: ['Constant', 'Value'],
            rows: [
              ['SLOW_QUERY_THRESHOLD_MS', '500'],
              ['MAX_CACHE_SIZE', '100'],
              ['CIRCUIT_MAX_FAILURES', '3'],
            ],
          ),
        ],
      ),
    );
  }
}

/// Visual architecture diagram widget
class _ArchitectureDiagramWidget extends StatelessWidget {
  const _ArchitectureDiagramWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.blue600,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Text(
              'observability-toolkit',
              style: AppTypography.bodyMD.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Top layer - Server, Backends, Tools
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              _DiagramBox(
                title: 'Server',
                items: const ['Rate Limiter', 'Error Handler'],
                color: AppColors.purple500,
              ),
              _DiagramBox(
                title: 'Backends',
                items: const ['LocalJsonl', 'SigNozApi'],
                color: AppColors.success,
              ),
              _DiagramBox(
                title: 'Tools',
                items: const ['obs_health_check', 'obs_query_*'],
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Arrows down
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.arrowDown, color: AppColors.gray500, size: 20),
              const SizedBox(width: 60),
              Icon(LucideIcons.arrowDown, color: AppColors.gray500, size: 20),
              const SizedBox(width: 60),
              Icon(LucideIcons.arrowDown, color: AppColors.gray500, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Internal Observability Layer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.gray800,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              border: Border.all(color: AppColors.blue500.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'Internal Observability Layer',
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.blue400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    _layerChip('Instrumentation'),
                    _layerChip('Metrics'),
                    _layerChip('Cache Stats'),
                    _layerChip('Histograms'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Icon(LucideIcons.arrowDown, color: AppColors.gray500, size: 20),
          const SizedBox(height: AppSpacing.sm),
          // OTLP Export
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.gray800,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
            ),
            child: Text(
              'OTLP Export → SigNoz / any OTLP backend',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagramBox extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;

  const _DiagramBox({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AppTypography.bodySM.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...items.map((item) => Text(
                item,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray400,
                  fontSize: 11,
                ),
              )),
        ],
      ),
    );
  }
}

StatusBadge _layerChip(String label) => StatusBadge(
      label: label,
      color: AppColors.gray300,
      backgroundColor: AppColors.gray700,
      borderColor: Colors.transparent,
      textStyle: AppTypography.bodySM.copyWith(
        color: AppColors.gray300,
        fontSize: 11,
      ),
    );

class _TechSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _TechSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.purple500, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final StatusServiceContent service;

  const _ServiceRow({required this.service});

  @override
  Widget build(BuildContext context) {
    final isOperational = service.isOperational;
    final statusColor = isOperational ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Row(
        children: [
          Icon(
            isOperational ? LucideIcons.checkCircle : LucideIcons.alertCircle,
            size: 18,
            color: statusColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              service.name,
              style: AppTypography.bodyMD.copyWith(color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Text(
              service.status,
              style: AppTypography.bodySM.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
