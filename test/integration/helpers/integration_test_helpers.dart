import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/services/content_loader.dart';

// Re-export shared test helpers so integration tests get everything from one import
export '../../helpers/test_helpers.dart'
    show
        testTheme,
        testableWidget,
        testableSection,
        testableWidgetWithProviders,
        setScreenSize,
        setMobileSize,
        setDesktopSize,
        setTabletSize,
        TestScreenSizes,
        setUpOverflowErrorSuppression,
        tearDownOverflowErrorSuppression,
        isOverflowError,
        clearOverflowExceptions,
        TestData,
        testPageStructure,
        testBackButtonCallback,
        testBackButtonCallbacks,
        testResponsiveLayout,
        PagePumpFunction,
        expectTextStyle,
        expectContainerDecoration;
export '../../helpers/test_content.dart' show initializeTestContent;

import '../../helpers/test_helpers.dart' as shared
    show
        setScreenSize,
        clearOverflowExceptions,
        TestScreenSizes,
        setUpOverflowErrorSuppression,
        tearDownOverflowErrorSuppression;
import '../../helpers/test_content.dart' show initializeTestContent;

// =============================================================================
// Compatibility Aliases
// =============================================================================

/// Alias for [shared.TestScreenSizes] used by integration tests.
typedef ScreenSizes = shared.TestScreenSizes;

/// Suppress overflow errors. Delegates to shared helper.
void suppressOverflowErrors() => shared.setUpOverflowErrorSuppression();

/// Restore error handler. Delegates to shared helper.
void restoreErrorHandler() => shared.tearDownOverflowErrorSuppression();

// =============================================================================
// Integration-Specific Helpers
// =============================================================================

/// Helper to pump frames without using pumpAndSettle.
///
/// Landing page has continuous animations that cause pumpAndSettle to timeout.
/// Automatically clears overflow exceptions after pumping.
Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  shared.clearOverflowExceptions(tester);
}

/// Helper to dismiss cookie banner if present.
Future<void> dismissCookieBanner(WidgetTester tester) async {
  final acceptButton = find.text('Accept All');
  if (acceptButton.evaluate().isNotEmpty) {
    await tester.tap(acceptButton);
    await pumpFrames(tester, frames: 5);
  }
}

/// Pumps the app with a testable router at a specific initial location.
Future<void> pumpAppWithRoute(
  WidgetTester tester, {
  required String initialLocation,
  Size screenSize = shared.TestScreenSizes.desktop,
}) async {
  if (!Content.isLoaded) {
    initializeTestContent();
  }

  shared.setScreenSize(tester, screenSize);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Landing'))),
          ),
          GoRoute(
            path: '/pricing',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Pricing'))),
          ),
          GoRoute(
            path: '/signup',
            builder: (context, state) {
              final tier = state.uri.queryParameters['tier'] ?? 'starter';
              return Scaffold(
                body: Center(child: Text('Signup - $tier')),
              );
            },
          ),
          GoRoute(
            path: '/contact',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Contact'))),
          ),
          GoRoute(
            path: '/docs',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Docs'))),
          ),
          GoRoute(
            path: '/blog',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Blog'))),
          ),
          GoRoute(
            path: '/whylabs-alternative',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('WhyLabs Alternative'))),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
    ),
  );
  await pumpFrames(tester, frames: 5);
}

/// Navigate to a route using GoRouter.
Future<void> navigateTo(WidgetTester tester, String route) async {
  final context = tester.element(find.byType(Navigator).first);
  GoRouter.of(context).go(route);
  await pumpFrames(tester, frames: 10);
}

/// Fill a form field by finding TextField with given label hint.
Future<void> fillFormField(
  WidgetTester tester,
  String labelText,
  String value,
) async {
  final textFields = find.byType(TextField);
  for (var i = 0; i < textFields.evaluate().length; i++) {
    final field = tester.widget<TextField>(textFields.at(i));
    final decoration = field.decoration;
    if (decoration?.labelText?.contains(labelText) == true ||
        decoration?.hintText?.contains(labelText) == true) {
      await tester.enterText(textFields.at(i), value);
      await pumpFrames(tester, frames: 2);
      return;
    }
  }
  await tester.enterText(textFields.first, value);
  await pumpFrames(tester, frames: 2);
}

/// Scroll to find a widget.
Future<bool> scrollToFind(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 20,
}) async {
  final scrollableFinder = find.byType(Scrollable).first;

  for (var i = 0; i < maxScrolls; i++) {
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
    await tester.fling(scrollableFinder, const Offset(0, -500), 1000);
    await pumpFrames(tester, frames: 5);
  }
  return finder.evaluate().isNotEmpty;
}

/// Find widget by text containing substring (case insensitive search).
Finder findTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data != null &&
        widget.data!.toLowerCase().contains(text.toLowerCase()),
  );
}

/// Tap a button with given text.
Future<void> tapButton(WidgetTester tester, String buttonText) async {
  final button = find.text(buttonText);
  if (button.evaluate().isNotEmpty) {
    await tester.tap(button.first);
    await pumpFrames(tester, frames: 5);
  }
}

/// Check if text is visible anywhere on screen.
bool isTextVisible(String text) {
  return find.textContaining(text).evaluate().isNotEmpty;
}
