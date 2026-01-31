import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/pages/sources_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';
import '../helpers/test_helpers.dart';

/// Matcher that validates a string is a valid URL with http/https scheme.
final isValidUrl = predicate<String?>(
  (url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  },
  'is a valid URL',
);

void main() {

  group('SourcesPage', () {
    group('content models', () {
      test('CitedStatistic creates with all required fields', () {
        const stat = CitedStatistic(
          value: '73%',
          label: 'faster debugging',
          source: 'Customer data, Q4 2024',
          type: StatisticType.customerData,
        );

        expect(stat.value, equals('73%'));
        expect(stat.label, equals('faster debugging'));
        expect(stat.source, equals('Customer data, Q4 2024'));
        expect(stat.type, equals(StatisticType.customerData));
        expect(stat.sourceUrl, isNull);
      });

      test('CitedStatistic creates with optional sourceUrl', () {
        const stat = CitedStatistic(
          value: '\$2.9B+',
          label: 'market by 2030',
          source: 'Grand View Research, 2024',
          sourceUrl: 'https://example.com/report',
          type: StatisticType.industry,
        );

        expect(stat.sourceUrl, equals('https://example.com/report'));
      });

      test('StatisticType has all expected values', () {
        expect(StatisticType.values.length, equals(4));
        expect(StatisticType.values, contains(StatisticType.industry));
        expect(StatisticType.values, contains(StatisticType.customerData));
        expect(StatisticType.values, contains(StatisticType.platformMetric));
        expect(StatisticType.values, contains(StatisticType.slaTarget));
      });
    });

    group('AppStatistics content', () {
      test('has industry statistics with sources', () {
        final stats = AppStatistics.industryStats;
        expect(stats, isNotEmpty);
        expect(stats.length, equals(3));

        for (final stat in stats) {
          expect(stat.type, equals(StatisticType.industry));
          expect(stat.source, isNotEmpty);
        }
      });

      test('industry statistics have source URLs', () {
        final stats = AppStatistics.industryStats;
        for (final stat in stats) {
          expect(stat.sourceUrl, isNotNull);
          expect(stat.sourceUrl, startsWith('https://'));
        }
      });

      test('has customer statistics', () {
        final stats = AppStatistics.customerStats;
        expect(stats, isNotEmpty);
        expect(stats.length, equals(2));

        for (final stat in stats) {
          expect(stat.type, equals(StatisticType.customerData));
        }
      });

      test('customer statistics do not have external URLs', () {
        final stats = AppStatistics.customerStats;
        for (final stat in stats) {
          expect(stat.sourceUrl, isNull);
        }
      });

      test('has platform metrics', () {
        expect(AppStatistics.tracesProcessed.type, equals(StatisticType.platformMetric));
        expect(AppStatistics.setupTime.type, equals(StatisticType.platformMetric));
      });

      test('has SLA targets', () {
        expect(AppStatistics.uptimeTarget.type, equals(StatisticType.slaTarget));
        expect(AppStatistics.uptimeTarget.value, equals('99.9%'));
      });

      test('has source disclaimer text', () {
        expect(AppStatistics.sourceDisclaimer, isNotEmpty);
        expect(AppStatistics.sourceDisclaimer, contains('aggregated'));
        expect(AppStatistics.sourceDisclaimer, contains('anonymized'));
      });

      test('debugging improvement statistic has correct values', () {
        expect(AppStatistics.debuggingImprovement.value, equals('73%'));
        expect(AppStatistics.debuggingImprovement.label, equals('faster debugging'));
        expect(AppStatistics.debuggingImprovement.type, equals(StatisticType.customerData));
      });

      test('cost reduction statistic has correct values', () {
        expect(AppStatistics.costReduction.value, equals('30-50%'));
        expect(AppStatistics.costReduction.label, contains('cost reduction'));
      });

      test('market size statistic has external source', () {
        expect(AppStatistics.marketSize.source, isNotEmpty);
        expect(AppStatistics.marketSize.sourceUrl, isNotNull);
        expect(AppStatistics.marketSize.sourceUrl, isNotEmpty);
        expect(AppStatistics.marketSize.sourceUrl, isValidUrl);
      });
    });

    group('widget rendering', () {
      testWidgets('renders hero section with title', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Sources & Citations'), findsWidgets);
      });

      testWidgets('renders transparency badge', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Transparency & Accountability'), findsOneWidget);
        expect(find.byIcon(LucideIcons.fileCheck), findsWidgets);
      });

      testWidgets('renders industry statistics section', (tester) async {
        setScreenSize(tester, const Size(1440, 2000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Industry Statistics'), findsOneWidget);
        // Text appears in section subtitle and methodology card
        expect(find.textContaining('third-party research'), findsWidgets);
      });

      testWidgets('renders customer results section', (tester) async {
        setScreenSize(tester, const Size(1440, 2000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Customer Results'), findsOneWidget);
        expect(find.textContaining('Aggregated and anonymized'), findsOneWidget);
      });

      testWidgets('renders platform metrics section', (tester) async {
        setScreenSize(tester, const Size(1440, 2500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Platform Metrics appears as section header and in methodology
        expect(find.text('Platform Metrics'), findsWidgets);
      });

      testWidgets('renders SLA commitments section', (tester) async {
        setScreenSize(tester, const Size(1440, 2500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Service Level Commitments'), findsOneWidget);
      });

      testWidgets('renders methodology section', (tester) async {
        setScreenSize(tester, const Size(1440, 3500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.dragUntilVisible(
          find.text('Methodology'),
          find.byType(CustomScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        expect(find.text('Methodology'), findsOneWidget);
      });

      testWidgets('renders methodology cards', (tester) async {
        setScreenSize(tester, const Size(1440, 4000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.dragUntilVisible(
          find.text('Customer Data Collection'),
          find.byType(CustomScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        expect(find.text('Customer Data Collection'), findsOneWidget);
        expect(find.text('Industry Statistics'), findsWidgets);
        expect(find.text('Platform Metrics'), findsWidgets);
        expect(find.text('SLA Commitments'), findsOneWidget);
      });

      testWidgets('renders statistic values', (tester) async {
        setScreenSize(tester, const Size(1440, 2000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Check for market size statistic (values come from content.yaml)
        expect(find.text(Content.statisticsMarketSizeValue), findsOneWidget);
        expect(find.text(Content.statisticsMarketGrowthValue), findsOneWidget);
        expect(find.text(Content.statisticsEnterpriseBudgetsValue), findsOneWidget);
      });

      testWidgets('renders customer statistic values', (tester) async {
        setScreenSize(tester, const Size(1440, 2500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('73%'), findsOneWidget);
        expect(find.text('30-50%'), findsOneWidget);
      });

      testWidgets('renders source labels', (tester) async {
        setScreenSize(tester, const Size(1440, 2000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('INDUSTRY REPORT'), findsWidgets);
      });

      testWidgets('renders contact section', (tester) async {
        setScreenSize(tester, const Size(1440, 4500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.dragUntilVisible(
          find.text('Questions about our data?'),
          find.byType(CustomScrollView),
          const Offset(0, -500),
        );
        await tester.pump();

        expect(find.text('Questions about our data?'), findsOneWidget);
        expect(find.textContaining(CompanyInfo.email), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('calls onBack callback when back button pressed', (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: SourcesPage(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('calls onBack when Back to Home pressed', (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: SourcesPage(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Back to Home'));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('renders app bar with title', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(SliverAppBar), findsOneWidget);
        expect(find.text('Sources & Citations'), findsWidgets);
      });
    });

    group('responsive design', () {
      testWidgets('renders correctly on mobile', (tester) async {
        setMobileSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(SourcesPage), findsOneWidget);
      });

      testWidgets('renders correctly on tablet', (tester) async {
        setTabletSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(SourcesPage), findsOneWidget);
      });

      testWidgets('renders correctly on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(SourcesPage), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('has section icons', (tester) async {
        setScreenSize(tester, const Size(1440, 2500));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Section icons should be present (may need scrolling)
        expect(find.byIcon(LucideIcons.barChart2), findsWidgets);
        expect(find.byIcon(LucideIcons.users), findsWidgets);
      });

      testWidgets('source URLs are selectable', (tester) async {
        setScreenSize(tester, const Size(1440, 2000));

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const SourcesPage(),
          ),
        );
        await tester.pump();
        await tester.pump();

        // SelectableText widgets should be present for URLs
        expect(find.byType(SelectableText), findsWidgets);
      });
    });
  });

  group('Routes.sources', () {
    test('sources route is defined', () {
      expect(Routes.sources, equals('/sources'));
    });

    test('sources route follows convention', () {
      expect(Routes.sources, startsWith('/'));
      expect(Routes.sources.contains(' '), isFalse);
    });
  });
}
