import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/chip_badge.dart';
import '../widgets/common/info_card.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// Alerts & Incident Management documentation page.
///
/// Covers budget alerts, anomaly detection, performance monitoring,
/// and integration with incident management tools.
class DocsAlertsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsAlertsPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return DocsPageScaffold(
      title: 'Alerts Guide',
      onBack: onBack,
      heroBuilder: (isMobile) => DocsHeroSection(
        key: const Key('hero-section'),
        badgeIcon: LucideIcons.bell,
        badgeColor: AppColors.warning,
        badgeLabel: 'Proactive Monitoring',
        headline: 'Alerts & Incident Management',
        subheadline:
            'Get notified before problems become incidents. Configure budget alerts, anomaly detection, and performance thresholds with intelligent routing.',
        isMobile: isMobile,
        children: const [
          SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              ChipBadge(
                icon: LucideIcons.dollarSign,
                label: 'Budget',
                accentColor: AppColors.warning,
                backgroundColor: AppColors.gray800,
                borderColor: AppColors.gray700,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                borderRadius: AppSpacing.radiusMD,
              ),
              ChipBadge(
                icon: LucideIcons.activity,
                label: 'Anomaly',
                accentColor: AppColors.warning,
                backgroundColor: AppColors.gray800,
                borderColor: AppColors.gray700,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                borderRadius: AppSpacing.radiusMD,
              ),
              ChipBadge(
                icon: LucideIcons.gauge,
                label: 'Latency',
                accentColor: AppColors.warning,
                backgroundColor: AppColors.gray800,
                borderColor: AppColors.gray700,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                borderRadius: AppSpacing.radiusMD,
              ),
              ChipBadge(
                icon: LucideIcons.alertTriangle,
                label: 'Error Rate',
                accentColor: AppColors.warning,
                backgroundColor: AppColors.gray800,
                borderColor: AppColors.gray700,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                borderRadius: AppSpacing.radiusMD,
              ),
            ],
          ),
        ],
      ),
      content: const _DocsContent(),
    );
  }
}

