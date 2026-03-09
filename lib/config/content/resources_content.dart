/// Resources section content.
library;

import 'package:lucide_icons/lucide_icons.dart';
import 'models.dart';
import 'constants.dart';

/// Resources section content.
abstract final class ResourcesContentVariants {
  /// Current production content
  static const current = ResourcesContent(
    sectionId: 'resources',
    title: 'Resources',
    subtitle: 'Guides, Documentation & Insights',
    documentation: _documentation,
    featuredPosts: _featuredPosts,
    leadMagnets: _leadMagnets,
    blogCtaText: 'View All Articles',
    blogCtaUrl: Routes.blog,
    docsCtaText: 'Browse Documentation',
    docsCtaUrl: Routes.docs,
  );

  static const _documentation = [
    DocCategoryContent(
      icon: LucideIcons.bookOpen,
      title: 'Getting Started',
      description:
          'Quick start guides and tutorials to get your first traces flowing in under 15 min.',
      url: Routes.docsQuickstart,
      popularTopics: [
        'Python SDK Setup',
        'TypeScript Integration',
        'OpenTelemetry Configuration',
        'Dashboard Overview',
      ],
    ),
    DocCategoryContent(
      icon: LucideIcons.code2,
      title: 'API Reference',
      description:
          'Complete API documentation with examples for all endpoints and SDK methods.',
      url: Routes.api,
      popularTopics: [
        'Trace Ingestion API',
        'Query API',
        'Alerts API',
        'Authentication',
      ],
    ),
    DocCategoryContent(
      icon: LucideIcons.shield,
      title: 'Compliance Guides',
      description:
          'In-depth guides for EU AI Act preparation, audit trails, and governance configuration.',
      url: Routes.docsCompliance,
      popularTopics: [
        'EU AI Act Overview',
        'Risk Classification',
        'Audit Trail Setup',
        'Human Oversight Workflows',
      ],
    ),
    DocCategoryContent(
      icon: LucideIcons.puzzle,
      title: 'Integrations',
      description:
          'Connect ${CompanyInfo.name} with your existing tools: Slack, PagerDuty, Datadog, and more.',
      url: Routes.docsIntegrations,
      popularTopics: [
        'Slack Notifications',
        'PagerDuty Alerting',
        'Grafana Dashboards',
        'Webhook Configuration',
      ],
    ),
  ];

  static const _featuredPosts = [
    BlogPostPreviewContent(
      title: 'Best LLM Monitoring Tools (2025 Guide)',
      excerpt:
          'I tested 11 platforms so you can skip the free trial hamster wheel. '
          'Includes pricing, features, and honest recommendations—from Phoenix (free) '
          'to Arize (\$50k+/year). Plus EU AI Act compliance considerations.',
      category: 'Comparison Guide',
      publishDate: '2024-12-24',
      readTime: '18 min read',
      slug: 'best-llm-monitoring-tools-2025',
      author: 'Alyshia Ledlie',
    ),
    BlogPostPreviewContent(
      title: 'End-to-End Agentic Observability: From Chaos to Control',
      excerpt:
          'Your AI agent just autonomously decided to email your entire customer database '
          'at 3 AM. Learn the Build, Test, Monitor, Analyze lifecycle that keeps agents '
          "reliable, compliant, and not accidentally ordering 10,000 pizzas.",
      category: 'Best Practices',
      publishDate: '2024-12-24',
      readTime: '12 min read',
      slug: 'end-to-end-agentic-observability-lifecycle',
      author: 'Alyshia Ledlie',
    ),
    BlogPostPreviewContent(
      title: 'LLM Cost Calculator & Optimization Guide (2025)',
      excerpt:
          'Compare API pricing for GPT-4, Claude, Gemini, and DeepSeek. Free calculator shows '
          'monthly costs. Learn techniques to reduce AI spending by 40-80%, from prompt caching '
          'to model routing.',
      category: 'Cost Optimization',
      publishDate: '2025-12-27',
      readTime: '5 min read',
      slug: 'llm-cost-optimization-guide',
      author: 'Alyshia Ledlie',
    ),
  ];

  static const _leadMagnets = [
    LeadMagnetContent(
      icon: LucideIcons.clipboardCheck,
      title: 'EU AI Act Compliance Checklist',
      description:
          'A comprehensive checklist covering all EU AI Act requirements for high-risk AI systems. '
          'Includes Article 12 traceability, documentation templates, and timeline milestones.',
      format: 'PDF',
      ctaText: 'Request Checklist',
      url: '/contact?subject=eu-ai-act-checklist',
    ),
    LeadMagnetContent(
      icon: LucideIcons.calculator,
      title: 'LLM Cost Calculator',
      description:
          'Compare pricing across GPT-4, Claude, Gemini, and DeepSeek. '
          'Calculate monthly costs and discover optimization techniques to save 40-80%.',
      format: 'Interactive Tool',
      ctaText: CTAText.calculateSavings,
      url: '/blog',
      requiresEmail: false,
    ),
    LeadMagnetContent(
      icon: LucideIcons.fileText,
      title: 'State of AI Observability 2025',
      description:
          'Original research on AI observability trends, challenges, and best practices. '
          'Data from 500+ AI teams on monitoring, compliance, and cost management.',
      format: 'Report',
      ctaText: 'Request Report',
      url: '/contact?subject=ai-observability-report',
    ),
  ];
}
