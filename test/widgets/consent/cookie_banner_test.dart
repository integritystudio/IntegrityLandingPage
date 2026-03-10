import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/models/consent_preferences.dart';
import 'package:integrity_studio_ai/widgets/consent/cookie_banner.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';

import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // HELPERS
  // ==========================================================================

  Widget buildBanner({VoidCallback? onConsentGiven}) {
    return testableWidget(
      Stack(
        children: [
          CookieBanner(onConsentGiven: onConsentGiven ?? () {}),
        ],
      ),
    );
  }

  Future<void> pumpBannerAndWait(WidgetTester tester, {VoidCallback? onConsentGiven}) async {
    await tester.pumpWidget(buildBanner(onConsentGiven: onConsentGiven));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> navigateToPreferences(WidgetTester tester) async {
    final manageButton = find.text('Manage Preferences');
    if (manageButton.evaluate().isEmpty) {
      await tester.tap(find.text('Manage'));
    } else {
      await tester.tap(manageButton);
    }
    await tester.pump();
  }

  // ==========================================================================
  // UNIT TESTS - ConsentPreferences
  // ==========================================================================

  group('ConsentPreferences', () {
    test('factory methods create correct consent levels', () {
      // acceptAll
      final acceptAll = ConsentPreferences.acceptAll();
      expect(acceptAll.essential, isTrue);
      expect(acceptAll.analytics, isTrue);
      expect(acceptAll.marketing, isTrue);

      // essentialOnly
      final essentialOnly = ConsentPreferences.essentialOnly();
      expect(essentialOnly.essential, isTrue);
      expect(essentialOnly.analytics, isFalse);
      expect(essentialOnly.marketing, isFalse);

      // analyticsOnly
      final analyticsOnly = ConsentPreferences.analyticsOnly();
      expect(analyticsOnly.essential, isTrue);
      expect(analyticsOnly.analytics, isTrue);
      expect(analyticsOnly.marketing, isFalse);

      // custom
      final custom = ConsentPreferences(analytics: true, marketing: false);
      expect(custom.essential, isTrue);
      expect(custom.analytics, isTrue);
      expect(custom.marketing, isFalse);
    });

    test('ConsentLevel enum maps to correct preferences', () {
      final essential = ConsentLevel.essential.toPreferences();
      expect(essential.analytics, isFalse);
      expect(essential.marketing, isFalse);

      final analytics = ConsentLevel.analytics.toPreferences();
      expect(analytics.analytics, isTrue);
      expect(analytics.marketing, isFalse);

      final all = ConsentLevel.all.toPreferences();
      expect(all.analytics, isTrue);
      expect(all.marketing, isTrue);
    });
  });

  // ==========================================================================
  // WIDGET TESTS - CookieBanner
  // ==========================================================================

  group('CookieBanner', () {
    // ------------------------------------------------------------------------
    // Main View Rendering
    // ------------------------------------------------------------------------

    group('main view', () {
      testWidgets('renders all elements on desktop', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);

        // Icon and header
        expect(find.byIcon(Icons.cookie_outlined), findsOneWidget);
        expect(find.text('Cookie Preferences'), findsOneWidget);

        // Description and privacy link
        expect(find.textContaining('We use cookies to improve your experience'), findsOneWidget);
        expect(find.text('Read our Privacy Policy'), findsOneWidget);

        // Desktop buttons
        expect(find.text('Manage Preferences'), findsOneWidget);
        expect(find.text('Reject Non-Essential'), findsOneWidget);
        expect(find.text('Accept All'), findsOneWidget);

        // Button types
        expect(find.byType(OutlineButton), findsNWidgets(2));
        expect(find.byType(GradientButton), findsOneWidget);

        // Positioned at bottom
        final columnFinder = find.byWidgetPredicate((widget) =>
            widget is Column && widget.mainAxisAlignment == MainAxisAlignment.end);
        expect(columnFinder, findsOneWidget);
      });

      testWidgets('renders mobile layout with shortened button labels', (tester) async {
        setMobileSize(tester);
        await pumpBannerAndWait(tester);

        expect(find.text('Accept All'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.text('Manage'), findsOneWidget);
      });

      testWidgets('has slide and fade animations', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(buildBanner());
        await tester.pump();

        expect(find.byType(SlideTransition), findsWidgets);
        expect(find.byType(FadeTransition), findsWidgets);
      });
    });

    // ------------------------------------------------------------------------
    // Button Interactions - Main View
    // ------------------------------------------------------------------------

    group('main view interactions', () {
      testWidgets('Accept All triggers onConsentGiven on desktop', (tester) async {
        setDesktopSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await tester.tap(find.text('Accept All'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Reject Non-Essential triggers onConsentGiven on desktop', (tester) async {
        setDesktopSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await tester.tap(find.text('Reject Non-Essential'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Accept All triggers onConsentGiven on mobile', (tester) async {
        setMobileSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await tester.tap(find.text('Accept All'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Reject triggers onConsentGiven on mobile', (tester) async {
        setMobileSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await tester.tap(find.text('Reject'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Manage Preferences navigates to preferences view', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);

        await tester.tap(find.text('Manage Preferences'));
        await tester.pump();

        expect(find.text('Essential Cookies'), findsOneWidget);
        expect(find.text('Analytics Cookies'), findsOneWidget);
        expect(find.text('Marketing Cookies'), findsOneWidget);
      });

      testWidgets('Manage navigates to preferences view on mobile', (tester) async {
        setMobileSize(tester);
        await pumpBannerAndWait(tester);

        await tester.tap(find.text('Manage'));
        await tester.pump();

        expect(find.text('Essential Cookies'), findsOneWidget);
      });
    });

    // ------------------------------------------------------------------------
    // Preferences View
    // ------------------------------------------------------------------------

    group('preferences view', () {
      testWidgets('renders all elements on desktop', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);
        await navigateToPreferences(tester);

        // Navigation
        expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);

        // Cookie categories
        expect(find.text('Essential Cookies'), findsOneWidget);
        expect(find.text('Analytics Cookies'), findsOneWidget);
        expect(find.text('Marketing Cookies'), findsOneWidget);

        // Descriptions
        expect(find.textContaining('Required for the website to function'), findsOneWidget);
        expect(find.textContaining('Google Analytics'), findsOneWidget);
        expect(find.textContaining('Facebook Pixel'), findsOneWidget);

        // Required badge
        expect(find.text('Required'), findsOneWidget);

        // Switches and buttons
        expect(find.byType(Switch), findsNWidgets(3));
        expect(find.text('Save Preferences'), findsOneWidget);
        expect(find.text('Reject All'), findsOneWidget);
      });

      testWidgets('back button returns to main view', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);
        await navigateToPreferences(tester);

        expect(find.text('Essential Cookies'), findsOneWidget);

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(find.text('Essential Cookies'), findsNothing);
        expect(find.text('Manage Preferences'), findsOneWidget);
      });

      testWidgets('Save Preferences triggers onConsentGiven', (tester) async {
        setDesktopSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await navigateToPreferences(tester);
        await tester.tap(find.text('Save Preferences'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Reject All triggers onConsentGiven', (tester) async {
        setDesktopSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await navigateToPreferences(tester);
        await tester.tap(find.text('Reject All'));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('Save Preferences works on mobile', (tester) async {
        setMobileSize(tester);
        var consentGiven = false;

        await pumpBannerAndWait(tester, onConsentGiven: () => consentGiven = true);
        await navigateToPreferences(tester);

        final saveButton = find.text('Save Preferences');
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettleWithTimeout();
        await tester.tap(saveButton);
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });
    });

    // ------------------------------------------------------------------------
    // Toggle Interactions
    // ------------------------------------------------------------------------

    group('toggle interactions', () {
      testWidgets('analytics and marketing toggles can be changed', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);
        await navigateToPreferences(tester);

        final switches = find.byType(Switch);
        expect(switches, findsNWidgets(3));

        // Analytics switch (index 1) - initially true, toggle off
        var analyticsSwitch = tester.widgetList<Switch>(switches).elementAt(1);
        expect(analyticsSwitch.value, isTrue);
        await tester.tap(switches.at(1));
        await tester.pump();
        analyticsSwitch = tester.widgetList<Switch>(switches).elementAt(1);
        expect(analyticsSwitch.value, isFalse);

        // Marketing switch (index 2) - initially false, toggle on
        var marketingSwitch = tester.widgetList<Switch>(switches).elementAt(2);
        expect(marketingSwitch.value, isFalse);
        await tester.tap(switches.at(2));
        await tester.pump();
        marketingSwitch = tester.widgetList<Switch>(switches).elementAt(2);
        expect(marketingSwitch.value, isTrue);
      });

      testWidgets('essential toggle is disabled', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);
        await navigateToPreferences(tester);

        final switches = find.byType(Switch);
        final essentialSwitch = tester.widgetList<Switch>(switches).elementAt(0);

        expect(essentialSwitch.value, isTrue);
        expect(essentialSwitch.onChanged, isNull);
      });
    });

    // ------------------------------------------------------------------------
    // Animation & Accessibility
    // ------------------------------------------------------------------------

    group('animation and accessibility', () {
      testWidgets('animates in on mount and out on consent', (tester) async {
        setDesktopSize(tester);
        var consentGiven = false;

        await tester.pumpWidget(buildBanner(onConsentGiven: () => consentGiven = true));
        await tester.pump();

        // After animation completes, should be visible
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Cookie Preferences'), findsOneWidget);

        // Trigger exit animation
        await tester.tap(find.text('Accept All'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettleWithTimeout();

        expect(consentGiven, isTrue);
      });

      testWidgets('has proper accessibility widgets', (tester) async {
        setDesktopSize(tester);
        await pumpBannerAndWait(tester);

        expect(find.byType(Material), findsWidgets);
        expect(find.byType(TextButton), findsOneWidget);
      });

      testWidgets('has SafeArea on mobile', (tester) async {
        setMobileSize(tester);
        await pumpBannerAndWait(tester);

        expect(find.byType(SafeArea), findsOneWidget);
      });
    });
  });
}
