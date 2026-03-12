import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/sections/page_hero_section.dart';

/// MCP Toolkit API Reference page.
///
/// Documents the observability-toolkit MCP server tools, query options,
/// OTel GenAI semantic conventions, and data types.
class ApiToolkitPage extends StatelessWidget {
  final VoidCallback? onBack;

  const ApiToolkitPage({
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
              'MCP Toolkit API',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: onBack ?? () => context.go('/'),
                  child: Text(
                    'Back to Docs',
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
              accentColor: const Color(0xFFA78BFA),
              badgeIcon: LucideIcons.terminal,
              badgeText: 'MCP Server Tools',
              headline: 'Observability Toolkit API',
              subheadline:
                  'Query traces, metrics, logs, and LLM events from local JSONL files or SigNoz Cloud. Full OTel GenAI semantic convention compliance.',
              extraContent: const Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: [
                  DocStatCard(value: '8', label: 'MCP Tools', accentColor: Color(0xFFA78BFA)),
                  DocStatCard(value: '10/10', label: 'OTel GenAI', accentColor: Color(0xFFA78BFA)),
                  DocStatCard(value: 'v1.8.0', label: 'Version', accentColor: Color(0xFFA78BFA)),
                  DocStatCard(value: '939+', label: 'Tests', accentColor: Color(0xFFA78BFA)),
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
                      'Built with OpenTelemetry GenAI Semantic Conventions',
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
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.info,
          title: 'Overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The observability-toolkit is an MCP (Model Context Protocol) server that provides observability tooling for LLM applications. Query traces, metrics, logs, and LLM events from local JSONL files or integrate with SigNoz Cloud.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Architecture',
                code: '''src/
\u251C\u2500\u2500 server.ts              # MCP server entry point
\u251C\u2500\u2500 backends/
\u2502   \u251C\u2500\u2500 local-jsonl.ts     # JSONL file backend
\u2502   \u251C\u2500\u2500 signoz-api.ts      # SigNoz Cloud backend
\u2502   \u2514\u2500\u2500 multi-directory.ts # Multi-directory aggregation
\u251C\u2500\u2500 tools/
\u2502   \u251C\u2500\u2500 query-traces.ts    # obs_query_traces
\u2502   \u251C\u2500\u2500 query-metrics.ts   # obs_query_metrics
\u2502   \u251C\u2500\u2500 query-logs.ts      # obs_query_logs
\u2502   \u251C\u2500\u2500 query-llm-events.ts # obs_query_llm_events
\u2502   \u251C\u2500\u2500 query-evaluations.ts # obs_query_evaluations
\u2502   \u251C\u2500\u2500 health-check.ts    # obs_health_check
\u2502   \u251C\u2500\u2500 context-stats.ts   # obs_context_stats
\u2502   \u2514\u2500\u2500 get-trace-url.ts   # obs_get_trace_url
\u2514\u2500\u2500 lib/
    \u251C\u2500\u2500 file-utils.ts      # JSONL streaming, gzip, pagination
    \u251C\u2500\u2500 indexer.ts         # File indexing for fast lookups
    \u2514\u2500\u2500 constants.ts       # OTel constants, status codes''',
              ),
            ],
          ),
        ),

