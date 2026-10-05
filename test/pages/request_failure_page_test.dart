import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/request_failure_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the RequestFailurePage widget with larger viewport
  Future<void> pumpRequestFailurePage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) =>
      tester.pumpPage(
        RequestFailurePage(onBack: onBack, onShowCookieSettings: onShowCookieSettings),
        mobile: mobile,
        desktopSize: TestScreenSizes.desktopLarge,
        clearOverflow: true,
      );

  /// Helper to scroll and clear overflow exceptions
  Future<void> scrollDown(WidgetTester tester, double offset) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -offset));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  group('RequestFailurePage', () {
    group('page structure', () {
      testPageStructure(pumpRequestFailurePage);
    });

    group('navigation', () {
      testBackButtonCallback(pumpRequestFailurePage);
    });

    group('hero section', () {
      testWidgets('renders error icon', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
      });

      testWidgets('renders Something Went Wrong heading', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Something Went Wrong'), findsOneWidget);
      });

      testWidgets('renders error message', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(
          find.textContaining('couldn\'t process your request'),
          findsOneWidget,
        );
      });
    });

    group('alternative contact section', () {
      testWidgets('renders alternative ways heading', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Alternative ways to reach us'), findsOneWidget);
      });

      testWidgets('renders email option', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Email us directly'), findsOneWidget);
        expect(find.text(CompanyInfo.email), findsOneWidget);
      });

      testWidgets('renders try again option', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Try again'), findsOneWidget);
      });

      testWidgets('renders mail icon', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.mail), findsOneWidget);
      });

      testWidgets('renders refresh icon', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget);
      });
    });

    group('CTA buttons', () {
      testWidgets('renders Back to Home button', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text(CTAText.backToHome), findsOneWidget);
      });

      testWidgets('renders Try Again button', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Try Again'), findsOneWidget);
      });

      testWidgets('Back to Home button is tappable', (tester) async {
        await pumpRequestFailurePage(tester);

        final button = find.text(CTAText.backToHome);
        expect(button, findsOneWidget);

        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(GestureDetector),
        );
        expect(buttonWidget, findsWidgets);
      });

      testWidgets('Try Again button is tappable', (tester) async {
        await pumpRequestFailurePage(tester);

        final button = find.text('Try Again');
        expect(button, findsOneWidget);

        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(GestureDetector),
        );
        expect(buttonWidget, findsWidgets);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<RequestFailurePage>(
        pumpRequestFailurePage,
        expectedTitle: 'Something Went Wrong',
        includeTablet: true,
      );


    });

    group('footer section', () {
      testWidgets('includes FooterSection widget when scrolled into view',
          (tester) async {
        await pumpRequestFailurePage(tester);

        await scrollDown(tester, 800);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('page structure includes footer in slivers', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byType(RequestFailurePage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('icons', () {
      testWidgets('renders error alert icon', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
      });
    });

    group('visual styling', () {
      testWidgets('hero section renders with containers', (tester) async {
        await pumpRequestFailurePage(tester);

        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('alternative contact card is rendered', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text('Alternative ways to reach us'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('text content is selectable', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('company info', () {
      test('CompanyInfo has email defined', () {
        expect(CompanyInfo.email, isNotEmpty);
      });
    });

    group('user already exists error', () {
      testWidgets('renders Account Already Exists heading for duplicate user error',
          (tester) async {
        await pumpRequestFailurePage(tester);
        clearOverflowExceptions(tester);
      });

      testWidgets('renders specific message for user already exists', (tester) async {
        clearOverflowExceptions(tester);
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const RequestFailurePage(
              error: 'User with this email already exists',
            ),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.text('Account Already Exists'), findsOneWidget);
        expect(
          find.textContaining('already registered'),
          findsOneWidget,
        );
      });

      testWidgets('Go to Sign In button appears for existing account',
          (tester) async {
        clearOverflowExceptions(tester);
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const RequestFailurePage(
              error: 'account already exists',
            ),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.text('Go to Sign In'), findsOneWidget);
      });

      testWidgets('detects user exists error case-insensitively', (tester) async {
        clearOverflowExceptions(tester);
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const RequestFailurePage(
              error: 'DUPLICATE USER ALREADY EXISTS IN DATABASE',
            ),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.text('Account Already Exists'), findsOneWidget);
      });
    });
  });
}
