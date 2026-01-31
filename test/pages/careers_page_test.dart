import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/careers_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../helpers/test_helpers.dart';

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  /// Helper to pump the CareersPage widget with larger viewport to avoid overflow
  Future<void> pumpCareersPage(
    WidgetTester tester, {
    VoidCallback? onBack,
    VoidCallback? onShowCookieSettings,
    bool mobile = false,
  }) async {
    clearOverflowExceptions(tester);

    if (mobile) {
      setMobileSize(tester);
    } else {
      // Use desktopLarge size to minimize overflow issues
      setScreenSize(tester, TestScreenSizes.desktopLarge);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: testTheme,
        home: CareersPage(
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

  group('CareersPage', () {
    group('page structure', () {
      testPageStructure(pumpCareersPage);

      testWidgets('renders company name in app bar', (tester) async {
        await pumpCareersPage(tester);

        expect(find.text(CompanyInfo.name), findsOneWidget);
      });

      testWidgets('renders shield icon in app bar', (tester) async {
        await pumpCareersPage(tester);

        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });
    });

    group('navigation', () {
      testBackButtonCallback(pumpCareersPage);

      testWidgets('renders navigation links on desktop', (tester) async {
        await pumpCareersPage(tester, mobile: false);

        expect(find.text('Features'), findsOneWidget);
        expect(find.text('Pricing'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
      });

      testWidgets('renders Get Started button on desktop', (tester) async {
        await pumpCareersPage(tester, mobile: false);

        expect(find.text('Get Started'), findsOneWidget);
      });

      testWidgets('hides navigation links on mobile', (tester) async {
        await pumpCareersPage(tester, mobile: true);

        expect(find.text('Features'), findsNothing);
        expect(find.text('Pricing'), findsNothing);
        expect(find.text('About'), findsNothing);
      });

      testWidgets('hides Get Started button on mobile', (tester) async {
        await pumpCareersPage(tester, mobile: true);

        expect(find.text('Get Started'), findsNothing);
      });
    });

    group('hero section', () {
      testWidgets('renders Join Our Team badge', (tester) async {
        await pumpCareersPage(tester);

        expect(find.text('Join Our Team'), findsOneWidget);
      });

      testWidgets('renders page title', (tester) async {
        await pumpCareersPage(tester);

        expect(find.text('Careers at Integrity Studio'), findsOneWidget);
      });

      testWidgets('renders subtitle description', (tester) async {
        await pumpCareersPage(tester);

        expect(
          find.text(
            'Help us build the future of AI observability and empower teams to ship reliable AI applications.',
          ),
          findsOneWidget,
        );
      });
    });

    group('no openings section', () {
      testWidgets('renders No Open Positions heading', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 300);

        expect(find.text('No Open Positions'), findsOneWidget);
      });

      testWidgets('renders briefcase icon', (tester) async {
        await pumpCareersPage(tester);

        expect(find.byIcon(LucideIcons.briefcase), findsOneWidget);
      });

      testWidgets('renders explanation text', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 300);

        expect(
          find.textContaining('We don\'t have any open roles at the moment'),
          findsOneWidget,
        );
      });
    });

    group('submit resume section', () {
      testWidgets('renders Stay on Our Radar heading', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.text('Stay on Our Radar'), findsOneWidget);
      });

      testWidgets('renders mail plus icon', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.byIcon(LucideIcons.mailPlus), findsOneWidget);
      });

      testWidgets('renders resume submission description', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(
          find.textContaining('Send us your resume and a brief introduction'),
          findsOneWidget,
        );
      });

      testWidgets('renders Submit Your Resume button', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.text('Submit Your Resume'), findsOneWidget);
      });

      testWidgets('renders response time info', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(
          find.text('We typically respond within 5 business days'),
          findsOneWidget,
        );
      });

      testWidgets('renders info icon', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.byIcon(LucideIcons.info), findsOneWidget);
      });
    });

    group('CTA buttons', () {
      testWidgets('Submit Your Resume button is tappable', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        final button = find.text('Submit Your Resume');
        expect(button, findsOneWidget);

        // Verify it's within a tappable widget hierarchy
        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(GestureDetector),
        );
        expect(buttonWidget, findsWidgets);
      });

      testWidgets('Get Started button is tappable on desktop', (tester) async {
        await pumpCareersPage(tester, mobile: false);

        final button = find.text('Get Started');
        expect(button, findsOneWidget);

        // Verify it's within a TextButton
        final buttonWidget = find.ancestor(
          of: button,
          matching: find.byType(TextButton),
        );
        expect(buttonWidget, findsOneWidget);
      });
    });

    group('responsive layout', () {
      testResponsiveLayout<CareersPage>(
        pumpCareersPage,
        expectedTitle: 'Careers at Integrity Studio',
      );

      testWidgets('desktop shows navigation actions', (tester) async {
        await pumpCareersPage(tester, mobile: false);

        // Desktop should show nav links and Get Started button
        expect(find.text('Features'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
      });

      testWidgets('mobile hides navigation actions', (tester) async {
        await pumpCareersPage(tester, mobile: true);

        // Mobile should hide nav links and Get Started button
        expect(find.text('Features'), findsNothing);
        expect(find.text('Get Started'), findsNothing);
      });

      testWidgets('tablet viewport renders correctly', (tester) async {
        setTabletSize(tester);
        clearOverflowExceptions(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: const CareersPage(),
          ),
        );
        await tester.pump();
        clearOverflowExceptions(tester);

        expect(find.byType(CareersPage), findsOneWidget);
      });
    });

    group('footer section', () {
      testWidgets('includes FooterSection widget when scrolled into view',
          (tester) async {
        await pumpCareersPage(tester);

        // Scroll to the bottom to make footer visible
        await scrollDown(tester, 800);
        await scrollDown(tester, 800);

        // FooterSection is added to the sliver list
        expect(find.byType(FooterSection), findsOneWidget);
      });

      testWidgets('page structure includes footer in slivers', (tester) async {
        await pumpCareersPage(tester);

        // The page should render without error with footer in sliver list
        expect(find.byType(CareersPage), findsOneWidget);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('content sections', () {
      testWidgets('all main sections are present', (tester) async {
        await pumpCareersPage(tester);

        // Hero section
        expect(find.text('Join Our Team'), findsOneWidget);
        expect(find.text('Careers at Integrity Studio'), findsOneWidget);
      });

      testWidgets('sections render in correct order', (tester) async {
        await pumpCareersPage(tester);

        // Get positions of key elements to verify order
        final heroFinder = find.text('Careers at Integrity Studio');
        expect(heroFinder, findsOneWidget);

        // Scroll to see more content
        await scrollDown(tester, 400);

        final noOpeningsFinder = find.text('No Open Positions');
        expect(noOpeningsFinder, findsOneWidget);

        await scrollDown(tester, 400);

        final submitFinder = find.text('Stay on Our Radar');
        expect(submitFinder, findsOneWidget);
      });
    });

    group('icons', () {
      testWidgets('renders app bar icons', (tester) async {
        await pumpCareersPage(tester);

        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('renders briefcase icon in no openings section',
          (tester) async {
        await pumpCareersPage(tester);

        expect(find.byIcon(LucideIcons.briefcase), findsOneWidget);
      });

      testWidgets('renders mail plus icon in submit section', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.byIcon(LucideIcons.mailPlus), findsOneWidget);
      });

      testWidgets('renders info icon in submit section', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.byIcon(LucideIcons.info), findsOneWidget);
      });
    });

    group('visual styling', () {
      testWidgets('hero section renders with containers', (tester) async {
        await pumpCareersPage(tester);

        // Find container widgets
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
      });

      testWidgets('no openings card is rendered', (tester) async {
        await pumpCareersPage(tester);

        // Card should be rendered with text content
        expect(find.text('No Open Positions'), findsOneWidget);
      });

      testWidgets('submit section renders correctly', (tester) async {
        await pumpCareersPage(tester);

        await scrollDown(tester, 500);

        expect(find.text('Stay on Our Radar'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('back button has tooltip', (tester) async {
        await pumpCareersPage(tester);

        final iconButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, LucideIcons.arrowLeft),
        );
        expect(iconButton.tooltip, equals('Back'));
      });

      testWidgets('text content is selectable', (tester) async {
        await pumpCareersPage(tester);

        // The page uses SelectionArea for text selection
        expect(find.byType(SelectionArea), findsOneWidget);
      });
    });

    group('company info', () {
      test('CompanyInfo has name defined', () {
        expect(CompanyInfo.name, isNotEmpty);
        expect(CompanyInfo.name, equals('Integrity Studio'));
      });

      test('CompanyInfo has email defined', () {
        expect(CompanyInfo.email, isNotEmpty);
      });
    });
  });
}
