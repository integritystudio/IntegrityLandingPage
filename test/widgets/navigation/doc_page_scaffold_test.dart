import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/navigation/doc_page_scaffold.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpScaffold(
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
        home: DocsPageScaffold(
          title: 'Test Docs',
          heroBuilder: (isMobile) => Text(isMobile ? 'hero-mobile' : 'hero-desktop'),
          content: const Text('page content'),
          onBack: onBack,
        ),
      ),
    );
    await tester.pump();
  }

  group('DocsPageScaffold', () {
    group('basic structure', () {
      testWidgets('renders title in app bar', (tester) async {
        await pumpScaffold(tester);
        expect(find.text('Test Docs'), findsOneWidget);
      });

      testWidgets('renders content widget', (tester) async {
        await pumpScaffold(tester);
        expect(find.text('page content'), findsOneWidget);
      });

      testWidgets('renders Back to Home action in app bar', (tester) async {
        await pumpScaffold(tester);
        expect(find.text('Back to Home'), findsOneWidget);
      });

      testWidgets('content is wrapped in 900px ConstrainedBox', (tester) async {
        await pumpScaffold(tester);
        final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
        final contentBox = boxes.where(
          (b) => b.constraints.maxWidth == 900,
        );
        expect(contentBox, isNotEmpty);
      });

      testWidgets('renders DocPageFooter', (tester) async {
        await pumpScaffold(tester);
        expect(find.byType(DocPageFooter), findsOneWidget);
      });
    });

    group('heroBuilder isMobile callback', () {
      testWidgets('passes isMobile=false at desktop width', (tester) async {
        await pumpScaffold(tester);
        expect(find.text('hero-desktop'), findsOneWidget);
        expect(find.text('hero-mobile'), findsNothing);
      });

      testWidgets('passes isMobile=true at mobile width', (tester) async {
        await pumpScaffold(tester, mobile: true);
        expect(find.text('hero-mobile'), findsOneWidget);
        expect(find.text('hero-desktop'), findsNothing);
      });
    });

    group('onBack callback', () {
      testWidgets('back arrow button invokes onBack', (tester) async {
        var called = false;
        await pumpScaffold(tester, onBack: () => called = true);
        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();
        expect(called, isTrue);
      });

      testWidgets('Back to Home text button invokes onBack', (tester) async {
        var called = false;
        await pumpScaffold(tester, onBack: () => called = true);
        await tester.tap(find.text('Back to Home'));
        await tester.pump();
        expect(called, isTrue);
      });
    });

    group('background', () {
      testWidgets('scaffold uses gray900 background', (tester) async {
        await pumpScaffold(tester);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, equals(AppColors.gray900));
      });
    });
  });
}