class _DocsContent extends StatelessWidget {
  const _DocsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Section
        DocSection(
          key: const Key('overview-section'),
          icon: LucideIcons.info,
          title: 'Overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Integrity Studio provides proactive alerting to catch issues before they impact your users or budget. Alerts can be triggered by thresholds, anomalies, or custom conditions.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureGrid(),
            ],
          ),
        ),

        // Alert Types Section
        DocSection(
          key: const Key('alert-types-section'),
          icon: LucideIcons.layers,
          title: 'Alert Types',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _AlertTypeCard(
                icon: LucideIcons.dollarSign,
                title: 'Budget Alerts',
                description:
                    'Get notified when spending approaches or exceeds your defined limits. Set daily, weekly, or monthly budgets per model, team, or application.',
                examples: [
                  'Daily spend exceeds \$100',
                  'Weekly token usage > 1M tokens',
                  'Single request cost > \$5',
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _AlertTypeCard(
                icon: LucideIcons.activity,
                title: 'Anomaly Detection',
                description:
                    'Automatically detect unusual patterns in your LLM usage using statistical analysis. No manual threshold configuration required.',
                examples: [
                  'Sudden spike in token usage',
                  'Unusual response latency patterns',
                  'Abnormal error rate increase',
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _AlertTypeCard(
                icon: LucideIcons.gauge,
                title: 'Performance Alerts',
                description:
                    'Monitor latency percentiles and throughput. Catch performance regressions before users notice.',
                examples: [
                  'P95 latency > 5 seconds',
                  'Throughput drops below 10 req/min',
                  'Time to first token > 2 seconds',
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _AlertTypeCard(
                icon: LucideIcons.alertTriangle,
                title: 'Error Rate Alerts',
                description:
                    'Track error rates and get alerted when they exceed acceptable thresholds.',
                examples: [
                  'Error rate > 5%',
                  'Rate limit errors spike',
                  'Model unavailable errors',
                ],
              ),
            ],
          ),
        ),

        // Creating Alerts Section
        DocSection(
          key: const Key('creating-alerts-section'),
          icon: LucideIcons.plus,
          title: 'Creating Alerts',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create alerts through the dashboard UI or API. Here\'s how to create a budget alert:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Dashboard UI',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocNumberedList(accentColor: AppColors.warning, items: [
                'Navigate to Alerts \u2192 Create Alert',
                'Select the alert type (Budget, Anomaly, Performance, Error)',
                'Configure the condition and threshold',
                'Add notification channels (Slack, PagerDuty, Email, Webhook)',
                'Set the alert severity and schedule',
                'Save and activate the alert',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'API',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''curl -X POST "https://api.integritystudio.ai/v1/alerts" \\
  -H "Authorization: Bearer \$API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "name": "Daily Budget Alert",
    "type": "budget",
    "condition": {
      "metric": "gen_ai.client.cost",
      "operator": "gt",
      "threshold": 100,
      "window": "24h"
    },
    "channels": [
      {"type": "slack", "webhook": "https://hooks.slack.com/..."}
    ],
    "severity": "warning"
  }''',
              ),
            ],
          ),
        ),

        // Conditions Section
        DocSection(
          key: const Key('alert-conditions-section'),
          icon: LucideIcons.filter,
          title: 'Alert Conditions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure precise conditions using metrics, operators, and time windows:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Available Metrics',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Metric', 'Description', 'Unit'],
                rows: [
                  ['gen_ai.client.cost', 'Total cost incurred', 'USD'],
                  ['gen_ai.client.token.usage', 'Tokens consumed', 'count'],
                  ['gen_ai.client.operation.duration', 'Request latency', 'ms'],
                  ['gen_ai.client.error.rate', 'Error percentage', '%'],
                  ['gen_ai.client.requests', 'Request count', 'count'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Operators',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Operator', 'Description', 'Example'],
                rows: [
                  ['gt', 'Greater than', 'cost > 100'],
                  ['gte', 'Greater than or equal', 'latency >= 5000'],
                  ['lt', 'Less than', 'throughput < 10'],
                  ['lte', 'Less than or equal', 'success_rate <= 95'],
                  ['eq', 'Equals', 'error_count == 0'],
                  ['anomaly', 'Statistical anomaly', 'Auto-detected deviation'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Time Windows',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(bulletColor: AppColors.warning, items: [
                '5m, 15m, 30m \u2014 Short-term spikes',
                '1h, 6h, 12h \u2014 Hourly patterns',
                '24h, 7d, 30d \u2014 Daily/weekly/monthly budgets',
              ]),
            ],
          ),
        ),

        // Notification Channels Section
        DocSection(
          key: const Key('notification-channels-section'),
          icon: LucideIcons.send,
          title: 'Notification Channels',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Route alerts to your existing tools and workflows:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ChannelCard(
                icon: LucideIcons.hash,
                title: 'Slack',
                description:
                    'Send alerts to Slack channels. Supports rich formatting with cost breakdowns, affected services, and quick action buttons.',
                code: '''{"type": "slack", "webhook": "https://hooks.slack.com/services/..."}''',
              ),
              const SizedBox(height: AppSpacing.md),
              const _ChannelCard(
                icon: LucideIcons.alertCircle,
                title: 'PagerDuty',
                description:
                    'Trigger PagerDuty incidents for critical alerts. Includes severity mapping and auto-resolution.',
                code:
                    '''{"type": "pagerduty", "routing_key": "your-routing-key", "severity": "critical"}''',
              ),
              const SizedBox(height: AppSpacing.md),
              const _ChannelCard(
                icon: LucideIcons.mail,
                title: 'Email',
                description:
                    'Send email notifications to individuals or distribution lists. Includes detailed alert context.',
                code: '''{"type": "email", "addresses": ["team@company.com", "oncall@company.com"]}''',
              ),
              const SizedBox(height: AppSpacing.md),
              const _ChannelCard(
                icon: LucideIcons.webhook,
                title: 'Webhook',
                description:
                    'Send alerts to any HTTP endpoint. Use for custom integrations, automation, or third-party tools.',
                code: '''{"type": "webhook", "url": "https://your-api.com/alerts", "method": "POST"}''',
              ),
              const SizedBox(height: AppSpacing.md),
              const _ChannelCard(
                icon: LucideIcons.messageSquare,
                title: 'Microsoft Teams',
                description:
                    'Post alerts to Microsoft Teams channels using incoming webhooks.',
                code: '''{"type": "teams", "webhook": "https://outlook.office.com/webhook/..."}''',
              ),
            ],
          ),
        ),

        // Alert Severity Section
        DocSection(
          key: const Key('alert-severity-section'),
          icon: LucideIcons.thermometer,
          title: 'Alert Severity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Classify alerts by severity to prioritize response and route appropriately:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SeverityCard(
                severity: 'Critical',
                color: Color(0xFFEF4444),
                description: 'Immediate action required. Production impacting.',
                examples: ['Budget exceeded 200%', 'Error rate > 50%', 'Service unavailable'],
                routing: 'PagerDuty, Phone call, SMS',
              ),
              const SizedBox(height: AppSpacing.md),
              const _SeverityCard(
                severity: 'Warning',
                color: Color(0xFFF59E0B),
                description: 'Attention needed soon. May escalate if unaddressed.',
                examples: ['Budget at 80%', 'Latency degradation', 'Elevated error rate'],
                routing: 'Slack, Email',
              ),
              const SizedBox(height: AppSpacing.md),
              const _SeverityCard(
                severity: 'Info',
                color: Color(0xFF3B82F6),
                description: 'Informational. No immediate action required.',
                examples: ['Daily cost summary', 'Usage milestone reached', 'Model version change'],
                routing: 'Email digest, Dashboard',
              ),
            ],
          ),
        ),

        // Schedules Section
        DocSection(
          key: const Key('alert-schedules-section'),
          icon: LucideIcons.clock,
          title: 'Alert Schedules',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Control when alerts are active and who receives them:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Time-Based Rules',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''{
  "schedule": {
    "timezone": "America/New_York",
    "active_hours": {
      "start": "09:00",
      "end": "18:00"
    },
    "active_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "outside_hours_action": "suppress"  // or "escalate", "digest"
  }
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Escalation Policies',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(bulletColor: AppColors.warning, items: [
                'Primary \u2192 Backup escalation after 15 minutes',
                'Weekend routing to on-call team',
                'Holiday schedules with reduced alerting',
                'Maintenance windows with alert suppression',
              ]),
            ],
          ),
        ),

        // Best Practices Section
        DocSection(
          key: const Key('best-practices-section'),
          icon: LucideIcons.lightbulb,
          title: 'Best Practices',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BestPractice(
                title: 'Start with budget alerts',
                description:
                    'Set conservative daily limits first. You can always adjust thresholds as you understand your usage patterns.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _BestPractice(
                title: 'Use anomaly detection for unknowns',
                description:
                    'When you don\'t know what "normal" looks like, let the system learn patterns and alert on deviations.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _BestPractice(
                title: 'Avoid alert fatigue',
                description:
                    'Too many alerts lead to ignored alerts. Start with critical issues only, then add more as needed.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _BestPractice(
                title: 'Test your alerts',
                description:
                    'Use the "Test Alert" feature to verify notifications reach the right channels before going live.',
              ),
              const SizedBox(height: AppSpacing.md),
              const _BestPractice(
                title: 'Document runbooks',
                description:
                    'Include links to runbooks in alert descriptions so responders know exactly what to do.',
              ),
            ],
          ),
        ),

        // Example Alerts Section
        DocSection(
          key: const Key('example-alerts-section'),
          icon: LucideIcons.fileCode,
          title: 'Example Alert Configurations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Cost Budget',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''{
  "name": "Daily Cost Budget - Production",
  "type": "budget",
  "condition": {
    "metric": "gen_ai.client.cost",
    "operator": "gt",
    "threshold": 500,
    "window": "24h",
    "filters": {"environment": "production"}
  },
  "channels": [
    {"type": "slack", "channel": "#ai-costs"},
    {"type": "email", "addresses": ["finance@company.com"]}
  ],
  "severity": "warning",
  "description": "Daily production spend exceeded \$500"
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Latency Degradation',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''{
  "name": "P95 Latency Alert",
  "type": "performance",
  "condition": {
    "metric": "gen_ai.client.operation.duration",
    "aggregation": "p95",
    "operator": "gt",
    "threshold": 10000,
    "window": "15m"
  },
  "channels": [
    {"type": "pagerduty", "severity": "warning"}
  ],
  "severity": "warning",
  "runbook": "https://wiki.company.com/runbooks/llm-latency"
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Anomaly Detection',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''{
  "name": "Token Usage Anomaly",
  "type": "anomaly",
  "condition": {
    "metric": "gen_ai.client.token.usage",
    "sensitivity": "medium",
    "baseline_window": "7d"
  },
  "channels": [
    {"type": "slack", "channel": "#ai-platform"}
  ],
  "severity": "info"
}''',
              ),
            ],
          ),
        ),

        // Related Docs Section
        DocSection(
          key: const Key('related-docs-section'),
          icon: LucideIcons.bookOpen,
          title: 'Related Documentation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocBulletList(bulletColor: AppColors.warning, items: [
                'Alerts API Reference \u2014 /api#alerts',
                'Slack Integration \u2014 /docs/integrations',
                'Cost Tracking \u2014 /docs/observability',
                'Dashboard Overview \u2014 /docs/quickstart',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

// Reusable Components

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: const [
        DocFeatureCard(
          icon: LucideIcons.dollarSign,
          title: 'Budget Protection',
          description: 'Never exceed your AI spend limits.',
          accentColor: AppColors.warning,
        ),
        DocFeatureCard(
          icon: LucideIcons.brain,
          title: 'Smart Detection',
          description: 'ML-powered anomaly detection.',
          accentColor: AppColors.warning,
        ),
        DocFeatureCard(
          icon: LucideIcons.zap,
          title: 'Instant Routing',
          description: 'Alerts delivered in seconds.',
          accentColor: AppColors.warning,
        ),
        DocFeatureCard(
          icon: LucideIcons.settings,
          title: 'Flexible Rules',
          description: 'Custom thresholds and schedules.',
          accentColor: AppColors.warning,
        ),
      ],
    );
  }
}

