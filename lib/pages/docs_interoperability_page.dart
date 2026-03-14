import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// OpenTelemetry Interoperability documentation page.
///
/// Covers the hook-based architecture, dual export pattern, signal types,
/// backend compatibility, and integration mechanisms for the observability framework.
class DocsInteroperabilityPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsInteroperabilityPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return DocsPageScaffold(
      title: 'Integrations Guide',
      onBack: onBack,
      heroBuilder: (isMobile) => DocsHeroSection(
        badgeIcon: LucideIcons.plug,
        badgeColor: AppColors.purple500,
        badgeContentColor: AppColors.purple400,
        badgeLabel: 'OpenTelemetry Native',
        headline: 'Interoperability & Integrations',
        subheadline:
            'How the observability framework integrates with OpenTelemetry, Langtrace, and SigNoz Cloud through a hook-based architecture with dual export capabilities.',
        isMobile: isMobile,
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
          icon: LucideIcons.layers,
          title: 'Core Architecture',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The observability framework uses OpenTelemetry as its foundation, with Langtrace for LLM-specific instrumentation, and SigNoz Cloud as the observability backend.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureGrid(),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Vendor Neutral',
                message:
                    'Built on OpenTelemetry standards, allowing you to switch backends or add additional exporters without code changes.',
              ),
            ],
          ),
        ),

        // Signal Types Section
        DocSection(
          icon: LucideIcons.radio,
          title: 'Signal Types Supported',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The framework captures three primary telemetry signal types, each optimized for different observability needs:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Signal', 'Description', 'Use Case'],
                rows: [
                  [
                    'Traces',
                    'Spans with parent-child relationships',
                    'Request flow & latency analysis'
                  ],
                  [
                    'Metrics',
                    'Counters, histograms, gauges',
                    'Performance & cost tracking'
                  ],
                  [
                    'Logs',
                    'Structured logging output',
                    'Debugging & audit trails'
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'GenAI Semantic Conventions',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '11 auto-instrumented LLM attributes standardize span data for consistent cross-tool analysis:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                bulletColor: AppColors.purple400,
                items: [
                  'gen_ai.system \u2014 Provider (anthropic, openai)',
                  'gen_ai.request.model \u2014 Model identifier',
                  'gen_ai.request.temperature \u2014 Sampling temperature',
                  'gen_ai.usage.input_tokens \u2014 Prompt tokens',
                  'gen_ai.usage.output_tokens \u2014 Completion tokens',
                  'gen_ai.response.finish_reason \u2014 Stop reason',
                ],
              ),
            ],
          ),
        ),

        // Dual Export Pattern Section
        DocSection(
          icon: LucideIcons.gitFork,
          title: 'Dual Export Pattern',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Telemetry exports through two channels simultaneously for reliability and offline analysis:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Export Channel', 'Destination', 'Purpose'],
                rows: [
                  [
                    'Local File',
                    '~/.claude/telemetry/',
                    'Offline analysis & backup'
                  ],
                  [
                    'Remote OTLP',
                    'SigNoz Cloud',
                    'Real-time dashboards & alerts'
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                code: '''# Data flow architecture
Claude Code Hooks → HookMonitor → Dual Export Pattern
                                   ├─ Local File Export (JSONL)
                                   └─ Remote OTLP (SigNoz Cloud)''',
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'Resilient by Design',
                message:
                    'Circuit breaker protection prevents slowdowns during backend outages. Local JSONL files ensure no data loss.',
              ),
            ],
          ),
        ),

        // Hook Architecture Section
        DocSection(
          icon: LucideIcons.webhook,
          title: 'Hook-Based Architecture',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The system instruments 12 hook types across event categories, providing fine-grained observability into Claude Code operations.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'HookContext Interface',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''// Available methods on HookContext
context.addAttribute(key, value)     // Add span attribute
context.addAttributes(attrs)         // Add multiple attributes
context.recordMetric(name, value, attrs)  // Record metric
context.startChildSpan(name, attrs)  // Create child span
context.logger.{trace,debug,info,warn,error}  // Structured logging''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Hook Event Types',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(
                bulletColor: AppColors.purple400,
                items: [
                  'Session lifecycle \u2014 start, stop, pause, resume',
                  'Tool execution \u2014 pre/post tool calls',
                  'Model interaction \u2014 request/response',
                  'Error handling \u2014 exceptions and retries',
                  'User prompts \u2014 input processing',
                  'Notification \u2014 stop signals and alerts',
                ],
              ),
            ],
          ),
        ),

        // Backend Compatibility Section
        DocSection(
          icon: LucideIcons.database,
          title: 'Backend Compatibility',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SigNoz Cloud provides the primary observability backend with enterprise-grade features:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Feature', 'Description'],
                rows: [
                  ['Pre-built Dashboards', '8 dashboards for visualization'],
                  ['Trace Correlation', 'Real-time search and linking'],
                  ['Gzip Compression', 'Reduced bandwidth for OTLP'],
                  [
                    'Circuit Breaker',
                    'Protection during outages'
                  ],
                  [
                    'Resource Detection',
                    'Auto-capture host/OS/process metadata'
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Alternative Backends',
                message:
                    'Any OpenTelemetry-compatible backend works: Jaeger, Grafana Tempo, Honeycomb, Datadog, or self-hosted collectors.',
              ),
            ],
          ),
        ),

        // Environment Configuration Section
        DocSection(
          icon: LucideIcons.settings,
          title: 'Environment Configuration',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Environment variables manage configuration across layers:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                code: '''# Required environment variables
OTEL_EXPORTER_OTLP_ENDPOINT="https://ingest.us.signoz.cloud"
SIGNOZ_INGESTION_KEY="<your-ingestion-key>"

# Optional: LLM-specific instrumentation
LANGTRACE_API_KEY="<your-langtrace-key>"

# Optional: Service identification
OTEL_SERVICE_NAME="claude-code-session"
OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production"''',
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.warning(
                title: 'Security Note',
                message:
                    'Store credentials in environment variables or a secrets manager. Never commit API keys to version control.',
              ),
            ],
          ),
        ),

        // PII Protection Section
        DocSection(
          icon: LucideIcons.shield,
          title: 'PII Redaction Bridge',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Langtrace automatically redacts 10 sensitive data patterns before export, ensuring compliance across multiple retention systems:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Pattern', 'Replacement'],
                rows: [
                  ['Email addresses', '[EMAIL]'],
                  ['Phone numbers', '[PHONE]'],
                  ['Credit card numbers', '[CREDIT_CARD]'],
                  ['Social Security numbers', '[SSN]'],
                  ['API keys (sk-*, key-*)', '[API_KEY]'],
                  ['JWT tokens', '[JWT_TOKEN]'],
                  ['IP addresses', '[IP_ADDRESS]'],
                  ['AWS credentials', '[AWS_KEY]'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'GDPR & CCPA Ready',
                message:
                    'Automatic PII redaction helps maintain compliance with privacy regulations while preserving observability value.',
              ),
            ],
          ),
        ),

        // Quick Start Section
        DocSection(
          icon: LucideIcons.rocket,
          title: 'Quick Start',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get started with the observability framework in three steps:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocNumberedList(
                accentColor: AppColors.purple500,
                items: [
                  'Set environment variables for your backend',
                  'Initialize the telemetry SDK at application startup',
                  'View traces and metrics in your dashboard',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                code: '''// Initialize at application startup
import { initTelemetry, withSpan, shutdown } from './lib/otel';

initTelemetry();

// Wrap operations in spans
await withSpan('my.operation', {
  'custom.attribute': 'value'
}, async (span) => {
  // Your code here
  span.addEvent('checkpoint', { detail: 'processed' });
});

// Clean shutdown
await shutdown();''',
              ),
            ],
          ),
        ),

        // Related Docs Section
        DocSection(
          icon: LucideIcons.bookOpen,
          title: 'Related Documentation',
          accentColor: AppColors.purple500,
          child: const DocBulletList(
            bulletColor: AppColors.purple400,
            items: [
              'Distributed Tracing Guide \u2014 /docs/tracing',
              'LLM Observability \u2014 /docs/llm-observability',
              'OpenTelemetry Documentation \u2014 opentelemetry.io',
              'SigNoz Documentation \u2014 signoz.io/docs',
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        DocFeatureCard(
          icon: LucideIcons.layers,
          title: 'OpenTelemetry Foundation',
          description: 'Industry-standard instrumentation and export.',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.bot,
          title: 'Langtrace LLM Support',
          description: 'Automatic GenAI semantic conventions.',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.barChart3,
          title: 'SigNoz Backend',
          description: 'Real-time dashboards and alerting.',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.hardDrive,
          title: 'Local JSONL Backup',
          description: 'Offline analysis and data resilience.',
          accentColor: AppColors.purple500,
        ),
      ],
    );
  }
}
