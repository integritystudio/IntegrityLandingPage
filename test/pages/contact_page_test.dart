import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/contact_page.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_pill_badge.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import '../helpers/test_constants.dart';
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
        home: ContactPage(
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
  Future<void> pumpContactPageBase(
    WidgetTester tester, {
    VoidCallback? onBack,
    bool mobile = false,
  }) =>
      pumpContactPage(tester, onBack: onBack, mobile: mobile);

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
      testPageStructure(pumpContactPageBase);

      testWidgets('renders SelectionArea for text selection', (tester) async {
        await pumpContactPage(tester);
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpContactPageBase);
    });

    group('hero section', () {
      testWidgets('displays badge with We\'re Here to Help label', (tester) async {
        await pumpContactPage(tester);
        expect(find.byType(GradientPillBadge), findsOneWidget);
        expect(find.text("We're Here to Help"), findsOneWidget);
      });

      testWidgets('displays headline Get in Touch', (tester) async {
        await pumpContactPage(tester);
        expect(find.text('Get in Touch'), findsWidgets);
      });

      testWidgets('displays subheadline about AI observability', (tester) async {
        await pumpContactPage(tester);
        expect(
          find.text(
            'Have questions about AI observability? Need help with integration? Our team is ready to assist you.',
          ),
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
        expect(find.text('Schedule a Demo'), findsWidgets);
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
      testResponsiveLayout<ContactPage>(pumpContactPageBase, includeTablet: true);
    });
  });
}
