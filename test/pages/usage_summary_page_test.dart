import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/usage_summary_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

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

  // CR52: the page fetches its own quota; the hub no longer supplies one.
  group('monthly quota', () {
    const usedUnits = 100;
    const monthlyLimit = 3000;
    const args = UsageSummaryArgs(orgId: 'org-1', orgName: 'Org One', jwt: 'test.jwt');

    late MockHttpAdapter adapter;

    setUp(() {
      adapter = MockHttpAdapter()
        ..stubJson('GET', {
          'org_id': 'org-1',
          'period_start': '2026-09-01',
          'buckets': [
            {'bucket_date': '2026-09-01', 'metric_key': 'requests', 'total_quantity': usedUnits, 'request_count': 1},
          ],
        }, path: '/usage/summary');
      DashboardService.setDioForTesting(dioWithMockAdapter(adapter));
    });

    tearDown(DashboardService.resetDio);

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpApp(const UsageSummaryPage(args: args));
      // Unmount so the page cancels its polling timer before the test ends.
      addTearDown(() => tester.pumpWidget(const SizedBox()));
    }

    testWidgets('shows usage against the fetched monthly limit', (tester) async {
      adapter.stubJson('GET', {'monthlyLimit': monthlyLimit}, path: '/quota/status');

      await pumpPage(tester);

      expect(find.text('$usedUnits / $monthlyLimit units'), findsOneWidget);
    });

    testWidgets('shows usage alone when the quota fetch fails', (tester) async {
      adapter.stubJson('GET', {'error': 'Forbidden'}, statusCode: 403, path: '/quota/status');

      await pumpPage(tester);

      expect(find.text('$usedUnits units'), findsOneWidget);
    });

    testWidgets('shows usage alone for an unlimited plan', (tester) async {
      adapter.stubJson('GET', {'monthlyLimit': null}, path: '/quota/status');

      await pumpPage(tester);

      expect(find.text('$usedUnits units'), findsOneWidget);
    });
  });
}
