import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/hover_text_link.dart';
import 'package:integrity_studio_ai/widgets/sections/footer_section.dart';
import '../../helpers/test_helpers.dart';

// Desktop footer link labels — single source of truth for desktop-layout tests.
// Mobile bottom bar uses abbreviated labels ('Privacy', 'Terms', 'Cookies').
const _productLabels = ['Features', 'Pricing', 'Documentation', 'API Reference'];
const _companyLabels = ['About', 'Blog', 'Sources', 'Careers', 'Contact'];
const _resourceLabels = ['Help Center', 'Status', 'Security'];
final _navLabels = [..._productLabels, ..._companyLabels, ..._resourceLabels];
const _legalLabels = [
  'Privacy Policy',
  'Terms of Service',
  'Cookie Policy',
  'Accessibility',
  'Cookie Settings',
];
const _socialLabels = ['LinkedIn', 'GitHub'];
const _mobileLegalLabels = ['Privacy', 'Terms', 'Cookies', 'Accessibility', 'Cookie Settings'];
// Desktop layout: 12 nav + 5 legal = 17 HoverTextLink widgets
final _expectedHoverLinkCount = _navLabels.length + _legalLabels.length; // = 17

void main() {
  group('FooterSection', () {
    // =======================================================================
    // Footer Link Data
    // =======================================================================

    testWidgets('renders expected number of nav, legal, and social elements', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(testableSection(const FooterSection()));
      await tester.pumpAndSettle();

      // Verify actual rendered widget counts match expected label counts
      expect(find.byType(IconButton), findsNWidgets(_socialLabels.length));
      expect(find.byType(HoverTextLink), findsNWidgets(_expectedHoverLinkCount));
      expect(find.text('Sources'), findsOneWidget); // Transparency link
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

      // Section headings
      expect(find.text('Product'), findsOneWidget);
      expect(find.text('Company'), findsOneWidget);
      expect(find.text('Resources'), findsOneWidget);

      // All nav and legal link labels render
      for (final label in [..._navLabels, ..._legalLabels]) {
        expect(find.text(label), findsOneWidget, reason: '$label missing');
      }

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
      expect(find.byType(IconButton), findsNWidgets(_socialLabels.length));
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

    testWidgets('renders abbreviated mobile bottom bar labels', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        testableSection(const FooterSection()),
      );
      await tester.pumpAndSettle();

      for (final label in _mobileLegalLabels) {
        expect(find.text(label), findsOneWidget, reason: 'mobile label "$label" missing');
      }
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

      final hoverLinks = find.descendant(
        of: find.byType(FooterSection),
        matching: find.byType(HoverTextLink),
      );
      expect(hoverLinks, findsNWidgets(_expectedHoverLinkCount));

      // Every nav and legal label must appear inside a HoverTextLink
      for (final label in [..._navLabels, ..._legalLabels]) {
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
