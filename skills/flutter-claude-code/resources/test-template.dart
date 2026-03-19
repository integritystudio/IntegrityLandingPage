// Standard widget test template for IntegrityLandingPage
// Copy and adapt for each new widget test file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../../test/helpers/test_helpers.dart';

void main() {
  group('WidgetName', () {
    late Widget widget;

    setUpAll(() {
      widget = MaterialApp(home: Scaffold(body: WidgetName()));
    });

    setUp(() {
      setUpOverflowErrorSuppression();
      IntegrationMocks.resetAll();
    });

    tearDown(() {
      tearDownOverflowErrorSuppression();
    });

    group('desktop', () {
      Future<void> pumpDesktop(WidgetTester tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(widget);
        await tester.pump();
      }

      testWidgets('renders heading', (tester) async {
        await pumpDesktop(tester);
        expect(find.text('Expected Text'), findsOneWidget);
      });
    });

    group('mobile', () {
      Future<void> pumpMobile(WidgetTester tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(widget);
        await tester.pump();
      }

      testWidgets('renders on mobile', (tester) async {
        await pumpMobile(tester);
        expect(find.byType(WidgetName), findsOneWidget);
      });
    });
  });
}
