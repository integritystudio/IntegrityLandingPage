/// Comparison/migration page content for competitor alternatives.
library;

import 'models.dart';
import 'constants.dart';

/// Competitor comparison page content.
abstract final class ComparisonPageVariants {
  /// WhyLabs migration page content
  /// Context: WhyLabs announced closure March 9, 2025, open-sourcing platform
  /// Target: Privacy-conscious orgs, healthcare/finance, data quality users
  static const whylabs = ComparisonPageContent(
    competitorName: 'WhyLabs',
    pageTitle: 'WhyLabs Alternative - Migrate to Integrity Studio',
    metaDescription:
        'Looking for a WhyLabs alternative? Integrity Studio provides enterprise-grade '
        'AI observability with EU AI Act compliance, privacy-first monitoring, and seamless '
        'migration from WhyLabs. Start your free trial today.',
    heroHeadline: "WhyLabs Is Shutting Down.\nYour AI Observability Shouldn't.",
    heroSubheadline:
        'Integrity Studio provides the same privacy-first AI monitoring you relied on '
        'with WhyLabs, plus EU AI Act compliance built-in. Migrate your data quality '
        'and LLM monitoring in under an hour.',
    heroCtaText: 'Start Free Migration',
    competitorStatus: 'WhyLabs announced shutdown March 9, 2025',
    keyDifferentiators: _whylabsDifferentiators,
    featureComparison: _whylabsFeatures,
    whyChooseUs: _whylabsWhyUs,
    whyChooseThem: _whylabsWhyThem,
    migrationSteps: _whylabsMigrationSteps,
    migrationTimeEstimate: 'Most teams complete migration in under 1 hour',
  );

  /// Arize AI comparison page content
  static const arize = ComparisonPageContent(
    competitorName: 'Arize AI',
    pageTitle: 'Arize AI Alternative - Integrity Studio Comparison',
    metaDescription:
        'Compare Integrity Studio vs Arize AI for AI observability. Simpler pricing, '
        'EU AI Act compliance, and developer-friendly integration.',
    heroHeadline: 'A Simpler Path to\nAI Observability',
    heroSubheadline:
        'Integrity Studio offers the same powerful AI observability as Arize AI, '
        'with transparent pricing and EU AI Act compliance built-in.',
    heroCtaText: CTAText.startFreeTrial,
    keyDifferentiators: _arizeDifferentiators,
    featureComparison: _arizeFeatures,
    whyChooseUs: _arizeWhyUs,
    whyChooseThem: _arizeWhyThem,
    migrationSteps: [],
    migrationTimeEstimate: 'Setup takes under 15 min',
  );

  // WhyLabs content details
  static const _whylabsDifferentiators = [
    'EU AI Act compliance ready - audit trails and documentation',
    'Privacy-first architecture with PII detection and redaction',
    'No vendor lock-in - export your data anytime',
    'Active development and support (not open-source-only)',
    'Seamless migration path with data import tools',
  ];

  static const _whylabsFeatures = [
    ComparisonFeature(
      feature: 'LLM Monitoring',
      ourSupport: true,
      theirSupport: true,
      ourValue: 'Full tracing + cost',
      theirValue: 'Basic monitoring',
    ),
    ComparisonFeature(
      feature: 'Data Quality Monitoring',
      ourSupport: true,
      theirSupport: true,
      ourValue: 'Integrated',
      theirValue: 'Primary focus',
    ),
    ComparisonFeature(
      feature: 'Agent Observability',
      ourSupport: true,
      theirSupport: false,
      ourValue: 'Multi-step tracing',
      theirValue: 'Not supported',
    ),
    ComparisonFeature(
      feature: 'EU AI Act Compliance',
      ourSupport: true,
      theirSupport: false,
      ourValue: 'Built-in templates',
      theirValue: 'Not available',
    ),
    ComparisonFeature(
      feature: 'PII Detection & Redaction',
      ourSupport: true,
      theirSupport: true,
      ourValue: 'Automatic + custom',
      theirValue: 'Basic detection',
    ),
    ComparisonFeature(
      feature: 'On-Premise Deployment',
      ourSupport: true,
      theirSupport: true,
      ourValue: 'Enterprise tier',
      theirValue: 'Self-hosted only',
    ),
    ComparisonFeature(
      feature: 'Managed Cloud Option',
      ourSupport: true,
      theirSupport: false,
      ourValue: 'All tiers',
      theirValue: 'Discontinued',
    ),
    ComparisonFeature(
      feature: 'Active Support & Updates',
      ourSupport: true,
      theirSupport: false,
      ourValue: '24/7 enterprise support',
      theirValue: 'Community only',
    ),
    ComparisonFeature(
      feature: 'HIPAA Compliance',
      ourSupport: true,
      theirSupport: true,
      ourValue: 'Enterprise tier',
      theirValue: 'Self-hosted',
    ),
    ComparisonFeature(
      feature: 'SOC 2 Type II',
      ourSupport: true,
      theirSupport: false,
      ourValue: 'In progress (Q2 2025)',
      theirValue: 'Not certified',
    ),
  ];