        // MCP Tools Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.wrench,
          title: 'MCP Tools',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Eight tools are available for querying observability data.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Tool', 'Description'],
                rows: [
                  ['obs_query_traces', 'Query distributed traces with filtering'],
                  ['obs_query_metrics', 'Query metrics with aggregations'],
                  ['obs_query_logs', 'Search logs with boolean operators'],
                  ['obs_query_llm_events', 'Query LLM-specific events'],
                  ['obs_query_evaluations', 'Query evaluation results'],
                  ['obs_health_check', 'System health and cache stats'],
                  ['obs_context_stats', 'Context window utilization'],
                  ['obs_get_trace_url', 'Generate SigNoz trace viewer links'],
                ],
              ),
            ],
          ),
        ),

        // Query Traces Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.gitBranch,
          title: 'obs_query_traces',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Query distributed traces with support for filtering by service, span name, duration, attributes, and agent/tool metadata.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Query Options',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['traceId', 'string', 'Filter by specific trace ID'],
                  ['serviceName', 'string', 'Filter by service name'],
                  ['spanName', 'string', 'Filter by span name'],
                  ['minDurationMs', 'number', 'Minimum duration in milliseconds'],
                  ['maxDurationMs', 'number', 'Maximum duration in milliseconds'],
                  ['spanNameRegex', 'string', 'Regex pattern for span name'],
                  ['attributeFilter', 'object', 'Key-value attribute filters'],
                  ['numericFilter', 'array', 'Numeric comparisons (gt, gte, lt, lte, eq)'],
                  ['agentId', 'string', 'Filter by agent ID'],
                  ['agentName', 'string', 'Filter by agent name'],
                  ['toolName', 'string', 'Filter by tool name'],
                  ['toolCallId', 'string', 'Filter by tool call ID'],
                  ['operationName', 'string', 'Filter by gen_ai.operation.name'],
                  ['startDate', 'string', 'Start date (YYYY-MM-DD)'],
                  ['endDate', 'string', 'End date (YYYY-MM-DD)'],
                  ['limit', 'number', 'Max results (default: 100)'],
                  ['offset', 'number', 'Pagination offset'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Example Query',
                code: '''{
  "serviceName": "ai-inference",
  "operationName": "chat",
  "minDurationMs": 1000,
  "attributeFilter": {
    "gen_ai.request.model": "claude-3-opus"
  },
  "startDate": "2026-01-01",
  "endDate": "2026-01-29",
  "limit": 50
}''',
              ),
            ],
          ),
        ),

        // Query LLM Events Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.messageSquare,
          title: 'obs_query_llm_events',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Query LLM-specific events with full OTel GenAI semantic convention support (10/10 compliance).',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Query Options',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['operationName', 'string', 'chat, embeddings, invoke_agent, execute_tool'],
                  ['provider', 'string', 'Provider name (anthropic, openai, etc.)'],
                  ['model', 'string', 'Model name filter'],
                  ['conversationId', 'string', 'Filter by conversation/session ID'],
                  ['agentId', 'string', 'Filter by agent ID'],
                  ['agentName', 'string', 'Filter by agent name'],
                  ['toolName', 'string', 'Filter by tool name'],
                  ['startDate', 'string', 'Start date (YYYY-MM-DD)'],
                  ['endDate', 'string', 'End date (YYYY-MM-DD)'],
                  ['limit', 'number', 'Max results (default: 50)'],
                  ['offset', 'number', 'Pagination offset'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Response Fields',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                title: 'LLMEventResponse',
                code: '''{
  "timestamp": "2026-01-29T10:30:00Z",
  "operationName": "chat",
  "provider": "anthropic",
  "model": "claude-3-opus",
  "responseModel": "claude-3-opus-20240229",
  "finishReasons": ["end_turn"],
  "temperature": 0.7,
  "maxTokens": 4096,
  "inputTokens": 1250,
  "outputTokens": 380,
  "durationMs": 2340,
  "conversationId": "conv_abc123",
  "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
  "spanId": "051581bf3cb55c13"
}''',
              ),
            ],
          ),
        ),

        // Query Metrics Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.barChart3,
          title: 'obs_query_metrics',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Query metrics with aggregation support including sum, avg, min, max, count, p50, p95, p99, and rate.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['metricName', 'string', 'Filter by metric name'],
                  ['aggregation', 'string', 'sum, avg, min, max, count, p50, p95, p99, rate'],
                  ['groupBy', 'array', 'Group by attribute keys'],
                  ['timeBucket', 'string', 'Time bucket (1m, 5m, 1h, 1d)'],
                  ['startDate', 'string', 'Start date (YYYY-MM-DD)'],
                  ['endDate', 'string', 'End date (YYYY-MM-DD)'],
                  ['limit', 'number', 'Max results'],
                  ['offset', 'number', 'Pagination offset'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Example: Token Usage by Model',
                code: '''{
  "metricName": "gen_ai.client.token.usage",
  "aggregation": "sum",
  "groupBy": ["gen_ai.request.model"],
  "timeBucket": "1d",
  "startDate": "2026-01-01",
  "endDate": "2026-01-29"
}''',
              ),
            ],
          ),
        ),

        // Query Logs Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.fileText,
          title: 'obs_query_logs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search logs with boolean operators, severity filtering, and field extraction.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['severity', 'string', 'ERROR, WARN, INFO, DEBUG'],
                  ['search', 'string', 'Text search in body'],
                  ['searchTerms', 'array', 'Multiple search terms'],
                  ['searchOperator', 'string', 'AND or OR (default: AND)'],
                  ['traceId', 'string', 'Filter by trace ID'],
                  ['excludeSearch', 'string', 'Exclude logs containing text'],
                  ['extractFields', 'array', 'JSON paths to extract'],
                  ['startDate', 'string', 'Start date (YYYY-MM-DD)'],
                  ['endDate', 'string', 'End date (YYYY-MM-DD)'],
                  ['limit', 'number', 'Max results'],
                ],
              ),
            ],
          ),
        ),

        // Query Evaluations Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.checkCircle2,
          title: 'obs_query_evaluations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Query LLM evaluation results (gen_ai.evaluation.result events) for quality assessment.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['evaluationName', 'string', 'Filter by metric (Relevance, Faithfulness)'],
                  ['scoreMin', 'number', 'Minimum score threshold'],
                  ['scoreMax', 'number', 'Maximum score threshold'],
                  ['scoreLabel', 'string', 'Filter by label (pass, fail, relevant)'],
                  ['responseId', 'string', 'Correlate to specific response'],
                  ['traceId', 'string', 'All evaluations for a trace'],
                  ['sessionId', 'string', 'Session-scoped evaluations'],
                  ['startDate', 'string', 'Start date (YYYY-MM-DD)'],
                  ['endDate', 'string', 'End date (YYYY-MM-DD)'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Evaluation Result',
                code: '''{
  "timestamp": "2026-01-29T10:30:00Z",
  "evaluationName": "Relevance",
  "scoreValue": 0.92,
  "scoreLabel": "relevant",
  "explanation": "Response directly addresses the query",
  "responseId": "resp_abc123",
  "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
  "spanId": "051581bf3cb55c13"
}''',
              ),
            ],
          ),
        ),

        // OTel GenAI Compliance Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.shield,
          title: 'OTel GenAI Semantic Conventions',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full compliance with OpenTelemetry GenAI semantic conventions (10/10 attributes).',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Core Attributes',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Attribute', 'Requirement', 'Description'],
                rows: [
                  ['gen_ai.operation.name', 'Required', 'chat, embeddings, invoke_agent, execute_tool'],
                  ['gen_ai.provider.name', 'Required', 'Provider (anthropic, openai, aws.bedrock)'],
                  ['gen_ai.request.model', 'Cond. Required', 'Requested model name'],
                  ['gen_ai.conversation.id', 'Cond. Required', 'Conversation/session ID'],
                  ['gen_ai.response.model', 'Recommended', 'Actual model that responded'],
                  ['gen_ai.response.finish_reasons', 'Recommended', 'Why generation stopped'],
                  ['gen_ai.request.temperature', 'Recommended', 'Sampling temperature'],
                  ['gen_ai.request.max_tokens', 'Recommended', 'Maximum output tokens'],
                  ['gen_ai.usage.input_tokens', 'Recommended', 'Prompt token count'],
                  ['gen_ai.usage.output_tokens', 'Recommended', 'Completion token count'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Agent/Tool Attributes',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Attribute', 'Type', 'Description'],
                rows: [
                  ['gen_ai.agent.id', 'string', 'Unique agent identifier'],
                  ['gen_ai.agent.name', 'string', 'Human-readable agent name'],
                  ['gen_ai.tool.name', 'string', 'Tool identifier'],
                  ['gen_ai.tool.type', 'string', 'function, extension, datastore'],
                  ['gen_ai.tool.call.id', 'string', 'Unique tool call identifier'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Provider Identifiers',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Provider', 'Value'],
                rows: [
                  ['Anthropic', 'anthropic'],
                  ['OpenAI', 'openai'],
                  ['AWS Bedrock', 'aws.bedrock'],
                  ['Azure OpenAI', 'azure.ai.openai'],
                  ['Google Gemini', 'gcp.gemini'],
                  ['Google Vertex AI', 'gcp.vertex_ai'],
                  ['Cohere', 'cohere'],
                  ['Mistral AI', 'mistral_ai'],
                ],
              ),
            ],
          ),
        ),

        // Data Types Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.database,
          title: 'Data Types',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TraceSpan',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                title: 'TraceSpan Interface',
                code: '''{
  traceId: string;
  spanId: string;
  parentSpanId?: string;
  name: string;
  kind?: string;
  startTimeUnixNano: number;
  endTimeUnixNano?: number;
  durationMs?: number;
  status?: { code: number; message?: string };
  statusCode?: 'UNSET' | 'OK' | 'ERROR';
  attributes?: Record<string, unknown>;
  events?: Array<{ name: string; timestamp: number; attributes?: Record<string, unknown> }>;
  links?: SpanLink[];
  instrumentationScope?: InstrumentationScope;
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'LogRecord',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                title: 'LogRecord Interface',
                code: '''{
  timestamp: string;
  severity: string;
  severityNumber?: number;  // OTel: 1=TRACE, 5=DEBUG, 9=INFO, 13=WARN, 17=ERROR, 21=FATAL
  body: string;
  traceId?: string;
  spanId?: string;
  attributes?: Record<string, unknown>;
  extractedFields?: Record<string, unknown>;
  instrumentationScope?: InstrumentationScope;
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'MetricDataPoint',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                title: 'MetricDataPoint Interface',
                code: '''{
  timestamp: string;
  name: string;
  value: number;
  unit?: string;
  attributes?: Record<string, unknown>;
  histogram?: HistogramData;
  exemplars?: Exemplar[];
  aggregationTemporality?: 'UNSPECIFIED' | 'DELTA' | 'CUMULATIVE';
}''',
              ),
            ],
          ),
        ),

        // Environment Variables Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.settings,
          title: 'Environment Variables',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocTable(
                headers: ['Variable', 'Default', 'Description'],
                rows: [
                  ['TELEMETRY_DIR', '~/.claude/telemetry', 'Local telemetry directory'],
                  ['SIGNOZ_URL', '-', 'SigNoz instance URL'],
                  ['SIGNOZ_API_KEY', '-', 'SigNoz API key'],
                  ['SIGNOZ_QUERY_URL', '-', 'SigNoz Query API URL'],
                  ['CACHE_TTL_MS', '60000', 'Query cache TTL in milliseconds'],
                  ['RETENTION_DAYS', '7', 'Days to retain telemetry files'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Example Configuration',
                code: '''# Local-only mode
export TELEMETRY_DIR=~/.claude/telemetry
export CACHE_TTL_MS=60000
export RETENTION_DAYS=7

# With SigNoz Cloud
export SIGNOZ_URL=https://ingest.us.signoz.cloud
export SIGNOZ_API_KEY=your-api-key
export SIGNOZ_QUERY_URL=https://us.signoz.cloud/api/v3''',
              ),
            ],
          ),
        ),

        // Health Check Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.heartPulse,
          title: 'obs_health_check',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Returns system health status including backend availability, file counts, and cache statistics.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
                title: 'Health Check Response',
                code: '''{
  "status": "healthy",
  "backends": {
    "local": { "available": true, "fileCount": 42 },
    "signoz": { "available": true, "latencyMs": 45 }
  },
  "cache": {
    "traces": { "hits": 10, "misses": 5, "hitRate": 0.67, "size": 15, "evictions": 0 },
    "logs": { "hits": 8, "misses": 12, "hitRate": 0.4, "size": 20, "evictions": 2 },
    "metrics": { "hits": 0, "misses": 0, "hitRate": 0, "size": 0, "evictions": 0 },
    "llmEvents": { "hits": 0, "misses": 0, "hitRate": 0, "size": 0, "evictions": 0 }
  },
  "version": "1.8.0"
}''',
              ),
            ],
          ),
        ),

        // Performance Features Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.zap,
          title: 'Performance Features',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocBulletList(bulletColor: AppColors.purple500, items: [
                'LRU Query Caching \u2014 Configurable TTL with hit/miss tracking',
                'File Indexing \u2014 .idx sidecar files for fast lookups without full scans',
                'Gzip Compression \u2014 Transparent handling of .gz telemetry files',
                'Streaming \u2014 Early termination for large JSONL files',
                'Cursor Pagination \u2014 Efficient pagination for SigNoz queries',
                'Circuit Breaker \u2014 Automatic failover when SigNoz is unavailable',
                'OTLP Export \u2014 Export traces, logs, metrics in standard format',
              ]),
            ],
          ),
        ),

        // Related Docs Section
        DocSection(accentColor: const Color(0xFF8B5CF6), 
          icon: LucideIcons.bookOpen,
          title: 'Related Documentation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocBulletList(bulletColor: AppColors.purple500, items: [
                'Platform API Reference \u2014 /api',
                'LLM Observability Guide \u2014 /docs/llm-observability',
                'Distributed Tracing \u2014 /docs/tracing',
                'Quickstart Guide \u2014 /docs/quickstart',
                'OpenTelemetry GenAI Conventions \u2014 opentelemetry.io',
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

