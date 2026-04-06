import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import '../services/analytics.dart';

part 'dashboard_models.freezed.dart';
part 'dashboard_models.g.dart';

/// Billing status for an organization.
@Freezed(fromJson: false, toJson: false)
abstract class BillingStatusData with _$BillingStatusData {
  const factory BillingStatusData({
    @Default('') String planKey,
    @Default('') String planDisplayName,
    @Default('inactive') String billingStatus,
    @Default(false) bool cancelAtPeriodEnd,
    DateTime? nextRenewalDate,
  }) = _BillingStatusData;

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

/// Daily usage bucket from the API.
@Freezed(toJson: false)
abstract class UsageBucket with _$UsageBucket {
  const factory UsageBucket({
    @JsonKey(name: 'bucket_date') @Default('') String bucketDate,
    @JsonKey(name: 'metric_key') @Default('') String metricKey,
    @JsonKey(name: 'total_quantity') @Default(0) int totalQuantity,
    @JsonKey(name: 'request_count') @Default(0) int requestCount,
    @JsonKey(name: 'avg_latency_ms') double? avgLatencyMs,
  }) = _UsageBucket;

  factory UsageBucket.fromJson(Map<String, dynamic> json) =>
      _$UsageBucketFromJson(json);
}

/// Usage summary data returned from the API.
@Freezed(fromJson: false, toJson: false)
abstract class UsageSummaryData with _$UsageSummaryData {
  const factory UsageSummaryData({
    @Default('') String orgId,
    @Default('') String periodStart,
    @Default([]) List<UsageBucket> buckets,
  }) = _UsageSummaryData;

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

/// Entitlements data for an organization.
@Freezed(fromJson: false, toJson: false)
abstract class EntitlementsData with _$EntitlementsData {
  const factory EntitlementsData({
    @Default('') String orgId,
    @Default({}) Map<String, Object?> entitlements,
  }) = _EntitlementsData;

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

/// Quota state returned from the DO quota status endpoint.
@Freezed(toJson: false)
abstract class QuotaStatusData with _$QuotaStatusData {
  const factory QuotaStatusData({
    String? planKey,
    @Default(0) int minuteLimit,
    @Default(0) int minuteUsed,
    int? monthlyLimit,
    @Default(0) int monthlyUsed,
    @JsonKey(name: 'minuteWindowExpiresIn')
    @Default(0)
    int minuteWindowExpiresInMs,
  }) = _QuotaStatusData;

  factory QuotaStatusData.fromJson(Map<String, dynamic> json) =>
      _$QuotaStatusDataFromJson(json);
}

/// Summary of an organization for the org switcher.
@Freezed(toJson: false)
abstract class OrgSummary with _$OrgSummary {
  const factory OrgSummary({
    @JsonKey(name: 'id') @Default('') String orgId,
    @Default('') String name,
    String? slug,
    @JsonKey(name: 'billing_status') @Default('inactive') String billingStatus,
    @JsonKey(name: 'current_plan') String? currentPlan,
    @Default('member') String role,
  }) = _OrgSummary;

  factory OrgSummary.fromJson(Map<String, dynamic> json) =>
      _$OrgSummaryFromJson(json);
}
