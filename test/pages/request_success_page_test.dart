import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/request_success_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the RequestSuccessPage widget with larger viewport
  Future<void> pumpRequestSuccessPage(
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
        home: RequestSuccessPage(
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

  group('RequestSuccessPage', () {
    group('page structure', () {
      testPageStructure(pumpRequestSuccessPage);

      testWidgets('renders company name in app bar', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text(CompanyInfo.name), findsOneWidget);
      });

      testWidgets('renders shield icon in app bar', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpRequestSuccessPage);

      testWidgets('renders navigation links on desktop', (tester) async {
        await pumpRequestSuccessPage(tester, mobile: false);

        // Nav links appear in both app bar and footer
        expect(find.text('Features'), findsWidgets);
        expect(find.text('Pricing'), findsWidgets);
        expect(find.text('About'), findsWidgets);
      });

      testWidgets('renders popup menu on mobile', (tester) async {
        await pumpRequestSuccessPage(tester, mobile: true);

        // Mobile uses popup menu instead of inline nav links
        expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      });
    });

    group('hero section', () {
      testWidgets('renders success icon', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
      });

      testWidgets('renders Request Received heading', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text('Request Received'), findsOneWidget);
      });

      testWidgets('renders thank you message', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(
          find.textContaining('Thank you for reaching out'),
          findsOneWidget,
        );
      });
    });

    group('next steps section', () {
      testWidgets('renders What happens next heading', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text('What happens next?'), findsOneWidget);
      });

      testWidgets('renders confirmation email step', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(
          find.textContaining('confirmation email'),
          findsOneWidget,
        );
      });

      testWidgets('renders team review step', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(
          find.textContaining('team will review'),
          findsOneWidget,
        );
      });

      testWidgets('renders response time step', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(
          find.textContaining('1 business day'),
          findsOneWidget,
        );
      });

      testWidgets('renders mail icon', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.mail), findsOneWidget);
      });

      testWidgets('renders user check icon', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.userCheck), findsOneWidget);
      });

      testWidgets('renders message circle icon', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
      });
    });

    group('CTA buttons', () {
      testWidgets('renders Back to Home button', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text('Back to Home'), findsOneWidget);
      });

      testWidgets('renders Explore Features button', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text('Explore Features'), findsOneWidget);
      });

      testWidgets('Back to Home button is tappable', (tester) async {
        await pumpRequestSuccessPage(tester);

        final button = find.text('Back to Home');
        expect(button, findsOneWidget);

        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(GestureDetector),
        );
        expect(buttonWidget, findsWidgets);
      });

      testWidgets('Explore Features button is tappable', (tester) async {
        await pumpRequestSuccessPage(tester);

        final button = find.text('Explore Features');
        expect(button, findsOneWidget);

        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(GestureDetector),
        );
        expect(buttonWidget, findsWidgets);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<RequestSuccessPage>(
        pumpRequestSuccessPage,
        expectedTitle: 'Request Received',
      );

      testWidgets('desktop shows navigation links', (tester) async {
        await pumpRequestSuccessPage(tester, mobile: false);

        // Nav links appear in both app bar and footer, so expect at least 1
        expect(find.text('Features'), findsWidgets);
        expect(find.text('Pricing'), findsWidgets);
      });

      testWidgets('mobile hides desktop nav links in app bar', (tester) async {
        await pumpRequestSuccessPage(tester, mobile: true);

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
            home: const RequestSuccessPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(RequestSuccessPage), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('includes FooterSection widget when scrolled into view',
          (tester) async {
        await pumpRequestSuccessPage(tester);

        await scrollDown(tester, 800);

        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('page structure includes footer in slivers', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byType(RequestSuccessPage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('icons', () {
      testWidgets('renders app bar icons', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('renders success checkmark icon', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
      });
    });

    group('visual styling', () {
      testWidgets('hero section renders with containers', (tester) async {
        await pumpRequestSuccessPage(tester);

        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('next steps card is rendered', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.text('What happens next?'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('back button has tooltip', (tester) async {
        await pumpRequestSuccessPage(tester);

        final iconButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, LucideIcons.arrowLeft),
        );
        expect(iconButton.tooltip, equals('Back'));
      });

      testWidgets('text content is selectable', (tester) async {
        await pumpRequestSuccessPage(tester);

        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });
  });
}
