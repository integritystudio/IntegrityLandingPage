import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/docs_observability_page.dart';
import 'package:integrity_studio_ai/widgets/docs/doc_components.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the DocsObservabilityPage widget
  Future<void> pumpObservabilityPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool mobile = false,
  }) async {
    if (mobile) {
      setMobileSize(tester);
    } else {
      setDesktopSize(tester);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: DocsObservabilityPage(onBack: onBack),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('DocsObservabilityPage', () {
    group('page structure', () {
      testPageStructure(pumpObservabilityPage);

      testWidgets('renders page title in app bar', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Observability Guide'), findsWidgets);
      });

      testWidgets('renders Back to Home text button', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Back to Home'), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallbacks(pumpObservabilityPage);
    });

    group('hero section', () {
      testWidgets('renders production-ready badge', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Production-Ready Framework'), findsOneWidget);
      });

      testWidgets('renders layers icon in badge', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.byIcon(LucideIcons.layers), findsOneWidget);
      });

      testWidgets('renders main headline', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Claude Code Observability & Context Management'),
            findsOneWidget);
      });

      testWidgets('renders subtitle', (tester) async {
        await pumpObservabilityPage(tester);

        expect(
            find.text(
                'Complete guide to token optimization, distributed tracing, and cost efficiency for Claude Code using OpenTelemetry and SigNoz.'),
            findsOneWidget);
      });
    });

    group('stats cards', () {
      testWidgets('renders cost reduction stat', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('81%'), findsOneWidget);
        expect(find.text('Cost Reduction'), findsOneWidget);
      });

      testWidgets('renders instrumented hooks stat', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('12'), findsOneWidget);
        expect(find.text('Instrumented Hooks'), findsOneWidget);
      });

      testWidgets('renders dashboards stat', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('8'), findsOneWidget);
        expect(find.text('Dashboards'), findsOneWidget);
      });

      testWidgets('renders MCP token savings stat', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('85%'), findsOneWidget);
        expect(find.text('MCP Token Savings'), findsOneWidget);
      });
    });

    group('documentation sections', () {
      testWidgets('renders Overview section with info icon', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Overview'), findsOneWidget);
        expect(find.byIcon(LucideIcons.info), findsWidgets);
      });

      testWidgets('renders Quick Start section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();

        expect(find.text('Quick Start'), findsOneWidget);
        expect(find.byIcon(LucideIcons.rocket), findsOneWidget);
      });

      testWidgets('renders Token Optimization section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();

        expect(find.text('Token Optimization Strategies'), findsOneWidget);
        expect(find.byIcon(LucideIcons.coins), findsOneWidget);
      });

      testWidgets('renders Efficient Tool Usage section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1000));
        await tester.pump();

        expect(find.text('Efficient Tool Usage'), findsOneWidget);
        expect(find.byIcon(LucideIcons.wrench), findsOneWidget);
      });

      testWidgets('renders Context Window Management section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1400));
        await tester.pump();

        expect(find.text('Context Window Management'), findsOneWidget);
        expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
      });

      testWidgets('renders MCP Server Optimization section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump();

        expect(find.text('MCP Server Optimization'), findsOneWidget);
        expect(find.byIcon(LucideIcons.plug), findsOneWidget);
      });

      testWidgets('renders Metrics Reference section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2500));
        await tester.pump();

        expect(find.text('Metrics Reference'), findsOneWidget);
        expect(find.byIcon(LucideIcons.barChart3), findsWidgets);
      });

      testWidgets('renders Cost Optimization section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3200));
        await tester.pump();

        expect(find.text('Cost Optimization'), findsOneWidget);
        expect(find.byIcon(LucideIcons.trendingDown), findsOneWidget);
      });

      testWidgets('renders Recommendations section', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3800));
        await tester.pump();

        expect(find.text('Recommendations'), findsOneWidget);
        expect(find.byIcon(LucideIcons.lightbulb), findsWidgets);
      });
    });

    group('overview content', () {
      testWidgets('renders Anthropic quote about context', (tester) async {
        await pumpObservabilityPage(tester);

        expect(
            find.textContaining(
                'Context management is "effectively the #1 job"'),
            findsOneWidget);
      });

      testWidgets('renders key results callout', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Key Results from Optimization'), findsOneWidget);
      });

      testWidgets('renders 81% cost reduction in results', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.textContaining('81% reduction in cost per session'),
            findsOneWidget);
      });
    });

    group('feature cards', () {
      testWidgets('renders Distributed Tracing feature', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Distributed Tracing'), findsOneWidget);
        expect(find.byIcon(LucideIcons.activity), findsOneWidget);
      });

      testWidgets('renders Metrics Collection feature', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Metrics Collection'), findsOneWidget);
      });

      testWidgets('renders Structured Logging feature', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('Structured Logging'), findsOneWidget);
        expect(find.byIcon(LucideIcons.fileText), findsOneWidget);
      });

      testWidgets('renders LLM Instrumentation feature', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.text('LLM Instrumentation'), findsOneWidget);
        expect(find.byIcon(LucideIcons.bot), findsOneWidget);
      });
    });

    group('token optimization content', () {
      testWidgets('renders hybrid model approach header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump();

        expect(find.text('Hybrid Model Approach'), findsOneWidget);
      });

      testWidgets('renders lazy loading results callout', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();

        expect(find.text('Results from Lazy Loading'), findsOneWidget);
      });
    });

    group('tool usage content', () {
      testWidgets('renders memory warning callout', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1200));
        await tester.pump();

        expect(find.text('Memory Warning'), findsOneWidget);
      });
    });

    group('context window content', () {
      testWidgets('renders context degradation warning', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1600));
        await tester.pump();

        expect(find.text('Context Degradation'), findsOneWidget);
      });

      testWidgets('renders built-in commands header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1700));
        await tester.pump();

        expect(find.text('Built-in Commands'), findsOneWidget);
      });
    });

    group('MCP optimization content', () {
      testWidgets('renders performance improvements callout', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2300));
        await tester.pump();

        expect(find.text('Performance Improvements'), findsOneWidget);
      });
    });

    group('metrics reference content', () {
      testWidgets('renders Hook Metrics header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2600));
        await tester.pump();

        expect(find.text('Hook Metrics'), findsOneWidget);
      });

      testWidgets('renders GenAI Metrics header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2800));
        await tester.pump();

        expect(find.text('GenAI Metrics'), findsOneWidget);
      });
    });

    group('cost optimization content', () {
      testWidgets('renders session strategy comparison header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3300));
        await tester.pump();

        expect(find.text('Session Strategy Comparison'), findsOneWidget);
      });

      testWidgets('renders the pattern callout', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3500));
        await tester.pump();

        expect(find.text('The Pattern'), findsOneWidget);
      });
    });

    group('recommendations content', () {
      testWidgets('renders Maintain the Gains header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3900));
        await tester.pump();

        expect(find.text('Maintain the Gains'), findsOneWidget);
      });

      testWidgets('renders Daily Workflow header', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4100));
        await tester.pump();

        expect(find.text('Daily Workflow'), findsOneWidget);
      });
    });

    group('doc components', () {
      testWidgets('renders DocSection widgets', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.byType(DocSection), findsWidgets);
      });

      testWidgets('renders DocFeatureCard widgets', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.byType(DocFeatureCard), findsWidgets);
      });

      testWidgets('renders DocTable widgets', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump();

        expect(find.byType(DocTable), findsWidgets);
      });

      testWidgets('renders DocCallout widgets', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.byType(DocCallout), findsWidgets);
      });

      testWidgets('renders DocBulletList widgets', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2200));
        await tester.pump();

        expect(find.byType(DocBulletList), findsWidgets);
      });

      testWidgets('renders DocCodeBlock widget', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4200));
        await tester.pump();

        expect(find.byType(DocCodeBlock), findsOneWidget);
      });
    });

    group('footer', () {
      testWidgets('renders OpenTelemetry and SigNoz credit', (tester) async {
        await pumpObservabilityPage(tester);

        // Scroll to very bottom of page in multiple steps
        for (int i = 0; i < 10; i++) {
          await tester.drag(
              find.byType(CustomScrollView), const Offset(0, -1000));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump();

        expect(find.text('Built with OpenTelemetry and SigNoz'), findsOneWidget);
      });

      testWidgets('renders copyright notice', (tester) async {
        await pumpObservabilityPage(tester);

        // Scroll to very bottom of page in multiple steps
        for (int i = 0; i < 10; i++) {
          await tester.drag(
              find.byType(CustomScrollView), const Offset(0, -1000));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump();

        expect(find.text('\u00A9 2026 Integrity Studio LLC'), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('renders on mobile viewport', (tester) async {
        // Use tablet size instead to avoid badge overflow
        setTabletSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const DocsObservabilityPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(DocsObservabilityPage), findsOneWidget);
        expect(find.text('Observability Guide'), findsWidgets);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        await pumpObservabilityPage(tester, mobile: false);

        expect(find.byType(DocsObservabilityPage), findsOneWidget);
        expect(find.text('Observability Guide'), findsWidgets);
      });

      testWidgets('renders hero section on tablet', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const DocsObservabilityPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Claude Code Observability & Context Management'),
            findsOneWidget);
        expect(find.text('Production-Ready Framework'), findsOneWidget);
      });

      testWidgets('renders stats on tablet', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const DocsObservabilityPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('81%'), findsOneWidget);
        expect(find.text('Cost Reduction'), findsOneWidget);
      });
    });

    group('callout variants', () {
      testWidgets('renders success callout with check icon', (tester) async {
        await pumpObservabilityPage(tester);

        expect(find.byIcon(LucideIcons.checkCircle), findsWidgets);
      });

      testWidgets('renders warning callout with alert icon', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1200));
        await tester.pump();

        expect(find.byIcon(LucideIcons.alertTriangle), findsWidgets);
      });

      testWidgets('renders danger callout with alert circle', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1600));
        await tester.pump();

        expect(find.byIcon(LucideIcons.alertCircle), findsWidgets);
      });
    });

    group('table content', () {
      testWidgets('renders model table headers', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();

        expect(find.text('Model'), findsOneWidget);
        expect(find.text('Use For'), findsOneWidget);
      });

      testWidgets('renders tool scenario table', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1100));
        await tester.pump();

        expect(find.text('Scenario'), findsOneWidget);
        expect(find.text('Recommended Tool'), findsOneWidget);
      });

      testWidgets('renders context window tier table', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pump();

        expect(find.text('Tier'), findsOneWidget);
        expect(find.text('Context Window'), findsOneWidget);
      });

      testWidgets('renders metrics reference table', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2700));
        await tester.pump();

        expect(find.text('Metric'), findsWidgets);
        expect(find.text('Type'), findsWidgets);
        expect(find.text('Description'), findsWidgets);
      });
    });

    group('code examples', () {
      testWidgets('renders daily workflow code block', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4200));
        await tester.pump();

        // Code block contains "Start session" - may appear multiple times
        expect(find.textContaining('Start session'), findsWidgets);
      });

      testWidgets('renders workflow steps in code block', (tester) async {
        await pumpObservabilityPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4300));
        await tester.pump();

        expect(find.textContaining('During work'), findsWidgets);
        expect(find.textContaining('Between tasks'), findsWidgets);
        expect(find.textContaining('End of session'), findsWidgets);
      });
    });
  });
}
