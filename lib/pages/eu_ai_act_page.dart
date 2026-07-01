import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/sections/page_hero_section.dart';

/// EU AI Act Compliance documentation page.
///
/// Covers observability, logging, and documentation requirements
/// for LLM and GenAI systems under EU Regulation 2024/1689.
class EuAiActPage extends StatelessWidget {
  final VoidCallback? onBack;

  const EuAiActPage({
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
          SliverAppBar(
            backgroundColor: AppColors.gray900,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
            ),
            title: Text(
              'EU AI Act Compliance',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: () => context.go('/compliance'),
                  child: Text(
                    'Back to Compliance',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: PageHeroSection(
              isMobile: isMobile,
              accentColor: AppColors.purple400,
              badgeIcon: LucideIcons.scale,
              badgeText: 'EU Regulation 2024/1689',
              headline: 'EU AI Act Observability Requirements',
              subheadline:
                  'Comprehensive guide to logging, documentation, and observability requirements for LLM and GenAI systems under the EU AI Act.',
              extraContent: Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  DocStatCard(
                    value: 'Aug 2024',
                    label: 'Act in Force',
                    accentColor: AppColors.purple400,
                    valueStyle: AppTypography.headingSM.copyWith(color: AppColors.purple400),
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
                  ),
                  DocStatCard(
                    value: 'Aug 2025',
                    label: 'GPAI Obligations',
                    accentColor: AppColors.purple400,
                    valueStyle: AppTypography.headingSM.copyWith(color: AppColors.purple400),
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
                  ),
                  DocStatCard(
                    value: 'Aug 2026',
                    label: 'High-Risk Requirements',
                    accentColor: AppColors.purple400,
                    valueStyle: AppTypography.headingSM.copyWith(color: AppColors.purple400),
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
                  ),
                ],
              ),
            ),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'Built with OpenTelemetry and SigNoz',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '\u00A9 2026 Integrity Studio LLC',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The EU AI Act entered into force on August 1, 2024, with a phased implementation timeline. This document summarizes the observability, logging, and documentation requirements relevant to LLM and GenAI systems.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Date', 'Requirements'],
                rows: [
                  ['Aug 2024', 'Act enters into force'],
                  ['Feb 2025', 'Prohibited AI practices apply'],
                  ['Aug 2025', 'GPAI obligations (Articles 53, 55)'],
                  ['Aug 2026', 'High-risk AI system requirements (Articles 12, 19)'],
                ],
              ),
            ],
          ),
        ),

        // GPAI Requirements Section
        DocSection(
          icon: LucideIcons.brain,
          title: 'General-Purpose AI (GPAI) Requirements',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Article 53: GPAI Provider Obligations',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Effective: August 2, 2025',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.purple400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Maintain technical documentation per Annex XI',
                  'Provide information to downstream providers per Annex XII',
                  'Establish copyright compliance policies',
                  'Publish training data summaries',
                ],
                bulletColor: AppColors.purple400,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Article 55: Systemic Risk GPAI Obligations',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Effective: August 2, 2025 | Models trained with >10^25 FLOPs',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.purple400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Model evaluation using standardized protocols',
                  'Adversarial testing (red teaming)',
                  'Systemic risk tracking and mitigation',
                  'Cybersecurity protection',
                  'Incident reporting to EU AI Office',
                ],
                bulletColor: AppColors.purple400,
              ),
            ],
          ),
        ),

        // Annex XI Section
        DocSection(
          icon: LucideIcons.fileText,
          title: 'Annex XI: GPAI Technical Documentation',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocCallout.info(
                title: 'Applies to All GPAI Providers',
                message: 'Including LLM providers serving EU users or markets.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '1. General Description',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Element', 'Description'],
                rows: [
                  ['Tasks', 'Intended tasks and AI system integration types'],
                  ['Acceptable Use', 'Policies governing permitted uses'],
                  ['Release Info', 'Date and distribution methods'],
                  ['Architecture', 'Model architecture and parameter count'],
                  ['I/O Format', 'Input/output modalities and formats'],
                  ['License', 'Licensing terms'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '2. Design & Training Process',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Element', 'Description'],
                rows: [
                  ['Technical Means', 'Infrastructure, tools, usage instructions for integration'],
                  ['Design Specifications', 'Training methodologies, key design choices, rationale'],
                  ['Optimization', 'What the model optimizes for, parameter relevance'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '3. Data Documentation',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Element', 'Description'],
                rows: [
                  ['Data Sources', 'Type and provenance of training/test/validation data'],
                  ['Curation Methods', 'Cleaning, filtering, preprocessing techniques'],
                  ['Data Points', 'Number, scope, and main characteristics'],
                  ['Data Selection', 'How data was obtained and selected'],
                  ['Bias Detection', 'Methods to identify unsuitable sources and biases'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '4. Compute & Energy',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Element', 'Description'],
                rows: [
                  ['Compute Resources', 'FLOPs used for training'],
                  ['Training Time', 'Duration of training process'],
                  ['Energy Consumption', 'Known or estimated (can estimate from compute)'],
                ],
              ),
            ],
          ),
        ),

        // High-Risk AI Section
        DocSection(
          icon: LucideIcons.alertTriangle,
          title: 'High-Risk AI System Requirements',
          accentColor: AppColors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Article 12: Record-Keeping',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Effective: August 2, 2026',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocNumberedList(
                items: [
                  'Automatic Logging Capability: Systems must technically enable automatic event recording (logs) that persist over the system\'s entire lifetime.',
                  'Required Log Events: Situations presenting risk (Art. 79), substantial modifications, post-market monitoring events (Art. 72), and operational monitoring events (Art. 26).',
                  'Biometric Identification Systems: Session timestamps, reference database info, input data producing matches, identity of verifying humans.',
                ],
                accentColor: AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.warning(
                title: 'Recital 71 Rationale',
                message: 'Comprehensible information on how high-risk AI systems have been developed and how they perform throughout their lifetime is essential to enable traceability, verify compliance, and support post-market surveillance.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Article 19: Automatically Generated Logs',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Effective: August 2, 2026',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Providers must retain logs generated by high-risk AI systems',
                  'Minimum retention period: 6 months (unless otherwise specified by law)',
                  'Deployers under provider control must also maintain logs',
                ],
                bulletColor: AppColors.warning,
              ),
            ],
          ),
        ),

        // OTel Mapping Section
        DocSection(
          icon: LucideIcons.plug,
          title: 'Observability Implementation Mapping',
          accentColor: AppColors.blue500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OTel GenAI Semantic Conventions Alignment',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['EU AI Act Requirement', 'OTel GenAI Attribute/Event'],
                rows: [
                  ['Session timestamps', 'gen_ai.conversation.id + span timestamps'],
                  ['Model identification', 'gen_ai.response.model'],
                  ['Input logging', 'gen_ai.content.prompt event'],
                  ['Output logging', 'gen_ai.content.completion event'],
                  ['Tool/database references', 'gen_ai.tool.name, gen_ai.tool.call.id'],
                  ['Token usage', 'gen_ai.usage.input_tokens, gen_ai.usage.output_tokens'],
                  ['Request parameters', 'gen_ai.request.temperature, gen_ai.request.max_tokens'],
                  ['Finish reasons', 'gen_ai.response.finish_reasons'],
                  ['Provider identification', 'gen_ai.provider.name, gen_ai.system'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Recommended Configuration',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''// Recommended settings for EU AI Act compliance
{
  RETENTION_DAYS: 180,          // 6+ months per Article 19
  LOG_LEVEL: 'info',            // Capture operational events
  TRACE_CONTENT: true,          // Enable input/output logging
  SESSION_TRACKING: true,       // Track conversation sessions
}''',
              ),
            ],
          ),
        ),

        // Compliance Checklist Section
        DocSection(
          icon: LucideIcons.checkSquare,
          title: 'Compliance Checklist',
          accentColor: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ChecklistItem(text: 'Enable automatic event logging for all AI system interactions'),
              const _ChecklistItem(text: 'Capture session start/end timestamps'),
              const _ChecklistItem(text: 'Log model version and configuration per request'),
              const _ChecklistItem(text: 'Record input data and corresponding outputs'),
              const _ChecklistItem(text: 'Track human verification events (if applicable)'),
              const _ChecklistItem(text: 'Implement 6+ month log retention'),
              const _ChecklistItem(text: 'Maintain technical documentation and keep it updated'),
              const _ChecklistItem(text: 'Enable traceability via trace IDs and session IDs'),
            ],
          ),
        ),

        // Penalties Section
        DocSection(
          icon: LucideIcons.alertCircle,
          title: 'Penalties',
          accentColor: AppColors.error,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocCallout.danger(
                title: 'Significant Financial Penalties',
                message: 'Non-compliance can result in substantial fines based on violation severity.',
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Violation', 'Fine'],
                rows: [
                  ['Prohibited AI practices', 'Up to 35M EUR or 7% global turnover'],
                  ['High-risk AI non-compliance', 'Up to 15M EUR or 3% global turnover'],
                  ['Incorrect information to authorities', 'Up to 7.5M EUR or 1% global turnover'],
                  ['GPAI provider violations', 'Up to 15M EUR or 3% global turnover'],
                ],
              ),
            ],
          ),
        ),

        // Integrity Studio Support Section
        DocSection(
          icon: LucideIcons.shield,
          title: 'Integrity Studio Compliance Support',
          accentColor: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Integrity Studio provides comprehensive observability tooling aligned with EU AI Act requirements.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Requirement', 'Article', 'Support Status'],
                rows: [
                  ['Automatic event logging', 'Art. 12(1)', 'Supported'],
                  ['Session timestamps', 'Art. 12(3)(a)', 'Supported'],
                  ['Tool/database references', 'Art. 12(3)(b)', 'Supported'],
                  ['Input data logging', 'Art. 12(3)(c)', 'Supported'],
                  ['Human verification tracking', 'Art. 12(3)(d)', 'Extensible'],
                  ['Log retention (6+ months)', 'Art. 19', 'Configurable'],
                  ['Model identification', 'Annex XI', 'Supported'],
                  ['Provider identification', 'Annex XI', 'Supported'],
                  ['Token usage tracking', 'Annex XI', 'Supported'],
                  ['Cost estimation', 'Annex XI', 'Supported'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'Full OTel GenAI Semantic Conventions',
                items: [
                  'gen_ai.operation.name: chat, embeddings, invoke_agent, execute_tool',
                  'gen_ai.conversation.id: Session correlation',
                  'gen_ai.response.model: Model version tracking',
                  'gen_ai.tool.name / gen_ai.tool.call.id: Tool identification',
                ],
              ),
            ],
          ),
        ),

        // References Section
        DocSection(
          icon: LucideIcons.bookOpen,
          title: 'References',
          accentColor: AppColors.gray500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official Sources',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'EU AI Act (Regulation 2024/1689) - eur-lex.europa.eu',
                  'Implementation Timeline - artificialintelligenceact.eu',
                  'EU AI Act Compliance Checker - artificialintelligenceact.eu',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Key Articles',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Article 12: Record-Keeping',
                  'Article 19: Automatically Generated Logs',
                  'Article 53: GPAI Provider Obligations',
                  'Article 55: Systemic Risk GPAI Obligations',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Relevant Annexes',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                items: [
                  'Annex XI: GPAI Technical Documentation',
                  'Annex XII: GPAI Transparency Information',
                  'Annex XIII: Systemic Risk Criteria',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.success, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              LucideIcons.check,
              size: 14,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.gray300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
