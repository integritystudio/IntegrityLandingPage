import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/dashboard_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

import '../helpers/mock_http_adapter.dart';
import '../helpers/test_helpers.dart';

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
        }, path: '/v1/orgs');
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
}
