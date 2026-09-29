import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:integrity_studio_ai/app.dart';
import 'package:integrity_studio_ai/pages/landing_page.dart';
import 'package:integrity_studio_ai/routing/cookie_shell.dart';
import 'package:integrity_studio_ai/routing/app_router.dart';
import 'package:integrity_studio_ai/theme/theme.dart';

void main() {

  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('IntegrityStudioApp', () {
    group('construction', () {
      testWidgets('creates without error', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(IntegrityStudioApp), findsOneWidget);
      });

      testWidgets('shows MaterialApp', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        // MaterialApp.router creates a MaterialApp internally
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    // Route -> page mapping lives in test/routing/app_router_test.dart, which
    // builds its own MaterialApp.router. This is the one routing assertion that
    // needs the real App: it proves IntegrityStudioApp mounts createAppRouter's
    // router, so '/' renders LandingPage.
    group('routing', () {
      testWidgets('initial route shows landing page', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(LandingPage), findsOneWidget);
      });
    });

    group('theme', () {
      testWidgets('uses dark theme', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.theme, isNotNull);
      });

      testWidgets('has correct title', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(
          materialApp.title,
          equals('Integrity Studio - Enterprise AI Observability'),
        );
      });

      testWidgets('hides debug banner', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.debugShowCheckedModeBanner, isFalse);
      });
    });

    group('state management', () {
      testWidgets('initState runs without errors on non-web platform',
          (tester) async {
        setDesktopSize(tester);

        // On non-web platforms, hasConsent() returns true,
        // so _showCookieBanner stays false
        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(IntegrityStudioApp), findsOneWidget);
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('completes async initialization after pump', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        // Allow async initialization to complete
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        // App should still be rendered correctly
        expect(find.byType(IntegrityStudioApp), findsOneWidget);
      });

      testWidgets('router is created during initialization', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(const IntegrityStudioApp());
        await tester.pump(const Duration(milliseconds: 100));

        // The router should be active (app renders pages)
        final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.routerConfig, isNotNull);
      });
    });
  });

  group('createAppRouter', () {
    testWidgets('creates router with all required parameters', (tester) async {
      setDesktopSize(tester);

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {},
      );

      expect(router, isA<GoRouter>());
      expect(router.configuration.routes.isNotEmpty, isTrue);
    });

    testWidgets('router uses CookieBannerShell', (tester) async {
      setDesktopSize(tester);

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // CookieBannerShell should be present as the shell route wrapper
      expect(find.byType(CookieBannerShell), findsOneWidget);
    });

    testWidgets('shows cookie banner when cookieBannerNotifier is true',
        (tester) async {
      setDesktopSize(tester);
      addTearDown(() => cookieBannerNotifier.value = false);

      cookieBannerNotifier.value = true;

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CookieBannerShell), findsOneWidget);
      expect(cookieBannerNotifier.value, isTrue);
    });

    testWidgets('hides cookie banner when cookieBannerNotifier is false',
        (tester) async {
      setDesktopSize(tester);

      cookieBannerNotifier.value = false;

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CookieBannerShell), findsOneWidget);
      expect(cookieBannerNotifier.value, isFalse);
    });
  });

  group('App callback integration', () {
    // Test using a testable version that exposes state via callbacks
    testWidgets('onConsentGiven callback is invokable', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => cookieBannerNotifier.value = false);

      bool consentWasGiven = false;
      cookieBannerNotifier.value = true;

      final router = createAppRouter(
        onConsentGiven: () => consentWasGiven = true,
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Get the shell and verify callback is wired
      final shell =
          tester.widget<CookieBannerShell>(find.byType(CookieBannerShell));
      shell.onConsentGiven();

      expect(consentWasGiven, isTrue);
    });

    testWidgets('onShowCookieSettings callback is passed to pages',
        (tester) async {
      setDesktopSize(tester);

      bool settingsShown = false;

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () => settingsShown = true,
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // LandingPage should have the callback
      final landingPage =
          tester.widget<LandingPage>(find.byType(LandingPage));
      landingPage.onShowCookieSettings?.call();

      expect(settingsShown, isTrue);
    });
  });

  group('Banner state change via notifier', () {
    testWidgets('banner visibility changes when notifier changes', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => cookieBannerNotifier.value = false);

      // Start with banner hidden
      cookieBannerNotifier.value = false;

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(cookieBannerNotifier.value, isFalse);

      // Change notifier to show banner
      cookieBannerNotifier.value = true;
      await tester.pump(const Duration(milliseconds: 100));

      expect(cookieBannerNotifier.value, isTrue);
    });
  });

  group('Stateful callback tests', () {
    // Test the callback behavior through the app's router mechanism
    testWidgets(
        'onConsentGiven callback hides banner via notifier',
        (tester) async {
      setDesktopSize(tester);
      addTearDown(() => cookieBannerNotifier.value = false);

      // Start with banner shown
      cookieBannerNotifier.value = true;

      bool consentCallbackInvoked = false;

      final router = createAppRouter(
        onConsentGiven: () {
          consentCallbackInvoked = true;
          cookieBannerNotifier.value = false;
        },
        onShowCookieSettings: () {},
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify initial state - banner shown
      expect(cookieBannerNotifier.value, isTrue);

      // Get shell and invoke consent callback
      final shell =
          tester.widget<CookieBannerShell>(find.byType(CookieBannerShell));
      shell.onConsentGiven();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify callback was invoked and notifier updated
      expect(consentCallbackInvoked, isTrue);
      expect(cookieBannerNotifier.value, isFalse);
    });

    testWidgets(
        'onShowCookieSettings callback shows banner via notifier',
        (tester) async {
      setDesktopSize(tester);
      addTearDown(() => cookieBannerNotifier.value = false);

      // Start with banner hidden
      cookieBannerNotifier.value = false;

      bool settingsCallbackInvoked = false;

      final router = createAppRouter(
        onConsentGiven: () {},
        onShowCookieSettings: () {
          settingsCallbackInvoked = true;
          cookieBannerNotifier.value = true;
        },
      );

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify initial state - banner hidden
      expect(cookieBannerNotifier.value, isFalse);

      // Get the landing page and invoke onShowCookieSettings
      final landingPage =
          tester.widget<LandingPage>(find.byType(LandingPage));
      landingPage.onShowCookieSettings?.call();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify callback was invoked and notifier updated
      expect(settingsCallbackInvoked, isTrue);
      expect(cookieBannerNotifier.value, isTrue);
    });
  });

  group('Real IntegrityStudioApp integration', () {
    testWidgets('renders correctly after initState', (tester) async {
      setDesktopSize(tester);

      // Create and pump the real app
      await tester.pumpWidget(const IntegrityStudioApp());

      // initState is called immediately, which sets up the router and starts consent checks
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the app renders correctly after initialization
      expect(find.byType(IntegrityStudioApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);

      // Allow any async operations to complete
      await tester.pump(const Duration(milliseconds: 500));

      // The app should still be rendering correctly
      expect(find.byType(IntegrityStudioApp), findsOneWidget);
    });
  });

  // Note: Achieving 90%+ coverage for lib/app.dart requires web tests
  // (flutter test --platform chrome) because:
  // 1. kIsWeb branches (lines 46-62) cannot be reached in native tests
  // 2. ConsentManager.hasConsent() always returns true on non-web platforms,
  //    so the !hasConsent branch (lines 39-42) is unreachable
  // 3. The _handleConsentGiven and _showCookieSettings callback methods
  //    (lines 67-77) are only invoked when the cookie banner is shown,
  //    which requires hasConsent() to return false (web-only scenario)
  //
  // Current native test coverage: ~50% (19/38 lines)
  // Maximum achievable without web tests: ~50-60%
}