class _AlertTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> examples;

  const _AlertTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.examples,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      icon: icon,
      title: title,
      description: description,
      iconColor: AppColors.warning,
      descriptionStyle: AppTypography.bodySM.copyWith(color: AppColors.gray300),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: examples
            .map((e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray800,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  ),
                  child: Text(
                    e,
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.gray400,
                      fontSize: 12,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String code;

  const _ChannelCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      icon: icon,
      title: title,
      description: description,
      iconColor: AppColors.warning,
      descriptionStyle: AppTypography.bodySM.copyWith(color: AppColors.gray300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.gray900,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        ),
        child: Text(
          code,
          style: const TextStyle(
            fontFamily: kDocCodeFontFamily,
            fontSize: 11,
            color: AppColors.gray400,
          ),
        ),
      ),
    );
  }
}

class _SeverityCard extends StatelessWidget {
  final String severity;
  final Color color;
  final String description;
  final List<String> examples;
  final String routing;

  const _SeverityCard({
    required this.severity,
    required this.color,
    required this.description,
    required this.examples,
    required this.routing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray700,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Text(
                  severity,
                  style: AppTypography.bodySM.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  description,
                  style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Examples: ',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  examples.join(', '),
                  style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Routing: ',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  routing,
                  style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BestPractice extends StatelessWidget {
  final String title;
  final String description;

  const _BestPractice({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.checkCircle, size: 18, color: AppColors.success),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

