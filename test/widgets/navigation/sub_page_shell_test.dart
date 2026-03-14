import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/navigation/sub_page_shell.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpShell(
    WidgetTester tester, {
    VoidCallback? onBack,
    List<Widget> slivers = const [],
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
        home: SubPageShell(
          onBack: onBack,
          slivers: slivers,
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
  });
}
