import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/docs_alerts_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the DocsAlertsPage widget (for interaction tests)
  Future<void> pumpDocsAlertsPage(
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
        home: DocsAlertsPage(onBack: onBack),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('DocsAlertsPage', () {
    // =========================================================================
    // Static structure tests - share widget state via setUpAll()
    // =========================================================================
    group('desktop structure tests', () {
      // Shared widget for static structure verification tests
      late Widget desktopPage;

      setUpAll(() {
        desktopPage = MaterialApp(
          theme: testTheme,
          home: const DocsAlertsPage(onBack: null),
        );
      });

      Future<void> pumpSharedDesktop(WidgetTester tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(desktopPage);
        await tester.pump();
        await tester.pump();
      }

      group('page structure', () {
        testWidgets('renders page title in app bar', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.text('Alerts Guide'), findsOneWidget);
        });

        testWidgets('renders Back to Home text button', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.text('Back to Home'), findsOneWidget);
        });
      });

      group('hero section', () {
        testWidgets('renders proactive monitoring badge', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.text('Proactive Monitoring'), findsOneWidget);
        });

        testWidgets('renders bell icon in badge', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byIcon(LucideIcons.bell), findsOneWidget);
        });

        testWidgets('renders main headline', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.text('Alerts & Incident Management'), findsOneWidget);
        });

        testWidgets('renders subtitle', (tester) async {
          await pumpSharedDesktop(tester);

          expect(
            find.textContaining('Get notified before problems become incidents'),
            findsOneWidget,
          );
        });

        testWidgets('renders alert type previews', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.text('Budget'), findsOneWidget);
          expect(find.text('Anomaly'), findsOneWidget);
          expect(find.text('Latency'), findsOneWidget);
          expect(find.text('Error Rate'), findsOneWidget);
        });

        testWidgets('renders alert type preview icons', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byIcon(LucideIcons.dollarSign), findsWidgets);
          expect(find.byIcon(LucideIcons.activity), findsWidgets);
          expect(find.byIcon(LucideIcons.gauge), findsWidgets);
          expect(find.byIcon(LucideIcons.alertTriangle), findsWidgets);
        });
      });

      group('overview section', () {
        testWidgets('renders Overview section title', (tester) async {
          await pumpSharedDesktop(tester);

          // Use key-based lookup instead of scrolling
          final section = find.byKey(const Key('overview-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Overview')),
            findsOneWidget,
          );
        });

        testWidgets('renders info icon for overview', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.info)),
            findsOneWidget,
          );
        });

        testWidgets('renders feature grid cards', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: section, matching: find.text('Budget Protection')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Smart Detection')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Instant Routing')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Flexible Rules')),
            findsOneWidget,
          );
        });
      });

      group('alert types section', () {
        testWidgets('renders Alert Types section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Alert Types')),
            findsOneWidget,
          );
        });

        testWidgets('renders layers icon for alert types', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.layers)),
            findsOneWidget,
          );
        });

        testWidgets('renders Budget Alerts card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(
            find.descendant(of: section, matching: find.text('Budget Alerts')),
            findsOneWidget,
          );
        });

        testWidgets('renders Anomaly Detection card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(
            find.descendant(of: section, matching: find.text('Anomaly Detection')),
            findsOneWidget,
          );
        });

        testWidgets('renders Performance Alerts card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(
            find.descendant(of: section, matching: find.text('Performance Alerts')),
            findsOneWidget,
          );
        });

        testWidgets('renders Error Rate Alerts card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-types-section'));
          expect(
            find.descendant(of: section, matching: find.text('Error Rate Alerts')),
            findsOneWidget,
          );
        });
      });

      group('creating alerts section', () {
        testWidgets('renders Creating Alerts section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Creating Alerts')),
            findsOneWidget,
          );
        });

        testWidgets('renders plus icon for creating alerts', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.plus)),
            findsOneWidget,
          );
        });

        testWidgets('renders Dashboard UI heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.text('Dashboard UI')),
            findsOneWidget,
          );
        });

        testWidgets('renders API heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.text('API')),
            findsOneWidget,
          );
        });

        testWidgets('renders numbered list items', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.textContaining('Navigate to Alerts')),
            findsOneWidget,
          );
        });
      });

      group('alert conditions section', () {
        testWidgets('renders Alert Conditions section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Alert Conditions')),
            findsOneWidget,
          );
        });

        testWidgets('renders filter icon for conditions', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.filter)),
            findsOneWidget,
          );
        });

        testWidgets('renders Available Metrics heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.text('Available Metrics')),
            findsOneWidget,
          );
        });

        testWidgets('renders Operators heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.text('Operators')),
            findsOneWidget,
          );
        });

        testWidgets('renders Time Windows heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.text('Time Windows')),
            findsOneWidget,
          );
        });
      });

      group('notification channels section', () {
        testWidgets('renders Notification Channels section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Notification Channels')),
            findsOneWidget,
          );
        });

        testWidgets('renders send icon for channels', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.send)),
            findsOneWidget,
          );
        });

        testWidgets('renders Slack channel card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.text('Slack')),
            findsOneWidget,
          );
        });

        testWidgets('renders PagerDuty channel card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.text('PagerDuty')),
            findsOneWidget,
          );
        });

        testWidgets('renders Email channel card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.text('Email')),
            findsOneWidget,
          );
        });

        testWidgets('renders Webhook channel card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.text('Webhook')),
            findsOneWidget,
          );
        });

        testWidgets('renders Microsoft Teams channel card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.text('Microsoft Teams')),
            findsOneWidget,
          );
        });
      });

      group('alert severity section', () {
        testWidgets('renders Alert Severity section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-severity-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Alert Severity')),
            findsOneWidget,
          );
        });

        testWidgets('renders thermometer icon for severity', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-severity-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.thermometer)),
            findsOneWidget,
          );
        });

        testWidgets('renders Critical severity card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-severity-section'));
          expect(
            find.descendant(of: section, matching: find.text('Critical')),
            findsOneWidget,
          );
        });

        testWidgets('renders Warning severity card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-severity-section'));
          expect(
            find.descendant(of: section, matching: find.text('Warning')),
            findsOneWidget,
          );
        });

        testWidgets('renders Info severity card', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-severity-section'));
          expect(
            find.descendant(of: section, matching: find.text('Info')),
            findsOneWidget,
          );
        });
      });

      group('alert schedules section', () {
        testWidgets('renders Alert Schedules section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-schedules-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Alert Schedules')),
            findsOneWidget,
          );
        });

        testWidgets('renders clock icon for schedules', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-schedules-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.clock)),
            findsOneWidget,
          );
        });

        testWidgets('renders Time-Based Rules heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-schedules-section'));
          expect(
            find.descendant(of: section, matching: find.text('Time-Based Rules')),
            findsOneWidget,
          );
        });

        testWidgets('renders Escalation Policies heading', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-schedules-section'));
          expect(
            find.descendant(of: section, matching: find.text('Escalation Policies')),
            findsOneWidget,
          );
        });
      });

      group('best practices section', () {
        testWidgets('renders Best Practices section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('best-practices-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Best Practices')),
            findsOneWidget,
          );
        });

        testWidgets('renders lightbulb icon for best practices', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('best-practices-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.lightbulb)),
            findsOneWidget,
          );
        });

        testWidgets('renders check circle icons for practices', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('best-practices-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.checkCircle)),
            findsWidgets,
          );
        });

        testWidgets('renders Start with budget alerts practice', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('best-practices-section'));
          expect(
            find.descendant(of: section, matching: find.text('Start with budget alerts')),
            findsOneWidget,
          );
        });

        testWidgets('renders Avoid alert fatigue practice', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('best-practices-section'));
          expect(
            find.descendant(of: section, matching: find.text('Avoid alert fatigue')),
            findsOneWidget,
          );
        });
      });

      group('example alerts section', () {
        testWidgets('renders Example Alert Configurations section title',
            (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('example-alerts-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Example Alert Configurations')),
            findsOneWidget,
          );
        });

        testWidgets('renders file code icon for examples', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('example-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.fileCode)),
            findsOneWidget,
          );
        });

        testWidgets('renders Daily Cost Budget example', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('example-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.text('Daily Cost Budget')),
            findsOneWidget,
          );
        });

        testWidgets('renders Latency Degradation example', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('example-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.text('Latency Degradation')),
            findsOneWidget,
          );
        });

        testWidgets('renders Anomaly Detection example', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('example-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.text('Anomaly Detection')),
            findsOneWidget,
          );
        });
      });

      group('related documentation section', () {
        testWidgets('renders Related Documentation section title', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('related-docs-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Related Documentation')),
            findsOneWidget,
          );
        });

        testWidgets('renders book open icon for related docs', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('related-docs-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.bookOpen)),
            findsOneWidget,
          );
        });
      });

      group('code samples', () {
        testWidgets('renders API code block with curl command', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('creating-alerts-section'));
          expect(
            find.descendant(of: section, matching: find.textContaining('curl -X POST')),
            findsOneWidget,
          );
        });

        testWidgets('renders selectable code text', (tester) async {
          await pumpSharedDesktop(tester);

          expect(find.byType(SelectableText), findsWidgets);
        });
      });

      group('tables', () {
        testWidgets('renders metrics table', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.byType(Table)),
            findsWidgets,
          );
          expect(
            find.descendant(of: section, matching: find.text('Metric')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Description')),
            findsWidgets,
          );
          expect(
            find.descendant(of: section, matching: find.text('Unit')),
            findsOneWidget,
          );
        });

        testWidgets('renders operators table', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('alert-conditions-section'));
          expect(
            find.descendant(of: section, matching: find.text('Operator')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Example')),
            findsOneWidget,
          );
        });
      });

      group('section icons', () {
        testWidgets('renders correct icons for each section', (tester) async {
          await pumpSharedDesktop(tester);

          // Icons visible in initial view
          expect(find.byIcon(LucideIcons.bell), findsOneWidget);

          // Use key-based lookup for overview section icon
          final overviewSection = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: overviewSection, matching: find.byIcon(LucideIcons.info)),
            findsOneWidget,
          );
        });

        testWidgets('renders dollar sign icon for budget features',
            (tester) async {
          await pumpSharedDesktop(tester);

          final overviewSection = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: overviewSection, matching: find.byIcon(LucideIcons.dollarSign)),
            findsOneWidget,
          );
        });

        testWidgets('renders brain icon for smart detection', (tester) async {
          await pumpSharedDesktop(tester);

          final overviewSection = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: overviewSection, matching: find.byIcon(LucideIcons.brain)),
            findsOneWidget,
          );
        });

        testWidgets('renders zap icon for instant routing', (tester) async {
          await pumpSharedDesktop(tester);

          final overviewSection = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: overviewSection, matching: find.byIcon(LucideIcons.zap)),
            findsOneWidget,
          );
        });

        testWidgets('renders settings icon for flexible rules', (tester) async {
          await pumpSharedDesktop(tester);

          final overviewSection = find.byKey(const Key('overview-section'));
          expect(
            find.descendant(of: overviewSection, matching: find.byIcon(LucideIcons.settings)),
            findsOneWidget,
          );
        });
      });

      group('channel icons', () {
        testWidgets('renders hash icon for Slack', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.hash)),
            findsOneWidget,
          );
        });

        testWidgets('renders alert circle icon for PagerDuty', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.alertCircle)),
            findsOneWidget,
          );
        });

        testWidgets('renders mail icon for Email', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.mail)),
            findsOneWidget,
          );
        });

        testWidgets('renders webhook icon for Webhook', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.webhook)),
            findsOneWidget,
          );
        });

        testWidgets('renders message square icon for Teams', (tester) async {
          await pumpSharedDesktop(tester);

          final section = find.byKey(const Key('notification-channels-section'));
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.messageSquare)),
            findsOneWidget,
          );
        });
      });
    });

    // =========================================================================
    // Interaction tests - require fresh state per test
    // =========================================================================
    group('page structure', () {
      testPageStructure(pumpDocsAlertsPage);
    });

    group('navigation', () {
      testBackButtonCallbacks(pumpDocsAlertsPage);
    });

    group('footer', () {
      testWidgets('renders footer with OpenTelemetry and SigNoz text',
          (tester) async {
        await pumpDocsAlertsPage(tester);

        // Scroll to footer using multiple drags
        final scrollView = find.byType(CustomScrollView);
        for (var i = 0; i < 15; i++) {
          await tester.drag(scrollView, const Offset(0, -600));
          await tester.pump();
        }

        expect(
          find.text('Built with OpenTelemetry and SigNoz'),
          findsOneWidget,
        );
      });

      testWidgets('renders copyright text', (tester) async {
        await pumpDocsAlertsPage(tester);

        // Scroll to footer using multiple drags
        final scrollView = find.byType(CustomScrollView);
        for (var i = 0; i < 15; i++) {
          await tester.drag(scrollView, const Offset(0, -600));
          await tester.pump();
        }

        expect(
          find.textContaining('2026 Integrity Studio LLC'),
          findsOneWidget,
        );
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<DocsAlertsPage>(
        pumpDocsAlertsPage,
        expectedTitle: 'Alerts Guide',
      );

      testWidgets('renders hero section on mobile', (tester) async {
        await pumpDocsAlertsPage(tester, mobile: true);

        expect(find.text('Proactive Monitoring'), findsOneWidget);
        expect(find.text('Alerts & Incident Management'), findsOneWidget);
      });

      testWidgets('renders alert type previews on mobile', (tester) async {
        await pumpDocsAlertsPage(tester, mobile: true);

        expect(find.text('Budget'), findsOneWidget);
        expect(find.text('Anomaly'), findsOneWidget);
      });
    });
  });
}
