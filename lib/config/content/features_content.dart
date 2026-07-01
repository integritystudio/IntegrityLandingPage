/// Features section content.
library;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'models.dart';

/// Features content variants.
abstract final class FeaturesContentVariants {
  /// Current production content
  /// Enhanced with compliance/EU AI Act features
  static const current = FeaturesContent(
    title: 'Platform Capabilities',
    subtitle: 'Comprehensive tools for AI application observability',
    features: _currentFeatures,
  );

  /// Legacy content (pre-audit)
  static const legacy = FeaturesContent(
    title: 'Platform Capabilities',
    subtitle: 'Comprehensive tools for AI application observability',
    features: _legacyFeatures,
  );

  static const _currentFeatures = [
    FeatureCardContent(
      icon: LucideIcons.activity,
      title: 'LLM Monitoring',
      description:
          'Track every LLM call with detailed performance metrics and cost attribution.',
      bullets: [
        'Token usage tracking',
        'Latency monitoring',
        'Cost attribution per request',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.gitBranch,
      title: 'Distributed Tracing',
      description:
          'End-to-end visibility across your AI application with OpenTelemetry support.',
      bullets: [
        'Request correlation',
        'Service dependency mapping',
        'Bottleneck identification',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.clipboardCheck,
      title: 'Compliance Reporting',
      description:
          'Automated documentation for EU AI Act Article 12 requirements.',
      bullets: [
        'Audit trail generation',
        'Risk classification support',
        'Decision traceability',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.shield,
      title: 'Security & Privacy',
      description:
          'Enterprise-grade security with PII detection and data masking.',
      bullets: [
        'Automatic PII redaction',
        'Role-based access control',
        'GDPR compliance tools',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.barChart3,
      title: 'Analytics Dashboard',
      description:
          'Customizable dashboards with real-time metrics and historical trends.',
      bullets: [
        'Custom visualizations',
        'Export capabilities',
        'Team collaboration',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.alertTriangle,
      title: 'Anomaly Detection',
      description:
          'Automated detection of performance regressions and unusual patterns.',
      bullets: [
        'Baseline comparison',
        'Custom alert thresholds',
        'Slack/PagerDuty integration',
      ],
    ),
  ];

  // Detailed features page content from observability audit
  static const pageTitle = 'Platform Features';
  static const pageSubtitle = 'Enterprise-grade observability with OpenTelemetry compliance';
  static const complianceBadge = '10/10 OTel Compliance';

  static const scores = [
    ('OTel Compliance', '10/10', 'Full spec support'),
    ('Data Model', '10/10', 'Complete with all metadata'),
    ('Query Capabilities', '10/10', 'Advanced operators'),
    ('Scalability', '9/10', 'Indexing, caching, streaming'),
    ('Backend Integration', '10/10', 'Full SigNoz + OTLP'),
  ];

  // Distributed Tracing features
  static const tracingTitle = 'Distributed Tracing';
  static const tracingDescription =
      'Full OpenTelemetry-compliant tracing with support for all span types, events, and cross-trace relationships.';
  static const tracingFeatures = [
    ('Standard Fields', 'traceId, spanId, parentSpanId'),
    ('Span Kinds', 'INTERNAL, SERVER, CLIENT, PRODUCER, CONSUMER'),
    ('Status Codes', 'UNSET, OK, ERROR'),
    ('Nanosecond Timestamps', 'Precise timing for performance analysis'),
    ('Span Events', 'Capture events with attributes within spans'),
    ('Span Links', 'Cross-trace relationships for complex workflows'),
    ('Instrumentation Scope', 'Library name, version, schema URL'),
    ('Custom Attributes', 'Flexible key-value metadata'),
  ];

  // Log Collection features
  static const logsTitle = 'Log Collection';
  static const logsDescription =
      'Structured logging with severity levels, trace correlation, and rich metadata.';
  static const logsFeatures = [
    ('Severity Levels', 'ERROR, WARN, INFO, DEBUG with OTel numbers (1-21)'),
    ('Trace Correlation', 'Automatic traceId and spanId linking'),
    ('Flexible Timestamps', 'ISO 8601 or nanosecond precision'),
    ('Instrumentation Scope', 'Source library identification'),
    ('Structured Body', 'String content with extracted fields'),
    ('Custom Attributes', 'Rich contextual metadata'),
  ];

  // Metrics features
  static const metricsTitle = 'Metrics Aggregation';
  static const metricsDescription =
      'Comprehensive metrics support with gauges, counters, histograms, and exemplars.';
  static const metricsFeatures = [
    ('Gauge Support', 'Point-in-time values for current state'),
    ('Counter Support', 'Cumulative values for throughput'),
    ('Histogram Support', 'Bucket distribution, sum, count'),
    ('Exemplars', 'Trace correlation for specific data points'),
    ('Aggregation Temporality', 'DELTA, CUMULATIVE, UNSPECIFIED'),
    ('Units', 'Standard unit strings for clarity'),
  ];

  // Query capabilities
  static const queryTitle = 'Advanced Query Capabilities';
  static const queryDescription =
      'Powerful filtering and aggregation for traces, logs, and metrics.';

  static const traceQueryFeatures = [
    ('Exact Match', 'Filter by traceId, service name'),
    ('Substring Match', 'Search span names'),
    ('Regex Patterns', 'Complex pattern matching'),
    ('Duration Filtering', 'Min/max duration in milliseconds'),
    ('Attribute Filtering', 'Match on any custom attribute'),
    ('Numeric Operators', 'gt, gte, lt, lte, eq'),
    ('Existence Checks', 'Attribute exists/not exists'),
    ('Negation', 'Exclude by span name'),
  ];

  static const logQueryFeatures = [
    ('Severity Filter', 'Exact severity level match'),
    ('Text Search', 'Case-insensitive substring search'),
    ('Boolean Search', 'AND/OR with multiple terms'),
    ('Field Extraction', 'JSON paths from log body'),
    ('Trace Correlation', 'Filter logs by traceId'),
    ('Numeric Operators', 'On attribute values'),
    ('Negation', 'Exclude by search term'),
  ];

  static const metricAggregations = [
    ('Basic Aggregations', 'sum, avg, min, max, count'),
    ('Percentiles', 'p50, p95, p99 calculations'),
    ('Rate Calculations', 'Per-second rate of change'),
    ('Time Bucketing', '1m, 5m, 1h, 1d intervals'),
    ('Group By', 'Aggregate by any attribute'),
  ];

  // Scalability
  static const scalabilityTitle = 'Scalability & Performance';
  static const scalabilityDescription =
      'Built for performance with streaming, indexing, and intelligent caching.';
  static const scalabilityFeatures = [
    ('Streaming', 'Line-by-line JSONL reading for O(1) memory'),
    ('Indexing', '.idx sidecar files for O(1) lookups'),
    ('Caching', 'LRU with TTL for instant repeat queries'),
    ('Parallel Queries', 'Promise.all across directories'),
    ('Bounded Sorting', 'O(n) vs O(n log n) for limits'),
    ('Early Termination', 'Stop at limit for reduced I/O'),
  ];

  static const scaleLimits = [
    ('~10,000 records/day', '~5-10 MB', '<100ms'),
    ('~100,000 records/day', '~50-100 MB', '<1s'),
    ('~1,000,000 records/day', '~500 MB', '2-5s'),
  ];

  // Integrations
  static const integrationsTitle = 'Integrations';
  static const integrationsDescription =
      'Full OTLP export compatibility with major observability platforms.';
  static const integrations = [
    'OpenTelemetry Collector',
    'SigNoz',
    'Jaeger',
    'Zipkin',
    'Any OTLP-compatible backend',
  ];

  static const _legacyFeatures = [
    FeatureCardContent(
      icon: LucideIcons.activity,
      title: 'LLM Monitoring',
      description:
          'Track every LLM call with detailed performance metrics and cost attribution.',
      bullets: [
        'Token usage tracking',
        'Latency monitoring',
        'Cost attribution per request',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.gitBranch,
      title: 'Distributed Tracing',
      description:
          'End-to-end visibility across your AI application with OpenTelemetry support.',
      bullets: [
        'Request correlation',
        'Service dependency mapping',
        'Bottleneck identification',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.alertTriangle,
      title: 'Anomaly Detection',
      description:
          'Automated detection of performance regressions and unusual patterns.',
      bullets: [
        'Baseline comparison',
        'Custom alert thresholds',
        'Slack/PagerDuty integration',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.shield,
      title: 'Security & Privacy',
      description:
          'Enterprise-grade security with PII detection and data masking.',
      bullets: [
        'Automatic PII redaction',
        'Role-based access control',
        'Audit logging',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.barChart3,
      title: 'Analytics Dashboard',
      description:
          'Customizable dashboards with real-time metrics and historical trends.',
      bullets: [
        'Custom visualizations',
        'Export capabilities',
        'Team collaboration',
      ],
    ),
    FeatureCardContent(
      icon: LucideIcons.zap,
      title: 'Performance Optimization',
      description:
          'Identify optimization opportunities with detailed performance insights.',
      bullets: [
        'Slow query detection',
        'Caching recommendations',
        'Resource utilization',
      ],
    ),
  ];
}