  static const _whylabsWhyUs = [
    'Active product development with new features monthly',
    'Dedicated support team with enterprise SLA options',
    'EU AI Act compliance tools for regulatory requirements',
    'Combined LLM monitoring + data quality in one platform',
    'Managed cloud option - no infrastructure to maintain',
    'Migration assistance and data import from WhyLabs',
  ];

  static const _whylabsWhyThem = [
    'Open-source self-hosted option if you prefer full control',
    'Existing WhyLabs expertise on your team',
    'Deep integration with existing WhyLabs pipelines',
    'Community-maintained with no vendor dependency',
  ];

  static const _whylabsMigrationSteps = [
    MigrationStep(
      number: 1,
      title: 'Export Your WhyLabs Data',
      description:
          'Use WhyLabs export tools to download your profiles, monitors, and historical data. '
          'We support JSON and Parquet formats.',
      docsUrl: '/docs/migration/whylabs-export',
    ),
    MigrationStep(
      number: 2,
      title: 'Create Integrity Studio Account',
      description:
          'Sign up for a free account and start your migration.',
      docsUrl: '/signup?ref=whylabs',
    ),
    MigrationStep(
      number: 3,
      title: 'Install SDK & Configure',
      description:
          'Replace WhyLabs SDK with Integrity Studio SDK. Our Python SDK has similar '
          'patterns for easy migration.',
      codeSnippet: '''# Before (WhyLabs)
from whylogs import why
result = why.log(df)

# After (Integrity Studio)
from integritystudio import monitor
monitor.log(df)''',
      docsUrl: '/docs/sdk/python',
    ),
    MigrationStep(
      number: 4,
      title: 'Import Historical Data',
      description:
          'Use our migration CLI to import your WhyLabs profiles and set up matching '
          'monitors. Most configurations translate directly.',
      codeSnippet: '''# Import WhyLabs data
integrity migrate whylabs \\
  --input exported_data/ \\
  --org your-org''',
      docsUrl: '/docs/migration/import',
    ),
    MigrationStep(
      number: 5,
      title: 'Configure Alerts & Dashboards',
      description:
          "Set up your monitoring dashboards and configure alerts. We'll auto-generate "
          'suggested thresholds based on your imported data.',
      docsUrl: '/docs/alerts',
    ),
  ];

  // Arize content details
  static const _arizeDifferentiators = [
    'Transparent, predictable pricing',
    'EU AI Act compliance tools included',
    'Faster integration - under 15 min setup',
    'No complex enterprise negotiations',
  ];

  static const _arizeFeatures = [
    ComparisonFeature(
      feature: 'LLM Monitoring',
      ourSupport: true,
      theirSupport: true,
    ),
    ComparisonFeature(
      feature: 'Distributed Tracing',
      ourSupport: true,
      theirSupport: true,
    ),
    ComparisonFeature(
      feature: 'EU AI Act Compliance',
      ourSupport: true,
      theirSupport: false,
    ),
    ComparisonFeature(
      feature: 'Transparent Pricing',
      ourSupport: true,
      theirSupport: false,
    ),
  ];

  static const _arizeWhyUs = [
    'Transparent pricing without enterprise negotiations',
    'EU AI Act compliance documentation built-in',
    'Faster time-to-value with 15-min setup',
  ];

  static const _arizeWhyThem = [
    'Larger enterprise customer base',
    'More mature product with longer track record',
    'Deeper ML model monitoring (non-LLM)',
  ];
}
