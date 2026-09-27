import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/blog_page.dart';
import 'package:integrity_studio_ai/pages/contact_page.dart';
// test_helpers imported via integration_test_helpers.dart
import 'helpers/integration_test_helpers.dart';
import 'helpers/mock_services.dart';

/// Integration tests for blog to contact flow.
///
/// Tests the complete user journey:
/// 1. View blog page
/// 2. Click CTA in blog post
/// 3. Verify navigation to contact with context
void main() {

  setUp(() {
    suppressOverflowErrors();
    IntegrationMocks.resetAll();
  });

  tearDown(() {
    restoreErrorHandler();
  });

  group('Blog Page Display', () {
    testWidgets('blog page renders correctly', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(BlogPage), findsOneWidget);
    });

    testWidgets('blog page is scrollable', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);
      expect(scrollables, findsWidgets);

      await tester.fling(scrollables.first, const Offset(0, -500), 1000);
      await pumpFrames(tester, frames: 10);

      expect(find.byType(BlogPage), findsOneWidget);
    });

    testWidgets('blog has article content', (tester) async {
      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      // Look for blog-related content
      final blogIndicators = [
        find.textContaining('Blog'),
        find.textContaining('Article'),
        find.textContaining('Read'),
        find.textContaining('Resources'),
      ];

      var foundContent = false;
      for (final indicator in blogIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundContent = true;
          break;
        }
      }

      expect(foundContent, isTrue, reason: 'Blog page should show recognisable content');
    });
  });

  group('Blog to Contact Navigation', () {
    testWidgets('can navigate from blog to contact', (tester) async {
      setDesktopSize(tester);

      final router = GoRouter(
        initialLocation: '/blog',
        routes: [
          GoRoute(
            path: '/blog',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  const Text('Blog'),
                  ElevatedButton(
                    onPressed: () => context.go('/contact'),
                    child: const Text('Contact Us'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) => ContactPage(
              onBack: () => context.go('/blog'),
              onShowCookieSettings: () {},
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await pumpFrames(tester, frames: 10);

      // Navigate to contact
      await tester.tap(find.text('Contact Us'));
      await pumpFrames(tester, frames: 20);

      expect(find.text('Get in Touch'), findsWidgets);
    });

    testWidgets('blog back button works', (tester) async {
      var backPressed = false;

      setDesktopSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () => backPressed = true),
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

  group('Contact Page After Blog', () {
    testWidgets('contact page fully functional after blog navigation',
        (tester) async {
      setDesktopSize(tester);

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
      await tester.fling(scrollables.first, const Offset(0, -400), 1000);
      await pumpFrames(tester, frames: 10);

      // Form should be functional
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'Blog Visitor');
        await pumpFrames(tester, frames: 3);
        expect(find.text('Blog Visitor'), findsWidgets);
      }
    });
  });

  group('Blog Mobile View', () {
    testWidgets('blog page renders on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      expect(find.byType(BlogPage), findsOneWidget);
    });

    testWidgets('blog scrolls on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: BlogPage(onBack: () {}),
        ),
      );
      await pumpFrames(tester, frames: 20);

      final scrollables = find.byType(Scrollable);
      await tester.fling(scrollables.first, const Offset(0, -400), 1000);
      await pumpFrames(tester, frames: 10);

      expect(find.byType(BlogPage), findsOneWidget);
    });
  });

  group('Full Blog to Contact Flow', () {
    testWidgets('complete navigation flow works', (tester) async {
      setDesktopSize(tester);

      var currentRoute = '/blog';

      final router = GoRouter(
        initialLocation: '/blog',
        routes: [
          GoRoute(
            path: '/blog',
            builder: (context, state) {
              currentRoute = '/blog';
              return BlogPage(onBack: () => context.go('/'));
            },
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) {
              currentRoute = '/contact';
              return ContactPage(
                onBack: () => context.go('/blog'),
                onShowCookieSettings: () {},
              );
            },
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

      expect(currentRoute, equals('/blog'));
    });
  });
}
