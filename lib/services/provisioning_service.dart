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

  /// Timestamp when the event was sent.
  /// Should be in UTC for consistency with toJson serialization.
  /// If a local DateTime is provided, it will be converted to UTC during serialization.
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

/// Authentication API response.
sealed class AuthResponse {
  const AuthResponse();
}

/// Successful authentication response with JWT.
class AuthSuccess extends AuthResponse {
  final String jwt;
  final String email;

  const AuthSuccess({
    required this.jwt,
    required this.email,
  });
}

/// Authentication error response.
class AuthError extends AuthResponse {
  final String error;

  const AuthError({required this.error});
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

  /// Max retry attempts (2 retries = 3 total attempts: initial + 2 retries)
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

  /// Sign up with email and password.
  ///
  /// Returns AuthSuccess (201) with JWT token or AuthError.
  static Future<AuthResponse> signUp(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_senderWorkerUrl/signup',
        data: jsonEncode({
          'email': email,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null,
        ),
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      if (response.statusCode == 201 && data['jwt'] != null) {
        return AuthSuccess(
          jwt: data['jwt'] as String,
          email: email,
        );
      }

      return AuthError(
        error: data['error'] as String? ?? _errorUnexpected,
      );
    } catch (e, stackTrace) {
      await ErrorTrackingService.captureException(e,
          stackTrace: stackTrace);
      return const AuthError(error: _errorUnexpected);
    }
  }

  /// Sign in with email and password.
  ///
  /// Returns AuthSuccess (200) with JWT token or AuthError.
  static Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _dio.post(
        '$_senderWorkerUrl/signin',
        data: jsonEncode({
          'email': email,
          'password': password,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null,
        ),
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      if (response.statusCode == 200 && data['jwt'] != null) {
        return AuthSuccess(
          jwt: data['jwt'] as String,
          email: email,
        );
      }

      return AuthError(
        error: data['error'] as String? ?? _errorUnexpected,
      );
    } catch (e, stackTrace) {
      await ErrorTrackingService.captureException(e,
          stackTrace: stackTrace);
      return const AuthError(error: _errorUnexpected);
    }
  }

  /// Send a provisioning event to the Sender Worker.
  ///
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<ProvisioningResponse> sendEvent(
    ProvisioningEvent event, {
    required String jwt,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_senderWorkerUrl/send',
          data: jsonEncode(event.toJson()),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
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
          final apiKey = data['apiKey'] as String?;
          // Treat missing or empty apiKey as a data integrity error
          if (apiKey == null || apiKey.isEmpty) {
            return const ProvisioningError(error: _errorUnexpected);
          }
          return ProvisioningSuccess(
            apiKey: apiKey,
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
  ///
  /// Returns true if the service is healthy, false otherwise.
  /// Retries transient errors (timeout, connection errors) with exponential backoff.
  /// Validates the URL is https:// to prevent injection attacks.
  static Future<bool> checkHealth(String receiverUrl) async {
    // URL validation: ensure it's a valid HTTPS URL
    final uri = Uri.tryParse(receiverUrl);
    if (uri == null || uri.scheme != 'https') {
      await ErrorTrackingService.captureException(
        ArgumentError('Health check URL must use https'),
        context: 'ProvisioningService.checkHealth',
        extra: {'receiverUrl': receiverUrl},
      );
      return false;
    }

    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$receiverUrl/health',
          options: Options(
            // Accept all non-null status codes — HTTP errors are handled in
            // the explicit dispatch below so Dio must not throw on 4xx/5xx.
            validateStatus: (status) => status != null,
          ),
        );
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        return response.statusCode == HttpStatus.ok.code && data['ok'] == true;
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        // Log on final attempt
        await ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'ProvisioningService.checkHealth',
          extra: {
            'endpoint': receiverUrl,
            'attempt': attempt + 1,
          },
        );
        return false;
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e,
            stackTrace: stackTrace);
        return false;
      }
    }

    // Unreachable, but satisfies the return type
    return false;
  }
}
