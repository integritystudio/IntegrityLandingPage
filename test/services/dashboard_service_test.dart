import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/services/dashboard_service.dart';

void main() {
  late _MockGetDio mockDio;

  setUp(() {
    mockDio = _MockGetDio();
    DashboardService.setDioForTesting(mockDio);
    DashboardService.retryDelay = (_) async {};
  });

  tearDown(() {
    DashboardService.resetDio();
    DashboardService.resetRetryDelay();
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
      mockDio.mockGetResponse({
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
      mockDio.mockGetResponse({'org_id': 'org-2'});

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
      mockDio.mockGetResponse(
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

    test('returns sanitized error on 403 — does not surface raw API string (L23)', () async {
      mockDio.mockGetResponse(
        {'error': 'Forbidden'},
        statusCode: 403,
      );

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, isNot(contains('Forbidden')));
    });

    test('returns server error message on 500 after retries', () async {
      mockDio.mockGetResponse({}, statusCode: 500);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('Server error'));
    });

    test('falls back to unexpected error when 4xx has no error field', () async {
      mockDio.mockGetResponse({}, statusCode: 422);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
    });
  });

  group('fetchEntitlements — network errors', () {
    test('returns timeout error on connection timeout', () async {
      mockDio.mockGetError(DioExceptionType.connectionTimeout);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('timed out'));
    });

    test('returns network error on connection error', () async {
      mockDio.mockGetError(DioExceptionType.connectionError);

      final result = await DashboardService.fetchEntitlements(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<EntitlementsError>());
      expect((result as EntitlementsError).error, contains('Network error'));
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
  });

  // ---------------------------------------------------------------------------
  // fetchQuotaStatus — HTTP responses
  // ---------------------------------------------------------------------------

  group('fetchQuotaStatus — success', () {
    test('returns QuotaStatusSuccess with parsed data on 200', () async {
      mockDio.mockGetResponse({
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
      mockDio.mockGetResponse({
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
      mockDio.mockGetResponse({'error': 'Unauthorized'}, statusCode: 401);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'bad-jwt',
      );

      expect(result, isA<QuotaStatusError>());
      final err = (result as QuotaStatusError).error;
      expect(err, isNot('Unauthorized'));
      expect(err, contains('log in'));
    });

    test('returns server error on 500 after retries', () async {
      mockDio.mockGetResponse({'error': 'Internal Error'}, statusCode: 500);

      final result = await DashboardService.fetchQuotaStatus(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<QuotaStatusError>());
      expect((result as QuotaStatusError).error, contains('Server error'));
    });
  });

  // ---------------------------------------------------------------------------
  // fetchBillingPortalUrl
  // ---------------------------------------------------------------------------

  group('fetchBillingPortalUrl', () {
    test('returns BillingPortalSuccess with url on 200', () async {
      mockDio.mockPostResponse(
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

    test('retries on 503 and returns server error after max retries (M42)', () async {
      mockDio.mockPostResponse({}, statusCode: 503);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'org-1',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      expect((result as BillingPortalError).error, contains('Server error'));
      expect(mockDio._postCallCount, 3); // initial + 2 retries
    });

    test('returns sanitized auth message on 401 — does not surface raw API string (L20)', () async {
      mockDio.mockPostResponse({'error': 'Unauthorized'}, statusCode: 401);

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
      mockDio.mockPostResponse({'error': 'Forbidden: org billing restricted'}, statusCode: 403);

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
      mockDio.mockPostResponse({'error': 'org_id not in stripe'}, statusCode: 404);

      final result = await DashboardService.fetchBillingPortalUrl(
        orgId: 'unknown-org',
        jwt: 'jwt',
      );

      expect(result, isA<BillingPortalError>());
      final err = (result as BillingPortalError).error;
      expect(err, isNot('org_id not in stripe'));
      expect(err, contains('not found'));
    });

    test('returns generic unexpected error on unrecognized 4xx — does not surface raw API string (L20)', () async {
      mockDio.mockPostResponse(
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
  });
}

// ---------------------------------------------------------------------------
// Minimal mock Dio — only implements get()
// ---------------------------------------------------------------------------

class _MockGetDio implements Dio {
  Map<String, dynamic> _responseData = {};
  int _statusCode = 200;
  DioExceptionType? _errorType;
  int _callCount = 0;

  Map<String, dynamic> _postResponseData = {};
  int _postStatusCode = 200;
  int _postCallCount = 0;

  void mockGetResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _responseData = Map.of(data);
    _statusCode = statusCode;
    _errorType = null;
    _callCount = 0;
  }

  void mockGetError(DioExceptionType type) {
    _errorType = type;
    _callCount = 0;
  }

  void mockPostResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _postResponseData = Map.of(data);
    _postStatusCode = statusCode;
    _postCallCount = 0;
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
    _callCount++;
    if (_errorType != null) {
      throw DioException(
        type: _errorType!,
        requestOptions: RequestOptions(path: path),
      );
    }
    return Response<T>(
      data: _responseData as T,
      statusCode: _statusCode,
      requestOptions: RequestOptions(path: path),
    );
  }

  // Unused Dio interface members — throw to catch accidental use.
  @override
  BaseOptions get options => BaseOptions();
  @override
  set options(BaseOptions _) {}
  @override
  Interceptors get interceptors => Interceptors();
  @override
  HttpClientAdapter get httpClientAdapter => throw UnimplementedError();
  @override
  set httpClientAdapter(HttpClientAdapter _) {}
  @override
  Transformer get transformer => throw UnimplementedError();
  @override
  set transformer(Transformer _) {}
  @override
  void close({bool force = false}) {}

  @override
  Future<Response<T>> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      Options? options,
      CancelToken? cancelToken,
      ProgressCallback? onSendProgress,
      ProgressCallback? onReceiveProgress}) async {
    _postCallCount++;
    return Response<T>(
      data: _postResponseData as T,
      statusCode: _postStatusCode,
      requestOptions: RequestOptions(path: path),
    );
  }

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
  Future<Response<T>> patch<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken,
          ProgressCallback? onSendProgress,
          ProgressCallback? onReceiveProgress}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> delete<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
          Options? options,
          CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<Response<T>> head<T>(String path,
          {Object? data,
          Map<String, dynamic>? queryParameters,
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

  @override
  Future<Response<T>> getUri<T>(Uri uri,
          {Object? data,
          Options? options,
          CancelToken? cancelToken,
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
  Future<Response<T>> putUri<T>(Uri uri,
          {Object? data,
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
  Future<Response<T>> deleteUri<T>(Uri uri,
          {Object? data,
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
  Future<Response> downloadUri(Uri uri, dynamic savePath,
          {ProgressCallback? onReceiveProgress,
          CancelToken? cancelToken,
          bool deleteOnError = true,
          String lengthHeader = Headers.contentLengthHeader,
          Object? data,
          Options? options,
          FileAccessMode fileAccessMode = FileAccessMode.write}) =>
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
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
