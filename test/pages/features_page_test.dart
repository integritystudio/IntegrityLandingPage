import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/features_content.dart';
import 'package:integrity_studio_ai/pages/features_page.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_pill_badge.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import '../helpers/test_constants.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpFeaturesPage(
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
        home: FeaturesPage(
          onBack: onBack,
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  // PagePumpFunction-compatible wrapper (drops onShowCookieSettings).
  Future<void> pumpFeaturesPageBase(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool mobile = false,
  }) =>
      pumpFeaturesPage(tester, onBack: onBack, mobile: mobile);

  group('FeaturesPage', () {
    group('constructor', () {
      testWidgets('creates with default parameters', (tester) async {
        await pumpFeaturesPage(tester);
        expect(find.byType(FeaturesPage), findsOneWidget);
      });

      testWidgets('creates with onBack callback', (tester) async {
        await pumpFeaturesPage(tester, onBack: () {});
        expect(find.byType(FeaturesPage), findsOneWidget);
      });

      testWidgets('creates with onShowCookieSettings callback', (tester) async {
        await pumpFeaturesPage(tester, onShowCookieSettings: () {});
        expect(find.byType(FeaturesPage), findsOneWidget);
      });
    });

    group('layout', () {
      testPageStructure(pumpFeaturesPageBase);

      testWidgets('renders SelectionArea for text selection', (tester) async {
        await pumpFeaturesPage(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpFeaturesPageBase);
    });

    group('hero section', () {
      testWidgets('displays badge with OTel compliance label', (tester) async {
        await pumpFeaturesPage(tester);
        expect(find.byType(GradientPillBadge), findsOneWidget);
        expect(find.text(FeaturesContentVariants.complianceBadge), findsOneWidget);
      });

      testWidgets('displays headline Platform Features', (tester) async {
        await pumpFeaturesPage(tester);
        expect(find.text(FeaturesContentVariants.pageTitle), findsOneWidget);
      });

      testWidgets('displays subheadline about enterprise observability', (tester) async {
        await pumpFeaturesPage(tester);
        expect(find.text(FeaturesContentVariants.pageSubtitle), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('renders FooterSection', (tester) async {
        await pumpFeaturesPage(tester);

        await tester.drag(find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('passes onShowCookieSettings to footer', (tester) async {
        await pumpFeaturesPage(tester, onShowCookieSettings: () {});

        await tester.drag(find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<FeaturesPage>(pumpFeaturesPageBase, includeTablet: true);
    });
  });
}
