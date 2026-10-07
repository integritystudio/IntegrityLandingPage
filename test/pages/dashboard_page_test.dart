import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/dashboard_page.dart';
import 'package:integrity_studio_ai/services/auth0_config.dart';
import 'package:integrity_studio_ai/services/auth0_service.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

import '../helpers/fake_auth0_browser.dart';
import '../helpers/mock_http_adapter.dart';
import '../helpers/test_helpers.dart';

/// GET /v1/me/team when no team org exists for the caller's domain (CR54).
const noTeam = {'domain': 'example.com', 'team': null, 'member': false};

void main() {
  group('pickActiveOrg', () {
    const orgs = [
      OrgSummary(orgId: 'org-1', name: 'One'),
      OrgSummary(orgId: 'org-2', name: 'Two'),
    ];

    test('selects the preferred org when the list contains it', () {
      expect(pickActiveOrg(orgs, 'org-2')?.orgId, 'org-2');
    });

    test('falls back to the first org when the preferred one is gone', () {
      expect(pickActiveOrg(orgs, 'org-9')?.orgId, 'org-1');
    });

    test('selects the first org when no preference is given', () {
      expect(pickActiveOrg(orgs, null)?.orgId, 'org-1');
    });

    test('returns null for an empty list', () {
      expect(pickActiveOrg(const [], 'org-1'), isNull);
    });
  });

  group('Observability card', () {
    setUp(() {
      final adapter = MockHttpAdapter()
        ..stubJson('GET', {
          'organizations': [
            {'id': 'org-1', 'name': 'Org One'},
          ],
        }, path: '/v1/orgs')
        ..stubJson('GET', noTeam, path: '/v1/me/team');
      DashboardService.setDioForTesting(dioWithMockAdapter(adapter));
    });

    tearDown(DashboardService.resetDio);

    testWidgets('appears after the other cards with its title and subtitle', (tester) async {
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      expect(find.text('Observability'), findsOneWidget);
      expect(find.text('View your traces, logs, metrics, and evaluations'), findsOneWidget);
      final entitlementsTop = tester.getTopLeft(find.text('Entitlements')).dy;
      expect(tester.getTopLeft(find.text('Observability')).dy, greaterThan(entitlementsTop));
    });

    testWidgets('is reachable on a short screen: the page scrolls rather than clipping', (tester) async {
      tester.view.physicalSize = const Size(400, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Observability'));
      expect(tester.getRect(find.text('Observability')).bottom, lessThanOrEqualTo(500));
    });

    testWidgets('tapping it does not throw when the URL cannot be opened', (tester) async {
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      await tester.ensureVisible(find.text('Observability'));
      await tester.tap(find.text('Observability'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Join your team card (CR54)', () {
    late MockHttpAdapter adapter;
    const personalOrg = {'id': 'org-personal', 'name': 'dev@acme.com'};
    const teamOrg = {'id': 'org-team', 'name': 'acme.com'};

    setUp(() {
      adapter = MockHttpAdapter()
        ..stubJson('GET', {
          'organizations': [personalOrg],
        }, path: '/v1/orgs');
      DashboardService.setDioForTesting(dioWithMockAdapter(adapter));
    });

    tearDown(DashboardService.resetDio);

    void stubTeam({required bool member}) => adapter.stubJson('GET', {
          'domain': 'acme.com',
          'team': teamOrg,
          'member': member,
        }, path: '/v1/me/team');

    testWidgets('is offered when a team org exists and the user is not in it', (tester) async {
      stubTeam(member: false);
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      expect(find.text('Join your team'), findsOneWidget);
      expect(find.text('Join acme.com'), findsOneWidget);
    });

    testWidgets('is not offered to a member', (tester) async {
      stubTeam(member: true);
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      expect(find.text('Join your team'), findsNothing);
    });

    testWidgets('is not offered when no team org exists', (tester) async {
      adapter.stubJson('GET', {'domain': 'acme.com', 'team': null, 'member': false}, path: '/v1/me/team');
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      expect(find.text('Join your team'), findsNothing);
    });

    testWidgets('joining posts once, hides the card and selects the team org', (tester) async {
      stubTeam(member: false);
      adapter.stubJson('POST', {
        'organizationId': 'org-team',
        'name': 'acme.com',
        'role': 'member',
        'joined': true,
      }, path: '/v1/me/team');
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));
      adapter.stubJson('GET', {
        'organizations': [personalOrg, teamOrg],
      }, path: '/v1/orgs');

      await tester.ensureVisible(find.text('Join acme.com'));
      await tester.tap(find.text('Join acme.com'));
      await tester.pumpAndSettle();

      expect(adapter.requestCount('POST'), 1);
      expect(adapter.requestLog.last.path, endsWith('/v1/orgs'));
      expect(find.text('Join your team'), findsNothing);
      final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
      expect(dropdown.value, 'org-team');
    });

    testWidgets('a refusal keeps the card and shows why', (tester) async {
      stubTeam(member: false);
      adapter.stubJson('POST', {'error': {'message': 'nope'}}, statusCode: 403, path: '/v1/me/team');
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      await tester.ensureVisible(find.text('Join acme.com'));
      await tester.tap(find.text('Join acme.com'));
      await tester.pumpAndSettle();

      expect(find.text('Join your team'), findsOneWidget);
      expect(find.text('Verify your email address, then try again.'), findsOneWidget);
    });
  });

  group('Sign out', () {
    late FakeAuth0Browser browser;

    setUp(() {
      browser = FakeAuth0Browser();
      browser.write(BrowserStore.local, 'auth0_refresh_token', 'refresh-1');
      Auth0Service.setForTesting(browser: browser);
      DashboardService.setDioForTesting(dioWithMockAdapter(
          MockHttpAdapter()
            ..stubJson('GET', {'organizations': []}, path: '/v1/orgs')
            ..stubJson('GET', noTeam, path: '/v1/me/team')));
    });

    tearDown(() {
      Auth0Service.resetForTesting();
      DashboardService.resetDio();
    });

    testWidgets('forgets the session and ends the shared Auth0 session', (tester) async {
      await tester.pumpApp(const DashboardPage(args: DashboardArgs(jwt: 'test.jwt')));

      await tester.tap(find.text('Sign out'));
      await tester.pump();

      expect(Auth0Service.hasSession, isFalse);
      expect(browser.lastNavigation?.host, Auth0Config.domain);
      expect(browser.lastNavigation?.path, '/v2/logout');
    });
  });
}
