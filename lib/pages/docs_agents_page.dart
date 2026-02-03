import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// Agent Observability documentation page.
///
/// Covers monitoring multi-step AI agents, tool calls, reasoning chains,
/// and evaluation metrics for agent quality assessment.
class DocsAgentsPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsAgentsPage({
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
          DocPageAppBar(title: 'Agent Observability', onBack: onBack),

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
                color: AppColors.purple500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.purple500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.bot,
                    size: 16,
                    color: AppColors.purple500,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Multi-Agent Ready',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.purple500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'Agent Observability',
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
                'Monitor multi-step AI agents, tool calls, and reasoning chains. Debug complex autonomous workflows with full execution traces and decision visualization.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Version Note
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.calendar,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Available in v1.9 \u2022 February 1st, 2026',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Key Stats
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: const [
                _StatBadge(label: 'Tool Calls', value: 'Tracked'),
                _StatBadge(label: 'Reasoning Chains', value: 'Visualized'),
                _StatBadge(label: 'Multi-Agent', value: 'Supported'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;

  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          Text(
            value,
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.purple500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
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
        _DocSection(
          icon: LucideIcons.eye,
          title: 'The Agent Observability Challenge',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI agents introduce observability complexity through:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const _BulletList(items: [
                'Non-deterministic execution: Same input may produce different tool call sequences',
                'Multi-turn reasoning: Extended context across many LLM calls',
                'Tool orchestration: External system interactions within agent loops',
                'Framework diversity: LangGraph, CrewAI, AutoGen, Claude Code have different patterns',
              ]),
              const SizedBox(height: AppSpacing.lg),
              const _InfoCallout(
                title: 'Industry Insight',
                message:
                    '89% of teams have implemented observability for agents, but only 52% have implemented evaluations. This gap represents a critical blind spot.',
              ),
            ],
          ),
        ),

        // Agent Span Semantics
        _DocSection(
          icon: LucideIcons.gitBranch,
          title: 'Agent Span Semantics',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenTelemetry GenAI conventions define three core operation types for agents:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Operation', 'Purpose', 'Example'],
                rows: [
                  ['create_agent', 'Agent instantiation', 'CustomerSupportAgent initialized'],
                  ['invoke_agent', 'Agent execution', 'Agent handles user query'],
                  ['execute_tool', 'Tool/function call', 'get_customer_info called'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Agent Invocation Span Hierarchy',
                code: '''Span: invoke_agent CustomerSupportAgent
\u251c\u2500\u2500 gen_ai.operation.name: "invoke_agent"
\u251c\u2500\u2500 gen_ai.agent.id: "agent_abc123"
\u251c\u2500\u2500 gen_ai.agent.name: "CustomerSupportAgent"
\u2514\u2500\u2500 gen_ai.conversation.id: "conv_xyz789"
    \u2502
    \u251c\u2500\u2500 Child Span: chat claude-3-opus
    \u2502   \u2514\u2500\u2500 gen_ai.operation.name: "chat"
    \u2502
    \u251c\u2500\u2500 Child Span: execute_tool get_customer_info
    \u2502   \u251c\u2500\u2500 gen_ai.tool.name: "get_customer_info"
    \u2502   \u251c\u2500\u2500 gen_ai.tool.type: "function"
    \u2502   \u2514\u2500\u2500 gen_ai.tool.call.id: "call_abc"
    \u2502
    \u2514\u2500\u2500 Child Span: chat claude-3-opus
        \u2514\u2500\u2500 gen_ai.operation.name: "chat"''',
              ),
            ],
          ),
        ),

        // Tool Execution Attributes
        _DocSection(
          icon: LucideIcons.wrench,
          title: 'Tool Execution Tracking',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture detailed information about every tool call:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Attribute', 'Type', 'Description'],
                rows: [
                  ['gen_ai.tool.name', 'string', 'Tool identifier'],
                  ['gen_ai.tool.type', 'string', 'function, extension, datastore'],
                  ['gen_ai.tool.description', 'string', 'Human-readable description'],
                  ['gen_ai.tool.call.id', 'string', 'Unique call identifier'],
                  ['gen_ai.tool.call.arguments', 'any', 'Input parameters (opt-in)'],
                  ['gen_ai.tool.call.result', 'any', 'Output (opt-in, sensitive)'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _WarningCallout(
                title: 'Sensitive Data',
                message:
                    'Tool arguments and results may contain sensitive data. Enable capture only when needed and ensure proper data handling.',
              ),
            ],
          ),
        ),

        // Agent Evaluation Metrics
        _DocSection(
          icon: LucideIcons.checkCircle,
          title: 'Agent Evaluation Metrics',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Core metrics for assessing agent quality:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Metric', 'Scope', 'Description'],
                rows: [
                  ['Task Completion', 'End-to-end', 'Did agent achieve stated goal?'],
                  ['Argument Correctness', 'Component', 'Were tool parameters valid?'],
                  ['Tool Correctness', 'End-to-end', 'Were correct tools selected?'],
                  ['Conversation Completeness', 'Multi-turn', 'Did agent satisfy user?'],
                  ['Turn Relevancy', 'Multi-turn', 'Did agent stay on track?'],
                  ['Handoff Correctness', 'Multi-agent', 'Was delegation appropriate?'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _InfoCallout(
                title: 'Single vs Multi-Turn',
                message:
                    'Single-turn agents complete in one interaction. Multi-turn agents span multiple user exchanges. Internal agent-to-agent calls do NOT count as turns\u2014only end-user interactions define turn boundaries.',
              ),
            ],
          ),
        ),

        // Agent-as-a-Judge
        _DocSection(
          icon: LucideIcons.scale,
          title: 'Agent-as-a-Judge Evaluation',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A newer paradigm for evaluating agentic systems. Standard LLM-as-Judge falls short because agents have:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const _BulletList(items: [
                'Multi-step execution with intermediate states',
                'Tool calls that introduce external system interactions',
                'Success depends on task completion, not just response quality',
                'Reasoning chains that may be valid even if final output differs',
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'The judge agent is endowed with similar capabilities:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const _FeatureGrid(),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Agent-as-a-Judge Evaluation Flow',
                code: '''Subject Agent Execution          Judge Agent (Parallel)
\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510         \u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510
\u2502 Step 1: Reasoning   \u2502\u25c0\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u25b6\u2502 Evaluate: Reasoning \u2502
\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u252c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518         \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518
          \u2502
\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510         \u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510
\u2502 Step 2: Tool Call   \u2502\u25c0\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u25b6\u2502 Evaluate: Tool Args \u2502
\u2502 get_customer(id=42) \u2502         \u2502 \u2713 Correct tool      \u2502
\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u252c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518         \u2502 \u2713 Valid parameters  \u2502
          \u2502                     \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518
\u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2534\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510         \u250c\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2510
\u2502 Step 3: Response    \u2502\u25c0\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u25b6\u2502 Evaluate: Task Done \u2502
\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518         \u2502 Score: 0.94         \u2502
                                  \u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2518''',
              ),
            ],
          ),
        ),

        // Framework Support
        _DocSection(
          icon: LucideIcons.layers,
          title: 'Framework Support',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Integrity Studio supports observability for popular agent frameworks:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Framework', 'Integration', 'Key Features'],
                rows: [
                  ['LangChain', 'Auto-instrumentation', 'Chain tracing, tool calls, memory'],
                  ['LangGraph', 'Auto-instrumentation', 'Graph execution, state tracking'],
                  ['CrewAI', 'Native support', 'Multi-agent coordination'],
                  ['Claude Code', 'Built-in', 'Tool execution, session context'],
                  ['Custom Agents', 'OpenTelemetry SDK', 'Manual instrumentation'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Python Auto-Instrumentation',
                code: '''from integrity_studio import IntegrityStudio

client = IntegrityStudio(
    api_key=os.environ["INTEGRITY_API_KEY"],
    service_name="my-agent-app",
)

# Enable auto-instrumentation for agent frameworks
client.instrument_langchain()
client.instrument_langgraph()

# Your agent code runs with automatic tracing
agent = create_react_agent(llm, tools)
result = agent.invoke({"input": "Help me with..."})''',
              ),
            ],
          ),
        ),

        // OTel Evaluation Events
        _DocSection(
          icon: LucideIcons.fileCheck,
          title: 'OpenTelemetry Evaluation Events',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The OpenTelemetry GenAI semantic conventions define a standardized event for capturing evaluation results:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SimpleTable(
                headers: ['Attribute', 'Type', 'Description'],
                rows: [
                  ['gen_ai.evaluation.name', 'string', 'Evaluation metric name'],
                  ['gen_ai.evaluation.score.value', 'double', 'Numeric score (0-1)'],
                  ['gen_ai.evaluation.score.label', 'string', 'pass, fail, relevant'],
                  ['gen_ai.evaluation.explanation', 'string', 'Reasoning for score'],
                  ['gen_ai.response.id', 'string', 'Correlation to response'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CodeBlock(
                title: 'Evaluation Event Example',
                code: '''Trace: Customer Support Query
\u251c\u2500\u2500 Span: invoke_agent CustomerSupportBot
\u2502   \u251c\u2500\u2500 Span: chat claude-3-opus
\u2502   \u2502   \u2514\u2500\u2500 Event: gen_ai.evaluation.result
\u2502   \u2502       \u251c\u2500\u2500 gen_ai.evaluation.name: "Relevance"
\u2502   \u2502       \u251c\u2500\u2500 gen_ai.evaluation.score.value: 0.92
\u2502   \u2502       \u251c\u2500\u2500 gen_ai.evaluation.score.label: "relevant"
\u2502   \u2502       \u2514\u2500\u2500 gen_ai.evaluation.explanation: "Addresses query"
\u2502   \u2502
\u2502   \u2514\u2500\u2500 Span: execute_tool lookup_customer
\u2502       \u2514\u2500\u2500 Event: gen_ai.evaluation.result
\u2502           \u251c\u2500\u2500 gen_ai.evaluation.name: "ToolCorrectness"
\u2502           \u2514\u2500\u2500 gen_ai.evaluation.score.label: "pass"''',
              ),
            ],
          ),
        ),

        // Next Steps
        _DocSection(
          icon: LucideIcons.arrowRight,
          title: 'Next Steps',
          color: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BulletList(items: [
                'Set up distributed tracing \u2014 /docs/tracing',
                'Configure alerting for agent failures \u2014 /docs/alerts',
                'Explore the API for custom metrics \u2014 /api',
                'Quick start guide \u2014 /docs/quickstart',
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
  final Color color;
  final Widget child;

  const _DocSection({
    required this.icon,
    required this.title,
    required this.color,
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
                  color: color,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headingSM.copyWith(color: color),
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
          icon: LucideIcons.eye,
          title: 'Observation',
          description: 'Inspect intermediate steps and action logs',
        ),
        _FeatureCard(
          icon: LucideIcons.wrench,
          title: 'Tool Access',
          description: 'Verify tool calls against expected behavior',
        ),
        _FeatureCard(
          icon: LucideIcons.play,
          title: 'Parallel Execution',
          description: 'Monitor decisions at each step in real-time',
        ),
        _FeatureCard(
          icon: LucideIcons.messageSquare,
          title: 'Granular Feedback',
          description: 'Identify which requirements were met/missed',
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
              color: AppColors.purple500.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: Icon(icon, color: AppColors.purple500, size: 18),
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
                        color: AppColors.purple500,
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
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
        ],
      ),
    );
  }
}
