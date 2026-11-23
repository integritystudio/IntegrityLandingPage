import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/checkout_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import '../helpers/test_helpers.dart';

import '../helpers/mock_http_adapter.dart';

const _jwt = 'test-jwt';
const _orgId = 'org-1';
const _checkoutUrl = 'https://checkout.stripe.com/c/pay/cs_test_1';

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

/// CheckoutPage contract:
/// - Resolves the active org from /bootstrap with the session's token, never
///   from an email, and checks out that org through api-gateway's org-scoped
///   POST /v1/orgs/:id/checkout-session with the same token.
/// - A failure at either step goes to /request_failure, or to /request_success
///   for enterprise, whose org exists either way.
void main() {
  late MockHttpAdapter provisioning;
  late MockHttpAdapter dashboard;

  setUp(() {
    setUpOverflowErrorSuppression();
    provisioning = MockHttpAdapter();
    dashboard = MockHttpAdapter();
    ProvisioningService.setDioForTesting(dioWithMockAdapter(provisioning));
    DashboardService.setDioForTesting(dioWithMockAdapter(dashboard));
    ProvisioningService.retryDelay = (_) async {};
    DashboardService.retryDelay = (_) async {};
  });

  tearDown(() {
    ProvisioningService.resetDio();
    ProvisioningService.resetRetryDelay();
    DashboardService.resetDio();
    DashboardService.resetRetryDelay();
    tearDownOverflowErrorSuppression();
  });

  void stubBootstrap() {
    provisioning.stubJson(
      'POST',
      {
        'organizations': [
          {'id': _orgId, 'name': 'Acme', 'role': 'owner', 'plan_key': 'starter', 'billing_status': 'inactive'},
        ],
        'active_org_id': _orgId,
        'entitlements': {'monthly_units': 0},
        'usage_snapshot': {'month_to_date_units': 0},
      },
      path: '/bootstrap',
    );
  }

  Future<void> pumpAndSettleRequests(WidgetTester tester, CheckoutArgs args) async {
    setDesktopSize(tester);
    await tester.pumpWidget(MaterialApp.router(
      theme: testTheme,
      routerConfig: _makeCheckoutRouter(args: args),
    ));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders a loading indicator while the session is created', (tester) async {
    setDesktopSize(tester);
    provisioning.stubNever('POST');

    await tester.pumpWidget(MaterialApp(
      theme: testTheme,
      home: const CheckoutPage(args: CheckoutArgs(jwt: _jwt, tier: 'growth')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Redirecting'), findsOneWidget);
  });

  testWidgets('checks out the bootstrap org through the gateway with the session token', (tester) async {
    stubBootstrap();
    dashboard.stubJson('POST', {'url': _checkoutUrl}, path: '/v1/orgs/$_orgId/checkout-session');

    await pumpAndSettleRequests(tester, const CheckoutArgs(jwt: _jwt, tier: 'Growth'));

    final checkout = dashboard.requestLog.singleWhere((r) => r.path.endsWith('/checkout-session'));
    expect(checkout.headers['Authorization'], 'Bearer $_jwt');
    expect(checkout.data, {'plan': 'growth'});
    expect(find.text('request_failure_page'), findsNothing);
  });

  testWidgets('routes to /request_failure when the gateway refuses a growth checkout', (tester) async {
    stubBootstrap();
    dashboard.stubJson('POST', {'error': 'Forbidden'}, statusCode: 403, path: '/v1/orgs/$_orgId/checkout-session');

    await pumpAndSettleRequests(tester, const CheckoutArgs(jwt: _jwt, tier: 'growth'));

    expect(find.text('request_failure_page'), findsOneWidget);
  });

  testWidgets('routes to /request_failure, calling no checkout, when bootstrap fails', (tester) async {
    provisioning.stubJson('POST', {'error': 'Unauthorized'}, statusCode: 401, path: '/bootstrap');

    await pumpAndSettleRequests(tester, const CheckoutArgs(jwt: _jwt, tier: 'growth'));

    expect(find.text('request_failure_page'), findsOneWidget);
    expect(dashboard.requestLog, isEmpty);
  });

  testWidgets('routes to /request_success when an enterprise checkout fails', (tester) async {
    stubBootstrap();
    dashboard.stubJson('POST', {'error': 'Plan enterprise is not available for self-serve checkout'},
        statusCode: 400, path: '/v1/orgs/$_orgId/checkout-session');

    await pumpAndSettleRequests(tester, const CheckoutArgs(jwt: _jwt, tier: 'enterprise'));

    expect(find.text('request_success_page'), findsOneWidget);
    expect(find.text('request_failure_page'), findsNothing);
  });
}
