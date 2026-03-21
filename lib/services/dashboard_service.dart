import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../theme/timings.dart';
import 'analytics.dart';
import 'http_status.dart';

/// API Gateway endpoint.
/// Configurable via --dart-define for staging/development.
const _apiGatewayUrl = String.fromEnvironment(
  'API_GATEWAY_URL',
  defaultValue: 'https://api-gateway.example.workers.dev',
);

/// Billing status for an organization.
class BillingStatusData {
  final String planKey;
  final String planDisplayName;
  final String billingStatus;
  final DateTime? nextRenewalDate;
  final bool cancelAtPeriodEnd;

  const BillingStatusData({
    required this.planKey,
    required this.planDisplayName,
    required this.billingStatus,
    required this.cancelAtPeriodEnd,
    this.nextRenewalDate,
  });

  factory BillingStatusData.fromJson(Map<String, dynamic> json) {
    final rawDate = json['current_period_end'] as String?;
    return BillingStatusData(
      planKey: json['plan_key'] as String? ?? '',
      planDisplayName: json['plan_display_name'] as String? ?? '',
      billingStatus: json['billing_status'] as String? ?? 'inactive',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      nextRenewalDate: rawDate != null ? DateTime.tryParse(rawDate) : null,
    );
  }
}

/// Billing status API response.
sealed class BillingStatusResponse {
  const BillingStatusResponse();
}

/// Successful billing status response.
class BillingStatusSuccess extends BillingStatusResponse {
  final BillingStatusData data;

  const BillingStatusSuccess({required this.data});
}

/// Billing status error response.
class BillingStatusError extends BillingStatusResponse {
  final String error;

  const BillingStatusError({required this.error});
}

/// Daily usage bucket from the API.
class UsageBucket {
  final String bucketDate;
  final String metricKey;
  final int totalQuantity;
  final int requestCount;
  final double? avgLatencyMs;

  const UsageBucket({
    required this.bucketDate,
    required this.metricKey,
    required this.totalQuantity,
    required this.requestCount,
    this.avgLatencyMs,
  });

  factory UsageBucket.fromJson(Map<String, dynamic> json) => UsageBucket(
        bucketDate: json['bucket_date'] as String? ?? '',
        metricKey: json['metric_key'] as String? ?? '',
        totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
        requestCount: (json['request_count'] as num?)?.toInt() ?? 0,
        avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble(),
      );
}

/// Usage summary data returned from the API.
class UsageSummaryData {
  final String orgId;
  final String periodStart;
  final List<UsageBucket> buckets;

  const UsageSummaryData({
    required this.orgId,
    required this.periodStart,
    required this.buckets,
  });
}

/// Usage summary API response.
sealed class UsageSummaryResponse {
  const UsageSummaryResponse();
}

/// Successful usage summary response.
class UsageSummarySuccess extends UsageSummaryResponse {
  final UsageSummaryData data;

  const UsageSummarySuccess({required this.data});
}

/// Usage summary error response.
class UsageSummaryError extends UsageSummaryResponse {
  final String error;

  const UsageSummaryError({required this.error});
}

/// API client for dashboard data endpoints.
class DashboardService {
  DashboardService._();

  static const String _errorTimeout = 'Connection timed out. Please try again.';
  static const String _errorNetwork = 'Network error. Please try again.';
  static const String _errorServer = 'Server error. Please try again.';
  static const String _errorUnexpected = 'An unexpected error occurred.';
  static const int _maxRetries = 2;

  static Dio _dio = Dio(BaseOptions(
    connectTimeout: AppTimings.httpConnectTimeout,
    receiveTimeout: AppTimings.httpReceiveTimeout,
  ));

  @visibleForTesting
  static void setDioForTesting(Dio dio) {
    _dio = dio;
  }

  @visibleForTesting
  static void resetDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: AppTimings.httpConnectTimeout,
      receiveTimeout: AppTimings.httpReceiveTimeout,
    ));
  }

  @visibleForTesting
  static Future<void> Function(Duration) retryDelay = Future.delayed;

  @visibleForTesting
  static void resetRetryDelay() {
    retryDelay = Future.delayed;
  }

  /// Fetch billing status for an organization.
  ///
  /// Calls GET /v1/orgs/:orgId/billing-status with the provided JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<BillingStatusResponse> fetchBillingStatus({
    required String orgId,
    required String jwt,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$_apiGatewayUrl/v1/orgs/$orgId/billing-status',
          options: Options(
            headers: {'Authorization': 'Bearer $jwt'},
            validateStatus: (status) => status != null,
          ),
        );

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return const BillingStatusError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          return BillingStatusSuccess(
            data: BillingStatusData.fromJson(data),
          );
        }

        return BillingStatusError(
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
          context: 'DashboardService.fetchBillingStatus',
          extra: {
            'orgId': orgId,
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const BillingStatusError(error: _errorTimeout);
        }
        return const BillingStatusError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const BillingStatusError(error: _errorUnexpected);
      }
    }

    return const BillingStatusError(error: _errorUnexpected);
  }

  /// Fetch monthly usage summary for an organization.
  ///
  /// Calls GET /v1/orgs/:orgId/usage/summary with the provided JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<UsageSummaryResponse> fetchUsageSummary({
    required String orgId,
    required String jwt,
  }) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$_apiGatewayUrl/v1/orgs/$orgId/usage/summary',
          options: Options(
            headers: {'Authorization': 'Bearer $jwt'},
            validateStatus: (status) => status != null,
          ),
        );

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return const UsageSummaryError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          final bucketsRaw = data['buckets'];
          final buckets = bucketsRaw is List
              ? bucketsRaw
                  .map((b) => UsageBucket.fromJson(b as Map<String, dynamic>))
                  .toList()
              : <UsageBucket>[];
          return UsageSummarySuccess(
            data: UsageSummaryData(
              orgId: data['org_id'] as String? ?? orgId,
              periodStart: data['period_start'] as String? ?? '',
              buckets: buckets,
            ),
          );
        }

        return UsageSummaryError(
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
          context: 'DashboardService.fetchUsageSummary',
          extra: {
            'orgId': orgId,
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const UsageSummaryError(error: _errorTimeout);
        }
        return const UsageSummaryError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const UsageSummaryError(error: _errorUnexpected);
      }
    }

    return const UsageSummaryError(error: _errorUnexpected);
  }
}
