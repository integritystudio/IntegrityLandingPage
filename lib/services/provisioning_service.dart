import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../theme/timings.dart';
import 'analytics.dart';
import 'http_status.dart';

/// Sender Worker endpoint.
/// Configurable via --dart-define for staging/development.
const _senderWorkerUrl = String.fromEnvironment(
  'SENDER_WORKER_URL',
  defaultValue: 'https://sender-worker.example.workers.dev',
);

/// Provisioning event payload.
class ProvisioningEvent {
  final String userId;
  final String action;
  final DateTime sentAt;

  const ProvisioningEvent({
    required this.userId,
    required this.action,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'action': action,
        'sentAt': sentAt.toUtc().toIso8601String(),
      };
}

/// Provisioning API response.
sealed class ProvisioningResponse {
  const ProvisioningResponse();
}

/// Successful provisioning response with API key.
class ProvisioningSuccess extends ProvisioningResponse {
  final String apiKey;
  final String received;

  const ProvisioningSuccess({
    required this.apiKey,
    required this.received,
  });
}

/// Provisioning error response.
class ProvisioningError extends ProvisioningResponse {
  final String error;

  const ProvisioningError({required this.error});
}

/// API client for the Sender Worker.
///
/// Sends provisioning events via POST to the Sender Worker,
/// which signs and forwards them to the Receiver Worker.
/// Flutter never touches the inter-service HMAC secret.
class ProvisioningService {
  ProvisioningService._();

  // Error message constants (per project rule: no magic strings)
  static const String _errorTimeout =
      'Connection timed out. Please try again.';
  static const String _errorNetwork =
      'Network error. Please try again.';
  static const String _errorServer =
      'Server error. Please try again.';
  static const String _errorUnexpected =
      'An unexpected error occurred.';

  static const int _maxRetries = 2;

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: AppTimings.httpConnectTimeout,
    receiveTimeout: AppTimings.httpReceiveTimeout,
  ));

  /// Set a custom Dio instance for testing.
  @visibleForTesting
  static void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  /// Reset Dio to default instance.
  @visibleForTesting
  static void resetDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: AppTimings.httpConnectTimeout,
      receiveTimeout: AppTimings.httpReceiveTimeout,
    ));
  }

  /// Retry delay function, injectable for testing.
  @visibleForTesting
  static Future<void> Function(Duration) retryDelay = Future.delayed;

  /// Reset retry delay to default.
  @visibleForTesting
  static void resetRetryDelay() {
    retryDelay = Future.delayed;
  }

  /// Send a provisioning event to the Sender Worker.
  ///
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<ProvisioningResponse> sendEvent(
    ProvisioningEvent event,
  ) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_senderWorkerUrl/send',
          data: jsonEncode(event.toJson()),
          options: Options(
            headers: {'Content-Type': 'application/json'},
            // Accept all non-null status codes — HTTP errors are handled in
            // the explicit dispatch below so Dio must not throw on 4xx/5xx.
            validateStatus: (status) => status != null,
          ),
        );

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        // Retryable server errors (500, 504)
        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return const ProvisioningError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code &&
            data['ok'] == true) {
          return ProvisioningSuccess(
            apiKey: data['apiKey'] as String? ?? '',
            received: data['received'] as String? ?? '',
          );
        }

        // Non-retryable: client error or unexpected status
        return ProvisioningError(
          error: data['error'] as String? ?? _errorUnexpected,
        );
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          // Exponential backoff: 1s, 2s
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        // Log to Sentry on final attempt
        await ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'ProvisioningService.sendEvent',
          extra: {
            'endpoint': _senderWorkerUrl,
            'type': 'provisioning_event',
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const ProvisioningError(error: _errorTimeout);
        }
        return const ProvisioningError(error: _errorNetwork);
      } catch (e, stackTrace) {
        // Non-retryable unexpected errors
        await ErrorTrackingService.captureException(e,
            stackTrace: stackTrace);
        return const ProvisioningError(error: _errorUnexpected);
      }
    }

    // Unreachable, but satisfies the return type
    return const ProvisioningError(error: _errorUnexpected);
  }

  /// Health check against the Receiver Worker (public endpoint).
  static Future<ProvisioningResponse> checkHealth(
    String receiverUrl,
  ) async {
    try {
      final response = await _dio.get('$receiverUrl/health');
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      if (response.statusCode == HttpStatus.ok.code &&
          data['ok'] == true) {
        return ProvisioningSuccess(
          apiKey: '',
          received: data['received'] as String? ?? '',
        );
      }
      return const ProvisioningError(error: _errorServer);
    } on DioException catch (e) {
      await ErrorTrackingService.captureException(
        e,
        context: 'ProvisioningService.checkHealth',
      );
      return const ProvisioningError(error: _errorNetwork);
    }
  }
}
