import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';

/// Unit tests for ProvisioningService.
///
/// Tests provisioning event submission and retry behavior.
/// Uses mock Dio to simulate API responses.
void main() {
  late MockProvisioningDio mockDio;

  setUp(() {
    mockDio = MockProvisioningDio();
    ProvisioningService.setDioForTesting(mockDio);
    ProvisioningService.retryDelay = (_) async {};
  });

  tearDown(() {
    ProvisioningService.resetDio();
    ProvisioningService.resetRetryDelay();
  });

  group('ProvisioningEvent', () {
    test('toJson includes all required fields', () {
      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final json = event.toJson();

      expect(json['action'], 'provision_api_key');
      expect(json['name'], 'user-123');
      expect(json['email'], 'user@example.com');
      expect(json['tier'], 'starter');
    });

    test('toJson matches SendRequestSchema keys exactly', () {
      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'alice',
        email: 'alice@example.com',
        tier: 'growth',
        orgName: 'Acme Corp',
      );

      final json = event.toJson();

      // Must contain exactly the keys the worker expects
      expect(json.keys, unorderedEquals(['action', 'name', 'email', 'tier', 'org_name']));
      expect(json['org_name'], 'Acme Corp');
      expect(json['tier'], 'growth');
    });

    test('toJson omits org_name when null', () {
      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'bob',
        email: 'bob@example.com',
      );

      final json = event.toJson();

      expect(json.containsKey('org_name'), isFalse);
      expect(json.keys, unorderedEquals(['action', 'name', 'email', 'tier']));
    });

    test('defaults tier to starter', () {
      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'carol',
        email: 'carol@example.com',
      );

      expect(event.tier, 'starter');
      expect(event.toJson()['tier'], 'starter');
    });
  });

  group('sendEvent', () {
    test('returns ProvisioningSuccess with apiKey and received on 200',
        () async {
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-test-key-123',
        'received': 'abc-def-ghi',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect((result as ProvisioningSuccess).apiKey, 'sk-test-key-123');
      expect(result.received, 'abc-def-ghi');
    });

    test('retries on 500 and succeeds on third attempt', () async {
      mockDio.setRetryableResponses([
        {'error': 'Server error'},
        {'error': 'Server error'},
        {
          'ok': true,
          'apiKey': 'sk-recovered',
          'received': 'xyz',
        },
      ], statusCode: 500, successStatusCode: 200);

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect((result as ProvisioningSuccess).apiKey, 'sk-recovered');
      expect(mockDio.postCallCount, 3);
    });

    test('returns ProvisioningError on 500 after max retries', () async {
      mockDio.mockPostResponse(
        {'error': 'Server error'},
        statusCode: 500,
      );

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect((result as ProvisioningError).error,
          'Server error. Please try again.');
      expect(mockDio.postCallCount, 3); // Initial + 2 retries
    });

    test('retries on 504 gateway timeout', () async {
      mockDio.setRetryableResponses([
        {'error': 'Gateway timeout'},
        {
          'ok': true,
          'apiKey': 'sk-recovered',
          'received': 'xyz',
        },
      ], statusCode: 504, successStatusCode: 200);

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('retries on connectionTimeout', () async {
      mockDio.mockPostError(DioExceptionType.connectionTimeout, attemptNumber: 0);
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-key',
        'received': 'abc',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('retries on receiveTimeout', () async {
      mockDio.mockPostError(DioExceptionType.receiveTimeout, attemptNumber: 0);
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-key',
        'received': 'abc',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('retries on connectionError', () async {
      mockDio.mockPostError(DioExceptionType.connectionError, attemptNumber: 0);
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-key',
        'received': 'abc',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('returns error on connectionTimeout after max retries', () async {
      mockDio.mockPostError(DioExceptionType.connectionTimeout);

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect((result as ProvisioningError).error,
          'Connection timed out. Please try again.');
      expect(mockDio.postCallCount, 3);
    });

    test('returns error on connectionError after max retries', () async {
      mockDio.mockPostError(DioExceptionType.connectionError);

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect((result as ProvisioningError).error,
          'Network error. Please try again.');
      expect(mockDio.postCallCount, 3);
    });

    test('does not retry on non-retryable 400 status', () async {
      mockDio.mockPostResponse(
        {'error': 'Bad request'},
        statusCode: 400,
      );

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'user-123',
        email: 'user@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect(mockDio.postCallCount, 1);
    });

    test('uses error from response data if available', () async {
      mockDio.mockPostResponse(
        {'error': 'Invalid userId format'},
        statusCode: 400,
      );

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'invalid',
        email: 'invalid@example.com',
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect((result as ProvisioningError).error, 'Invalid userId format');
    });

    test('sends body matching SendRequestSchema to /send endpoint', () async {
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-contract-test',
        'received': 'contract-id',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'jane',
        email: 'jane@example.com',
        tier: 'growth',
        orgName: 'Jane Co',
      );

      await ProvisioningService.sendEvent(event, jwt: 'jwt-abc');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['action'], 'provision_api_key');
      expect(body['name'], 'jane');
      expect(body['email'], 'jane@example.com');
      expect(body['tier'], 'growth');
      expect(body['org_name'], 'Jane Co');
      // Must not contain legacy fields
      expect(body.containsKey('userId'), isFalse);
      expect(body.containsKey('sentAt'), isFalse);
    });

    test('sends body without org_name when not provided', () async {
      mockDio.mockPostResponse({
        'ok': true,
        'apiKey': 'sk-no-org',
        'received': 'no-org-id',
      });

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'bob',
        email: 'bob@example.com',
      );

      await ProvisioningService.sendEvent(event, jwt: 'jwt-xyz');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!.containsKey('org_name'), isFalse);
      expect(body['tier'], 'starter');
    });
  });

  group('checkHealth', () {
    test('returns true on 200 with ok:true', () async {
      mockDio.mockGetResponse({'ok': true});

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, true);
      expect(mockDio.getCallCount, 1);
    });

    test('returns false on non-200', () async {
      mockDio.mockGetResponse(
        {'error': 'Service unavailable'},
        statusCode: 500,
      );

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, false);
      expect(mockDio.getCallCount, 1);
    });

    test('returns false on DioException', () async {
      mockDio.mockGetError(DioExceptionType.connectionError);

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, false);
    });

    test('rejects non-https URLs', () async {
      final result =
          await ProvisioningService.checkHealth('http://receiver.example.com');

      expect(result, false);
      expect(mockDio.getCallCount, 0); // No HTTP call made
    });

    test('rejects invalid URLs', () async {
      final result = await ProvisioningService.checkHealth('not-a-url');

      expect(result, false);
      expect(mockDio.getCallCount, 0); // No HTTP call made
    });

    test('retries on receiveTimeout and succeeds on retry', () async {
      mockDio.mockGetError(DioExceptionType.receiveTimeout, attemptNumber: 0);
      mockDio.mockGetResponse({'ok': true}, attemptNumber: 1);

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, true);
      expect(mockDio.getCallCount, 2);
    });

    test('returns false after max retries on transient errors', () async {
      mockDio.mockGetError(DioExceptionType.connectionTimeout);

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, false);
      expect(mockDio.getCallCount, 3); // Initial + 2 retries
    });

  });

  group('bootstrap', () {
    final bootstrapPayload = {
      'organizations': [
        {
          'id': 'org-1',
          'name': 'Integrity Studio',
          'role': 'owner',
          'plan_key': 'growth',
          'billing_status': 'active',
        }
      ],
      'active_org_id': 'org-1',
      'entitlements': {
        'usage_dashboard': true,
        'alerts': true,
        'compliance_summary': false,
        'monthly_units': 500000,
        'requests_per_minute': 600,
      },
      'usage_snapshot': {
        'month_to_date_units': 182044,
        'current_minute_remaining': 412,
      },
    };

    test('returns BootstrapSuccess with org, entitlements, usage on 200',
        () async {
      mockDio.mockPostResponse(bootstrapPayload);

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapSuccess>());
      final success = result as BootstrapSuccess;
      expect(success.activeOrg.id, 'org-1');
      expect(success.activeOrg.name, 'Integrity Studio');
      expect(success.activeOrg.planKey, 'growth');
      expect(success.organizations, hasLength(1));
      expect(success.entitlements.monthlyUnits, 500000);
      expect(success.entitlements.usageDashboard, true);
      expect(success.usageSnapshot.monthToDateUnits, 182044);
      expect(success.usageSnapshot.currentMinuteRemaining, 412);
    });

    test('falls back to first org when active_org_id has no match', () async {
      mockDio.mockPostResponse({
        ...bootstrapPayload,
        'active_org_id': 'org-unknown',
      });

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapSuccess>());
      expect((result as BootstrapSuccess).activeOrg.id, 'org-1');
    });

    test('returns BootstrapError on 401', () async {
      mockDio.mockPostResponse(
        {'error': 'Unauthorized'},
        statusCode: 401,
      );

      final result = await ProvisioningService.bootstrap(jwt: 'bad-jwt');

      expect(result, isA<BootstrapError>());
      expect((result as BootstrapError).error, 'Unauthorized');
    });

    test('returns BootstrapError when organizations list is empty', () async {
      mockDio.mockPostResponse({
        'organizations': <dynamic>[],
        'active_org_id': null,
      });

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapError>());
    });

    test('returns BootstrapError when organizations key is absent', () async {
      mockDio.mockPostResponse({'active_org_id': 'org-1'});

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapError>());
    });

    test('uses zero defaults when entitlements key is absent', () async {
      mockDio.mockPostResponse({
        'organizations': [
          {
            'id': 'org-1',
            'name': 'Acme',
            'role': 'member',
            'plan_key': 'free',
            'billing_status': 'active',
          }
        ],
        'active_org_id': 'org-1',
        // no entitlements or usage_snapshot
      });

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapSuccess>());
      final success = result as BootstrapSuccess;
      expect(success.entitlements.monthlyUnits, 0);
      expect(success.usageSnapshot.monthToDateUnits, 0);
    });

    test('returns BootstrapError on 500 after max retries', () async {
      mockDio.mockPostResponse({'error': 'Server error'}, statusCode: 500);

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapError>());
      expect(mockDio.postCallCount, 3);
    });

    test('retries on connectionTimeout and succeeds', () async {
      mockDio.mockPostError(DioExceptionType.connectionTimeout,
          attemptNumber: 0);
      mockDio.mockPostResponse(bootstrapPayload, attemptNumber: 1);

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('returns BootstrapError on connectionError after max retries',
        () async {
      mockDio.mockPostError(DioExceptionType.connectionError);

      final result = await ProvisioningService.bootstrap(jwt: 'test-jwt');

      expect(result, isA<BootstrapError>());
      expect((result as BootstrapError).error,
          'Network error. Please try again.');
      expect(mockDio.postCallCount, 3);
    });
  });

  group('signUp', () {
    test('sends email and password in POST body', () async {
      mockDio.mockPostResponse({'jwt': 'test.jwt.token'}, statusCode: 201);

      await ProvisioningService.signUp('user@example.com', 'secret123');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['email'], 'user@example.com');
      expect(body['password'], 'secret123');
    });

    test('returns AuthSuccess with jwt on 201', () async {
      mockDio.mockPostResponse({'jwt': 'test.jwt.token'}, statusCode: 201);

      final result = await ProvisioningService.signUp('user@example.com', 'secret123');

      expect(result, isA<AuthSuccess>());
      expect((result as AuthSuccess).jwt, 'test.jwt.token');
      expect(result.email, 'user@example.com');
    });

    test('includes name in POST body when provided', () async {
      mockDio.mockPostResponse({'jwt': 'tok'}, statusCode: 201);

      await ProvisioningService.signUp(
        'user@example.com',
        'secret123',
        name: 'Acme Corp',
      );

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['name'], 'Acme Corp');
    });

    test('omits name from POST body when not provided', () async {
      mockDio.mockPostResponse({'jwt': 'tok'}, statusCode: 201);

      await ProvisioningService.signUp('user@example.com', 'secret123');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!.containsKey('name'), isFalse);
    });

    test('omits name from POST body when empty string', () async {
      mockDio.mockPostResponse({'jwt': 'tok'}, statusCode: 201);

      await ProvisioningService.signUp('user@example.com', 'secret123', name: '');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!.containsKey('name'), isFalse);
    });

    test('includes tier in POST body', () async {
      mockDio.mockPostResponse({'jwt': 'tok'}, statusCode: 201);

      await ProvisioningService.signUp(
        'user@example.com',
        'secret123',
        tier: 'growth',
      );

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['tier'], 'growth');
    });

    test('defaults tier to starter when not provided', () async {
      mockDio.mockPostResponse({'jwt': 'tok'}, statusCode: 201);

      await ProvisioningService.signUp('user@example.com', 'secret123');

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['tier'], 'starter');
    });

    test('returns AuthError on non-201 response', () async {
      mockDio.mockPostResponse({'error': 'signup failed'}, statusCode: 500);

      final result = await ProvisioningService.signUp('user@example.com', 'secret123');

      expect(result, isA<AuthError>());
    });
  });

  group('createCheckoutSession', () {
    test('returns CheckoutSuccess with checkoutUrl on 200', () async {
      mockDio.mockPostResponse(
        {'checkoutUrl': 'https://checkout.stripe.com/pay/cs_test_abc'},
        statusCode: 200,
      );

      final result = await ProvisioningService.createCheckoutSession(
        email: 'user@example.com',
        tier: 'growth',
      );

      expect(result, isA<CheckoutSuccess>());
      expect(
        (result as CheckoutSuccess).checkoutUrl,
        'https://checkout.stripe.com/pay/cs_test_abc',
      );
    });

    test('sends email and tier in POST body', () async {
      mockDio.mockPostResponse(
        {'checkoutUrl': 'https://checkout.stripe.com/pay/cs_test'},
        statusCode: 200,
      );

      await ProvisioningService.createCheckoutSession(
        email: 'buyer@example.com',
        tier: 'growth',
      );

      final body = mockDio.lastPostBody;
      expect(body, isNotNull);
      expect(body!['email'], 'buyer@example.com');
      expect(body['tier'], 'growth');
    });

    test('returns CheckoutError when checkoutUrl is absent', () async {
      mockDio.mockPostResponse({}, statusCode: 200);

      final result = await ProvisioningService.createCheckoutSession(
        email: 'user@example.com',
        tier: 'growth',
      );

      expect(result, isA<CheckoutError>());
    });

    test('returns CheckoutError on 500', () async {
      mockDio.mockPostResponse(
        {'error': 'Stripe not configured'},
        statusCode: 500,
      );

      final result = await ProvisioningService.createCheckoutSession(
        email: 'user@example.com',
        tier: 'growth',
      );

      expect(result, isA<CheckoutError>());
    });
  });

  group('MockProvisioningDio per-attempt response data', () {
    test('post returns per-attempt data when attemptNumber matches', () async {
      // Attempt 0: connection error (triggers retry), attempt 1: success
      mockDio.mockPostError(DioExceptionType.connectionTimeout, attemptNumber: 0);
      mockDio.mockPostResponse(
        {'ok': true, 'apiKey': 'sk-retry-key', 'received': 'xyz'},
        attemptNumber: 1,
      );

      final event = ProvisioningEvent(
        action: 'provision_api_key',
        name: 'u1',
        email: 'u1@example.com',
      );
      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect((result as ProvisioningSuccess).apiKey, 'sk-retry-key');
      expect(mockDio.postCallCount, 2);
    });

    test('get returns per-attempt data when attemptNumber matches', () async {
      mockDio.mockGetError(DioExceptionType.connectionTimeout, attemptNumber: 0);
      mockDio.mockGetResponse(
        {'ok': true, 'status': 'healthy'},
        statusCode: 200,
        attemptNumber: 1,
      );

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, true);
      expect(mockDio.getCallCount, 2);
    });

    test('get falls back to global response when attempt has no override',
        () async {
      mockDio.mockGetResponse({'ok': true});

      final result =
          await ProvisioningService.checkHealth('https://receiver.example.com');

      expect(result, true);
      expect(mockDio.getCallCount, 1);
    });
  });
}

