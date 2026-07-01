/// Services section content.
library;

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'models.dart';
import 'constants.dart';

/// Services section content.
abstract final class ServicesContentVariants {
  /// Current production content
  static const current = ServicesContent(
    sectionId: 'services',
    title: 'Platform Services',
    subtitle: 'Comprehensive AI Observability for Enterprise',
    description:
        'From real-time LLM monitoring to automated compliance reporting, '
        '${CompanyInfo.name} provides the complete toolkit for production AI systems. '
        'Built for teams who need visibility, governance, and audit-ready documentation.',
    services: _services,
    ctaText: CTAText.startFreeTrial,
    ctaUrl: Routes.signupTeam,
  );

  static const _services = [
    ServiceItemContent(
      icon: LucideIcons.activity,
      title: 'LLM Monitoring & Tracing',
      description:
          'Track every LLM call with sub-100ms latency. Capture prompts, completions, '
          'tokens, costs, and performance metrics in real-time across all your models.',
      capabilities: [
        'Full request/response capture with token attribution',
        'Cost tracking per request, model, and team',
        'Latency percentiles and performance baselines',
        'Multi-provider support (OpenAI, Anthropic, Google, AWS Bedrock)',
        'OpenTelemetry-native instrumentation',
      ],
      ctaText: 'View Tracing Docs',
      ctaUrl: Routes.docsTracing,
    ),
    ServiceItemContent(
      icon: LucideIcons.bot,
      title: 'Agent Observability',
      description:
          'Monitor multi-step AI agents, tool calls, and reasoning chains. '
          'Debug complex autonomous workflows with full execution traces and decision visualization.',
      capabilities: [
        'Multi-turn conversation tracking',
        'Tool call monitoring with input/output capture',
        'Reasoning chain visualization',
        'Agent decision tree analysis',
        'LangChain, LlamaIndex, and custom agent support',
      ],
      ctaText: 'Explore Agent Features',
      ctaUrl: Routes.docsAgents,
    ),
    ServiceItemContent(
      icon: LucideIcons.shield,
      title: 'Compliance & Governance',
      description:
          'Built-in EU AI Act templates, automated audit trails, and framework mapping. '
          'Prepare for regulatory requirements with documentation that stands up to scrutiny.',
      capabilities: [
        'EU AI Act Article 12 traceability requirements',
        'Automated risk classification support',
        'Audit trail generation with immutable logs',
        'Human oversight tracking and approval workflows',
        'GDPR-compliant data handling and retention',
      ],
      ctaText: 'EU AI Act Guide',
      ctaUrl: ExternalUrls.euAiAct,
      disclaimer: ComplianceDisclaimers.euAiActShort,
    ),
    ServiceItemContent(
      icon: LucideIcons.barChart3,
      title: 'Analytics & Dashboards',
      description:
          'Interactive dashboards for token usage, costs, latency distributions, '
          'and model comparison analytics. Export data for stakeholder reporting.',
      capabilities: [
        'Customizable KPI dashboards',
        'Historical trend analysis',
        'Model performance benchmarking',
        'Team and project attribution',
        'Export to CSV, JSON, and PDF',
      ],
      ctaText: 'See Dashboard Demo',
      ctaUrl: Routes.demo,
    ),
    ServiceItemContent(
      icon: LucideIcons.bell,
      title: 'Alerting & Incident Management',
      description:
          'Proactive alerting for anomalies, budget thresholds, and performance degradation. '
          'Intelligent routing to your existing incident management tools.',
      capabilities: [
        'Budget alerts before cost overruns',
        'Anomaly detection for response quality',
        'Performance regression warnings',
        'Slack, PagerDuty, and webhook integrations',
        'Custom alert thresholds and schedules',
      ],
      ctaText: 'Configure Alerts',
      ctaUrl: Routes.docsAlerts,
    ),
    ServiceItemContent(
      icon: LucideIcons.code,
      title: 'Developer Experience',
      description:
          'Drop-in SDKs for Python, TypeScript, and Go. OpenTelemetry-native with '
          'minimal instrumentation required. Get to value in under 15 min.',
      capabilities: [
        'Python, TypeScript, and Go SDKs',
        'Auto-instrumentation for popular frameworks',
        'OpenTelemetry compatibility',
        'Comprehensive API documentation',
        'Self-hosted and cloud deployment options',
      ],
      ctaText: 'Quick Start Guide',
      ctaUrl: Routes.docsQuickstart,
    ),
  ];
}
