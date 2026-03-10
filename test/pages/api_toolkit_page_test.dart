import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/api_toolkit_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';
import '../helpers/test_constants.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpApiToolkitPage(
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
        home: ApiToolkitPage(onBack: onBack),
      ),
    );
    await tester.pump();
  }

  group('ApiToolkitPage', () {
    group('page structure', () {
      testPageStructure(pumpApiToolkitPage);

      testWidgets('renders page title in app bar', (tester) async {
        await pumpApiToolkitPage(tester);

        expect(find.text('MCP Toolkit API'), findsWidgets);
      });

      testWidgets('renders Back to Docs text button', (tester) async {
        await pumpApiToolkitPage(tester);

        expect(find.text('Back to Docs'), findsOneWidget);
      });
    });

    group('navigation', () {
      testWidgets('calls onBack when back arrow tapped', (tester) async {
        var callCount = 0;
        await pumpApiToolkitPage(tester, onBack: () => callCount++);

        await tester.tap(find.byIcon(LucideIcons.arrowLeft).first);
        await tester.pump();

        expect(callCount, 1);
      });

      testWidgets('calls onBack when Back to Docs tapped', (tester) async {
        var callCount = 0;
        await pumpApiToolkitPage(tester, onBack: () => callCount++);

        await tester.tap(find.text('Back to Docs'));
        await tester.pump();

        expect(callCount, 1);
      });
    });
  });
}
