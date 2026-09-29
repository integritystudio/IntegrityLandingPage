import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/widgets/navigation/shared_app_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../helpers/test_constants.dart';
import '../../helpers/test_helpers.dart';

Widget _makeApp(SharedAppBar appBar) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: CustomScrollView(
            slivers: [
              appBar,
              const SliverToBoxAdapter(child: SizedBox(height: 800)),
            ],
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: testTheme,
    routerConfig: router,
  );
}

List<NavItem> _items(int count) =>
    List.generate(count, (i) => NavItem(text: 'Item$i', onTap: () {}));

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('SharedAppBar desktop nav overflow', () {
    testWidgets('no More button with $kMaxInlineNavItems or fewer nav items', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: _items(kMaxInlineNavItems))));
      await tester.pump();

      expect(find.text('More'), findsNothing);
    });

    testWidgets('shows More button at boundary (${kMaxInlineNavItems + 1} items)', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: _items(kMaxInlineNavItems + 1))));
      await tester.pump();

      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('shows More button when nav items exceed $kMaxInlineNavItems', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
          _makeApp(SharedAppBar(navItems: _items(kMaxInlineNavItems + 2))));
      await tester.pump();

      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('inline shows first $kMaxInlineNavItems items; overflow items hidden until popup opened',
        (tester) async {
      setDesktopSize(tester);
      final navItems = _items(kMaxInlineNavItems + 2);
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: navItems)));
      await tester.pump();

      for (var i = 0; i < kMaxInlineNavItems; i++) {
        expect(find.text('Item$i'), findsOneWidget, reason: 'Item$i should be inline');
      }
      expect(find.text('Item$kMaxInlineNavItems'), findsNothing,
          reason: 'Item$kMaxInlineNavItems should be in overflow popup');
      expect(find.text('Item${kMaxInlineNavItems + 1}'), findsNothing,
          reason: 'Item${kMaxInlineNavItems + 1} should be in overflow popup');
    });

    testWidgets('overflow popup reveals extra items when opened', (tester) async {
      setDesktopSize(tester);
      final navItems = _items(kMaxInlineNavItems + 2);
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: navItems)));
      await tester.pump();

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('Item$kMaxInlineNavItems'), findsOneWidget);
      expect(find.text('Item${kMaxInlineNavItems + 1}'), findsOneWidget);
    });
  });

  group('SharedAppBar mobile nav semantics', () {
    testWidgets('hamburger menu has Navigation menu semantics label at mobile viewport',
        (tester) async {
      setMobileSize(tester);
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: _items(3))));
      await tester.pump();

      expect(
        find.bySemanticsLabel('Navigation menu'),
        findsOneWidget,
      );
    });

    testWidgets('popup menu items have Navigate to semantics labels when menu opened',
        (tester) async {
      setMobileSize(tester);
      final navItems = [
        NavItem(text: 'Features', onTap: () {}),
        NavItem(text: 'Docs', onTap: () {}),
      ];
      await tester.pumpWidget(_makeApp(SharedAppBar(navItems: navItems)));
      await tester.pump();

      // Open the popup menu
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Navigate to Features')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Navigate to Docs')), findsOneWidget);
    });
  });

  // SubPageShell renders SharedAppBar.subPage on every sub-page, so its
  // behaviour is tested once here rather than per page.
  group('SharedAppBar.subPage', () {
    // Page tests pumped desktop (pricing, status) and desktopLarge (careers,
    // request_failure, request_success); both widths are desktop layout.
    const desktopSizes = {
      'desktop': TestScreenSizes.desktop,
      'desktopLarge': TestScreenSizes.desktopLarge,
    };
    const subPageNavLabels = ['Features', 'About', 'Pricing', 'Contact', 'Docs'];

    Finder inAppBar(Finder matching) =>
        find.descendant(of: find.byType(SliverAppBar), matching: matching);

    Future<void> pumpSubPageAppBar(WidgetTester tester, Size size) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(_makeApp(SharedAppBar.subPage()));
      await tester.pump();
    }

    for (final entry in desktopSizes.entries) {
      group('on ${entry.key}', () {
        testWidgets('renders shield icon and company name in title',
            (tester) async {
          await pumpSubPageAppBar(tester, entry.value);

          expect(inAppBar(find.byIcon(LucideIcons.shield)), findsOneWidget);
          expect(inAppBar(find.text(CompanyInfo.name)), findsOneWidget);
        });

        testWidgets('renders nav links and Get Started inline, no menu',
            (tester) async {
          await pumpSubPageAppBar(tester, entry.value);

          for (final label in subPageNavLabels) {
            expect(inAppBar(find.text(label)), findsOneWidget, reason: label);
          }
          expect(inAppBar(find.text(CTAText.getStarted)), findsOneWidget);
          expect(inAppBar(find.byIcon(LucideIcons.menu)), findsNothing);
        });

        testWidgets('uses desktop toolbar height', (tester) async {
          await pumpSubPageAppBar(tester, entry.value);

          final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          expect(appBar.toolbarHeight, equals(kDesktopToolbarHeight));
        });
      });
    }

    group('on mobile', () {
      testWidgets('replaces nav links and Get Started with a popup menu',
          (tester) async {
        await pumpSubPageAppBar(tester, TestScreenSizes.mobile);

        expect(inAppBar(find.byIcon(LucideIcons.menu)), findsOneWidget);
        for (final label in subPageNavLabels) {
          expect(inAppBar(find.text(label)), findsNothing, reason: label);
        }
        expect(inAppBar(find.text(CTAText.getStarted)), findsNothing);
      });

      testWidgets('uses mobile toolbar height', (tester) async {
        await pumpSubPageAppBar(tester, TestScreenSizes.mobile);

        final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
        expect(appBar.toolbarHeight, equals(kMobileToolbarHeight));
      });
    });

    testWidgets('back button has Back tooltip', (tester) async {
      await pumpSubPageAppBar(tester, TestScreenSizes.desktopLarge);

      final backButton = tester.widget<IconButton>(
        inAppBar(find.widgetWithIcon(IconButton, LucideIcons.arrowLeft)),
      );
      expect(backButton.tooltip, equals('Back'));
    });
  });
}
