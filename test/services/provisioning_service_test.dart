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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime(2026, 3, 19, 12, 0, 0),
      );

      final json = event.toJson();

      expect(json['userId'], 'user-123');
      expect(json['action'], 'create-api-key');
      expect(json['sentAt'], isA<String>());
      // Verify ISO8601 format with Z (UTC)
      expect(json['sentAt'], contains('Z'));
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningSuccess>());
      expect(mockDio.postCallCount, 2);
    });

    test('returns error on connectionTimeout after max retries', () async {
      mockDio.mockPostError(DioExceptionType.connectionTimeout);

      final event = ProvisioningEvent(
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'user-123',
        action: 'create-api-key',
        sentAt: DateTime.now(),
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
        userId: 'invalid',
        action: 'create-api-key',
        sentAt: DateTime.now(),
      );

      final result = await ProvisioningService.sendEvent(event, jwt: 'test-jwt');

      expect(result, isA<ProvisioningError>());
      expect((result as ProvisioningError).error, 'Invalid userId format');
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

  group('MockProvisioningDio per-attempt response data', () {
    test('post returns per-attempt data when attemptNumber matches', () async {
      // Attempt 0: connection error (triggers retry), attempt 1: success
      mockDio.mockPostError(DioExceptionType.connectionTimeout, attemptNumber: 0);
      mockDio.mockPostResponse(
        {'ok': true, 'apiKey': 'sk-retry-key', 'received': 'xyz'},
        attemptNumber: 1,
      );

      final event = ProvisioningEvent(
        userId: 'u1',
        action: 'create-api-key',
        sentAt: DateTime(2026, 3, 20),
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
