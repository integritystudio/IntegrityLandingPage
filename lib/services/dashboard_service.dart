import 'dart:async';

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
    DateTime? parsedDate;
    if (rawDate != null && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) {
        unawaited(ErrorTrackingService.captureException(
          Exception('BillingStatusData: failed to parse current_period_end'),
          stackTrace: StackTrace.current,
          context: 'BillingStatusData.fromJson',
          extra: {'raw_date': rawDate},
        ));
      }
    }
    return BillingStatusData(
      planKey: json['plan_key'] as String? ?? '',
      planDisplayName: json['plan_display_name'] as String? ?? '',
      billingStatus: json['billing_status'] as String? ?? 'inactive',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      nextRenewalDate: parsedDate,
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

  factory UsageSummaryData.fromJson(Map<String, dynamic> json) {
    final bucketsRaw = json['buckets'];
    return UsageSummaryData(
      orgId: json['org_id'] as String? ?? '',
      periodStart: json['period_start'] as String? ?? '',
      buckets: bucketsRaw is List
          ? bucketsRaw
              .map((b) => UsageBucket.fromJson(b as Map<String, dynamic>))
              .toList()
          : <UsageBucket>[],
    );
  }
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

/// Entitlements data for an organization.
class EntitlementsData {
  final String orgId;
  final Map<String, Object?> entitlements;

  const EntitlementsData({
    required this.orgId,
    required this.entitlements,
  });

  factory EntitlementsData.fromJson(Map<String, dynamic> json) {
    final rawEntitlements = json['entitlements'];
    final Map<String, Object?> entries;
    if (rawEntitlements is Map<String, dynamic>) {
      entries = rawEntitlements.cast<String, Object?>();
    } else {
      entries = const {};
    }
    return EntitlementsData(
      orgId: json['org_id'] as String? ?? '',
      entitlements: entries,
    );
  }
}

/// Entitlements API response.
sealed class EntitlementsResponse {
  const EntitlementsResponse();
}

/// Successful entitlements response.
class EntitlementsSuccess extends EntitlementsResponse {
  final EntitlementsData data;

  const EntitlementsSuccess({required this.data});
}

/// Entitlements error response.
class EntitlementsError extends EntitlementsResponse {
  final String error;

  const EntitlementsError({required this.error});
}

/// Quota state returned from the DO quota status endpoint.
class QuotaStatusData {
  final String? planKey;
  final int minuteLimit;
  final int minuteUsed;
  final int? monthlyLimit;
  final int monthlyUsed;

  /// Milliseconds remaining until the current minute window resets.
  final int minuteWindowExpiresInMs;

  const QuotaStatusData({
    this.planKey,
    required this.minuteLimit,
    required this.minuteUsed,
    this.monthlyLimit,
    required this.monthlyUsed,
    required this.minuteWindowExpiresInMs,
  });

  factory QuotaStatusData.fromJson(Map<String, dynamic> json) => QuotaStatusData(
        planKey: json['planKey'] as String?,
        minuteLimit: (json['minuteLimit'] as num?)?.toInt() ?? 0,
        minuteUsed: (json['minuteUsed'] as num?)?.toInt() ?? 0,
        monthlyLimit: (json['monthlyLimit'] as num?)?.toInt(),
        monthlyUsed: (json['monthlyUsed'] as num?)?.toInt() ?? 0,
        minuteWindowExpiresInMs:
            (json['minuteWindowExpiresIn'] as num?)?.toInt() ?? 0,
      );
}

/// Quota status API response.
sealed class QuotaStatusResponse {
  const QuotaStatusResponse();
}

/// Successful quota status response.
class QuotaStatusSuccess extends QuotaStatusResponse {
  final QuotaStatusData data;

  const QuotaStatusSuccess({required this.data});
}

/// Quota status error response.
class QuotaStatusError extends QuotaStatusResponse {
  final String error;

  const QuotaStatusError({required this.error});
}

/// Summary of an organization for the org switcher.
class OrgSummary {
  final String orgId;
  final String name;
  final String? slug;
  final String billingStatus;
  final String? currentPlan;
  final String role;

  const OrgSummary({
    required this.orgId,
    required this.name,
    this.slug,
    required this.billingStatus,
    this.currentPlan,
    required this.role,
  });

  factory OrgSummary.fromJson(Map<String, dynamic> json) => OrgSummary(
        orgId: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String?,
        billingStatus: json['billing_status'] as String? ?? 'inactive',
        currentPlan: json['current_plan'] as String?,
        role: json['role'] as String? ?? 'member',
      );
}

/// Org list API response.
sealed class OrgListResponse {
  const OrgListResponse();
}

/// Successful org list response.
class OrgListSuccess extends OrgListResponse {
  final List<OrgSummary> orgs;

  const OrgListSuccess({required this.orgs});
}

/// Org list error response.
class OrgListError extends OrgListResponse {
  final String error;

  const OrgListError({required this.error});
}

/// Billing portal URL response.
sealed class BillingPortalResponse {
  const BillingPortalResponse();
}

/// Successful billing portal URL response.
class BillingPortalSuccess extends BillingPortalResponse {
  final String url;

  const BillingPortalSuccess({required this.url});
}

/// Billing portal error response.
class BillingPortalError extends BillingPortalResponse {
  final String error;

  const BillingPortalError({required this.error});
}

/// API client for dashboard data endpoints.
class DashboardService {
  DashboardService._();

  static const String _errorTimeout = 'Connection timed out. Please try again.';
  static const String _errorNetwork = 'Network error. Please try again.';
  static const String _errorServer = 'Server error. Please try again.';
  static const String _errorUnexpected = 'An unexpected error occurred.';
  static const String _errorBillingAuth = 'Authentication required. Please log in again.';
  static const String _errorBillingForbidden =
      "You don't have permission to manage billing for this organization.";
  static const String _errorBillingNotFound = 'Organization not found.';
  // Max retry attempts (2 retries = 3 total attempts: initial + 2 retries)
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
    // Reject orgId values that could alter the URL path or query string.
    if (orgId.isEmpty || orgId.contains(RegExp(r'[/?#%]'))) {
      return const BillingStatusError(error: _errorUnexpected);
    }
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

        return BillingStatusError(error: _sanitizeReadError(response.statusCode));
      } on DioException catch (e) {
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;

        if (isRetryable && attempt < _maxRetries) {
          await retryDelay(Duration(seconds: 1 << attempt));
          continue;
        }

        // SECURITY: never add jwt or other credentials to extra — Sentry stores this unredacted.
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
    if (orgId.isEmpty || orgId.contains(RegExp(r'[/?#%]'))) {
      return const UsageSummaryError(error: _errorUnexpected);
    }
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
          return UsageSummarySuccess(
            data: UsageSummaryData.fromJson(data),
          );
        }

        return UsageSummaryError(error: _sanitizeReadError(response.statusCode));
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

  /// Fetch feature entitlements for an organization.
  ///
  /// Calls GET /v1/orgs/:orgId/entitlements with the provided JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<EntitlementsResponse> fetchEntitlements({
    required String orgId,
    required String jwt,
  }) async {
    if (orgId.isEmpty || orgId.contains(RegExp(r'[/?#%]'))) {
      return const EntitlementsError(error: _errorUnexpected);
    }
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$_apiGatewayUrl/v1/orgs/$orgId/entitlements',
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
          return const EntitlementsError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          return EntitlementsSuccess(data: EntitlementsData.fromJson(data));
        }

        return EntitlementsError(error: _sanitizeReadError(response.statusCode));
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
          context: 'DashboardService.fetchEntitlements',
          extra: {
            'orgId': orgId,
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const EntitlementsError(error: _errorTimeout);
        }
        return const EntitlementsError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const EntitlementsError(error: _errorUnexpected);
      }
    }

    return const EntitlementsError(error: _errorUnexpected);
  }

  /// Fetch quota status (minute + monthly) for an organization.
  ///
  /// Calls GET /v1/orgs/:orgId/quota/status with the provided JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<QuotaStatusResponse> fetchQuotaStatus({
    required String orgId,
    required String jwt,
  }) async {
    if (orgId.isEmpty || orgId.contains(RegExp(r'[/?#%]'))) {
      return const QuotaStatusError(error: _errorUnexpected);
    }
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$_apiGatewayUrl/v1/orgs/$orgId/quota/status',
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
          return const QuotaStatusError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          return QuotaStatusSuccess(data: QuotaStatusData.fromJson(data));
        }

        return QuotaStatusError(error: _sanitizeReadError(response.statusCode));
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
          context: 'DashboardService.fetchQuotaStatus',
          extra: {
            'orgId': orgId,
            'attempt': attempt + 1,
          },
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const QuotaStatusError(error: _errorTimeout);
        }
        return const QuotaStatusError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const QuotaStatusError(error: _errorUnexpected);
      }
    }

    return const QuotaStatusError(error: _errorUnexpected);
  }

  /// Fetch a Stripe Customer Portal URL for an organization.
  ///
  /// Calls POST /v1/orgs/:orgId/billing-portal with the provided JWT.
  /// Requires owner or billing_admin role.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<BillingPortalResponse> fetchBillingPortalUrl({
    required String orgId,
    required String jwt,
  }) async {
    if (orgId.isEmpty || orgId.contains(RegExp(r'[/?#%]'))) {
      return const BillingPortalError(error: _errorUnexpected);
    }
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post(
          '$_apiGatewayUrl/v1/orgs/$orgId/billing-portal',
          options: Options(
            headers: {'Authorization': 'Bearer $jwt'},
            validateStatus: (status) => status != null,
          ),
        );

        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : const <String, dynamic>{};

        if (response.statusCode == HttpStatus.internalServerError.code ||
            response.statusCode == HttpStatus.serviceUnavailable.code ||
            response.statusCode == HttpStatus.gatewayTimeout.code) {
          if (attempt < _maxRetries) {
            await retryDelay(Duration(seconds: 1 << attempt));
            continue;
          }
          return const BillingPortalError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          final url = data['url'] as String?;
          if (url == null || url.isEmpty) {
            return const BillingPortalError(error: _errorUnexpected);
          }
          return BillingPortalSuccess(url: url);
        }

        return BillingPortalError(
          error: _billingPortalErrorMessage(response.statusCode),
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
          context: 'DashboardService.fetchBillingPortalUrl',
          extra: {'orgId': orgId, 'attempt': attempt + 1},
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const BillingPortalError(error: _errorTimeout);
        }
        return const BillingPortalError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const BillingPortalError(error: _errorUnexpected);
      }
    }

    return const BillingPortalError(error: _errorUnexpected);
  }

  static String _billingPortalErrorMessage(int? statusCode) {
    if (statusCode == HttpStatus.unauthorized.code) return _errorBillingAuth;
    if (statusCode == HttpStatus.forbidden.code) return _errorBillingForbidden;
    if (statusCode == HttpStatus.notFound.code) return _errorBillingNotFound;
    return _errorUnexpected;
  }

  /// Maps non-200 status codes to safe user-facing messages for read endpoints.
  /// Prevents raw API error strings from leaking to callers.
  static String _sanitizeReadError(int? statusCode) {
    if (statusCode == HttpStatus.unauthorized.code) return _errorBillingAuth;
    if (statusCode == HttpStatus.forbidden.code) return _errorBillingForbidden;
    return _errorUnexpected;
  }

  /// Fetch the list of organizations the authenticated user belongs to.
  ///
  /// Calls GET /v1/orgs with the provided JWT.
  /// Retries up to [_maxRetries] times on transient network errors
  /// with exponential backoff (1s, 2s).
  static Future<OrgListResponse> fetchOrgList({required String jwt}) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.get(
          '$_apiGatewayUrl/v1/orgs',
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
          return const OrgListError(error: _errorServer);
        }

        if (response.statusCode == HttpStatus.ok.code) {
          final raw = data['organizations'];
          final orgs = raw is List
              ? raw
                  .map((o) => OrgSummary.fromJson(o as Map<String, dynamic>))
                  .toList()
              : <OrgSummary>[];
          return OrgListSuccess(orgs: orgs);
        }

        return OrgListError(
          error: _sanitizeReadError(response.statusCode),
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

        // SECURITY: never add jwt or other credentials to extra — Sentry stores this unredacted.
        await ErrorTrackingService.captureException(
          e,
          stackTrace: e.stackTrace,
          context: 'DashboardService.fetchOrgList',
          extra: {'attempt': attempt + 1},
        );

        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          return const OrgListError(error: _errorTimeout);
        }
        return const OrgListError(error: _errorNetwork);
      } catch (e, stackTrace) {
        await ErrorTrackingService.captureException(e, stackTrace: stackTrace);
        return const OrgListError(error: _errorUnexpected);
      }
    }

    return const OrgListError(error: _errorUnexpected);
  }
}
