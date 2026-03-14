import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/widgets/navigation/shared_app_bar.dart';
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
}