// =============================================================================
// Mock Dio Implementation
// =============================================================================

class MockProvisioningDio implements Dio {
  final Map<String, dynamic> _mockPostResponseData = {};
  final Map<String, dynamic> _mockGetResponseData = {};
  int _mockPostStatusCode = 200;
  int _mockGetStatusCode = 200;
  Map<String, List<String>> _mockPostHeaders = {};
  Map<String, List<String>> _mockGetHeaders = {};

  DioExceptionType? _mockPostError;
  DioExceptionType? _mockGetError;

  List<Map<String, dynamic>>? _retryableResponses;
  int _retryableStatusCode = 500;
  int _successStatusCode = 200;
  int _retryAttempt = 0;

  final Map<int, DioExceptionType> _postErrorAttempts = {};
  final Map<int, DioExceptionType> _getErrorAttempts = {};

  /// Per-attempt response data for POST. Keyed by zero-based attempt index.
  final Map<int, Map<String, dynamic>> _postResponseAttempts = {};
  final Map<int, int> _postStatusAttempts = {};

  /// Per-attempt response data for GET. Keyed by zero-based attempt index.
  final Map<int, Map<String, dynamic>> _getResponseAttempts = {};
  final Map<int, int> _getStatusAttempts = {};

  int postCallCount = 0;
  int getCallCount = 0;

