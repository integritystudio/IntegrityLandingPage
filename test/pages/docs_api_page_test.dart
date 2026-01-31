import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/docs_api_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the DocsApiPage widget
  Future<void> pumpDocsApiPage(
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
        home: DocsApiPage(onBack: onBack),
      ),
    );
    await tester.pump();
  }

  group('DocsApiPage', () {
    group('page structure', () {
      testPageStructure(pumpDocsApiPage);

      testWidgets('renders page title in app bar', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('API Reference'), findsWidgets);
      });

      testWidgets('renders Back to Home text button', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('Back to Home'), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallbacks(pumpDocsApiPage);
    });

    group('hero section', () {
      testWidgets('renders API badge', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('REST & OTLP APIs'), findsOneWidget);
      });

      testWidgets('renders code icon in badge', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.byIcon(LucideIcons.code2), findsOneWidget);
      });

      testWidgets('renders subtitle', (tester) async {
        await pumpDocsApiPage(tester);

        expect(
          find.textContaining('Complete API documentation'),
          findsOneWidget,
        );
      });
    });

    group('stats cards', () {
      testWidgets('renders OTLP stat', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('OTLP'), findsOneWidget);
        expect(find.text('Native Protocol'), findsOneWidget);
      });

      testWidgets('renders REST stat', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('REST'), findsOneWidget);
        expect(find.text('Fallback API'), findsOneWidget);
      });

      testWidgets('renders SDK languages stat', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('3'), findsOneWidget);
        expect(find.text('SDK Languages'), findsOneWidget);
      });

      testWidgets('renders latency stat', (tester) async {
        await pumpDocsApiPage(tester);

        expect(find.text('<100ms'), findsOneWidget);
        expect(find.text('Avg Latency'), findsOneWidget);
      });
    });

    group('documentation sections', () {
      testWidgets('renders Authentication section with key icon',
          (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -200));
        await tester.pump();

        expect(find.text('Authentication'), findsOneWidget);
        expect(find.byIcon(LucideIcons.key), findsOneWidget);
      });

      testWidgets('renders Base URLs section with globe icon', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump();

        expect(find.text('Base URLs'), findsOneWidget);
        expect(find.byIcon(LucideIcons.globe), findsOneWidget);
      });

      testWidgets('renders Trace Ingestion API section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pump();

        expect(find.text('Trace Ingestion API'), findsOneWidget);
        expect(find.byIcon(LucideIcons.upload), findsOneWidget);
      });

      testWidgets('renders Query API section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump();

        expect(find.text('Query API'), findsOneWidget);
        expect(find.byIcon(LucideIcons.search), findsOneWidget);
      });

      testWidgets('renders Alerts API section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3500));
        await tester.pump();

        expect(find.text('Alerts API'), findsOneWidget);
        expect(find.byIcon(LucideIcons.bell), findsOneWidget);
      });

      testWidgets('renders SDKs & Libraries section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -5000));
        await tester.pump();

        expect(find.text('SDKs & Libraries'), findsOneWidget);
        expect(find.byIcon(LucideIcons.package), findsOneWidget);
      });

      testWidgets('renders Error Handling section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -6000));
        await tester.pump();

        expect(find.text('Error Handling'), findsOneWidget);
        expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
      });

      testWidgets('renders Related Documentation section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -7000));
        await tester.pump();

        expect(find.text('Related Documentation'), findsOneWidget);
        expect(find.byIcon(LucideIcons.bookOpen), findsOneWidget);
      });
    });

    group('code examples', () {
      testWidgets('renders Header Authentication code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        expect(find.text('Header Authentication'), findsOneWidget);
      });

      testWidgets('renders Environment Configuration code block',
          (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1200));
        await tester.pump();

        expect(find.text('Environment Configuration'), findsOneWidget);
      });

      testWidgets('renders Request Body code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1500));
        await tester.pump();

        expect(find.text('Request Body'), findsOneWidget);
      });

      testWidgets('renders Example Request code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2800));
        await tester.pump();

        expect(find.text('Example Request'), findsOneWidget);
      });

      testWidgets('renders Token Metrics Response code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3200));
        await tester.pump();

        expect(find.text('Token Metrics Response'), findsOneWidget);
      });

      testWidgets('renders Create Alert Request code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4000));
        await tester.pump();

        expect(find.text('Create Alert Request'), findsOneWidget);
      });

      testWidgets('renders Error Response Format code block', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -6500));
        await tester.pump();

        expect(find.text('Error Response Format'), findsOneWidget);
      });
    });

    group('API endpoint documentation', () {
      testWidgets('renders POST /v1/traces endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1300));
        await tester.pump();

        expect(find.text('POST'), findsWidgets);
        expect(find.text('/v1/traces'), findsWidgets);
        expect(find.text('Ingest a batch of spans'), findsOneWidget);
      });

      testWidgets('renders GET /v1/traces endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2200));
        await tester.pump();

        expect(find.text('GET'), findsWidgets);
        expect(find.text('List traces with filtering'), findsOneWidget);
      });

      testWidgets('renders GET /v1/traces/{traceId} endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3000));
        await tester.pump();

        expect(find.text('/v1/traces/{traceId}'), findsOneWidget);
        expect(
            find.text('Get a specific trace with all spans'), findsOneWidget);
      });

      testWidgets('renders GET /v1/metrics/tokens endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3100));
        await tester.pump();

        expect(find.text('/v1/metrics/tokens'), findsOneWidget);
        expect(find.text('Get token usage aggregations'), findsOneWidget);
      });

      testWidgets('renders POST /v1/alerts endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -3700));
        await tester.pump();

        expect(find.text('/v1/alerts'), findsWidgets);
        expect(find.text('Create a new alert rule'), findsOneWidget);
      });

      testWidgets('renders PUT /v1/alerts/{alertId} endpoint', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4800));
        await tester.pump();

        expect(find.text('PUT'), findsWidgets);
        expect(find.text('/v1/alerts/{alertId}'), findsWidgets);
      });

      testWidgets('renders DELETE /v1/alerts/{alertId} endpoint',
          (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4900));
        await tester.pump();

        expect(find.text('DELETE'), findsOneWidget);
        expect(find.text('Delete an alert rule'), findsOneWidget);
      });
    });

    group('tables', () {
      testWidgets('renders API Key Scopes table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();

        expect(find.text('API Key Scopes'), findsOneWidget);
        expect(find.text('Scope'), findsOneWidget);
        expect(find.text('Permissions'), findsOneWidget);
        expect(find.text('traces:write'), findsOneWidget);
        expect(find.text('traces:read'), findsOneWidget);
        expect(find.text('alerts:manage'), findsOneWidget);
        expect(find.text('admin'), findsOneWidget);
      });

      testWidgets('renders Base URLs table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pump();

        expect(find.text('Environment'), findsOneWidget);
        expect(find.text('Base URL'), findsOneWidget);
        expect(find.text('Production'), findsOneWidget);
        expect(find.text('OTLP Endpoint'), findsOneWidget);
        expect(find.text('Sandbox'), findsOneWidget);
      });

      testWidgets('renders Response Code table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1800));
        await tester.pump();

        expect(find.text('Response Code'), findsOneWidget);
        expect(find.text('200 OK'), findsOneWidget);
        expect(find.text('400 Bad Request'), findsOneWidget);
        expect(find.text('401 Unauthorized'), findsOneWidget);
        expect(find.text('429 Too Many Requests'), findsOneWidget);
      });

      testWidgets('renders Query Parameters table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2500));
        await tester.pump();

        expect(find.text('Query Parameters'), findsOneWidget);
        expect(find.text('Parameter'), findsOneWidget);
        expect(find.text('Type'), findsOneWidget);
        expect(find.text('ISO 8601'), findsWidgets);
      });

      testWidgets('renders Alert Conditions table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -4400));
        await tester.pump();

        expect(find.text('Alert Conditions'), findsOneWidget);
        expect(find.text('Operator'), findsOneWidget);
        expect(find.text('gt'), findsOneWidget);
        expect(find.text('lt'), findsOneWidget);
        expect(find.text('anomaly'), findsOneWidget);
      });

      testWidgets('renders Common Error Codes table', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -6700));
        await tester.pump();

        expect(find.text('Common Error Codes'), findsOneWidget);
        expect(find.text('Code'), findsOneWidget);
        expect(find.text('HTTP Status'), findsOneWidget);
        expect(find.text('INVALID_API_KEY'), findsOneWidget);
        expect(find.text('RATE_LIMIT_EXCEEDED'), findsOneWidget);
      });
    });

    group('SDK sections', () {
      testWidgets('renders Python SDK section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -5200));
        await tester.pump();

        expect(find.text('Python SDK'), findsOneWidget);
      });

      testWidgets('renders TypeScript SDK section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -5500));
        await tester.pump();

        expect(find.text('TypeScript SDK'), findsOneWidget);
      });

      testWidgets('renders Go SDK section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -5800));
        await tester.pump();

        expect(find.text('Go SDK'), findsOneWidget);
      });
    });

    group('callouts', () {
      testWidgets('renders API key warning callout', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pump();

        expect(
          find.textContaining('Never expose API keys'),
          findsOneWidget,
        );
        expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
      });

      testWidgets('renders Rate Limits info callout', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();

        expect(find.text('Rate Limits'), findsOneWidget);
        expect(find.textContaining('Free tier'), findsOneWidget);
        expect(find.byIcon(LucideIcons.lightbulb), findsOneWidget);
      });
    });

    group('related documentation', () {
      testWidgets('renders Getting Started Guide link', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -7200));
        await tester.pump();

        expect(find.textContaining('Getting Started Guide'), findsOneWidget);
      });

      testWidgets('renders Integrations link', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -7200));
        await tester.pump();

        expect(find.textContaining('Integrations'), findsOneWidget);
      });

      testWidgets('renders Distributed Tracing link', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -7200));
        await tester.pump();

        expect(find.textContaining('Distributed Tracing'), findsOneWidget);
      });

      testWidgets('renders OpenTelemetry Semantic Conventions link',
          (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -7200));
        await tester.pump();

        expect(find.textContaining('OpenTelemetry Semantic Conventions'),
            findsOneWidget);
      });
    });

    group('footer', () {
      test('CompanyInfo has name defined', () {
        expect(CompanyInfo.name, isNotEmpty);
        expect(CompanyInfo.name, equals('Integrity Studio'));
      });

      test('page has proper structure for footer', () {
        // Footer is included in the page structure via slivers
        // Verify content constants are available
        expect(CompanyInfo.copyright, contains('Integrity Studio'));
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<DocsApiPage>(pumpDocsApiPage);

      testWidgets('mobile viewport renders hero badge', (tester) async {
        await pumpDocsApiPage(tester, mobile: true);

        expect(find.text('REST & OTLP APIs'), findsOneWidget);
      });

      testWidgets('mobile viewport renders stat cards', (tester) async {
        await pumpDocsApiPage(tester, mobile: true);

        expect(find.text('OTLP'), findsOneWidget);
        expect(find.text('REST'), findsOneWidget);
      });

      testWidgets('desktop viewport renders all stat cards in view',
          (tester) async {
        await pumpDocsApiPage(tester, mobile: false);

        expect(find.text('OTLP'), findsOneWidget);
        expect(find.text('REST'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text('<100ms'), findsOneWidget);
      });
    });

    group('sub-sections', () {
      testWidgets('renders OTLP Ingestion sub-section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1100));
        await tester.pump();

        expect(find.text('OTLP Ingestion (Recommended)'), findsOneWidget);
      });

      testWidgets('renders REST API Ingestion sub-section', (tester) async {
        await pumpDocsApiPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1250));
        await tester.pump();

        expect(find.text('REST API Ingestion'), findsOneWidget);
      });
    });
  });
}
