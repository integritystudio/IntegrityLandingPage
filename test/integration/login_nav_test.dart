import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
import 'helpers/integration_test_helpers.dart';

/// Integration tests for the homepage Log In entry point.
///
/// Log In sends existing customers off-site to the dashboard SPA, which owns
/// the Auth0 Universal Login redirect (auth code + PKCE) — this site never
/// handles their credentials. Desktop shows an inline button; the compact
/// (mobile/tablet) nav exposes the same destination via the hamburger menu.
void main() {
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  /// URLs the app asked the platform to open, newest last.
  late List<String> launched;

  setUp(() {
    suppressOverflowErrors();
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
      if (call.method == 'canLaunch') return true;
      launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
  });

  tearDown(() {
    restoreErrorHandler();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
  });

  GoRouter buildRouter() => GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (context, state) => LandingPage(onShowCookieSettings: () {}),
          ),
          GoRoute(
            path: Routes.docs,
            builder: (context, state) => const Scaffold(body: Text('Docs')),
          ),
        ],
      );

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
    await pumpFrames(tester, frames: 20);
  }

  group('Homepage Log In', () {
    testWidgets('desktop nav shows a Log In button', (tester) async {
      setDesktopSize(tester);
      await pumpHome(tester);

      expect(find.text(CTAText.logIn), findsOneWidget);
    });

    testWidgets('tapping Log In opens the dashboard SPA', (tester) async {
      setDesktopSize(tester);
      await pumpHome(tester);

      await tester.tap(find.text(CTAText.logIn));
      await pumpFrames(tester, frames: 15);

      expect(launched, [ExternalUrls.dashboardApp]);
    });

    testWidgets('compact nav offers Log In in the menu', (tester) async {
      setMobileSize(tester);
      await pumpHome(tester);

      await tester.tap(find.byIcon(LucideIcons.menu));
      await pumpFrames(tester, frames: 15);

      expect(find.text(CTAText.logIn), findsOneWidget);
    });

    testWidgets('compact nav Log In opens the dashboard SPA', (tester) async {
      setMobileSize(tester);
      await pumpHome(tester);

      await tester.tap(find.byIcon(LucideIcons.menu));
      await pumpFrames(tester, frames: 15);
      await tester.tap(find.text(CTAText.logIn));
      await pumpFrames(tester, frames: 15);

      expect(launched, [ExternalUrls.dashboardApp]);
    });

    // Log In shares _handleNavItemSelected with every other menu entry, so
    // guard that an app path still routes in-app rather than off-site.
    testWidgets('an app-path nav item routes in-app, not off-site',
        (tester) async {
      setMobileSize(tester);
      await pumpHome(tester);

      await tester.tap(find.byIcon(LucideIcons.menu));
      await pumpFrames(tester, frames: 15);
      await tester.tap(find.text('Docs'));
      await pumpFrames(tester, frames: 15);

      expect(find.text('Docs'), findsOneWidget);
      expect(launched, isEmpty);
    });
  });
}
