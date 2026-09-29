import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/usage_summary_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';

import '../helpers/mock_http_adapter.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('aggregateUsageByDate', () {
    test('returns empty map for empty bucket list', () {
      final result = aggregateUsageByDate([]);
      expect(result, isEmpty);
    });

    test('returns single entry for single bucket', () {
      final buckets = [
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'requests',
          totalQuantity: 100,
          requestCount: 10,
        ),
      ];
      final result = aggregateUsageByDate(buckets);
      expect(result, {'2026-03-01': 100});
    });

    test('sums quantities for multiple metrics on same date', () {
      final buckets = [
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'requests',
          totalQuantity: 100,
          requestCount: 10,
        ),
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'tokens',
          totalQuantity: 500,
          requestCount: 5,
        ),
      ];
      final result = aggregateUsageByDate(buckets);
      expect(result, {'2026-03-01': 600});
    });

    test('keeps separate entries for different dates', () {
      final buckets = [
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'requests',
          totalQuantity: 100,
          requestCount: 10,
        ),
        const UsageBucket(
          bucketDate: '2026-03-02',
          metricKey: 'requests',
          totalQuantity: 200,
          requestCount: 20,
        ),
      ];
      final result = aggregateUsageByDate(buckets);
      expect(result, {'2026-03-01': 100, '2026-03-02': 200});
    });

    test('aggregates multi-metric multi-date buckets correctly', () {
      final buckets = [
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'requests',
          totalQuantity: 50,
          requestCount: 5,
        ),
        const UsageBucket(
          bucketDate: '2026-03-01',
          metricKey: 'tokens',
          totalQuantity: 300,
          requestCount: 3,
        ),
        const UsageBucket(
          bucketDate: '2026-03-02',
          metricKey: 'requests',
          totalQuantity: 80,
          requestCount: 8,
        ),
      ];
      final result = aggregateUsageByDate(buckets);
      expect(result['2026-03-01'], 350);
      expect(result['2026-03-02'], 80);
    });

    test('handles bucket with zero quantity', () {
      final buckets = [
        const UsageBucket(
          bucketDate: '2026-03-05',
          metricKey: 'requests',
          totalQuantity: 0,
          requestCount: 0,
        ),
      ];
      final result = aggregateUsageByDate(buckets);
      expect(result, {'2026-03-05': 0});
    });
  });

  group('monthlyResetLabel', () {
    test('names the first of the next UTC month', () {
      expect(monthlyResetLabel(DateTime.utc(2026, 9, 29, 12)), 'Resets October 1, 00:00 UTC');
    });

    test('rolls the year over in December', () {
      expect(monthlyResetLabel(DateTime.utc(2026, 12, 31, 23, 59)), 'Resets January 1, 00:00 UTC');
    });

    test('uses the UTC month, not the local one', () {
      // Already October in UTC, but still September on any machine west of UTC,
      // where reading the local month would name October 1.
      final instant = DateTime.utc(2026, 10, 1, 2);
      expect(monthlyResetLabel(instant.toLocal()), 'Resets November 1, 00:00 UTC');
    });
  });

  // CR52: the page fetches its own quota; the bar reads the meter the gateway
  // enforces, while the chart and per-metric table keep the bucket totals.
  group('monthly quota', () {
    const bucketUnits = 100;
    const monthlyLimit = 3000;
    const summaryPath = '/usage/summary';
    const quotaPath = '/quota/status';
    const args = UsageSummaryArgs(orgId: 'org-1', orgName: 'Org One', jwt: 'test.jwt');

    late MockHttpAdapter adapter;

    setUp(() {
      adapter = MockHttpAdapter()
        ..stubJson('GET', {
          'org_id': 'org-1',
          'period_start': '2026-09-01',
          'buckets': [
            {'bucket_date': '2026-09-01', 'metric_key': 'requests', 'total_quantity': bucketUnits, 'request_count': 1},
          ],
        }, path: summaryPath);
      DashboardService.setDioForTesting(dioWithMockAdapter(adapter));
    });

    tearDown(DashboardService.resetDio);

    void stubQuota({int? limit = monthlyLimit, int used = 0, String? planKey = 'starter'}) {
      adapter.stubJson('GET', {
        'planKey': ?planKey,
        'monthlyLimit': limit,
        'monthlyUsed': used,
      }, path: quotaPath);
    }

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpApp(const UsageSummaryPage(args: args));
      // Unmount so the page cancels its polling timer before the test ends.
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    }

    int summaryFetches() => adapter.requestLog.where((r) => r.path.endsWith(summaryPath)).length;

    testWidgets('shows the enforced monthlyUsed against the limit, not the bucket total', (tester) async {
      stubQuota(used: 40);
      await pumpPage(tester);

      expect(find.text('40 / $monthlyLimit units'), findsOneWidget);
      expect(find.text('1% used'), findsOneWidget);
      // The per-metric table still reports the bucket total.
      expect(find.text('$bucketUnits'), findsOneWidget);
      expect(find.byType(Alert), findsNothing);
    });

    testWidgets('shows the bucket total alone when the quota fetch fails', (tester) async {
      adapter.stubJson('GET', {'error': 'Forbidden'}, statusCode: 403, path: quotaPath);
      await pumpPage(tester);

      expect(find.text('$bucketUnits units'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('% used'), findsNothing);
    });

    testWidgets('does not read an uninitialised quota (no plan) as unlimited', (tester) async {
      stubQuota(limit: null, planKey: null);
      await pumpPage(tester);

      expect(find.text('$bucketUnits units'), findsOneWidget);
      expect(find.text('Unlimited plan'), findsNothing);
    });

    testWidgets('says "Unlimited plan" when the plan has no monthly limit', (tester) async {
      stubQuota(limit: null, used: 40, planKey: 'enterprise');
      await pumpPage(tester);

      expect(find.text('40 units'), findsOneWidget);
      expect(find.text('Unlimited plan'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows when the quota resets, in UTC', (tester) async {
      stubQuota(used: 40);
      await pumpPage(tester);

      expect(find.text(monthlyResetLabel(DateTime.now())), findsOneWidget);
    });

    testWidgets('states the warning level in words and raises an alert', (tester) async {
      stubQuota(used: 2400); // 80%
      await pumpPage(tester);

      expect(find.text('80% used'), findsOneWidget);
      expect(find.text('Approaching your monthly limit'), findsOneWidget);
      expect(find.textContaining("You have used 80% of this month's $monthlyLimit units."), findsOneWidget);
    });

    testWidgets('states the danger level in words', (tester) async {
      stubQuota(used: 2700); // 90%
      await pumpPage(tester);

      expect(find.text('90% used'), findsOneWidget);
      expect(find.text('Approaching your monthly limit'), findsOneWidget);
    });

    testWidgets('never says 100% before the limit is reached', (tester) async {
      stubQuota(used: 2999);
      await pumpPage(tester);

      expect(find.text('99% used'), findsOneWidget);
      expect(find.text('Monthly limit reached'), findsNothing);
    });

    testWidgets('shows a limit-reached state and alert at the limit', (tester) async {
      stubQuota(used: monthlyLimit);
      await pumpPage(tester);

      // The status line and the alert title.
      expect(find.text('Monthly limit reached'), findsNWidgets(2));
      expect(find.textContaining('New requests are refused until the quota resets.'), findsOneWidget);
    });

    testWidgets('gives the bar an accessible name and value', (tester) async {
      final handle = tester.ensureSemantics();
      stubQuota(used: 2400);
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)),
        isSemantics(label: 'Monthly usage, 2400 of $monthlyLimit units', value: '80'),
      );
      handle.dispose();
    });

    testWidgets('stops polling while hidden and refreshes on return', (tester) async {
      stubQuota(used: 40);
      await pumpPage(tester);
      final afterLoad = summaryFetches();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(minutes: 2));
      expect(summaryFetches(), afterLoad, reason: 'no polls while hidden');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(summaryFetches(), afterLoad + 1, reason: 'refreshes on return');

      await tester.pump(const Duration(seconds: 30));
      expect(summaryFetches(), afterLoad + 2, reason: 'polling resumes');
    });
  });
}
