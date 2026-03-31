import 'dart:convert';

import 'package:dio/dio.dart';

/// Mock Dio implementation for testing ProvisioningService.
///
/// Allows per-request and per-attempt response configuration to test
/// success paths, error handling, and retry logic.
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
      _getResponseAttempts.clear();
      _getStatusAttempts.clear();
      _retryableResponses = null;
      _retryAttempt = 0;
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
      final response = Response<dynamic>(
        data: _postResponseAttempts[currentAttempt],
        statusCode: _postStatusAttempts[currentAttempt] ?? _mockPostStatusCode,
        headers: Headers.fromMap(_mockPostHeaders),
        requestOptions: RequestOptions(path: path),
      );
      return response as Response<T>;
    }

    // Check for retryable responses
    if (_retryableResponses != null && _retryAttempt < _retryableResponses!.length) {
      final responseData = _retryableResponses![_retryAttempt];
      final statusCode = _retryAttempt == _retryableResponses!.length - 1
          ? _successStatusCode
          : _retryableStatusCode;
      _retryAttempt++;
      final response = Response<dynamic>(
        data: responseData,
        statusCode: statusCode,
        headers: Headers.fromMap(_mockPostHeaders),
        requestOptions: RequestOptions(path: path),
      );
      return response as Response<T>;
    }

    if (_mockPostError != null) {
      throw DioException(
        type: _mockPostError!,
        requestOptions: RequestOptions(path: path),
      );
    }

    final response = Response<dynamic>(
      data: _mockPostResponseData,
      statusCode: _mockPostStatusCode,
      headers: Headers.fromMap(_mockPostHeaders),
      requestOptions: RequestOptions(path: path),
    );
    return response as Response<T>;
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
      final response = Response<dynamic>(
        data: _getResponseAttempts[currentAttempt],
        statusCode: _getStatusAttempts[currentAttempt] ?? _mockGetStatusCode,
        headers: Headers.fromMap(_mockGetHeaders),
        requestOptions: RequestOptions(path: path),
      );
      return response as Response<T>;
    }

    if (_mockGetError != null) {
      throw DioException(
        type: _mockGetError!,
        requestOptions: RequestOptions(path: path),
      );
    }

    final response = Response<dynamic>(
      data: _mockGetResponseData,
      statusCode: _mockGetStatusCode,
      headers: Headers.fromMap(_mockGetHeaders),
      requestOptions: RequestOptions(path: path),
    );
    return response as Response<T>;
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
