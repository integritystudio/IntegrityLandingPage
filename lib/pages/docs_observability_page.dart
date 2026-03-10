import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/docs/doc_components.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// Claude Code Observability Guide documentation page.
///
/// Covers context management, token optimization, and observability
/// using OpenTelemetry and SigNoz.
class DocsObservabilityPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsObservabilityPage({
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
          DocPageAppBar(title: 'Observability Guide', onBack: onBack),

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
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.layers,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Production-Ready Framework',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'Claude Code Observability & Context Management',
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
                'Complete guide to token optimization, distributed tracing, and cost efficiency for Claude Code using OpenTelemetry and SigNoz.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Stats Grid
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: const [
                DocStatCard(value: '81%', label: 'Cost Reduction'),
                DocStatCard(value: '12', label: 'Instrumented Hooks'),
                DocStatCard(value: '8', label: 'Dashboards'),
                DocStatCard(value: '85%', label: 'MCP Token Savings'),
              ],
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
                'Context management is "effectively the #1 job" for engineers building AI agents. As Anthropic emphasizes: "Claude is already smart enough\u2014intelligence is not the bottleneck, context is."',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _FeatureGrid(),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'Key Results from Optimization',
                items: [
                  '81% reduction in cost per session',
                  '84% reduction in tokens per session',
                  '85% reduction in MCP tool overhead',
                  '3x more work completed with same daily spend',
                ],
              ),
            ],
          ),
        ),

        // Quick Start section
        DocSection(
          icon: LucideIcons.rocket,
          title: 'Quick Start',
          child: const DocCallout.info(
            title: 'Coming Soon',
            items: [
              'One-command setup via MCP toolkit',
              'Automatic configuration with API key',
            ],
          ),
        ),

        // Token Optimization Section
        DocSection(
          icon: LucideIcons.coins,
          title: 'Token Optimization Strategies',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claude 4 models have built-in token-efficient tool use that saves an average of 14% in output tokens (up to 70%) while reducing latency.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Results from Lazy Loading',
                items: [
                  'Initial context reduced from 7,584 to 3,434 tokens (54% reduction)',
                  'Monthly cost for 5 developers doing 100 sessions/day: \$72 (62% savings)',
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Hybrid Model Approach',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Model', 'Use For'],
                rows: [
                  ['Opus 4.5', 'High-level planning, architectural design, final code review'],
                  ['Sonnet/Haiku', 'Implementation work, syntax validation, data parsing, quick checks'],
                ],
              ),
            ],
          ),
        ),

        // Tool Usage Section
        DocSection(
          icon: LucideIcons.wrench,
          title: 'Efficient Tool Usage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocTable(
                headers: ['Scenario', 'Recommended Tool'],
                rows: [
                  ['Find files by name pattern', 'Glob'],
                  ['Search file contents', 'Grep'],
                  ['Read known file', 'Read (with offset/limit for large files)'],
                  ['Execute commands', 'Bash (with output truncation)'],
                  ['Open-ended exploration', 'Task/Subagent'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.warning(
                title: 'Memory Warning',
                message: 'Claude Code stores all bash output in memory for the entire session. Large outputs (90GB+ reported) can crash the application. Always truncate verbose commands.',
              ),
            ],
          ),
        ),

        // Context Window Section
        DocSection(
          icon: LucideIcons.layoutGrid,
          title: 'Context Window Management',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocTable(
                headers: ['Tier', 'Context Window', 'Notes'],
                rows: [
                  ['Standard', '200,000 tokens', 'Default for most users'],
                  ['Advanced (Tier 4+)', '1,000,000 tokens', 'Premium pricing applies'],
                  ['Premium threshold', '>200K tokens', '2x input, 1.5x output pricing'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.danger(
                title: 'Context Degradation',
                message: 'Avoid using the final 20% of your context window for complex tasks. Quality notably declines for memory-intensive operations.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Built-in Commands',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Command', 'Purpose'],
                rows: [
                  ['/context', 'Visualizes context usage'],
                  ['/clear', 'Wipes conversation history'],
                  ['/compact', 'Summarizes conversation'],
                  ['/cost', 'Shows token usage stats'],
                ],
              ),
            ],
          ),
        ),

        // MCP Optimization Section
        DocSection(
          icon: LucideIcons.plug,
          title: 'MCP Server Optimization',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MCP tool definitions can consume massive context:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.sm),
              const DocBulletList(items: [
                '5-server setup: ~55K tokens before conversation starts',
                'Jira alone: ~17K tokens',
                'One reported case: 134K tokens of tool definitions',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'MCP Tool Search reduces token overhead by 85% by loading tools on-demand rather than upfront.',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.success(
                title: 'Performance Improvements',
                items: [
                  'Opus 4: 49% to 74% accuracy',
                  'Opus 4.5: 79.5% to 88.1% accuracy',
                  '46.9% reduction in total agent tokens (51K to 8.5K)',
                ],
              ),
            ],
          ),
        ),

        // Metrics Reference Section
        DocSection(
          icon: LucideIcons.barChart3,
          title: 'Metrics Reference',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hook Metrics',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Metric', 'Type', 'Description'],
                rows: [
                  ['hook.duration', 'Histogram', 'Execution time distribution'],
                  ['hook.executions', 'Counter', 'Total invocations'],
                  ['mcp.invocations', 'Counter', 'MCP tool calls'],
                  ['agent.invocations', 'Counter', 'Subagent spawns'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'GenAI Metrics',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Metric', 'Type', 'Description'],
                rows: [
                  ['gen_ai.client.token.usage', 'Counter', 'Tokens consumed'],
                  ['gen_ai.client.cost', 'Counter', 'Cost in USD'],
                  ['gen_ai.client.operation.duration', 'Histogram', 'LLM call latency'],
                ],
              ),
            ],
          ),
        ),

        // Cost Optimization Section
        DocSection(
          icon: LucideIcons.trendingDown,
          title: 'Cost Optimization',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Strategy Comparison',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocTable(
                headers: ['Metric', 'Before', 'After', 'Change'],
                rows: [
                  ['Avg Sessions/Day', '7.3', '26.2', '+259%'],
                  ['Tokens/Session', '40,246', '6,503', '-84%'],
                  ['Cost/Session', '\$22.17', '\$3.64', '-84%'],
                  ['Cost/Message', '\$0.067', '\$0.021', '-69%'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'The Pattern',
                items: [
                  'Before: Fewer, longer sessions (avg 40K tokens) \u2192 expensive',
                  'After: More, shorter sessions (avg 6.5K tokens) \u2192 efficient',
                ],
              ),
            ],
          ),
        ),

        // Recommendations Section
        DocSection(
          icon: LucideIcons.lightbulb,
          title: 'Recommendations',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Maintain the Gains',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(items: [
                'Keep sessions short \u2014 Target <10K tokens/session',
                'Reset frequently \u2014 New session after major task completion',
                'Compact at 70% \u2014 Don\'t let context hit limits',
                'Monitor trends \u2014 Watch session.context.utilization in SigNoz',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Daily Workflow',
                style: AppTypography.headingSM.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocCodeBlock(
                code: '''1. Start session
   - /context to check baseline
   - Disable unused MCP servers

2. During work
   - Use subagents for verbose operations
   - Truncate bash output
   - Use Grep output_mode: "files_with_matches"

3. Between tasks
   - /clear if <50% context is relevant
   - /compact at 70% capacity

4. End of session
   - Document progress in .md file
   - /cost to review usage''',
              ),
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
          icon: LucideIcons.activity,
          title: 'Distributed Tracing',
          description: 'Track operations across hook invocations with OpenTelemetry spans.',
        ),
        DocFeatureCard(
          icon: LucideIcons.barChart3,
          title: 'Metrics Collection',
          description: 'Monitor performance, token usage, and cost patterns.',
        ),
        DocFeatureCard(
          icon: LucideIcons.fileText,
          title: 'Structured Logging',
          description: 'Debug issues with logs correlated to trace context.',
        ),
        DocFeatureCard(
          icon: LucideIcons.bot,
          title: 'LLM Instrumentation',
          description: 'Track token usage, costs, and model performance.',
        ),
      ],
    );
  }
}
