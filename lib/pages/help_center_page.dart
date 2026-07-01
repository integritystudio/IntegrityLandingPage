import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';

/// Help Center page with troubleshooting guides and common solutions.
class HelpCenterPage extends StatelessWidget {
  final VoidCallback? onBack;

  const HelpCenterPage({
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
              'Help Center',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
          ),

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
                child: _HelpContent(isMobile: isMobile),
              ),
            ),
          ),

          // Contact Support CTA
          SliverToBoxAdapter(
            child: _ContactSupportSection(isMobile: isMobile),
          ),

          // Footer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              child: Center(
                child: Text(
                  '\u00A9 2026 Integrity Studio LLC',
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              ),
            ),
          ),
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
            // Icon
            Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
              child: const Icon(
                LucideIcons.helpCircle,
                size: 32,
                color: AppColors.blue400,
              ),
            ),

            // Headline
            Text(
              'Help Center',
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 28)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Find answers to common questions and troubleshooting guides for the Integrity Studio observability platform.',
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

class _HelpContent extends StatelessWidget {
  final bool isMobile;

  const _HelpContent({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Getting Started
        _HelpSection(
          icon: LucideIcons.rocket,
          title: 'Getting Started',
          items: const [
            _HelpItem(
              question: 'How do I install the observability toolkit?',
              answer:
                  'Install via Claude MCP:\n\nclaude mcp add observability-toolkit -- npx -y observability-toolkit\n\nOr for local development, point to your local build.',
            ),
            _HelpItem(
              question: 'What environment variables do I need to configure?',
              answer:
                  'Key variables:\n\n- TELEMETRY_DIR: Local telemetry directory (default: ~/.claude/telemetry)\n- SIGNOZ_URL: SigNoz instance URL (optional)\n- SIGNOZ_API_KEY: SigNoz API key (optional)\n- CACHE_TTL_MS: Query cache TTL in milliseconds (default: 60000)\n- RETENTION_DAYS: Days to retain telemetry files (default: 7)',
            ),
            _HelpItem(
              question: 'Where are telemetry files stored?',
              answer:
                  'Telemetry is stored in JSONL files:\n\n- Global: ~/.claude/telemetry/\n- Project-local: .claude/telemetry/, telemetry/, .telemetry/\n\nFile patterns: traces-YYYY-MM-DD.jsonl, logs-YYYY-MM-DD.jsonl, metrics-YYYY-MM-DD.jsonl',
            ),
          ],
        ),

        // Query Troubleshooting
        _HelpSection(
          icon: LucideIcons.search,
          title: 'Query Troubleshooting',
          items: const [
            _HelpItem(
              question: 'Why are my queries returning empty results?',
              answer:
                  'Check the following:\n\n1. Verify telemetry files exist in TELEMETRY_DIR\n2. Check the date range - files are named by date (traces-YYYY-MM-DD.jsonl)\n3. Ensure filters match your data (serviceName, spanName, etc.)\n4. Run obs_health_check to verify backend status',
            ),
            _HelpItem(
              question: 'How do I filter traces by duration?',
              answer:
                  'Use minDurationMs and maxDurationMs:\n\nobs_query_traces({ minDurationMs: 100, maxDurationMs: 5000 })\n\nThis returns traces between 100ms and 5 seconds.',
            ),
            _HelpItem(
              question: 'How do I use regex patterns for span names?',
              answer:
                  'Use the spanNameRegex parameter:\n\nobs_query_traces({ spanNameRegex: "^http\\..*" })\n\nThis matches all spans starting with "http."',
            ),
            _HelpItem(
              question: 'How do I search logs with multiple terms?',
              answer:
                  'Use searchTerms with searchOperator:\n\n// AND - all terms must match\nobs_query_logs({ searchTerms: ["error", "timeout"], searchOperator: "AND" })\n\n// OR - any term matches\nobs_query_logs({ searchTerms: ["error", "warning"], searchOperator: "OR" })',
            ),
          ],
        ),

        // Performance Issues
        _HelpSection(
          icon: LucideIcons.zap,
          title: 'Performance Issues',
          items: const [
            _HelpItem(
              question: 'Queries are running slowly. How can I improve performance?',
              answer:
                  'Performance tips:\n\n1. Use date filters (startDate, endDate) to limit file scans\n2. Enable query caching with CACHE_TTL_MS\n3. Use limit parameter to reduce result size\n4. Check cache stats with obs_health_check - high miss rate indicates cache TTL may be too short\n5. File indexing (.idx files) speeds up lookups',
            ),
            _HelpItem(
              question: 'How do I check cache performance?',
              answer:
                  'Run obs_health_check({ verbose: true }) to see cache statistics:\n\n{\n  "cache": {\n    "traces": { "hits": 10, "misses": 5, "hitRate": 0.67 },\n    "logs": { "hits": 8, "misses": 12, "hitRate": 0.4 }\n  }\n}\n\nA low hit rate suggests increasing CACHE_TTL_MS.',
            ),
            _HelpItem(
              question: 'Telemetry files are getting too large. What should I do?',
              answer:
                  'Options:\n\n1. Set RETENTION_DAYS to automatically clean old files\n2. Enable gzip compression (.jsonl.gz files are supported)\n3. Use more specific queries with filters to reduce scan time',
            ),
          ],
        ),

        // LLM Events & OTel
        _HelpSection(
          icon: LucideIcons.messageSquare,
          title: 'LLM Events & OpenTelemetry',
          items: const [
            _HelpItem(
              question: 'How do I query LLM events by operation type?',
              answer:
                  'Use the operationName filter:\n\nobs_query_llm_events({ operationName: "chat" })\nobs_query_llm_events({ operationName: "invoke_agent" })\nobs_query_llm_events({ operationName: "execute_tool" })\nobs_query_llm_events({ operationName: "embeddings" })',
            ),
            _HelpItem(
              question: 'How do I filter by provider or model?',
              answer:
                  'Use provider and model filters:\n\nobs_query_llm_events({ provider: "anthropic", model: "claude-3-opus" })\n\nThe provider follows OTel GenAI conventions with fallback: gen_ai.provider.name -> gen_ai.system -> provider',
            ),
            _HelpItem(
              question: 'How do I correlate events by conversation?',
              answer:
                  'Use conversationId to group related events:\n\nobs_query_llm_events({ conversationId: "conv-abc123" })\n\nThis returns all LLM calls within a single conversation session.',
            ),
            _HelpItem(
              question: 'How do I filter traces by agent or tool?',
              answer:
                  'Use OTel GenAI agent/tool filters:\n\nobs_query_traces({ agentName: "Explore" })\nobs_query_traces({ toolName: "Read", toolCallId: "toolu_123" })\nobs_query_traces({ operationName: "execute_tool" })',
            ),
          ],
        ),

        // SigNoz Integration
        _HelpSection(
          icon: LucideIcons.cloud,
          title: 'SigNoz Integration',
          items: const [
            _HelpItem(
              question: 'How do I connect to SigNoz Cloud?',
              answer:
                  'Set environment variables:\n\nexport SIGNOZ_URL=https://ingest.us.signoz.cloud\nexport SIGNOZ_API_KEY=your-api-key\n\nThe toolkit will automatically use SigNoz as a backend when configured.',
            ),
            _HelpItem(
              question: 'SigNoz queries are failing. What should I check?',
              answer:
                  'Troubleshooting steps:\n\n1. Verify SIGNOZ_URL and SIGNOZ_API_KEY are set correctly\n2. Check obs_health_check for backend status\n3. The circuit breaker may be open if SigNoz was unavailable - it will auto-recover\n4. Verify API key has correct permissions',
            ),
            _HelpItem(
              question: 'How do I get a trace URL for SigNoz?',
              answer:
                  'Use obs_get_trace_url:\n\nobs_get_trace_url({ traceId: "abc123..." })\n\nThis returns a direct link to view the trace in SigNoz.',
            ),
          ],
        ),

        // Metrics & Aggregations
        _HelpSection(
          icon: LucideIcons.barChart3,
          title: 'Metrics & Aggregations',
          items: const [
            _HelpItem(
              question: 'What aggregation types are supported?',
              answer:
                  'Supported aggregations:\n\n- sum: Total value\n- avg: Average value\n- min/max: Minimum/maximum values\n- count: Number of data points\n- p50, p95, p99: Percentiles\n- rate: Per-second rate of change',
            ),
            _HelpItem(
              question: 'How do I group metrics by time buckets?',
              answer:
                  'Use the timeBucket parameter:\n\nobs_query_metrics({\n  metricName: "token.usage",\n  aggregation: "sum",\n  timeBucket: "1h",\n  groupBy: ["model"]\n})\n\nSupported buckets: 1m, 5m, 1h, 1d',
            ),
            _HelpItem(
              question: 'How do I calculate percentiles?',
              answer:
                  'Use p50, p95, or p99 aggregation:\n\nobs_query_metrics({ metricName: "latency", aggregation: "p95" })\n\nThis returns the 95th percentile latency.',
            ),
          ],
        ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_HelpItem> items;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
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
              Text(
                title,
                style: AppTypography.headingSM.copyWith(
                  color: AppColors.blue400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Items
          ...items.map((item) => _HelpItemCard(item: item)),
        ],
      ),
    );
  }
}

class _HelpItem {
  final String question;
  final String answer;

  const _HelpItem({
    required this.question,
    required this.answer,
  });
}

class _HelpItemCard extends StatefulWidget {
  final _HelpItem item;

  const _HelpItemCard({required this.item});

  @override
  State<_HelpItemCard> createState() => _HelpItemCardState();
}

class _HelpItemCardState extends State<_HelpItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: AppTypography.bodyMD.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: AppColors.gray400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Answer (expandable)
          if (_isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.gray900,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: SelectableText(
                  widget.item.answer,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    color: AppColors.gray300,
                    height: 1.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactSupportSection extends StatelessWidget {
  final bool isMobile;

  const _ContactSupportSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        vertical: AppSpacing.xl,
      ),
      padding: EdgeInsets.all(isMobile ? AppSpacing.xl : AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue500.withValues(alpha: 0.15),
            AppColors.blue600.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: AppColors.blue500.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            LucideIcons.messageCircle,
            size: 48,
            color: AppColors.blue400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Still having issues?',
            style: AppTypography.headingMD.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Our support team is here to help you get the most out of Integrity Studio.',
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () {
              if (!context.mounted) return;
              context.go('/contact');
            },
            icon: const Icon(LucideIcons.mail, size: 18),
            label: const Text('Contact Support'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
