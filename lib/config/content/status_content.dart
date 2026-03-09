/// Status section content.
library;

import 'models.dart';
import 'constants.dart';

/// Status section content.
abstract final class StatusContentVariants {
  /// Current production content
  static final current = StatusContent(
    title: 'Platform Status',
    subtitle: 'Real-time operational health and performance metrics',
    statusBadge: 'All Systems Operational',
    allOperational: true,
    metrics: _metrics,
    services: _services,
    statusPageUrl: ExternalUrls.statusPage,
    statusPageCta: 'View Full Status Page',
  );

  static final _metrics = [
    StatusMetricContent(
      label: 'Uptime',
      value: PlatformMetrics.uptime,
      sublabel: PlatformMetrics.uptimeSla,
    ),
    StatusMetricContent(
      label: 'Cache Hit Rate',
      value: '>80%',
      sublabel: 'Query Performance',
    ),
    StatusMetricContent(
      label: 'Query Latency',
      value: '<500ms',
      sublabel: 'P95 Response Time',
    ),
    StatusMetricContent(
      label: 'Setup Time',
      value: PlatformMetrics.setupTime,
      sublabel: PlatformMetrics.setupTimeLabel,
    ),
  ];

  static const _services = [
    StatusServiceContent(
      name: 'Trace Ingestion API',
      status: 'Operational',
    ),
    StatusServiceContent(
      name: 'Log Collection Pipeline',
      status: 'Operational',
    ),
    StatusServiceContent(
      name: 'Metrics Aggregation',
      status: 'Operational',
    ),
    StatusServiceContent(
      name: 'Query Cache',
      status: 'Operational',
    ),
    StatusServiceContent(
      name: 'Dashboard & Analytics',
      status: 'Operational',
    ),
    StatusServiceContent(
      name: 'Alerting System',
      status: 'Operational',
    ),
  ];
}

/// Observability health indicators based on internal metrics.
abstract final class ObservabilityHealthContent {
  // Cache health thresholds
  static const cacheHitRateExcellent = 80;
  static const cacheHitRateGood = 50;
  static const cacheHitRateFair = 20;

  static const cacheHitRateLabels = {
    'excellent': '>80% - Cache is effective',
    'good': '50-80% - Normal operation',
    'fair': '20-50% - Consider tuning',
    'poor': '<20% - Review query patterns',
  };

  // Query latency thresholds (ms)
  static const queryLatencyNormal = 500;
  static const queryLatencySlow = 1000;
  static const queryLatencyVerySlow = 5000;

  static const queryLatencyLabels = {
    'normal': '<500ms - Normal',
    'moderate': '500-1000ms - Monitor',
    'slow': '1-5s - Investigate',
    'verySlow': '>5s - Action needed',
  };

  // Circuit breaker states
  static const circuitBreakerStates = {
    'closed': 'Normal operation - requests flowing',
    'halfOpen': 'Testing recovery - limited requests',
    'open': 'Failing over - requests blocked',
  };

  // Health check components
  static const healthComponents = [
    'Trace Query Backend',
    'Log Query Backend',
    'Metrics Query Backend',
    'LLM Events Backend',
    'Query Result Cache',
    'Circuit Breaker',
  ];

  // Performance metrics descriptions
  static const metricsDescriptions = {
    'cacheHits': 'Successful cache lookups',
    'cacheMisses': 'Cache misses (key not found or TTL expired)',
    'cacheEvictions': 'Entries removed due to max size limit',
    'cacheSize': 'Current number of cached entries',
    'hitRate': 'Ratio of hits to total lookups',
  };

  // Configuration defaults
  static const configDefaults = {
    'cacheTtl': '60 seconds',
    'maxCacheSize': '100 entries',
    'slowQueryThreshold': '500ms',
    'circuitBreakerThreshold': '3 failures',
    'circuitResetTimeout': '30 seconds',
  };
}