  /// The decoded JSON body of the most recent POST call (for assertion in tests).
  Map<String, dynamic>? lastPostBody;

  void mockPostResponse(
    Map<String, dynamic> data, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
    int attemptNumber = -1,
  }) {
    if (attemptNumber >= 0) {
      _postResponseAttempts[attemptNumber] = Map.of(data);
      _postStatusAttempts[attemptNumber] = statusCode;
      _postErrorAttempts.remove(attemptNumber);
      _retryableResponses = null;
      _retryAttempt = 0;
    } else {
      _mockPostResponseData.clear();
      _mockPostResponseData.addAll(data);
      _mockPostStatusCode = statusCode;
      _mockPostHeaders = headers ?? {};
      _mockPostError = null;
      _retryableResponses = null;
      _retryAttempt = 0;
      _postResponseAttempts.clear();
      _postStatusAttempts.clear();
    }
  }

  void mockPostError(
    DioExceptionType type, {
    int attemptNumber = -1,
  }) {
    if (attemptNumber >= 0) {
      _postErrorAttempts[attemptNumber] = type;
      _retryableResponses = null;
      _retryAttempt = 0;
    } else {
      _mockPostError = type;
      _mockPostStatusCode = 200;
      _mockPostResponseData.clear();
    }
  }

  void setRetryableResponses(
    List<Map<String, dynamic>> responses, {
    int statusCode = 500,
    int successStatusCode = 200,
  }) {
    _retryableResponses = responses;
    _retryableStatusCode = statusCode;
    _successStatusCode = successStatusCode;
    _retryAttempt = 0;
  }

  void mockGetResponse(
    Map<String, dynamic> data, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
    int attemptNumber = -1,
  }) {
    if (attemptNumber >= 0) {
      _getResponseAttempts[attemptNumber] = Map.of(data);
      _getStatusAttempts[attemptNumber] = statusCode;
      _getErrorAttempts.remove(attemptNumber);
    } else {
      _mockGetResponseData.clear();
      _mockGetResponseData.addAll(data);
      _mockGetStatusCode = statusCode;
      _mockGetHeaders = headers ?? {};
      _mockGetError = null;
      _getErrorAttempts.clear();
      _getResponseAttempts.clear();
      _getStatusAttempts.clear();
    }
  }

  void mockGetError(
    DioExceptionType type, {
    int attemptNumber = -1,
  }) {
    if (attemptNumber >= 0) {
      _getErrorAttempts[attemptNumber] = type;
    } else {
      _mockGetError = type;
      _mockGetStatusCode = 200;
      _mockGetResponseData.clear();
    }
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (data is String) {
      lastPostBody = jsonDecode(data) as Map<String, dynamic>;
    }
    final currentAttempt = postCallCount;
    postCallCount++;

    // Check for error at this attempt
    if (_postErrorAttempts.containsKey(currentAttempt)) {
      throw DioException(
        type: _postErrorAttempts[currentAttempt]!,
        requestOptions: RequestOptions(path: path),
      );
    }

    // Check for per-attempt response data
    if (_postResponseAttempts.containsKey(currentAttempt)) {
      return Response<T>(
        data: _postResponseAttempts[currentAttempt]! as T,
        statusCode: _postStatusAttempts[currentAttempt] ?? _mockPostStatusCode,
        headers: Headers.fromMap(_mockPostHeaders),
        requestOptions: RequestOptions(path: path),
      );
    }

    // Check for retryable responses
    if (_retryableResponses != null && _retryAttempt < _retryableResponses!.length) {
      final response = _retryableResponses![_retryAttempt];
      final statusCode = _retryAttempt == _retryableResponses!.length - 1
          ? _successStatusCode
          : _retryableStatusCode;
      _retryAttempt++;
      return Response<T>(
        data: response as T,
        statusCode: statusCode,
        requestOptions: RequestOptions(path: path),
      );
    }

    if (_mockPostError != null) {
      throw DioException(
        type: _mockPostError!,
        requestOptions: RequestOptions(path: path),
      );
    }

    return Response<T>(
      data: _mockPostResponseData as T,
      statusCode: _mockPostStatusCode,
      headers: Headers.fromMap(_mockPostHeaders),
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final currentAttempt = getCallCount;
    getCallCount++;

    // Check for error at this attempt
    if (_getErrorAttempts.containsKey(currentAttempt)) {
      throw DioException(
        type: _getErrorAttempts[currentAttempt]!,
        requestOptions: RequestOptions(path: path),
      );
    }

    // Check for per-attempt response data
    if (_getResponseAttempts.containsKey(currentAttempt)) {
      return Response<T>(
        data: _getResponseAttempts[currentAttempt]! as T,
        statusCode: _getStatusAttempts[currentAttempt] ?? _mockGetStatusCode,
        headers: Headers.fromMap(_mockGetHeaders),
        requestOptions: RequestOptions(path: path),
      );
    }

    if (_mockGetError != null) {
      throw DioException(
        type: _mockGetError!,
        requestOptions: RequestOptions(path: path),
      );
    }

    return Response<T>(
      data: _mockGetResponseData as T,
      statusCode: _mockGetStatusCode,
      headers: Headers.fromMap(_mockGetHeaders),
      requestOptions: RequestOptions(path: path),
    );
  }

  @override
  BaseOptions get options => BaseOptions();

  @override
  set options(BaseOptions options) {}

  @override
  Interceptors get interceptors => Interceptors();

  @override
  HttpClientAdapter get httpClientAdapter => throw UnimplementedError();

  @override
  set httpClientAdapter(HttpClientAdapter adapter) {}

  @override
  Transformer get transformer => throw UnimplementedError();

  @override
  set transformer(Transformer transformer) {}

  @override
  void close({bool force = false}) {}

  @override
  Future<Response<T>> delete<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Dio clone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) =>
      this;

  @override
  Future<Response> download(String urlPath, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options,
          FileAccessMode fileAccessMode = FileAccessMode.write}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> getUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> head<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> headUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> patch<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> patchUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> postUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> put<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> putUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> deleteUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> request<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> requestUri<T>(Uri uri,
          {Object? data,
          CancelToken? cancelToken,
          Options? options,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  Future<Response> upload(String filePath, String uploadUrl,
          {ProgressCallback? onSendProgress}) =>
      throw UnimplementedError();

  Future<Response> uploadFileStream(Stream<List<int>> fileStream, int fileSize,
          String uploadUrl,
          {ProgressCallback? onSendProgress}) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('MockProvisioningDio method not implemented: ${invocation.memberName}');
  }
}
