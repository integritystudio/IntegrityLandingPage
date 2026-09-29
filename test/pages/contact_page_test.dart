import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/contact_content.dart';
import 'package:integrity_studio_ai/pages/contact_page.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_pill_badge.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:integrity_studio_ai/widgets/sections/marketing_hero_section.dart';
import '../helpers/test_constants.dart';
import '../helpers/test_content.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
  });
  tearDown(tearDownOverflowErrorSuppression);

  Future<void> pumpContactPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) =>
      tester.pumpPage(
        ContactPage(onBack: onBack, onShowCookieSettings: onShowCookieSettings),
        mobile: mobile,
        clearOverflow: true,
      );

  group('ContactPage', () {
    group('constructor', () {
      testWidgets('creates with default parameters', (tester) async {
        await pumpContactPage(tester);
        expect(find.byType(ContactPage), findsOneWidget);
      });

      testWidgets('creates with onBack callback', (tester) async {
        await pumpContactPage(tester, onBack: () {});
        expect(find.byType(ContactPage), findsOneWidget);
      });

      testWidgets('creates with onShowCookieSettings callback', (tester) async {
        await pumpContactPage(tester, onShowCookieSettings: () {});
        expect(find.byType(ContactPage), findsOneWidget);
      });
    });

    group('layout', () {
      testPageStructure(pumpContactPage);

      testWidgets('renders SelectionArea for text selection', (tester) async {
        await pumpContactPage(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpContactPage);
    });

    group('hero section', () {
      testWidgets('displays badge with We\'re Here to Help label', (tester) async {
        await pumpContactPage(tester);
        expect(find.byType(GradientPillBadge), findsOneWidget);
        expect(find.text(ContactContentVariants.heroBadge), findsOneWidget);
      });

      // contact.title is "Get in Touch" too, so the hero is rendered under a headline of
      // its own; counting "Get in Touch" cannot tell which key the hero reads.
      testWidgets('headlines the hero with contact.hero_headline', (tester) async {
        const heroHeadline = 'Talk to Us';
        withContent(await realContentWith('hero_headline: "Get in Touch"', 'hero_headline: "$heroHeadline"'));
        await pumpContactPage(tester);
        expect(
          find.descendant(of: find.byType(MarketingHeroSection), matching: find.text(heroHeadline)),
          findsOneWidget,
        );
      });

      testWidgets('displays subheadline about AI observability', (tester) async {
        await pumpContactPage(tester);
        expect(
          find.text(ContactContentVariants.heroSubheadline),
          findsOneWidget,
        );
      });
    });

    group('quick contact section', () {
      testWidgets('displays Email Us card', (tester) async {
        await pumpContactPage(tester);
        expect(find.text('Email Us'), findsOneWidget);
      });

      testWidgets('displays Schedule a Demo card', (tester) async {
        await pumpContactPage(tester);
        expect(find.text('Schedule a Demo'), findsNWidgets(2));
      });
    });

    group('support info section', () {
      testWidgets('displays Support Information heading', (tester) async {
        await pumpContactPage(tester);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump();
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.text('Support Information'), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('renders FooterSection', (tester) async {
        await pumpContactPage(tester);

        await tester.drag(find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('passes onShowCookieSettings to footer', (tester) async {
        await pumpContactPage(tester, onShowCookieSettings: () {});

        await tester.drag(find.byType(CustomScrollView), kScrollToPricingOffset);
        await tester.pump();
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(FooterSection), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<ContactPage>(pumpContactPage, includeTablet: true);
    });
  });
}
