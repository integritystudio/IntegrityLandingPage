import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/navigation/sub_page_shell.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:integrity_studio_ai/services/analytics.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpShell(
    WidgetTester tester, {
    VoidCallback? onBack,
    List<Widget> slivers = const [],
    bool mobile = false,
    String? analyticsPageName,
  }) async {
    if (mobile) {
      setMobileSize(tester);
    } else {
      setDesktopSize(tester);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: SubPageShell(
          onBack: onBack,
          slivers: slivers,
          analyticsPageName: analyticsPageName,
        ),
      ),
    );
    await tester.pump();
  }

  group('SubPageShell', () {
    group('structure', () {
      testWidgets('renders Scaffold', (tester) async {
        await pumpShell(tester);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders CustomScrollView', (tester) async {
        await pumpShell(tester);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('renders SelectionArea', (tester) async {
        await pumpShell(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });

      testWidgets('renders SliverAppBar', (tester) async {
        await pumpShell(tester);
        expect(find.byType(SliverAppBar), findsOneWidget);
      });

      testWidgets('renders back button in app bar', (tester) async {
        await pumpShell(tester);
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      });

      testWidgets('renders provided content slivers', (tester) async {
        await pumpShell(
          tester,
          slivers: [
            const SliverToBoxAdapter(child: Text('content-sliver')),
          ],
        );
        expect(find.text('content-sliver'), findsOneWidget);
      });

      testWidgets('renders FooterSection', (tester) async {
        await pumpShell(tester);
        expect(find.byType(FooterSection), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('back button triggers onBack callback', (tester) async {
        var called = false;
        await pumpShell(tester, onBack: () => called = true);

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(called, isTrue);
      });
    });

    group('responsive', () {
      testWidgets('renders on mobile viewport', (tester) async {
        await pumpShell(tester, mobile: true);
        expect(find.byType(SubPageShell), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        await pumpShell(tester, mobile: false);
        expect(find.byType(SubPageShell), findsOneWidget);
      });
    });

    group('analytics', () {
      setUp(() {
        AnalyticsService.enableCallLog();
      });

      tearDown(() {
        AnalyticsService.resetForTesting();
      });

      testWidgets('tracks page view when analyticsPageName is provided',
          (tester) async {
        await pumpShell(tester, analyticsPageName: 'test_page');

        expect(AnalyticsService.callLog, isNotNull);
        expect(
          AnalyticsService.callLog!.any(
            (entry) =>
                entry.event == AnalyticsEvent.pageView &&
                entry.params['page_title'] == 'test_page',
          ),
          isTrue,
        );
      });

      testWidgets('does not track page view when analyticsPageName is null',
          (tester) async {
        await pumpShell(tester);

        expect(AnalyticsService.callLog, isEmpty);
      });

      testWidgets('tracks page view only once on rebuild', (tester) async {
        await pumpShell(tester, analyticsPageName: 'test_page');

        // Trigger a rebuild by pumping again (simulates resize / setState)
        await tester.pump();

        final pageViewCount = AnalyticsService.callLog!
            .where((entry) => entry.event == AnalyticsEvent.pageView)
            .length;

        expect(pageViewCount, equals(1));
      });

      testWidgets('tracks new page view when analyticsPageName changes',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: SubPageShell(
              slivers: const [],
              analyticsPageName: 'page_a',
            ),
          ),
        );
        await tester.pump();

        // Change analyticsPageName via rebuild
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: SubPageShell(
              slivers: const [],
              analyticsPageName: 'page_b',
            ),
          ),
        );
        await tester.pump();

        final pageViews = AnalyticsService.callLog!
            .where((entry) => entry.event == AnalyticsEvent.pageView)
            .toList();

        expect(pageViews.length, equals(2));
        expect(pageViews[0].params['page_title'], equals('page_a'));
        expect(pageViews[1].params['page_title'], equals('page_b'));
      });
    });
  });
}
