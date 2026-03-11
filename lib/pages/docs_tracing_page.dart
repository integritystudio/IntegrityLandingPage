import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// Distributed Tracing & EU AI Act Compliance documentation page.
///
/// Covers how OpenTelemetry tracing enables EU AI Act compliance through
/// automatic logging, record-keeping, and auditable AI operations.
class DocsTracingPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsTracingPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          // App bar
          DocPageAppBar(title: 'Tracing Guide', onBack: onBack),

          // Hero Section
          SliverToBoxAdapter(
            child: _HeroSection(isMobile: isMobile),
          ),

          // Content
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: const _DocsContent(),
              ),
            ),
          ),

          // Footer
          const SliverToBoxAdapter(child: DocPageFooter()),
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
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.shieldCheck,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'EU AI Act Compliant',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'Distributed Tracing for AI Compliance',
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 28)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                'How OpenTelemetry tracing enables EU AI Act compliance through automatic logging, record-keeping, and auditable AI operations.',
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

class _DocsContent extends StatelessWidget {
  const _DocsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overview Section
        DocSection(
          icon: LucideIcons.info,
          title: 'Overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The EU AI Act establishes comprehensive requirements for AI systems operating in the European Union. For high-risk AI systems, automatic logging and traceability are not optional\u2014they\'re legal requirements.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureGrid(),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.warning(
                title: 'Compliance Deadline',
                message: 'August 2, 2026 marks full enforcement of the EU AI Act. Organizations should begin implementation now\u2014conformity assessment alone takes 6-12 months. Penalties can reach up to \u20AC35M or 7% of global revenue.',
              ),
            ],
          ),
        ),

        // EU AI Act Context Section
        DocSection(
          icon: LucideIcons.scale,
          title: 'EU AI Act Context',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The EU AI Act entered into force on August 1, 2024 and establishes a risk-based regulatory framework for AI systems. Tracing and logging requirements primarily apply to high-risk AI systems.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Key Compliance Timeline',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _Timeline(items: [
                _TimelineItem(
                  date: 'February 2, 2025',
                  title: 'Prohibited AI Practices',
                  description: 'Ban on social scoring, manipulative AI, and certain biometric systems.',
                ),
                _TimelineItem(
                  date: 'August 2, 2025',
                  title: 'GPAI Model Rules',
                  description: 'Governance rules and obligations for general-purpose AI models.',
                ),
                _TimelineItem(
                  date: 'August 2, 2026',
                  title: 'Full Enforcement',
                  description: 'All high-risk AI system requirements become fully applicable.',
                ),
                _TimelineItem(
                  date: 'August 2, 2027',
                  title: 'Product-Embedded AI',
                  description: 'Extended deadline for high-risk AI embedded in regulated products.',
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Who Must Comply?',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              DocBulletList(items: const [
                'Providers \u2014 Organizations developing or placing AI systems on the market',
                'Deployers \u2014 Organizations using AI systems in their operations',
                'Importers \u2014 Entities bringing AI systems into the EU market',
                'Distributors \u2014 Those making AI systems available in the supply chain',
              ]),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Global Impact',
                message: 'Even organizations outside the EU must comply if their AI systems are used within the EU market or their outputs affect EU residents.',
              ),
            ],
          ),
        ),

        // Article 12 Requirements Section
        DocSection(
          icon: LucideIcons.fileText,
          title: 'Article 12: Record-Keeping Requirements',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Article 12 of the EU AI Act mandates automatic logging capabilities for high-risk AI systems. This is where distributed tracing becomes essential.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Core Requirements',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Requirement', 'How Tracing Helps'],
                rows: [
                  ['Automatic Recording', 'OpenTelemetry auto-instruments all operations'],
                  ['Traceability', 'Distributed traces link all related operations'],
                  ['Risk Identification', 'Anomaly detection on trace data'],
                  ['Post-Market Monitoring', 'Real-time dashboards and alerts'],
                  ['Human Verification', 'User attribution in span attributes'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'What Must Be Logged',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              DocBulletList(items: const [
                'Period of use \u2014 When the system was active and processing',
                'Reference databases \u2014 Which data sources were consulted',
                'Input data \u2014 What data was processed (with appropriate redaction)',
                'Personnel identification \u2014 Who verified the results',
                'Significant changes \u2014 Any modifications to system behavior',
              ]),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                code: '''// Example: OpenTelemetry span with Article 12 attributes
await withSpan('ai.decision', {
  // Period of use
  'ai.operation.start_time': new Date().toISOString(),

  // Reference databases
  'ai.database.name': 'customer_embeddings_v2',
  'ai.database.version': '2024.1.3',

  // Personnel verification
  'ai.verifier.id': 'operator_12345',
  'ai.verifier.role': 'human_reviewer',

  // Model information
  'gen_ai.system': 'anthropic',
  'gen_ai.request.model': 'claude-opus-4-5-20251101',
}, async (span) => {
  // AI operation logic
});''',
              ),
            ],
          ),
        ),

        // Distributed Tracing Section
        DocSection(
          icon: LucideIcons.activity,
          title: 'Distributed Tracing Implementation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distributed tracing tracks requests as they flow through your AI system, creating a complete audit trail that satisfies Article 12 requirements.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Key Tracing Concepts',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Concept', 'Description', 'Compliance Value'],
                rows: [
                  ['Trace', 'Complete request journey', 'Full audit trail'],
                  ['Span', 'Individual unit of work', 'Granular logging'],
                  ['Trace ID', 'Unique identifier linking spans', 'Correlate logs across services'],
                  ['Attributes', 'Key-value metadata', 'Record Article 12 data'],
                  ['Events', 'Timestamped logs in span', 'Document occurrences'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Sample Implementation',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''import { initTelemetry, withSpan, logger, shutdown } from './lib/otel';

// Initialize at application startup
initTelemetry();

// Trace an AI inference operation
async function processAIRequest(request) {
  return withSpan('ai.inference', {
    'ai.system.version': '2.1.0',
    'ai.deployer.id': process.env.DEPLOYER_ID,
    'ai.operator.id': request.operatorId,
  }, async (span) => {
    logger.info('AI inference started', { requestId: request.id });

    const result = await model.generate(request.prompt);

    span.setAttributes({
      'ai.output.tokens': result.tokens,
      'ai.output.confidence': result.confidence,
    });

    return result;
  });
}''',
              ),
            ],
          ),
        ),

        // Storage & Retention Section
        DocSection(
          icon: LucideIcons.database,
          title: 'Storage & Retention',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The EU AI Act requires maintaining records for the lifetime of the AI system. This necessitates long-term, cost-effective storage strategies.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Retention Requirements',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Data Type', 'Minimum', 'Recommended'],
                rows: [
                  ['Operational logs', 'System lifetime', '7+ years'],
                  ['Decision audit trails', 'System lifetime', '10+ years'],
                  ['Model versions', 'System lifetime', 'Permanent'],
                  ['Training data records', 'System lifetime', 'Permanent'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'Cost-Effective Archival',
                message: 'Use tiered storage: hot storage for recent data (30 days), warm storage for mid-term (1 year), and cold storage (S3 Glacier, etc.) for long-term compliance archives.',
              ),
            ],
          ),
        ),

        // Compliance Checklist Section
        DocSection(
          icon: LucideIcons.clipboardCheck,
          title: 'Compliance Checklist',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use this checklist to verify your tracing implementation meets EU AI Act requirements:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Technical Requirements',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(checked: true, items: [
                'Automatic logging enabled for all AI operations',
                'Trace IDs generated for request correlation',
                'Span attributes include required Article 12 data',
                'Input/output tokens recorded (redacted as needed)',
                'Operator/verifier identification captured',
                'Database/model versions logged',
                'Timestamps in ISO 8601 format',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Operational Requirements',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(checked: true, items: [
                'Real-time monitoring dashboards configured',
                'Alerting for anomalous AI behavior',
                'Incident response procedures documented',
                'Post-market monitoring process established',
                'Human oversight workflows defined',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Data Management',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(checked: true, items: [
                'PII redaction rules implemented',
                'Long-term retention storage configured',
                'Data export procedures for auditors',
                'Backup and disaster recovery tested',
              ]),
            ],
          ),
        ),

        // PII Protection Section
        DocSection(
          icon: LucideIcons.lock,
          title: 'PII Protection',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'While logging is required, you must also protect personal data. Implement automatic PII redaction in your telemetry pipeline.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Auto-Redacted Patterns',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Data Type', 'Replacement'],
                rows: [
                  ['Email addresses', '[EMAIL]'],
                  ['Phone numbers', '[PHONE]'],
                  ['Credit cards', '[CREDIT_CARD]'],
                  ['SSN', '[SSN]'],
                  ['API keys', '[API_KEY]'],
                  ['JWT tokens', '[JWT_TOKEN]'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                code: '''// PII redaction middleware
const redactPII = (text) => {
  return text
    .replace(/[\\w.-]+@[\\w.-]+\\.\\w+/g, '[EMAIL]')
    .replace(/\\+?[\\d\\s-]{10,}/g, '[PHONE]')
    .replace(/\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}/g, '[CREDIT_CARD]')
    .replace(/\\d{3}-\\d{2}-\\d{4}/g, '[SSN]')
    .replace(/sk-[a-zA-Z0-9]{32,}/g, '[API_KEY]');
};''',
              ),
            ],
          ),
        ),

        // Sources Section
        DocSection(
          icon: LucideIcons.bookOpen,
          title: 'Sources & References',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official EU AI Act Resources',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              DocBulletList(items: const [
                'EU AI Act - Shaping Europe\'s Digital Future',
                'Article 12: Record-Keeping Requirements',
                'Article 26: Obligations of Deployers',
                'High-Level Summary of the AI Act',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Technical Documentation',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              DocBulletList(items: const [
                'OpenTelemetry Documentation',
                'SigNoz Documentation',
                'Full Observability Framework Guide',
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
          icon: LucideIcons.fileText,
          title: 'Automatic Logging',
          description: 'Capture every AI operation without manual intervention.',
        ),
        DocFeatureCard(
          icon: LucideIcons.link,
          title: 'End-to-End Traceability',
          description: 'Track requests across distributed systems.',
        ),
        DocFeatureCard(
          icon: LucideIcons.barChart3,
          title: 'Audit-Ready Evidence',
          description: 'Generate compliance artifacts for regulators.',
        ),
        DocFeatureCard(
          icon: LucideIcons.lock,
          title: 'PII Protection',
          description: 'Auto-redact sensitive data while maintaining visibility.',
        ),
      ],
    );
  }
}
class _TimelineItem {
  final String date;
  final String title;
  final String description;

  const _TimelineItem({
    required this.date,
    required this.title,
    required this.description,
  });
}

class _Timeline extends StatelessWidget {
  final List<_TimelineItem> items;

  const _Timeline({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == items.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.blue500,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: AppColors.blue500.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.date,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.blue400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: AppTypography.bodyMD.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

