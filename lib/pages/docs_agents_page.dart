import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/docs/doc_components.dart';
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
    return DocsPageScaffold(
      title: 'Agent Observability',
      onBack: onBack,
      heroBuilder: (isMobile) => DocsHeroSection(
        badgeIcon: LucideIcons.bot,
        badgeColor: AppColors.purple500,
        badgeLabel: 'Multi-Agent Ready',
        headline: 'Agent Observability',
        subheadline:
            'Monitor multi-step AI agents, tool calls, and reasoning chains. Debug complex autonomous workflows with full execution traces and decision visualization.',
        isMobile: isMobile,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.blue500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.blue400),
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
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            alignment: WrapAlignment.center,
            children: [
              DocStatCard(
                value: 'Tracked',
                label: 'Tool Calls',
                accentColor: AppColors.purple500,
                valueStyle: AppTypography.bodyMD.copyWith(color: AppColors.purple500, fontWeight: FontWeight.w600),
                constraints: const BoxConstraints(),
              ),
              DocStatCard(
                value: 'Visualized',
                label: 'Reasoning Chains',
                accentColor: AppColors.purple500,
                valueStyle: AppTypography.bodyMD.copyWith(color: AppColors.purple500, fontWeight: FontWeight.w600),
                constraints: const BoxConstraints(),
              ),
              DocStatCard(
                value: 'Supported',
                label: 'Multi-Agent',
                accentColor: AppColors.purple500,
                valueStyle: AppTypography.bodyMD.copyWith(color: AppColors.purple500, fontWeight: FontWeight.w600),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
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
          icon: LucideIcons.eye,
          title: 'The Agent Observability Challenge',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI agents introduce observability complexity through:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(bulletColor: AppColors.purple500, items: [
                'Non-deterministic execution: Same input may produce different tool call sequences',
                'Multi-turn reasoning: Extended context across many LLM calls',
                'Tool orchestration: External system interactions within agent loops',
                'Framework diversity: LangGraph, CrewAI, AutoGen, Claude Code have different patterns',
              ]),
              const SizedBox(height: AppSpacing.lg),
              const DocCallout.info(
                title: 'Industry Insight',
                message:
                    '89% of teams have implemented observability for agents, but only 52% have implemented evaluations. This gap represents a critical blind spot.',
              ),
            ],
          ),
        ),

        // Agent Span Semantics
        DocSection(
          icon: LucideIcons.gitBranch,
          title: 'Agent Span Semantics',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenTelemetry GenAI conventions define three core operation types for agents:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
                headers: ['Operation', 'Purpose', 'Example'],
                rows: [
                  ['create_agent', 'Agent instantiation', 'CustomerSupportAgent initialized'],
                  ['invoke_agent', 'Agent execution', 'Agent handles user query'],
                  ['execute_tool', 'Tool/function call', 'get_customer_info called'],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocCodeBlock(
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
        DocSection(
          icon: LucideIcons.wrench,
          title: 'Tool Execution Tracking',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture detailed information about every tool call:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
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
              const DocCallout.warning(
                title: 'Sensitive Data',
                message:
                    'Tool arguments and results may contain sensitive data. Enable capture only when needed and ensure proper data handling.',
              ),
            ],
          ),
        ),

        // Agent Evaluation Metrics
        DocSection(
          icon: LucideIcons.checkCircle,
          title: 'Agent Evaluation Metrics',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Core metrics for assessing agent quality:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
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
              const DocCallout.info(
                title: 'Single vs Multi-Turn',
                message:
                    'Single-turn agents complete in one interaction. Multi-turn agents span multiple user exchanges. Internal agent-to-agent calls do NOT count as turns\u2014only end-user interactions define turn boundaries.',
              ),
            ],
          ),
        ),

        // Agent-as-a-Judge
        DocSection(
          icon: LucideIcons.scale,
          title: 'Agent-as-a-Judge Evaluation',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A newer paradigm for evaluating agentic systems. Standard LLM-as-Judge falls short because agents have:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.md),
              const DocBulletList(bulletColor: AppColors.purple500, items: [
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
              const DocCodeBlock(
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
        DocSection(
          icon: LucideIcons.layers,
          title: 'Framework Support',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Integrity Studio supports observability for popular agent frameworks:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
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
              const DocCodeBlock(
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
        DocSection(
          icon: LucideIcons.fileCheck,
          title: 'OpenTelemetry Evaluation Events',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The OpenTelemetry GenAI semantic conventions define a standardized event for capturing evaluation results:',
                style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              ),
              const SizedBox(height: AppSpacing.lg),
              const DocTable(
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
              const DocCodeBlock(
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
        DocSection(
          icon: LucideIcons.arrowRight,
          title: 'Next Steps',
          accentColor: AppColors.purple500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DocBulletList(bulletColor: AppColors.purple500, items: [
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

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: const [
        DocFeatureCard(
          icon: LucideIcons.eye,
          title: 'Observation',
          description: 'Inspect intermediate steps and action logs',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.wrench,
          title: 'Tool Access',
          description: 'Verify tool calls against expected behavior',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.play,
          title: 'Parallel Execution',
          description: 'Monitor decisions at each step in real-time',
          accentColor: AppColors.purple500,
        ),
        DocFeatureCard(
          icon: LucideIcons.messageSquare,
          title: 'Granular Feedback',
          description: 'Identify which requirements were met/missed',
          accentColor: AppColors.purple500,
        ),
      ],
    );
  }
}
