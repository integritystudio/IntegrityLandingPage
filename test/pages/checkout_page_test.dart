import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integrity_studio_ai/pages/checkout_page.dart';
import 'package:integrity_studio_ai/services/provisioning_service.dart';
import '../helpers/test_helpers.dart';

/// GoRouter wrapping CheckoutPage for navigation testing.
GoRouter _makeCheckoutRouter({required CheckoutArgs args}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => CheckoutPage(args: args),
      ),
      GoRoute(
        path: '/request_failure',
        builder: (_, __) =>
            const Scaffold(body: Text('request_failure_page')),
      ),
      GoRoute(
        path: '/request_success',
        builder: (_, __) =>
            const Scaffold(body: Text('request_success_page')),
      ),
    ],
  );
}

void main() {
  setUp(setUpOverflowErrorSuppression);
  tearDown(tearDownOverflowErrorSuppression);

  group('CheckoutPage', () {
    group('loading state', () {
      testWidgets('renders loading indicator while fetching session',
          (tester) async {
        setDesktopSize(tester);

        // Mock: never resolves — page stays in loading state.
        final neverDio = _NeverPostDio();
        ProvisioningService.setDioForTesting(neverDio);
        addTearDown(ProvisioningService.resetDio);

        final args = CheckoutArgs(email: 'user@example.com', tier: 'growth');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.textContaining('Redirecting'), findsOneWidget);
      });
    });

    group('error routing', () {
      late _MockCheckoutDio mockDio;

      setUp(() {
        mockDio = _MockCheckoutDio();
        ProvisioningService.setDioForTesting(mockDio);
        ProvisioningService.retryDelay = (_) async {};
      });

      tearDown(() {
        ProvisioningService.resetDio();
        ProvisioningService.resetRetryDelay();
      });

      testWidgets('routes to /request_failure on CheckoutError for growth tier', (tester) async {
        setDesktopSize(tester);
        mockDio.mockPostResponse(
          {'error': 'Stripe not configured'},
          statusCode: 500,
        );

        final args = CheckoutArgs(email: 'user@example.com', tier: 'growth');
        final router = _makeCheckoutRouter(args: args);

        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_failure_page'), findsOneWidget);
      });

      testWidgets('routes to /request_success on CheckoutError for enterprise tier', (tester) async {
        setDesktopSize(tester);
        mockDio.mockPostResponse(
          {'error': 'no Stripe price configured for tier: enterprise'},
          statusCode: 500,
        );

        final args = CheckoutArgs(email: 'corp@bigco.com', tier: 'enterprise');
        final router = _makeCheckoutRouter(args: args);

        await tester.pumpWidget(MaterialApp.router(
          theme: testTheme,
          routerConfig: router,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('request_success_page'), findsOneWidget);
        expect(find.text('request_failure_page'), findsNothing);
      });
    });

    group('args', () {
      testWidgets('accepts growth tier args', (tester) async {
        setDesktopSize(tester);

        final neverDio = _NeverPostDio();
        ProvisioningService.setDioForTesting(neverDio);
        addTearDown(ProvisioningService.resetDio);

        final args = CheckoutArgs(email: 'buyer@test.com', tier: 'growth');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();

        expect(find.byType(CheckoutPage), findsOneWidget);
      });

      testWidgets('accepts enterprise tier args', (tester) async {
        setDesktopSize(tester);

        final neverDio = _NeverPostDio();
        ProvisioningService.setDioForTesting(neverDio);
        addTearDown(ProvisioningService.resetDio);

        final args =
            CheckoutArgs(email: 'corp@bigco.com', tier: 'enterprise');
        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: CheckoutPage(args: args),
          ),
        );
        await tester.pump();

        expect(find.byType(CheckoutPage), findsOneWidget);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Mock Dio: returns immediately — used for error-routing tests.
// ---------------------------------------------------------------------------

class _MockCheckoutDio implements Dio {
  Map<String, dynamic> _postData = {};
  int _postStatusCode = 200;

  void mockPostResponse(Map<String, dynamic> data, {int statusCode = 200}) {
    _postData = Map.of(data);
    _postStatusCode = statusCode;
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
  }) async =>
      Response<T>(
        data: Map<String, dynamic>.from(_postData) as T,
        statusCode: _postStatusCode,
        requestOptions: RequestOptions(path: path),
      );

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
  Dio clone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) => this;
  @override
  Future<Response<T>> get<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> getUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> postUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> deleteUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response> download(String urlPath, dynamic savePath, {ProgressCallback? onReceiveProgress, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response> downloadUri(Uri uri, dynamic savePath, {ProgressCallback? onReceiveProgress, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) => throw UnimplementedError();
  @override
  Future<Response<T>> head<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> headUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> patch<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> patchUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> put<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> putUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> request<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> requestUri<T>(Uri uri, {Object? data, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Mock Dio: never resolves — used for loading-state tests.
// ---------------------------------------------------------------------------

class _NeverPostDio implements Dio {
  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) => Completer<Response<T>>().future; // Never completes

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
  Dio clone({
    BaseOptions? options,
    Interceptors? interceptors,
    HttpClientAdapter? httpClientAdapter,
    Transformer? transformer,
  }) => this;
  @override
  Future<Response<T>> get<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> getUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> postUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> delete<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> deleteUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response> download(String urlPath, dynamic savePath, {ProgressCallback? onReceiveProgress, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response> downloadUri(Uri uri, dynamic savePath, {ProgressCallback? onReceiveProgress, CancelToken? cancelToken, bool deleteOnError = true, String lengthHeader = Headers.contentLengthHeader, Object? data, Options? options, FileAccessMode fileAccessMode = FileAccessMode.write}) => throw UnimplementedError();
  @override
  Future<Response<T>> fetch<T>(RequestOptions requestOptions) => throw UnimplementedError();
  @override
  Future<Response<T>> head<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> headUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<Response<T>> patch<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> patchUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> put<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> putUri<T>(Uri uri, {Object? data, Options? options, CancelToken? cancelToken, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> request<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
  @override
  Future<Response<T>> requestUri<T>(Uri uri, {Object? data, CancelToken? cancelToken, Options? options, ProgressCallback? onSendProgress, ProgressCallback? onReceiveProgress}) => throw UnimplementedError();
}
