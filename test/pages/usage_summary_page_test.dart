import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/pages/usage_summary_page.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

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
}
