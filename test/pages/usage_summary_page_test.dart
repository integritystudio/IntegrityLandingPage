import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/usage_summary_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
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
      // where reading the local month would name October 1. On a UTC machine it
      // cannot fail, which is why CI runs the suite with TZ=America/Denver (TS34).
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
    const pollInterval = Duration(seconds: 30);
    const summaryBody = {
      'org_id': 'org-1',
      'period_start': '2026-09-01',
      'buckets': [
        {'bucket_date': '2026-09-01', 'metric_key': 'requests', 'total_quantity': bucketUnits, 'request_count': 1},
      ],
    };

    late MockHttpAdapter adapter;

    setUp(() {
      adapter = MockHttpAdapter()..stubJson('GET', summaryBody, path: summaryPath);
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
    int quotaFetches() => adapter.requestLog.where((r) => r.path.endsWith(quotaPath)).length;

    Color? barColor(WidgetTester tester) =>
        tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).valueColor?.value;

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

    // QuotaThresholds: warning from 75%, danger from 90%, reached at the limit. Danger
    // shares warning's words and alert, so the bar colour is what tells them apart.
    const approachingTitle = 'Approaching your monthly limit';
    const reachedLabel = 'Monthly limit reached';
    final belowLimit = <({String name, int used, String status, String? alert, Color color})>[
      (name: 'normal, well under', used: 40, status: '1% used', alert: null, color: AppColors.blue500),
      (name: 'normal, one unit under 75%', used: 2249, status: '74% used', alert: null, color: AppColors.blue500),
      (name: 'warning at exactly 75%', used: 2250, status: '75% used', alert: approachingTitle, color: AppColors.warning),
      (name: 'warning, one unit under 90%', used: 2699, status: '89% used', alert: approachingTitle, color: AppColors.warning),
      (name: 'danger at exactly 90%', used: 2700, status: '90% used', alert: approachingTitle, color: AppColors.error),
      (name: 'danger one unit short: never "100% used"', used: 2999, status: '99% used', alert: approachingTitle, color: AppColors.error),
    ];
    for (final level in belowLimit) {
      testWidgets('level ${level.name}', (tester) async {
        stubQuota(used: level.used);
        await pumpPage(tester);

        expect(find.text(level.status), findsOneWidget);
        expect(find.text(approachingTitle), level.alert == null ? findsNothing : findsOneWidget);
        expect(find.text(reachedLabel), findsNothing);
        expect(barColor(tester), level.color);
      });
    }

    for (final used in [monthlyLimit, monthlyLimit + 500]) {
      testWidgets('level reached at $used units: status, alert and a full red bar', (tester) async {
        stubQuota(used: used);
        await pumpPage(tester);

        expect(find.text('$used / $monthlyLimit units'), findsOneWidget);
        // The status line and the alert title.
        expect(find.text(reachedLabel), findsNWidgets(2));
        expect(find.textContaining('New requests are refused until the quota resets.'), findsOneWidget);
        expect(barColor(tester), AppColors.error);
        expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 1.0);
      });
    }

    testWidgets('Try again refetches the quota as well as the summary', (tester) async {
      // Retries of the 500 would otherwise leave delay timers pending at the end.
      DashboardService.retryDelay = (_) async {};
      addTearDown(DashboardService.resetRetryDelay);
      stubQuota(used: 40);
      adapter.stubJson('GET', {'error': 'unavailable'}, statusCode: 500, path: summaryPath);
      await pumpPage(tester);
      final quotaBefore = quotaFetches();
      final summaryBefore = summaryFetches();

      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(seconds: 1));

      // The summary 500 is retried by DashboardService, so only "fetched again" is stable.
      expect(summaryFetches(), greaterThan(summaryBefore));
      expect(quotaFetches(), quotaBefore + 1);
    });

    testWidgets('gives the bar an accessible name and value', (tester) async {
      final handle = tester.ensureSemantics();
      stubQuota(used: 2400);
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.byType(LinearProgressIndicator)),
        isSemantics(label: 'Monthly usage, 2400 of $monthlyLimit units', value: '80'),
      );
      // Not addTearDown: flutter_test checks for undisposed handles before teardowns run.
      handle.dispose();
    });

    testWidgets('stops polling while hidden and refreshes on return', (tester) async {
      stubQuota(used: 40);
      await pumpPage(tester);
      final summaryAfterLoad = summaryFetches();
      final quotaAfterLoad = quotaFetches();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(minutes: 2));
      expect(summaryFetches(), summaryAfterLoad, reason: 'no polls while hidden');
      expect(quotaFetches(), quotaAfterLoad, reason: 'no polls while hidden');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(summaryFetches(), summaryAfterLoad + 1, reason: 'refreshes on return');
      expect(quotaFetches(), quotaAfterLoad + 1, reason: 'refreshes on return');

      await tester.pump(pollInterval);
      expect(summaryFetches(), summaryAfterLoad + 2, reason: 'polling resumes');
      expect(quotaFetches(), quotaAfterLoad + 2, reason: 'each poll refreshes the quota too');
    });

    testWidgets('keeps polling while inactive, and resuming replaces the timer rather than adding one', (tester) async {
      stubQuota(used: 40);
      await pumpPage(tester);
      // Move out of phase with the first timer, so a leaked one would fire on its own beat.
      await tester.pump(const Duration(seconds: 20));
      final afterLoad = quotaFetches();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 15));
      expect(quotaFetches(), afterLoad + 1, reason: 'inactive (e.g. a focus change) keeps polling');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(quotaFetches(), afterLoad + 2, reason: 'resuming refreshes once');

      await tester.pump(pollInterval);
      expect(quotaFetches(), afterLoad + 3, reason: 'one poll per interval, not one per resume');
    });

    final quotaFailures = <({String name, void Function() restub})>[
      (name: 'is refused', restub: () => adapter.stubJson('GET', {'error': 'Forbidden'}, statusCode: 403, path: quotaPath)),
      (name: 'has no plan', restub: () => stubQuota(limit: null, planKey: null)),
    ];
    for (final failure in quotaFailures) {
      testWidgets('keeps the last quota when a later fetch ${failure.name}', (tester) async {
        stubQuota(used: 40);
        await pumpPage(tester);
        final before = quotaFetches();

        failure.restub();
        await tester.pump(pollInterval);

        expect(quotaFetches(), before + 1);
        expect(find.text('40 / $monthlyLimit units'), findsOneWidget);
      });
    }

    testWidgets('keeps the summary on screen when a background poll fails', (tester) async {
      // Retries of the 500 would otherwise leave delay timers pending at the end.
      DashboardService.retryDelay = (_) async {};
      addTearDown(DashboardService.resetRetryDelay);
      stubQuota(used: 40);
      await pumpPage(tester);
      final before = summaryFetches();

      adapter.stubJson('GET', {'error': 'unavailable'}, statusCode: 500, path: summaryPath);
      await tester.pump(pollInterval);

      expect(summaryFetches(), greaterThan(before));
      expect(find.text('Try again'), findsNothing);
      expect(find.text('$bucketUnits'), findsOneWidget);
    });

    testWidgets('does not start a second summary request while one is in flight', (tester) async {
      stubQuota(used: 40);
      final firstLoad = adapter.stubDelayedJson('GET', summaryBody, path: summaryPath);
      // Not pumpApp: its settle would time out on the loading spinner.
      await tester.pumpPage(const UsageSummaryPage(args: args));
      addTearDown(() => tester.pumpWidget(const SizedBox()));

      await tester.pump(pollInterval);
      expect(quotaFetches(), 2, reason: 'the poll ran');
      expect(summaryFetches(), 1, reason: 'but skipped the summary still in flight');

      firstLoad.complete();
      await tester.pump();
      await tester.pump(pollInterval);
      expect(summaryFetches(), 2);
    });
  });
}
