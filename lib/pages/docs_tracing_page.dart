import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
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
        _DocSection(
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
              _WarningCallout(
                title: 'Compliance Deadline',
                message: 'August 2, 2026 marks full enforcement of the EU AI Act. Organizations should begin implementation now\u2014conformity assessment alone takes 6-12 months. Penalties can reach up to \u20AC35M or 7% of global revenue.',
              ),
            ],
          ),
        ),

        // EU AI Act Context Section
        _DocSection(
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
              _BulletList(items: const [
                'Providers \u2014 Organizations developing or placing AI systems on the market',
                'Deployers \u2014 Organizations using AI systems in their operations',
                'Importers \u2014 Entities bringing AI systems into the EU market',
                'Distributors \u2014 Those making AI systems available in the supply chain',
              ]),
              const SizedBox(height: AppSpacing.lg),
              _InfoCallout(
                title: 'Global Impact',
                message: 'Even organizations outside the EU must comply if their AI systems are used within the EU market or their outputs affect EU residents.',
              ),
            ],
          ),
        ),

        // Article 12 Requirements Section
        _DocSection(
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
              const _SimpleTable(
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
              _BulletList(items: const [
                'Period of use \u2014 When the system was active and processing',
                'Reference databases \u2014 Which data sources were consulted',
                'Input data \u2014 What data was processed (with appropriate redaction)',
                'Personnel identification \u2014 Who verified the results',
                'Significant changes \u2014 Any modifications to system behavior',
              ]),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
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
        _DocSection(
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
              const _SimpleTable(
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
              const _CodeBlock(
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
        _DocSection(
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
              const _SimpleTable(
                headers: ['Data Type', 'Minimum', 'Recommended'],
                rows: [
                  ['Operational logs', 'System lifetime', '7+ years'],
                  ['Decision audit trails', 'System lifetime', '10+ years'],
                  ['Model versions', 'System lifetime', 'Permanent'],
                  ['Training data records', 'System lifetime', 'Permanent'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SuccessCallout(
                title: 'Cost-Effective Archival',
                message: 'Use tiered storage: hot storage for recent data (30 days), warm storage for mid-term (1 year), and cold storage (S3 Glacier, etc.) for long-term compliance archives.',
              ),
            ],
          ),
        ),

        // Compliance Checklist Section
        _DocSection(
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
              const _ChecklistSection(items: [
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
              const _ChecklistSection(items: [
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
              const _ChecklistSection(items: [
                'PII redaction rules implemented',
                'Long-term retention storage configured',
                'Data export procedures for auditors',
                'Backup and disaster recovery tested',
              ]),
            ],
          ),
        ),

        // PII Protection Section
        _DocSection(
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
              const _SimpleTable(
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
              const _CodeBlock(
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
        _DocSection(
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
              _BulletList(items: const [
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
              _BulletList(items: const [
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

class _DocSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DocSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blue500,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headingSM.copyWith(
                    color: AppColors.blue400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: const [
        _FeatureCard(
          icon: LucideIcons.fileText,
          title: 'Automatic Logging',
          description: 'Capture every AI operation without manual intervention.',
        ),
        _FeatureCard(
          icon: LucideIcons.link,
          title: 'End-to-End Traceability',
          description: 'Track requests across distributed systems.',
        ),
        _FeatureCard(
          icon: LucideIcons.barChart3,
          title: 'Audit-Ready Evidence',
          description: 'Generate compliance artifacts for regulators.',
        ),
        _FeatureCard(
          icon: LucideIcons.lock,
          title: 'PII Protection',
          description: 'Auto-redact sensitive data while maintaining visibility.',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray700,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue500.withValues(alpha: 0.2),
                  AppColors.purple500.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Icon(icon, color: AppColors.blue400, size: 18),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.bodyMD.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
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

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 13,
          color: AppColors.gray300,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;

  const _SimpleTable({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        child: Table(
          border: TableBorder.symmetric(
            inside: BorderSide(color: AppColors.gray700),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: AppColors.gray800),
              children: headers
                  .map((h) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          h,
                          style: AppTypography.bodySM.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            ...rows.map(
              (row) => TableRow(
                children: row
                    .map((cell) => Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Text(
                            cell,
                            style: AppTypography.bodySM.copyWith(
                              color: AppColors.gray300,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;

  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u2022 ',
                      style: AppTypography.bodyMD.copyWith(
                        color: AppColors.blue400,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodyMD.copyWith(
                          color: AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  final List<String> items;

  const _ChecklistSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.checkSquare,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodyMD.copyWith(
                          color: AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _SuccessCallout extends StatelessWidget {
  final String title;
  final String message;

  const _SuccessCallout({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border(
          left: BorderSide(color: AppColors.success, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.checkCircle, color: AppColors.success, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
        ],
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  final String title;
  final String message;

  const _InfoCallout({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blue500.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border(
          left: BorderSide(color: AppColors.blue500, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lightbulb, color: AppColors.blue400, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.blue400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
        ],
      ),
    );
  }
}

class _WarningCallout extends StatelessWidget {
  final String title;
  final String message;

  const _WarningCallout({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border(
          left: BorderSide(color: AppColors.warning, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMD.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}
