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

/// API Gateway endpoint.
/// Configurable via --dart-define for staging/development.
const _apiGatewayUrl = String.fromEnvironment(
  'API_GATEWAY_URL',
  defaultValue: 'https://api-gateway.example.workers.dev',
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

/// Bootstrap API response.
sealed class BootstrapResponse {
  const BootstrapResponse();
}

/// Organization from bootstrap response.
class BootstrapOrg {
  final String id;
  final String name;
  final String role;
  final String planKey;
  final String billingStatus;

  const BootstrapOrg({
    required this.id,
    required this.name,
    required this.role,
    required this.planKey,
    required this.billingStatus,
  });

  factory BootstrapOrg.fromJson(Map<String, dynamic> json) => BootstrapOrg(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
        planKey: json['plan_key'] as String? ?? '',
        billingStatus: json['billing_status'] as String? ?? '',
      );
}

/// Feature entitlements from bootstrap response.
class BootstrapEntitlements {
  final bool usageDashboard;
  final bool alerts;
  final bool complianceSummary;
  final int monthlyUnits;
  final int requestsPerMinute;

  const BootstrapEntitlements({
    required this.usageDashboard,
    required this.alerts,
    required this.complianceSummary,
    required this.monthlyUnits,
    required this.requestsPerMinute,
  });

  factory BootstrapEntitlements.fromJson(Map<String, dynamic> json) =>
      BootstrapEntitlements(
        usageDashboard: json['usage_dashboard'] as bool? ?? false,
        alerts: json['alerts'] as bool? ?? false,
        complianceSummary: json['compliance_summary'] as bool? ?? false,
        monthlyUnits: json['monthly_units'] as int? ?? 0,
        requestsPerMinute: json['requests_per_minute'] as int? ?? 0,
      );
}

/// Current-period usage snapshot from bootstrap response.
class BootstrapUsageSnapshot {
  final int monthToDateUnits;
  final int currentMinuteRemaining;

  const BootstrapUsageSnapshot({
    required this.monthToDateUnits,
    required this.currentMinuteRemaining,
  });

  factory BootstrapUsageSnapshot.fromJson(Map<String, dynamic> json) =>
      BootstrapUsageSnapshot(
        monthToDateUnits: json['month_to_date_units'] as int? ?? 0,
        currentMinuteRemaining: json['current_minute_remaining'] as int? ?? 0,
      );
}

/// Successful bootstrap response.
class BootstrapSuccess extends BootstrapResponse {
  final BootstrapOrg activeOrg;
  final List<BootstrapOrg> organizations;
  final BootstrapEntitlements entitlements;
  final BootstrapUsageSnapshot usageSnapshot;

  const BootstrapSuccess({
    required this.activeOrg,
    required this.organizations,
    required this.entitlements,
    required this.usageSnapshot,
  });
}

/// Bootstrap error response.
class BootstrapError extends BootstrapResponse {
  final String error;

  const BootstrapError({required this.error});
}

/// Arguments passed to CheckoutPage.
class CheckoutArgs {
  final String email;
  final String tier;

  const CheckoutArgs({required this.email, required this.tier});
}

/// Checkout API response.
sealed class CheckoutResponse {
  const CheckoutResponse();
}

/// Successful checkout response with Stripe session URL.
class CheckoutSuccess extends CheckoutResponse {
  final String checkoutUrl;

  const CheckoutSuccess({required this.checkoutUrl});
}

/// Checkout error response.
class CheckoutError extends CheckoutResponse {
  final String error;

  const CheckoutError({required this.error});
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
  static Future<AuthResponse> signUp(
    String email,
    String password, {
    String? name,
    String tier = 'starter',
  }) async {
    try {
      final response = await _dio.post(
        '$_senderWorkerUrl/signup',
        data: jsonEncode({
          'email': email,
          'password': password,
          if (name != null && name.isNotEmpty) 'name': name,
          'tier': tier,
        }),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null,
        ),
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      if (response.statusCode == 201) {
        return AuthSuccess(
          jwt: data['jwt'] as String? ?? '',
          email: data['email'] as String? ?? email,
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

  /// Create a Stripe checkout session for a paid tier.
  ///
  /// Returns CheckoutSuccess with the Stripe-hosted checkout URL, or CheckoutError.
  static Future<CheckoutResponse> createCheckoutSession({
    required String email,
    required String tier,
  }) async {
    try {
      final response = await _dio.post(
        '$_senderWorkerUrl/create-checkout-session',
        data: jsonEncode({'email': email, 'tier': tier}),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null,
        ),
      );

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : const <String, dynamic>{};

      if (response.statusCode == 200 && data['checkoutUrl'] != null) {
        return CheckoutSuccess(checkoutUrl: data['checkoutUrl'] as String);
      }

      return CheckoutError(
        error: data['error'] as String? ?? _errorUnexpected,
      );
    } catch (e, stackTrace) {
      await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
      return const CheckoutError(error: _errorUnexpected);
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

  /// Load org context, entitlements, and usage snapshot from the API Gateway.
  ///
  /// Should be called after sign-in with the Auth JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<BootstrapResponse> bootstrap({required String jwt}) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_apiGatewayUrl/bootstrap',
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
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
          return const BootstrapError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          final orgsRaw = data['organizations'];
          if (orgsRaw is! List || orgsRaw.isEmpty) {
            return const BootstrapError(error: _errorUnexpected);
          }
          final orgs = orgsRaw
              .map((o) => BootstrapOrg.fromJson(o as Map<String, dynamic>))
              .toList();
          final activeOrgId = data['active_org_id'] as String?;
          final activeOrg = orgs.firstWhere(
            (o) => o.id == activeOrgId,
            orElse: () => orgs.first,
          );
          return BootstrapSuccess(
            activeOrg: activeOrg,
            organizations: orgs,
            entitlements: data['entitlements'] is Map<String, dynamic>
                ? BootstrapEntitlements.fromJson(
                    data['entitlements'] as Map<String, dynamic>)
                : const BootstrapEntitlements(
                    usageDashboard: false,
                    alerts: false,
                    complianceSummary: false,
                    monthlyUnits: 0,
                    requestsPerMinute: 0,
                  ),
            usageSnapshot: data['usage_snapshot'] is Map<String, dynamic>
                ? BootstrapUsageSnapshot.fromJson(
                    data['usage_snapshot'] as Map<String, dynamic>)
                : const BootstrapUsageSnapshot(
                    monthToDateUnits: 0,
                    currentMinuteRemaining: 0,
                  ),
          );
        }

        // Non-retryable: 401, 403, or unexpected status
        return BootstrapError(
          error: data['error'] as String? ?? _errorUnexpected,
        );
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        await ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'ProvisioningService.bootstrap',
          extra: {
            'endpoint': _apiGatewayUrl,
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const BootstrapError(error: _errorTimeout);
        }
        return const BootstrapError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const BootstrapError(error: _errorUnexpected);
      }
    }

    // Unreachable, but satisfies the return type
    return const BootstrapError(error: _errorUnexpected);
  }
}
