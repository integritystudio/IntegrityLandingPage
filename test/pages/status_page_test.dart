import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/pages/status_page.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:integrity_studio_ai/widgets/common/chip_badge.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_constants.dart';

void main() {
  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
  });
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpStatusPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) async {
    clearOverflowExceptions(tester);
    if (mobile) {
      setMobileSize(tester);
    } else {
      setDesktopSize(tester);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: StatusPage(
          onBack: onBack,
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  Future<void> pumpStatusPageWithRouter(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
  }) async {
    setDesktopSize(tester);
    clearOverflowExceptions(tester);

    final router = GoRouter(
      initialLocation: '/status',
      routes: [
        GoRoute(
          path: '/status',
          builder: (_, __) => StatusPage(
            onBack: onBack,
            onShowCookieSettings: onShowCookieSettings,
          ),
        ),
        GoRoute(
          path: '/',
          builder: (_, __) =>
              const Scaffold(body: Text('home_page')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: testTheme,
        routerConfig: router,
      ),
    );
    await tester.pump();
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  group('StatusPage', () {
    group('constructor', () {
      testWidgets('creates with default parameters', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byType(StatusPage), findsOneWidget);
      });

      testWidgets('creates with onBack callback', (tester) async {
        await pumpStatusPage(tester, onBack: () {});
        expect(find.byType(StatusPage), findsOneWidget);
      });

      testWidgets('creates with onShowCookieSettings callback', (tester) async {
        await pumpStatusPage(tester, onShowCookieSettings: () {});
        expect(find.byType(StatusPage), findsOneWidget);
      });
    });

    group('layout', () {
      testPageStructure(pumpStatusPage);

      testWidgets('renders SelectionArea for text selection', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('app bar', () {
      testWidgets('renders back button icon', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
      });

      testWidgets('back button triggers onBack callback', (tester) async {
        var called = false;
        await pumpStatusPage(tester, onBack: () => called = true);
        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();
        expect(called, isTrue);
      });

      testWidgets('back button navigates to / when no onBack provided',
          (tester) async {
        await pumpStatusPageWithRouter(tester);
        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();
        await tester.pump();
        expect(find.text('home_page'), findsOneWidget);
      });

      testWidgets('title tap navigates to home', (tester) async {
        await pumpStatusPageWithRouter(tester);
        // The GestureDetector wrapping the logo title navigates to '/'
        // Find it via its Semantics wrapper
        final semantics = find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.label == 'Navigate to home');
        expect(semantics, findsOneWidget);
        await tester.tap(semantics);
        await tester.pump();
        await tester.pump();
        expect(find.text('home_page'), findsOneWidget);
      });

      testWidgets('renders shield icon in app bar title', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byIcon(LucideIcons.shield), findsWidgets);
      });

      testWidgets('renders different toolbar heights on mobile vs desktop',
          (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const StatusPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.toolbarHeight, equals(kMobileToolbarHeight));
      });
    });

    group('hero section', () {
      testWidgets('renders hero status badge', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byType(ChipBadge), findsWidgets);
      });

      testWidgets('renders checkCircle icon in hero badge', (tester) async {
        await pumpStatusPage(tester);
        expect(find.byIcon(LucideIcons.checkCircle), findsWidgets);
      });
    });

    group('metrics section', () {
      testWidgets('renders metric cards', (tester) async {
        await pumpStatusPage(tester);
        // Metrics section contains value text from content
        // At least one metric card should be visible
        expect(find.byType(Wrap), findsWidgets);
      });
    });

    group('services section', () {
      testWidgets('renders Service Status heading', (tester) async {
        await pumpStatusPage(tester);
        expect(find.text('Service Status'), findsOneWidget);
      });

      testWidgets('renders service rows from content', (tester) async {
        await pumpStatusPage(tester);
        // Service rows have checkCircle icons for operational services
        expect(find.byIcon(LucideIcons.checkCircle), findsWidgets);
      });
    });

    group('developer appendix section', () {
      Future<void> scrollToDevAppendix(WidgetTester tester) async {
        // Keep scrolling until Developer Documentation is visible
        for (var i = 0; i < kMaxDevAppendixScrolls; i++) {
          await tester.drag(find.byType(CustomScrollView), kScrollToDevAppendixOffset);
          await tester.pump();
          clearOverflowExceptions(tester);
          if (find.text('Developer Documentation').evaluate().isNotEmpty) break;
        }
      }

      testWidgets('renders Developer Documentation header collapsed',
          (tester) async {
        await pumpStatusPage(tester);
        await scrollToDevAppendix(tester);

        expect(find.text('Developer Documentation'), findsOneWidget);
      });

      testWidgets('expands developer appendix on tap', (tester) async {
        await pumpStatusPage(tester);
        await scrollToDevAppendix(tester);

        expect(find.text('Developer Documentation'), findsOneWidget);

        // Tap to expand
        await tester.tap(find.text('Developer Documentation'));
        await tester.pump();
        clearOverflowExceptions(tester);

        // After expanding, technical details become visible
        expect(find.text('Architecture Diagram'), findsOneWidget);
      });

      testWidgets('collapses developer appendix on second tap', (tester) async {
        await pumpStatusPage(tester);
        await scrollToDevAppendix(tester);

        // Expand
        await tester.tap(find.text('Developer Documentation'));
        await tester.pump();
        clearOverflowExceptions(tester);
        expect(find.text('Architecture Diagram'), findsOneWidget);

        // Scroll back to make the header visible again after expansion
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, 200));
        await tester.pump();
        clearOverflowExceptions(tester);

        // Collapse
        await tester.tap(find.text('Developer Documentation'));
        await tester.pump();
        clearOverflowExceptions(tester);
        expect(find.text('Architecture Diagram'), findsNothing);
      });
    });

    group('footer section', () {
      testWidgets('renders FooterSection', (tester) async {
        await pumpStatusPage(tester);

        await tester.drag(
            find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('passes onShowCookieSettings to footer', (tester) async {
        await pumpStatusPage(tester, onShowCookieSettings: () {});

        await tester.drag(
            find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<StatusPage>(pumpStatusPage, includeTablet: true);

      testWidgets('uses mobile toolbar height on narrow viewport',
          (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const StatusPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.toolbarHeight, equals(kMobileToolbarHeight));
      });

      testWidgets('uses desktop toolbar height on wide viewport',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const StatusPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.toolbarHeight, equals(kDesktopToolbarHeight));
      });
    });
  });
}
