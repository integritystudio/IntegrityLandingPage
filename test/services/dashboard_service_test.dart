import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() {
  late HttpServer fakeServer;
  late Dio testDio;
  late _FakeServerHandler serverHandler;

  setUp(() async {
    serverHandler = _FakeServerHandler();
    // Bind and connect via the IPv4 literal, never 'localhost': under
    // `flutter test --coverage` every concurrent tester runs a VM service on
    // a random 127.0.0.1 port, and a hostname lets the client's
    // address-family fallback land on one of those (it answers 403 to
    // everything), which flakes the error-mapping tests.
    fakeServer = await shelf_io.serve(
      (request) => serverHandler.handle(request),
      InternetAddress.loopbackIPv4,
      0, // Use any available port
    );

    // Configure Dio to hit the fake server
    testDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    // Add interceptor to handle network errors and redirect requests to the fake server
    testDio.interceptors.add(
      _TestInterceptor(serverHandler, 'http://127.0.0.1:${fakeServer.port}'),
    );

    DashboardService.setDioForTesting(testDio);
    DashboardService.retryDelay = (_) async {};
  });

  tearDown(() async {
    DashboardService.resetDio();
    DashboardService.resetRetryDelay();
    await fakeServer.close();
  });

  // ---------------------------------------------------------------------------
  // BillingStatusData.fromJson
  // ---------------------------------------------------------------------------

  group('BillingStatusData.fromJson', () {
    test('parses all fields from full payload', () {
      final data = BillingStatusData.fromJson({
        'plan_key': 'growth',
        'plan_display_name': 'Growth',
        'billing_status': 'active',
        'cancel_at_period_end': true,
        'current_period_end': '2026-05-01T00:00:00Z',
      });

      expect(data.planKey, 'growth');
      expect(data.planDisplayName, 'Growth');
      expect(data.billingStatus, 'active');
      expect(data.cancelAtPeriodEnd, true);
      expect(data.nextRenewalDate, isNotNull);
    });

    test('uses empty string defaults when fields are missing', () {
      final data = BillingStatusData.fromJson({});

      expect(data.planKey, '');
      expect(data.planDisplayName, '');
      expect(data.billingStatus, 'inactive');
      expect(data.cancelAtPeriodEnd, false);
      expect(data.nextRenewalDate, isNull);
    });

    test('nextRenewalDate is null when current_period_end is absent', () {
      final data = BillingStatusData.fromJson({
        'plan_key': 'starter',
        'billing_status': 'active',
        'cancel_at_period_end': false,
      });

      expect(data.nextRenewalDate, isNull);
    });

    test('nextRenewalDate is null when current_period_end is empty string', () {
      final data = BillingStatusData.fromJson({
        'current_period_end': '',
        'plan_key': 'starter',
        'billing_status': 'active',
        'cancel_at_period_end': false,
      });

      expect(data.nextRenewalDate, isNull);
    });

    test('nextRenewalDate is null when current_period_end is unparseable', () {
      final data = BillingStatusData.fromJson({
        'plan_key': 'starter',
        'billing_status': 'active',
        'cancel_at_period_end': false,
        'current_period_end': 'not-a-date',
      });

      expect(data.nextRenewalDate, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchBillingStatus — orgId validation
  // ---------------------------------------------------------------------------

  group('fetchBillingStatus — orgId validation', () {
    test('returns error for empty orgId', () async {
      final result = await DashboardService.fetchBillingStatus(
        orgId: '',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });

    test('returns error for orgId with slash', () async {
      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org/bad',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });

    test('returns error for orgId with question mark', () async {
      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org?bad',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });

    test('returns error for orgId with hash', () async {
      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org#bad',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });

    test('returns error for orgId with percent', () async {
      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org%20bad',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });
  });

  // ---------------------------------------------------------------------------
  // fetchBillingStatus — HTTP responses
  // ---------------------------------------------------------------------------

  group('fetchBillingStatus — success', () {
    test('returns BillingStatusSuccess with parsed data on 200', () async {
      serverHandler.mockGetResponse({
        'plan_key': 'growth',
        'plan_display_name': 'Growth',
        'billing_status': 'active',
        'cancel_at_period_end': false,
        'current_period_end': '2026-05-01T00:00:00Z',
      });

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<BillingStatusSuccess>());
      final success = result as BillingStatusSuccess;
      expect(success.data.planKey, 'growth');
      expect(success.data.billingStatus, 'active');
      expect(success.data.cancelAtPeriodEnd, false);
      expect(success.data.nextRenewalDate, isNotNull);
    });

    test('returns BillingStatusSuccess with defaults on minimal payload', () async {
      serverHandler.mockGetResponse({});

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<BillingStatusSuccess>());
      final success = result as BillingStatusSuccess;
      expect(success.data.planKey, '');
      expect(success.data.billingStatus, 'inactive');
    });
  });

  group('fetchBillingStatus — error responses', () {
    test('returns sanitized auth message on 401', () async {
      serverHandler.mockGetResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'bad-jwt',
      );

      expect(result, isA<BillingStatusError>());
      final err = (result as BillingStatusError).error;
      expect(err, isNot(contains('Unauthorized')));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403', () async {
      serverHandler.mockGetResponse({'error': 'Forbidden'}, statusCode: 403);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      final err = (result as BillingStatusError).error;
      expect(err, isNot(contains('Forbidden')));
      expect(err, contains('permission'));
    });

    test('returns server error on 500 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect((result as BillingStatusError).error, contains('Server error'));
    });

    test('returns server error on 504 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 504);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect((result as BillingStatusError).error, contains('Server error'));
    });

    test('returns unexpected error on unrecognized 4xx', () async {
      serverHandler.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });

    test('retries on 500 before returning server error', () async {
      serverHandler.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect(serverHandler.callCount, 3);
    });
  });

  group('fetchBillingStatus — network errors', () {
    test('returns timeout error on connection timeout', () async {
      serverHandler.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect((result as BillingStatusError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockGetError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect((result as BillingStatusError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
      expect((result as BillingStatusError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockGetThrow(Exception('boom'));

      final result = await DashboardService.fetchBillingStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingStatusError>());
    });
  });

  // ---------------------------------------------------------------------------
  // UsageBucket.fromJson
  // ---------------------------------------------------------------------------

  group('UsageBucket.fromJson', () {
    test('parses all fields from full payload', () {
      final bucket = UsageBucket.fromJson({
        'bucket_date': '2026-04-01',
        'metric_key': 'api_calls',
        'total_quantity': 1000,
        'request_count': 50,
        'avg_latency_ms': 123.4,
      });

      expect(bucket.bucketDate, '2026-04-01');
      expect(bucket.metricKey, 'api_calls');
      expect(bucket.totalQuantity, 1000);
      expect(bucket.requestCount, 50);
      expect(bucket.avgLatencyMs, 123.4);
    });

    test('uses empty string defaults for missing string fields', () {
      final bucket = UsageBucket.fromJson({});

      expect(bucket.bucketDate, '');
      expect(bucket.metricKey, '');
      expect(bucket.totalQuantity, 0);
      expect(bucket.requestCount, 0);
      expect(bucket.avgLatencyMs, isNull);
    });

    test('avgLatencyMs is null when absent', () {
      final bucket = UsageBucket.fromJson({
        'bucket_date': '2026-04-01',
        'metric_key': 'api_calls',
        'total_quantity': 10,
        'request_count': 2,
      });

      expect(bucket.avgLatencyMs, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // UsageSummaryData.fromJson
  // ---------------------------------------------------------------------------

  group('UsageSummaryData.fromJson', () {
    test('parses org_id, period_start, and buckets list', () {
      final data = UsageSummaryData.fromJson({
        'org_id': 'org-1',
        'period_start': '2026-04-01',
        'buckets': [
          {
            'bucket_date': '2026-04-01',
            'metric_key': 'api_calls',
            'total_quantity': 100,
            'request_count': 10,
          },
        ],
      });

      expect(data.orgId, 'org-1');
      expect(data.periodStart, '2026-04-01');
      expect(data.buckets, hasLength(1));
      expect(data.buckets.first.bucketDate, '2026-04-01');
    });

    test('returns empty buckets when key is missing', () {
      final data = UsageSummaryData.fromJson({'org_id': 'org-1'});

      expect(data.buckets, isEmpty);
    });

    test('returns empty buckets when value is not a list', () {
      final data = UsageSummaryData.fromJson({
        'org_id': 'org-1',
        'buckets': 'not-a-list',
      });

      expect(data.buckets, isEmpty);
    });

    test('uses empty string defaults when fields are missing', () {
      final data = UsageSummaryData.fromJson({});

      expect(data.orgId, '');
      expect(data.periodStart, '');
    });
  });

  // ---------------------------------------------------------------------------
  // fetchUsageSummary — orgId validation
  // ---------------------------------------------------------------------------

  group('fetchUsageSummary — orgId validation', () {
    test('returns error for empty orgId', () async {
      final result = await DashboardService.fetchUsageSummary(
        orgId: '',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
    });

    test('returns error for orgId with slash', () async {
      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org/bad',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
    });

    test('returns error for orgId with query char', () async {
      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org?bad',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
    });
  });

  // ---------------------------------------------------------------------------
  // fetchUsageSummary — HTTP responses
  // ---------------------------------------------------------------------------

  group('fetchUsageSummary — success', () {
    test('returns UsageSummarySuccess with parsed data on 200', () async {
      serverHandler.mockGetResponse({
        'org_id': 'org-1',
        'period_start': '2026-04-01',
        'buckets': [
          {
            'bucket_date': '2026-04-01',
            'metric_key': 'api_calls',
            'total_quantity': 100,
            'request_count': 5,
          },
        ],
      });

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<UsageSummarySuccess>());
      final success = result as UsageSummarySuccess;
      expect(success.data.orgId, 'org-1');
      expect(success.data.buckets, hasLength(1));
    });

    test('returns UsageSummarySuccess with empty buckets on minimal payload', () async {
      serverHandler.mockGetResponse({'org_id': 'org-2'});

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-2',
        jwt: 'test-jwt',
      );

      expect(result, isA<UsageSummarySuccess>());
      final success = result as UsageSummarySuccess;
      expect(success.data.buckets, isEmpty);
    });
  });

  group('fetchUsageSummary — error responses', () {
    test('returns sanitized auth message on 401', () async {
      serverHandler.mockGetResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'bad-jwt',
      );

      expect(result, isA<UsageSummaryError>());
      final err = (result as UsageSummaryError).error;
      expect(err, isNot(contains('Unauthorized')));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403', () async {
      serverHandler.mockGetResponse({'error': 'Forbidden'}, statusCode: 403);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      final err = (result as UsageSummaryError).error;
      expect(err, contains('permission'));
    });

    test('returns server error on 500 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      expect((result as UsageSummaryError).error, contains('Server error'));
      expect(serverHandler.callCount, 3);
    });

    test('returns server error on 504 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 504);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      expect((result as UsageSummaryError).error, contains('Server error'));
    });

    test('returns unexpected error on unrecognized 4xx', () async {
      serverHandler.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
    });
  });

  group('fetchUsageSummary — network errors', () {
    test('returns timeout error on connection timeout', () async {
      serverHandler.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      expect((result as UsageSummaryError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockGetError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      expect((result as UsageSummaryError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
      expect((result as UsageSummaryError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockGetThrow(Exception('boom'));

      final result = await DashboardService.fetchUsageSummary(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<UsageSummaryError>());
    });
  });

  // ---------------------------------------------------------------------------
  // EntitlementsData.fromJson
  // ---------------------------------------------------------------------------

  group('EntitlementsData.fromJson', () {
    test('parses org_id and entitlements map', () {
      final data = EntitlementsData.fromJson({
        'org_id': 'org-1',
        'entitlements': {
          'usage_dashboard': true,
          'alerts': false,
          'monthly_units': 500000,
        },
      });

      expect(data.orgId, 'org-1');
      expect(data.entitlements['usage_dashboard'], true);
      expect(data.entitlements['alerts'], false);
      expect(data.entitlements['monthly_units'], 500000);
    });

    test('returns empty entitlements when key is missing', () {
      final data = EntitlementsData.fromJson({'org_id': 'org-2'});

      expect(data.orgId, 'org-2');
      expect(data.entitlements, isEmpty);
    });

    test('returns empty entitlements when value is not a map', () {
      final data = EntitlementsData.fromJson({
        'org_id': 'org-3',
        'entitlements': ['not', 'a', 'map'],
      });

      expect(data.entitlements, isEmpty);
    });

    test('uses empty string for missing org_id', () {
      final data = EntitlementsData.fromJson({'entitlements': {}});

      expect(data.orgId, '');
    });

    test('handles null entitlement values', () {
      final data = EntitlementsData.fromJson({
        'org_id': 'org-4',
        'entitlements': {'soft_limit': null},
      });

      expect(data.entitlements['soft_limit'], isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchEntitlements — orgId validation
  // ---------------------------------------------------------------------------

  group('fetchEntitlements — orgId validation', () {
    test('returns error for empty orgId', () async {
      final result = await DashboardService.fetchEntitlements(
        orgId: '',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });

    test('returns error for orgId with slash', () async {
      final result = await DashboardService.fetchEntitlements(
        orgId: 'org/bad',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });

    test('returns error for orgId with query char', () async {
      final result = await DashboardService.fetchEntitlements(
        orgId: 'org?bad',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });
  });

  // ---------------------------------------------------------------------------
  // fetchEntitlements — HTTP responses
  // ---------------------------------------------------------------------------

  group('fetchEntitlements — success', () {
    test('returns EntitlementsSuccess with parsed data on 200', () async {
      serverHandler.mockGetResponse({
        'org_id': 'org-1',
        'entitlements': {
          'usage_dashboard': true,
          'alerts': false,
          'monthly_units': 500000,
        },
      });

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<EntitlementsSuccess>());
      final success = result as EntitlementsSuccess;
      expect(success.data.orgId, 'org-1');
      expect(success.data.entitlements['usage_dashboard'], true);
      expect(success.data.entitlements['alerts'], false);
      expect(success.data.entitlements['monthly_units'], 500000);
    });

    test('returns EntitlementsSuccess with empty map when entitlements absent', () async {
      serverHandler.mockGetResponse({'org_id': 'org-2'});

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-2',
        jwt: 'test-jwt',
      );

      expect(result, isA<EntitlementsSuccess>());
      final success = result as EntitlementsSuccess;
      expect(success.data.entitlements, isEmpty);
    });
  });

  group('fetchEntitlements — error responses', () {
    test('returns sanitized auth message on 401 — does not surface raw API string (L23)', () async {
      serverHandler.mockGetResponse(
        {'error': 'Unauthorized'},
        statusCode: 401,
      );

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'bad-jwt',
      );

      expect(result, isA<EntitlementsError>());
      final err = (result as EntitlementsError).error;
      expect(err, isNot('Unauthorized'));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403 — does not surface raw API string (L23)', () async {
      serverHandler.mockGetResponse(
        {'error': 'Forbidden'},
        statusCode: 403,
      );

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      final err = (result as EntitlementsError).error;
      expect(err, isNot(contains('Forbidden')));
      expect(err, contains('permission'));
    });

    test('returns server error message on 500 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('Server error'));
    });

    test('returns server error on 504 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 504);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('Server error'));
    });

    test('falls back to unexpected error when 4xx has no error field', () async {
      serverHandler.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });
  });

  group('fetchEntitlements — network errors', () {
    test('returns timeout error on connection timeout', () async {
      serverHandler.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockGetError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockGetThrow(Exception('boom'));

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });
  });

  // ---------------------------------------------------------------------------
  // QuotaStatusData.fromJson
  // ---------------------------------------------------------------------------

  group('QuotaStatusData.fromJson', () {
    test('parses all fields from full payload', () {
      final data = QuotaStatusData.fromJson({
        'planKey': 'growth',
        'minuteLimit': 60,
        'minuteUsed': 5,
        'monthlyLimit': 500000,
        'monthlyUsed': 12345,
        'minuteWindowExpiresIn': 45000,
      });

      expect(data.planKey, 'growth');
      expect(data.minuteLimit, 60);
      expect(data.minuteUsed, 5);
      expect(data.monthlyLimit, 500000);
      expect(data.monthlyUsed, 12345);
      expect(data.minuteWindowExpiresInMs, 45000);
    });

    test('monthlyLimit is null when absent (unlimited plan)', () {
      final data = QuotaStatusData.fromJson({
        'planKey': 'enterprise',
        'minuteLimit': 120,
        'minuteUsed': 0,
        'monthlyUsed': 0,
        'minuteWindowExpiresIn': 60000,
      });

      expect(data.monthlyLimit, isNull);
      expect(data.minuteLimit, 120);
    });

    test('uses zero defaults for missing numeric fields', () {
      final data = QuotaStatusData.fromJson({});

      expect(data.minuteLimit, 0);
      expect(data.minuteUsed, 0);
      expect(data.monthlyUsed, 0);
      expect(data.minuteWindowExpiresInMs, 0);
    });

    test('planKey is null when absent', () {
      final data = QuotaStatusData.fromJson({'minuteLimit': 60});

      expect(data.planKey, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchQuotaStatus — orgId validation
  // ---------------------------------------------------------------------------

  group('fetchQuotaStatus — orgId validation', () {
    test('returns error for empty orgId', () async {
      final result = await DashboardService.fetchQuotaStatus(
        orgId: '',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
    });

    test('returns error for orgId with slash', () async {
      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org/bad',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
    });

    test('returns error for orgId with query char', () async {
      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org?bad',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
    });
  });

  // ---------------------------------------------------------------------------
  // fetchQuotaStatus — HTTP responses
  // ---------------------------------------------------------------------------

  group('fetchQuotaStatus — success', () {
    test('returns QuotaStatusSuccess with parsed data on 200', () async {
      serverHandler.mockGetResponse({
        'org_id': 'org-1',
        'planKey': 'growth',
        'minuteLimit': 60,
        'minuteUsed': 5,
        'monthlyLimit': 500000,
        'monthlyUsed': 12345,
        'minuteWindowExpiresIn': 45000,
      });

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<QuotaStatusSuccess>());
      final success = result as QuotaStatusSuccess;
      expect(success.data.planKey, 'growth');
      expect(success.data.minuteLimit, 60);
      expect(success.data.minuteUsed, 5);
      expect(success.data.monthlyLimit, 500000);
    });

    test('returns QuotaStatusSuccess with null monthlyLimit on 200', () async {
      serverHandler.mockGetResponse({
        'org_id': 'org-1',
        'planKey': 'enterprise',
        'minuteLimit': 120,
        'minuteUsed': 0,
        'monthlyUsed': 0,
        'minuteWindowExpiresIn': 60000,
      });

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'test-jwt',
      );

      expect(result, isA<QuotaStatusSuccess>());
      expect((result as QuotaStatusSuccess).data.monthlyLimit, isNull);
    });
  });

  group('fetchQuotaStatus — error responses', () {
    test('returns sanitized auth message on 401 — does not surface raw API string (L23)', () async {
      serverHandler.mockGetResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'bad-jwt',
      );

      expect(result, isA<QuotaStatusError>());
      final err = (result as QuotaStatusError).error;
      expect(err, isNot('Unauthorized'));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403', () async {
      serverHandler.mockGetResponse({'error': 'Forbidden'}, statusCode: 403);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      final err = (result as QuotaStatusError).error;
      expect(err, contains('permission'));
    });

    test('returns server error on 500 after retries', () async {
      serverHandler.mockGetResponse({'error': 'Internal Error'}, statusCode: 500);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('Server error'));
    });

    test('returns server error on 504 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 504);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('Server error'));
    });

    test('returns unexpected error on unrecognized 4xx', () async {
      serverHandler.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
    });
  });

  group('fetchQuotaStatus — network errors', () {
    test('returns timeout error on connection timeout', () async {
      serverHandler.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockGetError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockGetThrow(Exception('boom'));

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
    });
  });

  // ---------------------------------------------------------------------------
  // OrgSummary.fromJson
  // ---------------------------------------------------------------------------

  group('OrgSummary.fromJson', () {
    test('parses all fields from full payload', () {
      final org = OrgSummary.fromJson({
        'id': 'org-1',
        'name': 'Acme Corp',
        'slug': 'acme',
        'billing_status': 'active',
        'current_plan': 'growth',
        'role': 'owner',
      });

      expect(org.orgId, 'org-1');
      expect(org.name, 'Acme Corp');
      expect(org.slug, 'acme');
      expect(org.billingStatus, 'active');
      expect(org.currentPlan, 'growth');
      expect(org.role, 'owner');
    });

    test('uses defaults for missing fields', () {
      final org = OrgSummary.fromJson({});

      expect(org.orgId, '');
      expect(org.name, '');
      expect(org.slug, isNull);
      expect(org.billingStatus, 'inactive');
      expect(org.currentPlan, isNull);
      expect(org.role, 'member');
    });

    test('slug and currentPlan are null when absent', () {
      final org = OrgSummary.fromJson({
        'id': 'org-2',
        'name': 'Test Org',
        'billing_status': 'active',
        'role': 'member',
      });

      expect(org.slug, isNull);
      expect(org.currentPlan, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchOrgList — success
  // ---------------------------------------------------------------------------

  group('fetchOrgList — success', () {
    test('returns OrgListSuccess with parsed orgs on 200', () async {
      serverHandler.mockGetResponse({
        'organizations': [
          {
            'id': 'org-1',
            'name': 'Acme Corp',
            'slug': 'acme',
            'billing_status': 'active',
            'current_plan': 'growth',
            'role': 'owner',
          },
          {
            'id': 'org-2',
            'name': 'Beta Inc',
            'billing_status': 'inactive',
            'role': 'member',
          },
        ],
      });

      final result = await DashboardService.fetchOrgList(jwt: 'test-jwt');

      expect(result, isA<OrgListSuccess>());
      final success = result as OrgListSuccess;
      expect(success.orgs, hasLength(2));
      expect(success.orgs.first.orgId, 'org-1');
      expect(success.orgs.first.name, 'Acme Corp');
      expect(success.orgs.last.orgId, 'org-2');
    });

    test('returns OrgListSuccess with empty list when organizations key missing', () async {
      serverHandler.mockGetResponse({});

      final result = await DashboardService.fetchOrgList(jwt: 'test-jwt');

      expect(result, isA<OrgListSuccess>());
      expect((result as OrgListSuccess).orgs, isEmpty);
    });

    test('returns OrgListSuccess with empty list when organizations is not a list', () async {
      serverHandler.mockGetResponse({'organizations': 'not-a-list'});

      final result = await DashboardService.fetchOrgList(jwt: 'test-jwt');

      expect(result, isA<OrgListSuccess>());
      expect((result as OrgListSuccess).orgs, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // fetchOrgList — error responses
  // ---------------------------------------------------------------------------

  group('fetchOrgList — error responses (L23)', () {
    test('returns sanitized auth message on 401 — does not surface raw API string', () async {
      serverHandler.mockGetResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchOrgList(jwt: 'expired-jwt');

      expect(result, isA<OrgListError>());
      final err = (result as OrgListError).error;
      expect(err, isNot(contains('Unauthorized')));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403 — does not surface raw API string', () async {
      serverHandler.mockGetResponse({'error': 'Forbidden'}, statusCode: 403);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      final err = (result as OrgListError).error;
      expect(err, isNot(contains('Forbidden')));
      expect(err, contains('permission'));
    });

    test('returns server error on 500 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      expect((result as OrgListError).error, contains('Server error'));
      expect(serverHandler.callCount, 3);
    });

    test('returns server error on 504 after retries', () async {
      serverHandler.mockGetResponse({}, statusCode: 504);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      expect((result as OrgListError).error, contains('Server error'));
    });

    test('returns unexpected error on unrecognized 4xx', () async {
      serverHandler.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
    });
  });

  group('fetchOrgList — network errors', () {
    test('returns timeout error on connection timeout', () async {
      serverHandler.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      expect((result as OrgListError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockGetError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      expect((result as OrgListError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
      expect((result as OrgListError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockGetThrow(Exception('boom'));

      final result = await DashboardService.fetchOrgList(jwt: 'jwt');

      expect(result, isA<OrgListError>());
    });
  });

  // ---------------------------------------------------------------------------
  // fetchBillingPortalUrl
  // ---------------------------------------------------------------------------

  group('fetchBillingPortalUrl', () {
    test('returns BillingPortalSuccess with url on 200', () async {
      serverHandler.mockPostResponse(
        {'url': 'https://billing.stripe.com/session/abc'},
        statusCode: 200,
      );

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalSuccess>());
      expect(
        (result as BillingPortalSuccess).url,
        'https://billing.stripe.com/session/abc',
      );
    });

    test('returns error when url is missing from 200 response', () async {
      serverHandler.mockPostResponse({}, statusCode: 200);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
    });

    test('returns error when url is empty string in 200 response', () async {
      serverHandler.mockPostResponse({'url': ''}, statusCode: 200);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
    });

    test('retries on 503 and returns server error after max retries (M42)', () async {
      serverHandler.mockPostResponse({}, statusCode: 503);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('Server error'));
      expect(serverHandler.postCallCount, 3); // initial + 2 retries
    });

    test('retries on 500 and returns server error after max retries', () async {
      serverHandler.mockPostResponse({}, statusCode: 500);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('Server error'));
      expect(serverHandler.postCallCount, 3);
    });

    test('retries on 504 and returns server error after max retries', () async {
      serverHandler.mockPostResponse({}, statusCode: 504);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('Server error'));
    });

    test('returns sanitized auth message on 401 — does not surface raw API string (L20)', () async {
      serverHandler.mockPostResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'expired-jwt',
      );

      expect(result, isA<BillingPortalError>());
      final err = (result as BillingPortalError).error;
      expect(err, isNot('Unauthorized'));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403 — does not surface raw API string (L20)', () async {
      serverHandler.mockPostResponse({'error': 'Forbidden: org billing restricted'}, statusCode: 403);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      final err = (result as BillingPortalError).error;
      expect(err, isNot('Forbidden: org billing restricted'));
      expect(err, contains('permission'));
    });

    test('returns sanitized not-found message on 404 — does not surface raw API string (L20)', () async {
      serverHandler.mockPostResponse({'error': 'org_id not in stripe'}, statusCode: 404);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'unknown-org',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      final err = (result as BillingPortalError).error;
      expect(err, isNot('org_id not in stripe'));
      // Copy changed from 'Organization not found.' — that told an owner looking at
      // their own org that it did not exist, when the actual and far more common
      // cause of this 404 is the org having no Stripe customer.
      expect(err, contains('No billing account'));
    });

    test('returns generic unexpected error on unrecognized 4xx — does not surface raw API string (L20)', () async {
      serverHandler.mockPostResponse(
        {'error': 'Stripe internal: cus_invalid param'},
        statusCode: 422,
      );

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      final err = (result as BillingPortalError).error;
      expect(err, isNot(contains('Stripe internal')));
      expect(err, 'An unexpected error occurred.');
    });

    test('returns error on invalid orgId', () async {
      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: '',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
    });

    test('returns error for orgId with slash', () async {
      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org/bad',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
    });

    test('returns timeout error on connection timeout', () async {
      serverHandler.mockPostError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('timed out'));
    });

    test('returns timeout error on receive timeout', () async {
      serverHandler.mockPostError(DioExceptionType.receiveTimeout);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      serverHandler.mockPostError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('Network error'));
    });

    test('returns unexpected error on non-DioException', () async {
      serverHandler.mockPostThrow(Exception('boom'));

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
    });
  });

  // ---------------------------------------------------------------------------
  // BillingStatusData — plan key source and billing-account flag
  // ---------------------------------------------------------------------------

  group('BillingStatusData.fromJson — plan and billing account', () {
    // The endpoint returns `current_plan`; the model read `plan_key`, which it has
    // never sent, so the plan row rendered '—' for every org regardless of plan.
    test('reads planKey from current_plan, the field the API actually returns', () {
      final data = BillingStatusData.fromJson({
        'current_plan': 'growth',
        'billing_status': 'active',
      });

      expect(data.planKey, 'growth');
    });

    test('falls back to plan_key when current_plan is absent', () {
      expect(BillingStatusData.fromJson({'plan_key': 'starter'}).planKey, 'starter');
    });

    test('reads has_billing_account', () {
      expect(
        BillingStatusData.fromJson({'has_billing_account': true}).hasBillingAccount,
        isTrue,
      );
      expect(
        BillingStatusData.fromJson({'has_billing_account': false}).hasBillingAccount,
        isFalse,
      );
    });

    // An older gateway build omits the field. Defaulting to false shows "Choose a
    // plan", which is recoverable; defaulting to true would show "Manage Billing"
    // and reproduce the 404 this change exists to remove.
    test('defaults hasBillingAccount to false when the field is absent', () {
      expect(BillingStatusData.fromJson({}).hasBillingAccount, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // createCheckoutSession
  // ---------------------------------------------------------------------------

  group('createCheckoutSession', () {
    test('returns BillingPortalSuccess with url on 200', () async {
      serverHandler.mockPostResponse(
        {'url': 'https://checkout.stripe.com/c/pay/abc'},
        statusCode: 200,
      );

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect(result, isA<BillingPortalSuccess>());
      expect(
        (result as BillingPortalSuccess).url,
        'https://checkout.stripe.com/c/pay/abc',
      );
    });

    test('sends the requested plan in the request body', () async {
      serverHandler.mockPostResponse(
        {'url': 'https://checkout.stripe.com/c/pay/abc'},
        statusCode: 200,
      );

      await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect(serverHandler.lastPostBody, {'plan': 'growth'});
    });

    test('returns error when url is missing from 200 response', () async {
      serverHandler.mockPostResponse({}, statusCode: 200);

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect(result, isA<BillingPortalError>());
    });

    test('rejects an orgId that could alter the URL path', () async {
      serverHandler.mockPostResponse({'url': 'https://x'}, statusCode: 200);

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1/../other',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect(result, isA<BillingPortalError>());
      expect(serverHandler.postCallCount, 0);
    });

    test('returns sanitized auth message on 401', () async {
      serverHandler.mockPostResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'expired-jwt',
        plan: 'growth',
      );

      final err = (result as BillingPortalError).error;
      expect(err, isNot('Unauthorized'));
      expect(err, contains('log in'));
    });

    test('returns sanitized permission message on 403', () async {
      serverHandler.mockPostResponse(
        {'error': 'Checkout requires owner or billing_admin role'},
        statusCode: 403,
      );

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect((result as BillingPortalError).error, contains('permission'));
    });

    // 409 means a Stripe customer appeared since the page loaded, so the portal —
    // not a second checkout — is the right destination. A second Checkout run would
    // mint a duplicate customer and orphan the original subscription.
    test('returns a refresh-to-manage message on 409', () async {
      serverHandler.mockPostResponse(
        {'error': 'Organization already has a billing account'},
        statusCode: 409,
      );

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      final err = (result as BillingPortalError).error;
      expect(err, contains('already has a billing account'));
    });

    test('does not surface the raw API string on an unrecognized 4xx', () async {
      serverHandler.mockPostResponse(
        {'error': 'Stripe internal: price_xyz invalid'},
        statusCode: 400,
      );

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect((result as BillingPortalError).error, isNot(contains('price_xyz')));
    });

    test('returns server error after exhausting retries on 500', () async {
      serverHandler.mockPostResponse({'error': 'boom'}, statusCode: 500);

      final result = await DashboardService.createCheckoutSession(
        orgId: 'org-1',
        jwt: 'jwt',
        plan: 'growth',
      );

      expect(result, isA<BillingPortalError>());
      expect(serverHandler.postCallCount, 3);
    });
  });
}

// ---------------------------------------------------------------------------
// Test Interceptor — handles network errors and redirects to fake server
// ---------------------------------------------------------------------------

class _TestInterceptor extends Interceptor {
  final _FakeServerHandler _handler;
  final String _fakeBaseUrl;

  _TestInterceptor(this._handler, this._fakeBaseUrl);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Determine if this is a POST or GET request and check for errors
    final isPost = options.method.toUpperCase() == 'POST';
    final hasError = isPost
        ? (_handler._postErrorType != null || _handler._postThrowable != null)
        : (_handler._errorType != null || _handler._throwable != null);

    if (hasError) {
      if (isPost) {
        if (_handler._postThrowable != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: _handler._postThrowable,
              type: DioExceptionType.unknown,
            ),
          );
          return;
        }
        if (_handler._postErrorType != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: _handler._postErrorType!,
            ),
          );
          return;
        }
      } else {
        if (_handler._throwable != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: _handler._throwable,
              type: DioExceptionType.unknown,
            ),
          );
          return;
        }
        if (_handler._errorType != null) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: _handler._errorType!,
            ),
          );
          return;
        }
      }
    }

    // Extract the path from the full URL and redirect to fake server
    final uri = Uri.parse(options.path);
    final path = uri.path;
    final query = uri.query;

    final newUrl = '$_fakeBaseUrl$path${query.isNotEmpty ? '?$query' : ''}';
    options.path = newUrl;

    handler.next(options);
  }
}

// ---------------------------------------------------------------------------
// Fake HTTP Server Handler — returns configurable responses/errors
// ---------------------------------------------------------------------------

class _FakeServerHandler {
  Map<String, dynamic> _responseData = {};
  int _statusCode = 200;
  DioExceptionType? _errorType;
  Exception? _throwable;
  int callCount = 0;

  Map<String, dynamic> _postResponseData = {};
  int _postStatusCode = 200;
  DioExceptionType? _postErrorType;
  Exception? _postThrowable;
  int postCallCount = 0;

  void mockGetResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _responseData = data;
    _statusCode = statusCode;
    _errorType = null;
    _throwable = null;
    callCount = 0;
  }

  void mockGetError(DioExceptionType type) {
    _errorType = type;
    _throwable = null;
    callCount = 0;
  }

  void mockGetThrow(Exception e) {
    _throwable = e;
    _errorType = null;
    callCount = 0;
  }

  void mockPostResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _postResponseData = data;
    _postStatusCode = statusCode;
    _postErrorType = null;
    _postThrowable = null;
    postCallCount = 0;
  }

  void mockPostError(DioExceptionType type) {
    _postErrorType = type;
    _postThrowable = null;
    postCallCount = 0;
  }

  void mockPostThrow(Exception e) {
    _postThrowable = e;
    _postErrorType = null;
    postCallCount = 0;
  }

  /// Decoded JSON body of the most recent POST, for asserting what was sent.
  Map<String, dynamic>? lastPostBody;

  Future<shelf.Response> handle(shelf.Request request) async {
    final isPost = request.method == 'POST';

    if (isPost) {
      postCallCount++;
      final raw = await request.readAsString();
      lastPostBody = raw.isEmpty
          ? null
          : jsonDecode(raw) as Map<String, dynamic>;
      // Note: errors are handled by _TestInterceptor; this only returns valid HTTP responses
      return shelf.Response(
        _postStatusCode,
        body: jsonEncode(_postResponseData),
        headers: {'content-type': 'application/json'},
      );
    } else {
      callCount++;
      // Note: errors are handled by _TestInterceptor; this only returns valid HTTP responses
      return shelf.Response(
        _statusCode,
        body: jsonEncode(_responseData),
        headers: {'content-type': 'application/json'},
      );
    }
  }
}
