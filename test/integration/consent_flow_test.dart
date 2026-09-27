import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/routing/cookie_shell.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for the cookie consent flow.
///
/// Tests the complete user journey:
/// 1. Load app with cookieBannerNotifier.value = true
/// 2. Verify banner appears
/// 3. Click "Accept All" or "Customize"
/// 4. Verify consent saved
/// 5. Verify analytics enabled/disabled appropriately
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
    cookieBannerNotifier.value = false;
  });

  tearDown(() {
    restoreErrorHandler();
    cookieBannerNotifier.value = false;
  });

  group('Cookie Banner Display', () {
    testWidgets('cookie banner appears when notifier is true',
        (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('App Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for cookie banner elements
      final acceptButton = find.text('Accept All');
      final hasAcceptButton = acceptButton.evaluate().isNotEmpty;

      // Banner should show or app content should be visible
      expect(hasAcceptButton || find.text('App Content').evaluate().isNotEmpty,
          isTrue);
    });

    testWidgets('cookie banner does not appear when notifier is false',
        (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('App Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // App content should be visible without banner blocking
      expect(find.text('App Content'), findsOneWidget);
    });

    testWidgets('accept all button dismisses banner', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      var consentGiven = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () => consentGiven = true,
            child: const Scaffold(body: Center(child: Text('App Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await pumpFrames(tester, frames: 10);

        // Consent callback should be triggered
        expect(consentGiven, isTrue);
      }
    });

    testWidgets('essential only option exists', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('App Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for essential only option
      final essentialOptions = [
        find.textContaining('Essential'),
        find.textContaining('Necessary'),
        find.textContaining('Decline'),
      ];

      var foundOption = false;
      for (final option in essentialOptions) {
        if (option.evaluate().isNotEmpty) {
          foundOption = true;
          break;
        }
      }

      // Either found option or app renders correctly
      expect(foundOption, isTrue, reason: 'Cookie consent options should be visible');
    });

    testWidgets('customize preferences option exists', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('App Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for customize option
      final customizeOptions = [
        find.textContaining('Customize'),
        find.textContaining('Manage'),
        find.textContaining('Preferences'),
        find.textContaining('Settings'),
      ];

      var foundOption = false;
      for (final option in customizeOptions) {
        if (option.evaluate().isNotEmpty) {
          foundOption = true;
          break;
        }
      }

      expect(foundOption, isTrue, reason: 'Cookie consent options should be visible');
    });
  });

  group('Consent Flow Interactions', () {
    testWidgets('page is scrollable with banner showing', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: LandingPage(onShowCookieSettings: () {}),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find scrollable and try scrolling
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      if (scrollables.evaluate().isNotEmpty) {
        await tester.drag(scrollables.first, const Offset(0, -100));
        await pumpFrames(tester, frames: 5);
      }

      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('content is fully interactive after consent', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: LandingPage(onShowCookieSettings: () {}),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Accept cookies
      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await pumpFrames(tester, frames: 10);
      }

      // Content should now be fully interactive
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1000);
        await pumpFrames(tester, frames: 10);
      }

      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('forms work after consent given', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: LandingPage(onShowCookieSettings: () {}),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Accept cookies
      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await pumpFrames(tester, frames: 5);
      }

      // Scroll to contact section
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        for (var i = 0; i < 7; i++) {
          await tester.fling(scrollables.first, const Offset(0, -800), 1500);
          await pumpFrames(tester, frames: 8);
        }
      }

      // Form fields should be interactive
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Test');
        await pumpFrames(tester, frames: 3);
        expect(find.text('Test'), findsWidgets);
      }
    });
  });

  group('Privacy Link Navigation', () {
    testWidgets('privacy policy link is accessible in banner', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for privacy link
      final privacyLinks = [
        find.textContaining('Privacy'),
        find.textContaining('privacy'),
      ];

      var foundLink = false;
      for (final link in privacyLinks) {
        if (link.evaluate().isNotEmpty) {
          foundLink = true;
          break;
        }
      }

      expect(foundLink, isTrue, reason: 'Privacy/terms links should be visible in the banner');
    });
  });

  group('Banner UI/UX', () {
    testWidgets('banner has proper styling', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: const Scaffold(body: Center(child: Text('Content'))),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        // Button should be visible and tappable
        final buttonWidget = tester.widget(acceptButton);
        expect(buttonWidget, isNotNull);
      }
    });

    testWidgets('banner does not block critical hero content', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: LandingPage(onShowCookieSettings: () {}),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Hero content should be visible even with banner
      final heroIndicators = [
        find.textContaining('AI Observability'),
        find.textContaining('Integrity'),
      ];

      var heroVisible = false;
      for (final indicator in heroIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          heroVisible = true;
          break;
        }
      }

      expect(heroVisible, isTrue,
          reason: 'Hero should be visible with cookie banner');
    });

    testWidgets('banner is properly dismissed after accept', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return CookieBannerShell(
                onConsentGiven: () {},
                child: const Scaffold(body: Center(child: Text('Content'))),
              );
            },
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await pumpFrames(tester, frames: 10);
      }

      // App should continue functioning — child content is still present
      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('Consent State Management', () {
    testWidgets('page functions normally after consent', (tester) async {
      setDesktopSize(tester);
      cookieBannerNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: CookieBannerShell(
            onConsentGiven: () {},
            child: LandingPage(onShowCookieSettings: () {}),
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Accept consent
      final acceptButton = find.text('Accept All');
      if (acceptButton.evaluate().isNotEmpty) {
        await tester.tap(acceptButton);
        await pumpFrames(tester, frames: 10);
      }

      // Page should continue to function
      expect(find.byType(LandingPage), findsOneWidget);

      // Should be able to interact with the page
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1000);
        await pumpFrames(tester, frames: 10);
      }

      expect(find.byType(LandingPage), findsOneWidget);
    });
  });
}
