import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/eu_ai_act_page.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpEuAiActPage(
    WidgetTester tester, {
    VoidCallback? onBack,
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
        home: EuAiActPage(onBack: onBack),
      ),
    );
    await tester.pump();
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  group('EuAiActPage', () {
    group('page structure', () {
      testPageStructure(pumpEuAiActPage);

      testWidgets('renders page title in app bar', (tester) async {
        await pumpEuAiActPage(tester);

        expect(find.text('EU AI Act Compliance'), findsWidgets);
      });

      testWidgets('renders Back to Compliance text button', (tester) async {
        await pumpEuAiActPage(tester);

        expect(find.text('Back to Compliance'), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpEuAiActPage);
    });

    group('hero section', () {
      testWidgets('renders EU regulation badge', (tester) async {
        await pumpEuAiActPage(tester);

        expect(find.text('EU Regulation 2024/1689'), findsOneWidget);
      });

      testWidgets('renders scale icon in badge', (tester) async {
        await pumpEuAiActPage(tester);

        expect(find.byIcon(LucideIcons.scale), findsOneWidget);
      });

      testWidgets('renders headline', (tester) async {
        await pumpEuAiActPage(tester);

        expect(find.text('EU AI Act Observability Requirements'), findsOneWidget);
      });

      testWidgets('renders timeline cards', (tester) async {
        await pumpEuAiActPage(tester);

        // Dates appear in both timeline cards and overview table
        expect(find.text('Aug 2024'), findsWidgets);
        expect(find.text('Act in Force'), findsOneWidget);
        expect(find.text('Aug 2025'), findsWidgets);
        expect(find.text('GPAI Obligations'), findsOneWidget);
        expect(find.text('Aug 2026'), findsWidgets);
        expect(find.text('High-Risk Requirements'), findsOneWidget);
      });
    });

    group('content sections', () {
      testWidgets('renders Overview section', (tester) async {
        await pumpEuAiActPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();

        expect(find.text('Overview'), findsOneWidget);
      });

      testWidgets('renders GPAI Requirements section', (tester) async {
        await pumpEuAiActPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
        await tester.pump();

        expect(find.text('General-Purpose AI (GPAI) Requirements'), findsOneWidget);
      });

      testWidgets('renders Compliance Checklist section', (tester) async {
        await pumpEuAiActPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
        await tester.pump();

        expect(find.text('Compliance Checklist'), findsOneWidget);
      });

      testWidgets('renders Penalties section', (tester) async {
        await pumpEuAiActPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -4500));
        await tester.pump();

        expect(find.text('Penalties'), findsOneWidget);
      });
    });

    group('footer', () {
      testWidgets('renders copyright', (tester) async {
        await pumpEuAiActPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
        await tester.pump();

        expect(find.textContaining('Integrity Studio'), findsWidgets);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<EuAiActPage>(pumpEuAiActPage);
    });
  });
}
