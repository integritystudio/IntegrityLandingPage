/// Transport-layer stub for Dio-based service tests.
///
/// Tests inject a real [Dio] wired to a [MockHttpAdapter] so the full
/// production request pipeline runs (BaseOptions, headers, transformer,
/// validateStatus, DioException mapping) and only the HTTP wire is faked.
/// [HttpClientAdapter] is a two-method interface dio keeps stable, unlike
/// the full [Dio] surface which grows across minor releases.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Build a real [Dio] whose transport is [adapter].
Dio dioWithMockAdapter(MockHttpAdapter adapter) =>
    Dio()..httpClientAdapter = adapter;

class MockHttpAdapter implements HttpClientAdapter {
  /// Every request that reached the transport, in order.
  final List<RequestOptions> requestLog = [];

  final Map<String, _Stub> _stubs = {};

  int requestCount(String method) =>
      requestLog.where((r) => r.method == method.toUpperCase()).length;

  /// Respond to [method] requests with [data] as a JSON body.
  ///
  /// [path] narrows the stub to URLs ending with that suffix (e.g. '/send'),
  /// so services that hit several endpoints with the same HTTP method can be
  /// stubbed by URL rather than by call order. A path stub wins over a bare
  /// method stub; the method stub remains the fallback.
  void stubJson(
    String method,
    Map<String, dynamic> data, {
    int statusCode = 200,
    Map<String, List<String>>? headers,
    String? path,
  }) {
    _stubs[_key(method, path)] =
        _Stub(data: data, statusCode: statusCode, headers: headers);
  }

  /// Fail [method] requests with a [DioException] of [type].
  /// [path] narrows the stub as in [stubJson].
  void stubError(String method, DioExceptionType type, {String? path}) {
    _stubs[_key(method, path)] = _Stub(errorType: type);
  }

  static String _key(String method, [String? path]) =>
      path == null ? method.toUpperCase() : '${method.toUpperCase()} $path';

  /// Respond to [method] only after the returned completer is completed.
  Completer<void> stubDelayedJson(
    String method,
    Map<String, dynamic> data, {
    int statusCode = 200,
  }) {
    final gate = Completer<void>();
    _stubs[method.toUpperCase()] =
        _Stub(data: data, statusCode: statusCode, gate: gate);
    return gate;
  }

  /// Never respond to [method] requests (loading-state tests).
  void stubNever(String method) {
    _stubs[method.toUpperCase()] = _Stub(never: true);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestLog.add(options);
    // Longest suffix wins so overlapping stubs (e.g. '/send' vs '/resend')
    // resolve to the most specific match rather than insertion order.
    final pathStubs = _stubs.entries.where((e) =>
        e.key.startsWith('${options.method} ') &&
        options.path.endsWith(e.key.split(' ')[1]));
    final stub = pathStubs.isNotEmpty
        ? pathStubs
            .reduce((a, b) => a.key.length >= b.key.length ? a : b)
            .value
        : _stubs[options.method];
    if (stub == null) {
      throw StateError(
          'MockHttpAdapter: no stub for ${options.method} ${options.path}');
    }
    if (stub.never) {
      await Completer<void>().future;
    }
    if (stub.gate != null) {
      await stub.gate!.future;
    }
    if (stub.errorType != null) {
      throw DioException(requestOptions: options, type: stub.errorType!);
    }
    return ResponseBody.fromString(
      jsonEncode(stub.data),
      stub.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?stub.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Stub {
  const _Stub({
    this.data = const {},
    this.statusCode = 200,
    this.headers,
    this.errorType,
    this.gate,
    this.never = false,
  });

  final Map<String, dynamic> data;
  final int statusCode;
  final Map<String, List<String>>? headers;
  final DioExceptionType? errorType;
  final Completer<void>? gate;
  final bool never;
}
