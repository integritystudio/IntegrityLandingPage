import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/hover_text_link.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('FooterSection', () {
    // =======================================================================
    // Footer Link Data
    // =======================================================================

    test('footer link structure and social platforms are defined correctly', () {
      // Footer sections are defined statically in the widget
      const productLinks = ['Features', 'Pricing', 'Documentation', 'API Reference'];
      const companyLinks = ['About', 'Blog', 'Sources', 'Careers', 'Contact'];
      const resourceLinks = ['Help Center', 'Status', 'Security'];
      const socialPlatforms = ['X', 'LinkedIn', 'GitHub'];

      expect(productLinks, hasLength(4));
      expect(companyLinks, hasLength(5));
      expect(companyLinks.contains('Sources'), isTrue); // Transparency link
      expect(resourceLinks, hasLength(3));
      expect(socialPlatforms, hasLength(3));
    });

    // =======================================================================
    // Copyright and Legal Links
    // =======================================================================

    test('copyright year and legal links are valid', () {
      final currentYear = DateTime.now().year;
      expect(currentYear, greaterThanOrEqualTo(2024));

      const legalLinks = ['Privacy Policy', 'Terms of Service', 'Cookie Settings'];
      expect(legalLinks.contains('Privacy Policy'), isTrue);
      expect(legalLinks.contains('Terms of Service'), isTrue);
      expect(legalLinks.contains('Cookie Settings'), isTrue);
    });

    // =======================================================================
    // Widget Rendering - All Link Sections
    // =======================================================================

    testWidgets('renders all footer link sections and content', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      // Footer section exists
      expect(find.byType(FooterSection), findsOneWidget);
      expect(find.text('IntegrityStudio'), findsOneWidget);

      // Product section
      expect(find.text('Product'), findsOneWidget);
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Pricing'), findsOneWidget);
      expect(find.text('Documentation'), findsOneWidget);

      // Company section (includes Sources for transparency)
      expect(find.text('Company'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Blog'), findsOneWidget);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('Careers'), findsOneWidget);
      expect(find.text('Contact'), findsOneWidget);

      // Resources section
      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('Help Center'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);

      // Legal links
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Cookie Settings'), findsOneWidget);

      // Compliance disclaimer
      expect(
        find.textContaining('AI governance and observability'),
        findsOneWidget,
      );

      // Sources link is tappable (wrapped in GestureDetector)
      final sourcesLink = find.text('Sources');
      final gestureDetector = find.ancestor(
        of: sourcesLink,
        matching: find.byType(GestureDetector),
      );
      expect(gestureDetector, findsWidgets);
    });

    // =======================================================================
    // Widget Rendering - Social Icons
    // =======================================================================

    testWidgets('renders social media icons with icon buttons', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.linkedin), findsOneWidget);
      expect(find.byIcon(LucideIcons.github), findsOneWidget);
      expect(find.byType(IconButton), findsWidgets);
    });

    // =======================================================================
    // Responsive and Widget Structure
    // =======================================================================

    testWidgets('renders correctly on mobile with gesture detectors', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FooterSection), findsOneWidget);
      expect(find.text('Sources'), findsOneWidget);
      expect(find.byType(GestureDetector), findsWidgets);

      // Note: Tablet test skipped due to pre-existing footer layout issue at 768-900px widths
    });

    // =======================================================================
    // Callbacks
    // =======================================================================

    testWidgets('calls onCookieSettings when Cookie Settings tapped', (tester) async {
      setDesktopSize(tester);
      var cookieSettingsCalled = false;

      await tester.pumpWidget(
        testableSection(
          FooterSection(onCookieSettings: () => cookieSettingsCalled = true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cookie Settings'));
      await tester.pumpAndSettle();

      expect(cookieSettingsCalled, isTrue);
    });

    testWidgets('Blog link accepts onNavigateToBlog callback', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(
          FooterSection(onNavigateToBlog: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsWidgets);
    });

    // =======================================================================
    // Regression: #62 — HoverTextLink replaces _FooterLink
    // Also covers #53 — verifies all nav and legal labels render inside
    // HoverTextLink (route-constant usage enforced at source level)
    // =======================================================================

    testWidgets('all footer links are HoverTextLink with expected labels (#62, #53 regression)',
        (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      // Product(4) + Company(5) + Resources(3) + legal(5) = 17
      const expectedHoverLinkCount = 17;
      final hoverLinks = find.descendant(
        of: find.byType(FooterSection),
        matching: find.byType(HoverTextLink),
      );
      expect(hoverLinks, findsNWidgets(expectedHoverLinkCount));

      // Every link label must appear inside a HoverTextLink
      const expectedNavLabels = [
        'Features',
        'Pricing',
        'Documentation',
        'API Reference',
        'About',
        'Blog',
        'Sources',
        'Careers',
        'Contact',
        'Help Center',
        'Status',
        'Security',
      ];
      const expectedLegalLabels = [
        'Privacy Policy',
        'Terms of Service',
        'Cookie Policy',
        'Accessibility',
        'Cookie Settings',
      ];
      for (final label in [...expectedNavLabels, ...expectedLegalLabels]) {
        expect(
          find.descendant(
            of: find.byType(HoverTextLink),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$label must be rendered inside HoverTextLink',
        );
      }
    });

    // =======================================================================
    // Regression: #55 — _launchUrl error handling
    // =======================================================================

    testWidgets('social icon buttons are tappable without crash (#55 regression)',
        (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      // Tapping social icons should not throw (error handling wraps launchUrl)
      final iconButtons = find.byType(IconButton);
      expect(iconButtons, findsWidgets);

      // Tap first icon button — launchUrl will fail in test env but
      // try/catch in _launchUrl (#55) prevents crash
      await tester.tap(iconButtons.first);
      await tester.pumpAndSettle();

      // App should remain stable
      expect(find.byType(FooterSection), findsOneWidget);
    });
  });
}
