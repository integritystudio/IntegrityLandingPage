import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/api_toolkit_page.dart';
import 'package:flutter/material.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the ApiToolkitPage widget.
  Future<void> pumpApiToolkitPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) =>
      tester.pumpPage(ApiToolkitPage(onBack: onBack), mobile: mobile, frames: 1);

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
      testBackButtonCallbacks(
        pumpApiToolkitPage,
        backButtonText: 'Back to Docs',
      );
    });

    group('responsive layout', () {
      testResponsiveLayout<ApiToolkitPage>(pumpApiToolkitPage);
    });
  });
}
