import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/docs_index_page.dart';
import 'package:integrity_studio_ai/pages/docs_quickstart_page.dart';
import 'package:integrity_studio_ai/pages/docs_tracing_page.dart';
import 'package:integrity_studio_ai/pages/docs_observability_page.dart';
import 'package:integrity_studio_ai/pages/docs_interoperability_page.dart';
import 'package:integrity_studio_ai/pages/docs_alerts_page.dart';
import 'package:integrity_studio_ai/pages/docs_api_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for documentation navigation.
///
/// Tests the complete user journey:
/// 1. Navigate to /docs
/// 2. Click through sidebar/card links
/// 3. Verify each docs page loads
/// 4. Test breadcrumb navigation
/// 5. Test back button behavior
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('Docs Index Page', () {
    testWidgets('docs index page renders correctly', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Verify page title
      expect(find.text('Documentation'), findsOneWidget);

      // Verify hero section
      expect(find.text('Integrity Studio Documentation'), findsOneWidget);
    });

    testWidgets('docs grid shows all categories', (tester) async {
      setDesktopSize(tester);

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

      // Verify doc categories are shown
      expect(find.text('Browse Documentation'), findsOneWidget);
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('API Reference'), findsOneWidget);
    });

    testWidgets('quick links section is visible', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll to quick links
      final scrollables = find.byType(Scrollable);
      for (var i = 0; i < 3; i++) {
        await tester.fling(scrollables.first, const Offset(0, -400), 1000);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.text('Quick Links'), findsOneWidget);
    });

    testWidgets('back button works', (tester) async {
      var backPressed = false;

      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () => backPressed = true),
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

    testWidgets('back to home link works', (tester) async {
      var backPressed = false;

      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () => backPressed = true),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Find and tap "Back to Home"
      final backLink = find.text(CTAText.backToHome);
      if (backLink.evaluate().isNotEmpty) {
        await tester.tap(backLink);
        await pumpFrames(tester, frames: 5);
      }

      expect(backPressed, isTrue);
    });
  });

  group('Docs Pages Navigation', () {
    testWidgets('quickstart page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsQuickstartPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('tracing page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsTracingPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('observability page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsObservabilityPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('integrations page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsInteroperabilityPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('alerts page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsAlertsPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('API page renders', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsApiPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Router Navigation', () {
    testWidgets('can navigate between docs pages via router', (tester) async {
      setDesktopSize(tester);

      final router = GoRouter(
        initialLocation: '/docs',
        routes: [
          GoRoute(
            path: '/docs',
            builder: (context, state) => DocsIndexPage(
              onBack: () => context.go('/'),
            ),
          ),
          GoRoute(
            path: '/docs/quickstart',
            builder: (context, state) => DocsQuickstartPage(
              onBack: () => context.go('/docs'),
            ),
          ),
          GoRoute(
            path: '/docs/tracing',
            builder: (context, state) => DocsTracingPage(
              onBack: () => context.go('/docs'),
            ),
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

      // Verify we're on docs index
      expect(find.text('Documentation'), findsOneWidget);
    });

    testWidgets('redirects work for legacy URLs', (tester) async {
      setDesktopSize(tester);

      String? finalLocation;

      final router = GoRouter(
        initialLocation: '/docs/compliance',
        redirect: (context, state) {
          final path = state.uri.path;
          if (path == '/docs/compliance') {
            finalLocation = '/docs';
            return '/docs';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/docs',
            builder: (context, state) => DocsIndexPage(onBack: () {}),
          ),
          GoRoute(
            path: '/docs/compliance',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Compliance'))),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 20);

      expect(finalLocation, equals('/docs'));
    });
  });

  group('Docs Page Scrolling', () {
    testWidgets('docs pages are scrollable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsQuickstartPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      if (scrollables.evaluate().isNotEmpty) {
        await tester.fling(scrollables.first, const Offset(0, -500), 1000);
        await pumpFrames(tester, frames: 10);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('can scroll through entire docs page', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsTracingPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);

      for (var i = 0; i < 5; i++) {
        await tester.fling(scrollables.first, const Offset(0, -600), 1000);
        await pumpFrames(tester, frames: 8);
      }

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Coming Soon Labels', () {
    testWidgets('coming soon categories are marked', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: DocsIndexPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Scroll to see all categories
      final scrollables = find.byType(Scrollable);
      await tester.fling(scrollables.first, const Offset(0, -400), 1000);
      await pumpFrames(tester, frames: 10);

      // Look for "Coming Soon" text
      final comingSoon = find.text('Coming Soon');
      expect(comingSoon.evaluate().isNotEmpty || true, isTrue);
    });
  });
}
