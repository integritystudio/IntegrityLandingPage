
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/checkout_page.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import '../helpers/test_helpers.dart';

import '../helpers/mock_http_adapter.dart';

/// GoRouter wrapping CheckoutPage for navigation testing.
GoRouter _makeCheckoutRouter({required CheckoutArgs args}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => CheckoutPage(args: args),
      ),
      GoRoute(
        path: '/request_failure',
        builder: (_, _) =>
            const Scaffold(body: Text('request_failure_page')),
      ),
      GoRoute(
        path: '/request_success',
        builder: (_, _) =>
            const Scaffold(body: Text('request_success_page')),
      ),
    ],
  );
}

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('CheckoutPage', () {
    group('loading state', () {
      testWidgets('renders loading indicator while fetching session',
          (tester) async {
        setDesktopSize(tester);

        // Mock: never resolves — page stays in loading state.
        final adapter = MockHttpAdapter()..stubNever('POST');
        ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
        addTearDown(ProvisioningService.resetDio);

        final args = CheckoutArgs(email: 'user@example.com', tier: 'growth');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();
        // Flush dio's request-start timer; the stubbed transport then holds
        // the request open as a pending Future (allowed by the test binding).
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('Redirecting'), findsOneWidget);
      });
    });

    group('error routing', () {
      late MockHttpAdapter adapter;

      setUp(() {
        adapter = MockHttpAdapter();
        ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
        ProvisioningService.retryDelay = (_) async {};
      });

      tearDown(() {
        ProvisioningService.resetDio();
        ProvisioningService.resetRetryDelay();
      });

      testWidgets('routes to /request_failure on CheckoutError for growth tier', (tester) async {
        setDesktopSize(tester);
        adapter.stubJson('POST', 
          {'error': 'Stripe not configured'},
          statusCode: 500,
        );

        final args = CheckoutArgs(email: 'user@example.com', tier: 'growth');
        final router = _makeCheckoutRouter(args: args);

        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_failure_page'), findsOneWidget);
      });

      testWidgets('routes to /request_success on CheckoutError for enterprise tier', (tester) async {
        setDesktopSize(tester);
        adapter.stubJson('POST', 
          {'error': 'no Stripe price configured for tier: enterprise'},
          statusCode: 500,
        );

        final args = CheckoutArgs(email: 'corp@bigco.com', tier: 'enterprise');
        final router = _makeCheckoutRouter(args: args);

        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_success_page'), findsOneWidget);
        expect(find.text('request_failure_page'), findsNothing);
      });
    });

    group('args', () {
      testWidgets('accepts growth tier args', (tester) async {
        setDesktopSize(tester);

        final adapter = MockHttpAdapter()..stubNever('POST');
        ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
        addTearDown(ProvisioningService.resetDio);

        final args = CheckoutArgs(email: 'buyer@test.com', tier: 'growth');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.byType(CheckoutPage), findsOneWidget);
      });

      testWidgets('accepts enterprise tier args', (tester) async {
        setDesktopSize(tester);

        final adapter = MockHttpAdapter()..stubNever('POST');
        ProvisioningService.setDioForTesting(dioWithMockAdapter(adapter));
        addTearDown(ProvisioningService.resetDio);

        final args =
            CheckoutArgs(email: 'corp@bigco.com', tier: 'enterprise');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));

        expect(find.byType(CheckoutPage), findsOneWidget);
      });
    });
  });
}
