import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';
import 'package:integrity_studio_ai/pages/callback_page.dart';
import 'package:integrity_studio_ai/pages/dashboard_page.dart';
import 'package:integrity_studio_ai/pages/provision_page.dart';
import 'package:integrity_studio_ai/services/auth0_service.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';

import '../helpers/fake_auth0_browser.dart';
import '../helpers/mock_http_adapter.dart';
import '../helpers/test_helpers.dart';

const _tokenPath = '/oauth/token';
const _orgsPath = '/v1/orgs';

/// CallbackPage contract: exchange the code, then route on the user's orgs —
/// none (a new account) → /provision carrying the session and any signup
/// intent; some → /dashboard. Any failure stays on the page with a retry.
void main() {
  late FakeAuth0Browser browser;
  late MockHttpAdapter http;
  Object? provisionExtra;
  Object? dashboardExtra;

  setUp(() {
    setUpOverflowErrorSuppression();
    initializeTestContent();
    browser = FakeAuth0Browser();
    http = MockHttpAdapter();
    Auth0Service.setForTesting(browser: browser, dio: dioWithMockAdapter(http));
    DashboardService.setDioForTesting(dioWithMockAdapter(http));
    DashboardService.retryDelay = (_) async {};
    provisionExtra = null;
    dashboardExtra = null;
  });

  tearDown(() {
    Auth0Service.resetForTesting();
    DashboardService.resetDio();
    DashboardService.resetRetryDelay();
    tearDownOverflowErrorSuppression();
  });

  String idToken(String email) {
    String part(Map<String, dynamic> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'RS256'})}.${part({'email': email})}.sig';
  }

  void stubTokens() => http.stubJson(
        'POST',
        {
          'access_token': 'access-1',
          'expires_in': 86400,
          'id_token': idToken('user@example.com'),
          'refresh_token': 'refresh-1',
        },
        path: _tokenPath,
      );

  void stubOrgs(List<Map<String, dynamic>> orgs) =>
      http.stubJson('GET', {'organizations': orgs}, path: _orgsPath);

  /// Start a login in this "tab" and return the state Auth0 would echo back.
  String startLogin({SignupIntent? signup}) {
    Auth0Service.login(signup: signup);
    return browser.lastNavigation!.queryParameters['state']!;
  }

  Future<void> pumpCallback(WidgetTester tester, Map<String, String> params) async {
    setDesktopSize(tester);
    final location = Uri(path: Routes.callback, queryParameters: params).toString();
    await tester.pumpWidget(MaterialApp.router(
      theme: testTheme,
      routerConfig: GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const Text('home')),
          GoRoute(
            path: Routes.callback,
            builder: (_, state) => CallbackPage(uri: state.uri),
          ),
          GoRoute(
            path: Routes.provision,
            builder: (_, state) {
              provisionExtra = state.extra;
              return const Text('provision');
            },
          ),
          GoRoute(
            path: Routes.dashboard,
            builder: (_, state) {
              dashboardExtra = state.extra;
              return const Text('dashboard');
            },
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    clearOverflowExceptions(tester);
  }

  testWidgets('a new account (no orgs) goes to /provision with its session and signup',
      (tester) async {
    final state = startLogin(signup: const SignupIntent(tier: SignupTiers.growth));
    stubTokens();
    stubOrgs([]);

    await pumpCallback(tester, {'code': 'c1', 'state': state});

    expect(find.text('provision'), findsOneWidget);
    final args = provisionExtra as ProvisionArgs;
    expect(args.session.accessToken, 'access-1');
    expect(args.session.email, 'user@example.com');
    expect(args.signup?.tier, SignupTiers.growth);
    final orgsRequest = http.requestLog.singleWhere((r) => r.path.endsWith(_orgsPath));
    expect(orgsRequest.headers['Authorization'], 'Bearer access-1');
  });

  testWidgets('a returning user (has orgs) goes to /dashboard with the access token',
      (tester) async {
    final state = startLogin();
    stubTokens();
    stubOrgs([
      {'id': 'org-1', 'name': 'Acme'},
    ]);

    await pumpCallback(tester, {'code': 'c1', 'state': state});

    expect(find.text('dashboard'), findsOneWidget);
    expect((dashboardExtra as DashboardArgs).jwt, 'access-1');
  });

  testWidgets('an error from Auth0 is shown with a way to sign in again', (tester) async {
    startLogin();

    await pumpCallback(tester, {'error': 'access_denied', 'error_description': 'User cancelled'});

    expect(find.byType(Alert), findsOneWidget);
    expect(find.text('User cancelled'), findsOneWidget);
    expect(http.requestLog, isEmpty);

    browser.navigations.clear();
    await tester.tap(find.widgetWithText(GradientButton, 'Sign in again'));
    await tester.pump();
    expect(browser.lastNavigation?.path, '/authorize');
  });

  testWidgets('a forged state is refused before any token request', (tester) async {
    startLogin();

    await pumpCallback(tester, {'code': 'c1', 'state': 'forged'});

    expect(find.byType(Alert), findsOneWidget);
    expect(http.requestLog, isEmpty);
    expect(provisionExtra, isNull);
    expect(dashboardExtra, isNull);
  });

  testWidgets('an org lookup failure is shown rather than guessed at', (tester) async {
    final state = startLogin();
    stubTokens();
    http.stubJson('GET', {'error': 'unauthorized'}, statusCode: 401, path: _orgsPath);

    await pumpCallback(tester, {'code': 'c1', 'state': state});

    expect(find.byType(Alert), findsOneWidget);
    expect(provisionExtra, isNull, reason: 'an error must not read as "no orgs yet"');
    expect(dashboardExtra, isNull);
  });
}
