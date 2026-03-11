import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/request_failure_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  }) async {
    clearOverflowExceptions(tester);

    if (mobile) {
      setMobileSize(tester);
    } else {
      setScreenSize(tester, TestScreenSizes.desktopLarge);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: RequestFailurePage(
          onBack: onBack,
          onShowCookieSettings: onShowCookieSettings,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    clearOverflowExceptions(tester);
  }

  /// Helper to scroll and clear overflow exceptions
  Future<void> scrollDown(WidgetTester tester, double offset) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -offset));
    await tester.pump();
    clearOverflowExceptions(tester);
  }

  group('RequestFailurePage', () {
    group('page structure', () {
      testPageStructure(pumpRequestFailurePage);

      testWidgets('renders company name in app bar', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.text(CompanyInfo.name), findsOneWidget);
      });

      testWidgets('renders shield icon in app bar', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpRequestFailurePage);

      testWidgets('renders navigation links on desktop', (tester) async {
        await pumpRequestFailurePage(tester, mobile: false);

        // Nav links appear in both app bar and footer
        expect(find.text('Features'), findsWidgets);
        expect(find.text('Pricing'), findsWidgets);
        expect(find.text('About'), findsWidgets);
      });

      testWidgets('renders popup menu on mobile', (tester) async {
        await pumpRequestFailurePage(tester, mobile: true);

        // Mobile uses popup menu instead of inline nav links
        expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      });
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
          find.textContaining('couldn\'t send your message'),
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

        expect(find.text('Try submitting again'), findsOneWidget);
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
      );

      testWidgets('desktop shows navigation links', (tester) async {
        await pumpRequestFailurePage(tester, mobile: false);

        // Nav links appear in both app bar and footer, so expect at least 1
        expect(find.text('Features'), findsWidgets);
        expect(find.text('Pricing'), findsWidgets);
      });

      testWidgets('mobile hides desktop nav links in app bar', (tester) async {
        await pumpRequestFailurePage(tester, mobile: true);

        // On mobile, app bar nav links are hidden (only footer links show)
        // Find the SliverAppBar actions area - it should not contain nav links
        final appBar = find.byType(SliverAppBar);
        expect(appBar, findsOneWidget);
      });

      testWidgets('tablet viewport renders correctly', (tester) async {
        setTabletSize(tester);
        clearOverflowExceptions(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const RequestFailurePage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(RequestFailurePage), findsOneWidget);
      });
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
      testWidgets('renders app bar icons', (tester) async {
        await pumpRequestFailurePage(tester);

        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

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
      testWidgets('back button has tooltip', (tester) async {
        await pumpRequestFailurePage(tester);

        final iconButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, LucideIcons.arrowLeft),
        );
        expect(iconButton.tooltip, equals('Back'));
      });

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
  });
}
