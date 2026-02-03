import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// API Reference documentation page.
///
/// Covers the Trace Ingestion API, Query API, Alerts API,
/// authentication, and SDK usage examples.
class DocsApiPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsApiPage({
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
          DocPageAppBar(title: 'API Reference', onBack: onBack),

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
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.code2,
                    size: 16,
                    color: Color(0xFF22D3EE),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'REST & OTLP APIs',
                    style: AppTypography.bodySM.copyWith(
                      color: const Color(0xFF22D3EE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'API Reference',
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
                'Complete API documentation for trace ingestion, querying, alerts, and SDK integration. OpenTelemetry-native with REST fallback.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // API Stats
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: const [
                _StatCard(value: 'OTLP', label: 'Native Protocol'),
                _StatCard(value: 'REST', label: 'Fallback API'),
                _StatCard(value: '3', label: 'SDK Languages'),
                _StatCard(value: '<100ms', label: 'Avg Latency'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 160),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.headingMD.copyWith(
              color: const Color(0xFF22D3EE),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray400,
            ),
            textAlign: TextAlign.center,
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
        // Authentication Section
        _DocSection(
          icon: LucideIcons.key,
          title: 'Authentication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All API requests require authentication via API key. Include your key in the request headers.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Header Authentication',
                code: '''# Include in all requests
Authorization: Bearer <your-api-key>

# Or use the X-API-Key header
X-API-Key: <your-api-key>''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'API Key Scopes',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SimpleTable(
                headers: ['Scope', 'Permissions'],
                rows: [
                  ['traces:write', 'Ingest traces and spans'],
                  ['traces:read', 'Query traces and analytics'],
                  ['alerts:manage', 'Create, update, delete alerts'],
                  ['admin', 'Full access to all endpoints'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _WarningCallout(
                message:
                    'Never expose API keys in client-side code. Use environment variables or a secrets manager.',
              ),
            ],
          ),
        ),

        // Base URL Section
        _DocSection(
          icon: LucideIcons.globe,
          title: 'Base URLs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SimpleTable(
                headers: ['Environment', 'Base URL'],
                rows: [
                  ['Production', 'https://api.integritystudio.ai/v1'],
                  ['OTLP Endpoint', 'https://ingest.integritystudio.ai'],
                  ['Sandbox', 'https://sandbox-api.integritystudio.ai/v1'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _InfoCallout(
                title: 'Rate Limits',
                message:
                    'Free tier: 100 req/min. Team: 1,000 req/min. Enterprise: Custom limits.',
              ),
            ],
          ),
        ),

        // Trace Ingestion Section
        _DocSection(
          icon: LucideIcons.upload,
          title: 'Trace Ingestion API',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send traces using OpenTelemetry Protocol (OTLP) or the REST API. OTLP is recommended for production workloads.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'OTLP Ingestion (Recommended)',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Environment Configuration',
                code: '''# Configure OTLP exporter
export OTEL_EXPORTER_OTLP_ENDPOINT="https://ingest.integritystudio.ai"
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Bearer <your-api-key>"
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'REST API Ingestion',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _EndpointCard(
                method: 'POST',
                path: '/v1/traces',
                description: 'Ingest a batch of spans',
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Request Body',
                code: '''{
  "resourceSpans": [{
    "resource": {
      "attributes": [
        { "key": "service.name", "value": { "stringValue": "my-service" } }
      ]
    },
    "scopeSpans": [{
      "spans": [{
        "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
        "spanId": "051581bf3cb55c13",
        "name": "ai.inference",
        "kind": 1,
        "startTimeUnixNano": "1704067200000000000",
        "endTimeUnixNano": "1704067201000000000",
        "attributes": [
          { "key": "gen_ai.system", "value": { "stringValue": "anthropic" } },
          { "key": "gen_ai.request.model", "value": { "stringValue": "claude-3-opus" } },
          { "key": "gen_ai.usage.input_tokens", "value": { "intValue": "1250" } },
          { "key": "gen_ai.usage.output_tokens", "value": { "intValue": "380" } }
        ]
      }]
    }]
  }]
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Response Code', 'Description'],
                rows: [
                  ['200 OK', 'Traces accepted successfully'],
                  ['400 Bad Request', 'Invalid payload format'],
                  ['401 Unauthorized', 'Invalid or missing API key'],
                  ['429 Too Many Requests', 'Rate limit exceeded'],
                ],
              ),
            ],
          ),
        ),

        // Query API Section
        _DocSection(
          icon: LucideIcons.search,
          title: 'Query API',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Query traces, spans, and aggregated metrics with flexible filtering and pagination.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _EndpointCard(
                method: 'GET',
                path: '/v1/traces',
                description: 'List traces with filtering',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Query Parameters',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SimpleTable(
                headers: ['Parameter', 'Type', 'Description'],
                rows: [
                  ['start', 'ISO 8601', 'Start time (required)'],
                  ['end', 'ISO 8601', 'End time (required)'],
                  ['service', 'string', 'Filter by service name'],
                  ['operation', 'string', 'Filter by operation name'],
                  ['minDuration', 'int', 'Minimum duration in ms'],
                  ['limit', 'int', 'Max results (default: 100)'],
                  ['offset', 'int', 'Pagination offset'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Example Request',
                code: '''curl -X GET "https://api.integritystudio.ai/v1/traces?\\
  start=2024-01-01T00:00:00Z&\\
  end=2024-01-02T00:00:00Z&\\
  service=ai-inference&\\
  minDuration=1000&\\
  limit=50" \\
  -H "Authorization: Bearer <your-api-key>"''',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _EndpointCard(
                method: 'GET',
                path: '/v1/traces/{traceId}',
                description: 'Get a specific trace with all spans',
              ),
              const SizedBox(height: AppSpacing.lg),
              const _EndpointCard(
                method: 'GET',
                path: '/v1/metrics/tokens',
                description: 'Get token usage aggregations',
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Token Metrics Response',
                code: '''{
  "data": {
    "totalInputTokens": 1250000,
    "totalOutputTokens": 380000,
    "totalCost": 45.50,
    "byModel": {
      "claude-3-opus": { "input": 500000, "output": 150000, "cost": 30.00 },
      "claude-3-sonnet": { "input": 750000, "output": 230000, "cost": 15.50 }
    },
    "byDay": [
      { "date": "2024-01-01", "input": 420000, "output": 130000, "cost": 15.20 }
    ]
  }
}''',
              ),
            ],
          ),
        ),

        // Alerts API Section
        _DocSection(
          icon: LucideIcons.bell,
          title: 'Alerts API',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure alerts for anomalies, budget thresholds, and performance degradation.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _EndpointCard(
                method: 'POST',
                path: '/v1/alerts',
                description: 'Create a new alert rule',
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Create Alert Request',
                code: '''{
  "name": "High Token Usage Alert",
  "description": "Alert when daily token usage exceeds threshold",
  "condition": {
    "metric": "gen_ai.client.token.usage",
    "operator": "gt",
    "threshold": 100000,
    "window": "1h"
  },
  "channels": [
    { "type": "slack", "webhook": "https://hooks.slack.com/..." },
    { "type": "email", "address": "alerts@company.com" }
  ],
  "severity": "warning"
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Alert Conditions',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SimpleTable(
                headers: ['Operator', 'Description'],
                rows: [
                  ['gt', 'Greater than threshold'],
                  ['lt', 'Less than threshold'],
                  ['eq', 'Equals threshold'],
                  ['anomaly', 'Statistical anomaly detection'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _EndpointCard(
                method: 'GET',
                path: '/v1/alerts',
                description: 'List all alert rules',
              ),
              const SizedBox(height: AppSpacing.md),
              const _EndpointCard(
                method: 'PUT',
                path: '/v1/alerts/{alertId}',
                description: 'Update an alert rule',
              ),
              const SizedBox(height: AppSpacing.md),
              const _EndpointCard(
                method: 'DELETE',
                path: '/v1/alerts/{alertId}',
                description: 'Delete an alert rule',
              ),
            ],
          ),
        ),

        // SDK Section
        _DocSection(
          icon: LucideIcons.package,
          title: 'SDKs & Libraries',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official SDKs provide auto-instrumentation and simplified API access.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Python SDK',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Installation & Usage',
                code: '''# Install
pip install integrity-studio

# Usage
from integrity_studio import IntegrityStudio

client = IntegrityStudio(api_key="your-api-key")

# Auto-instrument LLM calls
with client.trace("ai.inference") as span:
    response = anthropic.messages.create(...)
    span.set_attribute("gen_ai.usage.input_tokens", response.usage.input_tokens)''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'TypeScript SDK',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Installation & Usage',
                code: '''// Install
npm install @integrity-studio/sdk

// Usage
import { IntegrityStudio } from '@integrity-studio/sdk';

const client = new IntegrityStudio({ apiKey: 'your-api-key' });

// Auto-instrument with wrapper
const response = await client.trace('ai.inference', async (span) => {
  const result = await anthropic.messages.create({...});
  span.setAttribute('gen_ai.usage.input_tokens', result.usage.input_tokens);
  return result;
});''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Go SDK',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _CodeBlock(
                title: 'Installation & Usage',
                code: '''// Install
go get github.com/integritystudio/sdk-go

// Usage
import "github.com/integritystudio/sdk-go"

client := integritystudio.NewClient("your-api-key")

ctx, span := client.StartSpan(ctx, "ai.inference")
defer span.End()

// Your LLM call
span.SetAttribute("gen_ai.request.model", "claude-3-opus")''',
              ),
            ],
          ),
        ),

        // Error Handling Section
        _DocSection(
          icon: LucideIcons.alertCircle,
          title: 'Error Handling',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All errors follow a consistent format with actionable error codes.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Error Response Format',
                code: '''{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit of 100 requests per minute exceeded",
    "details": {
      "limit": 100,
      "window": "1m",
      "retryAfter": 45
    }
  }
}''',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Common Error Codes',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const _SimpleTable(
                headers: ['Code', 'HTTP Status', 'Description'],
                rows: [
                  ['INVALID_API_KEY', '401', 'API key is invalid or expired'],
                  ['INSUFFICIENT_SCOPE', '403', 'API key lacks required scope'],
                  ['RATE_LIMIT_EXCEEDED', '429', 'Too many requests'],
                  ['INVALID_PAYLOAD', '400', 'Request body validation failed'],
                  ['TRACE_NOT_FOUND', '404', 'Requested trace does not exist'],
                  ['INTERNAL_ERROR', '500', 'Unexpected server error'],
                ],
              ),
            ],
          ),
        ),

        // Related Docs Section
        _DocSection(
          icon: LucideIcons.bookOpen,
          title: 'Related Documentation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BulletList(items: const [
                'Getting Started Guide \u2014 /docs/quickstart',
                'Integrations \u2014 /docs/integrations',
                'Distributed Tracing \u2014 /docs/tracing',
                'OpenTelemetry Semantic Conventions \u2014 opentelemetry.io',
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
                  color: const Color(0xFF06B6D4),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headingSM.copyWith(
                    color: const Color(0xFF22D3EE),
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

class _EndpointCard extends StatelessWidget {
  final String method;
  final String path;
  final String description;

  const _EndpointCard({
    required this.method,
    required this.path,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final methodColor = switch (method) {
      'GET' => AppColors.success,
      'POST' => AppColors.blue500,
      'PUT' => AppColors.warning,
      'DELETE' => AppColors.error,
      _ => AppColors.gray400,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: methodColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Text(
              method,
              style: AppTypography.bodySM.copyWith(
                color: methodColor,
                fontWeight: FontWeight.w700,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path,
                  style: AppTypography.bodyMD.copyWith(
                    color: Colors.white,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  final String? title;

  const _CodeBlock({required this.code, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray400,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
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
        ),
      ],
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
                        color: const Color(0xFF22D3EE),
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

class _InfoCallout extends StatelessWidget {
  final String title;
  final String message;

  const _InfoCallout({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
        border: const Border(
          left: BorderSide(color: Color(0xFF06B6D4), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.lightbulb, color: Color(0xFF22D3EE), size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: const Color(0xFF22D3EE),
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
  final String message;

  const _WarningCallout({required this.message});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMD.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
