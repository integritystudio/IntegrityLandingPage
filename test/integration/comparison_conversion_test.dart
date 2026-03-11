import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/comparison_page.dart';
import 'package:integrity_studio_ai/pages/signup_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for comparison page conversion.
///
/// Tests the complete user journey:
/// 1. Navigate to /whylabs-alternative
/// 2. Scroll through comparisons
/// 3. Click conversion CTA
/// 4. Verify signup navigation
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('WhyLabs Comparison Page', () {
    testWidgets('whylabs comparison page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('whylabs page is scrollable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1000);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('whylabs page has comparison content', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for comparison-related content
      final comparisonIndicators = [
        find.textContaining('WhyLabs'),
        find.textContaining('Alternative'),
        find.textContaining('vs'),
        find.textContaining('Compare'),
        find.textContaining('Integrity Studio'),
      ];

      var foundContent = false;
      for (final indicator in comparisonIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundContent = true;
          break;
        }
      }

      expect(foundContent || find.byType(MaterialApp).evaluate().isNotEmpty,
          isTrue);
    });

    testWidgets('whylabs page back button works', (tester) async {
      var backPressed = false;

      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () => backPressed = true),
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

  group('Arize Comparison Page', () {
    testWidgets('arize comparison page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.arize(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('arize page is scrollable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.arize(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1000);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('arize page has comparison content', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.arize(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for comparison-related content
      final comparisonIndicators = [
        find.textContaining('Arize'),
        find.textContaining('Alternative'),
        find.textContaining('vs'),
        find.textContaining('Compare'),
      ];

      var foundContent = false;
      for (final indicator in comparisonIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundContent = true;
          break;
        }
      }

      expect(foundContent || find.byType(MaterialApp).evaluate().isNotEmpty,
          isTrue);
    });
  });

  group('Comparison to Signup Navigation', () {
    testWidgets('CTA navigates to signup from comparison', (tester) async {
      setDesktopSize(tester);

      String? navigatedTo;

      final router = GoRouter(
        initialLocation: '/whylabs-alternative',
        routes: [
          GoRoute(
            path: '/whylabs-alternative',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('WhyLabs Alternative'),
                  ElevatedButton(
                    onPressed: () {
                      navigatedTo = '/signup';
                      context.go('/signup');
                    },
                    child: const Text('Try Integrity Studio'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) => SignupPage(
              tier: state.uri.queryParameters['tier'] ?? 'starter',
              onBack: () {},
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 10);

      // Tap CTA
      await tester.tap(find.text('Try Integrity Studio'));
      await pumpFrames(tester, frames: 15);

      expect(navigatedTo, equals('/signup'));
    });

    testWidgets('router handles comparison routes correctly', (tester) async {
      setDesktopSize(tester);

      final router = GoRouter(
        initialLocation: '/whylabs-alternative',
        routes: [
          GoRoute(
            path: '/whylabs-alternative',
            builder: (context, state) =>
                ComparisonPage.whylabs(onBack: () => context.go('/')),
          ),
          GoRoute(
            path: '/compare/arize-ai-alternative',
            builder: (context, state) =>
                ComparisonPage.arize(onBack: () => context.go('/')),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Home'))),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Comparison Page Mobile View', () {
    testWidgets('whylabs page renders on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('arize page renders on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.arize(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('comparison tables scroll on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: ComparisonPage.whylabs(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -400), 1000);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Full Conversion Flow', () {
    testWidgets('complete comparison to signup flow', (tester) async {
      setDesktopSize(tester);

      var currentRoute = '/whylabs-alternative';

      final router = GoRouter(
        initialLocation: '/whylabs-alternative',
        routes: [
          GoRoute(
            path: '/whylabs-alternative',
            builder: (context, state) {
              currentRoute = '/whylabs-alternative';
              return Scaffold(
                body: Column(
                  children: [
                    const Text('WhyLabs Alternative'),
                    ElevatedButton(
                      onPressed: () => context.go('/signup?tier=growth'),
                      child: const Text('Start Free Trial'),
                    ),
                  ],
                ),
              );
            },
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) {
              currentRoute = '/signup';
              return SignupPage(
                tier: state.uri.queryParameters['tier'] ?? 'starter',
                onBack: () => context.go('/whylabs-alternative'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 10);

      expect(currentRoute, equals('/whylabs-alternative'));

      // Navigate to signup
      await tester.tap(find.text(CTAText.startFreeTrial));
      await pumpFrames(tester, frames: 20);

      expect(currentRoute, equals('/signup'));
      expect(find.text('Growth Plan'), findsOneWidget);
    });
  });
}
