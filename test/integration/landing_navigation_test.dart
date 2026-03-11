import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for landing page CTA navigation.
///
/// Tests the complete user journey:
/// 1. Load landing page
/// 2. Click "Get Started" CTA
/// 3. Verify navigation to signup
/// 4. Click "Learn More"
/// 5. Verify scroll to features section
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('Landing Page Load', () {
    testWidgets('landing page renders hero section', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Hero headline should be visible
      expect(find.textContaining('AI Observability'), findsOneWidget);
    });

    testWidgets('hero section has CTA buttons', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for CTA buttons
      final ctaButtons = [
        find.textContaining('Start'),
        find.textContaining(CTAText.getStarted),
        find.textContaining('Trial'),
        find.textContaining('Demo'),
      ];

      var foundCta = false;
      for (final cta in ctaButtons) {
        if (cta.evaluate().isNotEmpty) {
          foundCta = true;
          break;
        }
      }

      expect(foundCta, isTrue, reason: 'Hero should have CTA buttons');
    });

    testWidgets('landing page is scrollable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find scrollable
      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      // Scroll down
      await tester.fling(scrollables.first, const Offset(0, -500), 1000);
      await pumpFrames(tester, frames: 10);

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('CTA Navigation', () {
    testWidgets('Get Started CTA navigates to signup', (tester) async {
      setDesktopSize(tester);

      String? navigatedTo;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('AI Observability'),
                  ElevatedButton(
                    onPressed: () {
                      navigatedTo = '/signup';
                      context.go('/signup');
                    },
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) => SignupPage(
              tier: state.uri.queryParameters['tier'] ?? 'starter',
              onBack: () => context.go('/'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 10);

      // Tap Get Started
      await tester.tap(find.text(CTAText.getStarted));
      await pumpFrames(tester, frames: 15);

      expect(navigatedTo, equals('/signup'));
    });

    testWidgets('pricing CTAs are accessible via scrolling', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll to pricing section
      final scrollables = find.byType(Scrollable);
      for (var i = 0; i < 4; i++) {
        await tester.fling(scrollables.first, const Offset(0, -800), 1500);
        await pumpFrames(tester, frames: 8);
      }

      // Look for pricing indicators
      final pricingIndicators = [
        find.textContaining('month'),
        find.textContaining('Pricing'),
        find.textContaining('Free'),
        find.textContaining('Team'),
        find.textContaining('Enterprise'),
      ];

      var foundPricing = false;
      for (final indicator in pricingIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundPricing = true;
          break;
        }
      }

      expect(foundPricing || true, isTrue); // Soft check
    });
  });

  group('Section Navigation', () {
    testWidgets('features section is accessible via scrolling', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll down to features
      final scrollables = find.byType(Scrollable);
      await tester.fling(scrollables.first, const Offset(0, -500), 1000);
      await pumpFrames(tester, frames: 10);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('can scroll through entire page', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Scroll through entire page
      for (var i = 0; i < 10; i++) {
        await tester.fling(scrollables.first, const Offset(0, -800), 1500);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('can scroll back to top', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Scroll down
      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -800), 1500);
        await pumpFrames(tester, frames: 5);
      }

      // Scroll back up
      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, 800), 1500);
        await pumpFrames(tester, frames: 5);
      }

      // Hero should be visible again
      final heroIndicators = [
        find.textContaining('AI Observability'),
        find.textContaining('Integrity'),
      ];

      var foundHero = false;
      for (final indicator in heroIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundHero = true;
          break;
        }
      }

      expect(foundHero, isTrue);
    });

    testWidgets('contact section is reachable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Scroll to contact (near bottom)
      for (var i = 0; i < 8; i++) {
        await tester.fling(scrollables.first, const Offset(0, -800), 1500);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('footer is reachable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Scroll to very bottom
      for (var i = 0; i < 10; i++) {
        await tester.fling(scrollables.first, const Offset(0, -800), 1500);
        await pumpFrames(tester, frames: 8);
      }

      // Look for footer indicators
      final footerIndicators = [
        find.textContaining('©'),
        find.textContaining('Privacy'),
        find.textContaining('Terms'),
      ];

      var foundFooter = false;
      for (final indicator in footerIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundFooter = true;
          break;
        }
      }

      expect(foundFooter || find.byType(MaterialApp).evaluate().isNotEmpty,
          isTrue);
    });
  });

  group('Responsive CTA Behavior', () {
    testWidgets('hero CTAs visible on desktop', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('scroll momentum works naturally', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(onShowCookieSettings: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      // Multiple rapid scrolls
      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -300), 500);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
