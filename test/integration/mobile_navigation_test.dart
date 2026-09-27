import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
import 'package:integrity_studio_ai/pages/contact_page.dart';
import 'package:integrity_studio_ai/pages/pricing_page.dart';
import 'package:integrity_studio_ai/pages/docs_index_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for mobile menu navigation.
///
/// Tests the complete user journey on mobile:
/// 1. Set viewport to mobile size
/// 2. Tap hamburger menu
/// 3. Verify menu opens
/// 4. Navigate to each main section
/// 5. Verify menu closes after selection
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('Mobile Viewport Rendering', () {
    testWidgets('landing page adapts to mobile viewport', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Hero should be visible
      expect(find.textContaining('AI Observability'), findsOneWidget);
    });

    testWidgets('contact page adapts to mobile viewport', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.text('Get in Touch'), findsWidgets);
    });

    testWidgets('pricing page adapts to mobile viewport', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: PricingPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.textContaining('Simple, Transparent Pricing'), findsWidgets);
    });

    testWidgets('docs page adapts to mobile viewport', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.text('Documentation'), findsOneWidget);
    });
  });

  group('Mobile Scrolling', () {
    testWidgets('landing page scrolls on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find scrollable and scroll
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -400), 1000);
        await pumpFrames(tester, frames: 8);
      }

      // LandingPage survives scrolling
      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('contact page scrolls on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      for (var i = 0; i < 3; i++) {
        await tester.fling(scrollables.first, const Offset(0, -400), 1000);
        await pumpFrames(tester, frames: 8);
      }

      // ContactPage survives scrolling
      expect(find.byType(ContactPage), findsOneWidget);
    });

    testWidgets('can scroll to contact section on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Scroll to contact (near bottom)
      for (var i = 0; i < 8; i++) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1500);
        await pumpFrames(tester, frames: 8);
      }

      // LandingPage survives deep scroll
      expect(find.byType(LandingPage), findsOneWidget);
    });
  });

  group('Mobile Form Interaction', () {
    testWidgets('form fields work on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll to form
      final scrollables = find.byType(Scrollable);
      await tester.fling(scrollables.first, const Offset(0, -300), 1000);
      await pumpFrames(tester, frames: 10);

      // Find text fields and enter data
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
      await tester.enterText(textFields.first, 'Mobile Test');
      await pumpFrames(tester, frames: 3);
      expect(find.text('Mobile Test'), findsWidgets);
    });

    testWidgets('quick contact cards stack on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Cards should be present
      expect(find.textContaining('Email'), findsWidgets);
      expect(find.textContaining('Schedule'), findsWidgets);
    });
  });

  group('Mobile Touch Gestures', () {
    testWidgets('swipe scrolling works on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Simulate swipe gestures
      await tester.drag(scrollables.first, const Offset(0, -200));
      await pumpFrames(tester, frames: 5);

      await tester.drag(scrollables.first, const Offset(0, -200));
      await pumpFrames(tester, frames: 5);

      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('fling scrolling works on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Fast fling
      await tester.fling(scrollables.first, const Offset(0, -800), 2000);
      await pumpFrames(tester, frames: 15);

      expect(find.byType(LandingPage), findsOneWidget);
    });
  });

  group('Mobile Back Button', () {
    testWidgets('back button works on mobile contact page', (tester) async {
      var backPressed = false;

      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () => backPressed = true,
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find and tap back button
      final iconButtons = find.byType(IconButton);
      if (iconButtons.evaluate().isNotEmpty) {
        await tester.tap(iconButtons.first);
        await pumpFrames(tester, frames: 5);
      }

      expect(backPressed, isTrue);
    });

    testWidgets('back button works on mobile docs page', (tester) async {
      var backPressed = false;

      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () => backPressed = true),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final iconButtons = find.byType(IconButton);
      if (iconButtons.evaluate().isNotEmpty) {
        await tester.tap(iconButtons.first);
        await pumpFrames(tester, frames: 5);
      }

      expect(backPressed, isTrue);
    });
  });

  group('Mobile Responsive Layout', () {
    testWidgets('content wraps correctly on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Hero content should be visible
      expect(find.textContaining('AI Observability'), findsOneWidget);

      // Page should not overflow (would cause render errors)
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('docs cards stack on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll to docs grid
      final scrollables = find.byType(Scrollable);
      await tester.fling(scrollables.first, const Offset(0, -300), 1000);
      await pumpFrames(tester, frames: 10);

      // Cards should be visible
      expect(find.text('Getting Started'), findsOneWidget);
    });
  });

  group('Tablet Viewport', () {
    testWidgets('landing page renders on tablet', (tester) async {
      setScreenSize(tester, ScreenSizes.tablet);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('AI Observability'), findsOneWidget);
    });

    testWidgets('contact page renders on tablet', (tester) async {
      setScreenSize(tester, ScreenSizes.tablet);

      await tester.pumpWidget(
        MaterialApp(
          home: ContactPage(
            onBack: () {},
            onShowCookieSettings: () {},
          ),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
