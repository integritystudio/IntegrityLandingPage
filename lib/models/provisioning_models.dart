import 'package:freezed_annotation/freezed_annotation.dart';

part 'provisioning_models.freezed.dart';
part 'provisioning_models.g.dart';

/// Provisioning event payload matching SendRequestSchema on sender-worker.
@Freezed(fromJson: false, toJson: false)
abstract class ProvisioningEvent with _$ProvisioningEvent {
  const ProvisioningEvent._();

  const factory ProvisioningEvent({
    required String action,
    required String name,
    required String email,
    @Default('starter') String tier,
    String? orgName,
  }) = _ProvisioningEvent;

  Map<String, dynamic> toJson() => {
        'action': action,
        'name': name,
        'email': email,
        'tier': tier,
        if (orgName != null) 'org_name': orgName,
      };
}

/// Organization from bootstrap response.
@Freezed(toJson: false)
abstract class BootstrapOrg with _$BootstrapOrg {
  const factory BootstrapOrg({
    @Default('') String id,
    @Default('') String name,
    @Default('') String role,
    @JsonKey(name: 'plan_key') @Default('') String planKey,
    @JsonKey(name: 'billing_status') @Default('') String billingStatus,
  }) = _BootstrapOrg;

  factory BootstrapOrg.fromJson(Map<String, dynamic> json) =>
      _$BootstrapOrgFromJson(json);
}

/// Feature entitlements from bootstrap response.
@Freezed(toJson: false)
abstract class BootstrapEntitlements with _$BootstrapEntitlements {
  const factory BootstrapEntitlements({
    @JsonKey(name: 'usage_dashboard') @Default(false) bool usageDashboard,
    @Default(false) bool alerts,
    @JsonKey(name: 'compliance_summary') @Default(false) bool complianceSummary,
    @JsonKey(name: 'monthly_units') @Default(0) int monthlyUnits,
    @JsonKey(name: 'requests_per_minute') @Default(0) int requestsPerMinute,
  }) = _BootstrapEntitlements;

  factory BootstrapEntitlements.fromJson(Map<String, dynamic> json) =>
      _$BootstrapEntitlementsFromJson(json);
}

/// Current-period usage snapshot from bootstrap response.
///
/// Deliberately does not carry a per-minute figure. `current_minute_remaining` used to be
/// declared here as a non-nullable `int` defaulting to `0`, while the server always sent
/// `null` — the value lives in the quota Durable Object and bootstrap cannot see it. The
/// generated decoder turned that `null` into `0`, so the field reported "none remaining"
/// for "unknown", and nothing ever displayed it. The authoritative source is
/// `GET /v1/orgs/:id/quota/status` via [QuotaStatusData], which carries real
/// minuteLimit/minuteUsed values.
///
/// [unavailable] is set by the server when the usage aggregate could not be read, so a
/// failed query is distinguishable from a genuinely new account rather than both showing 0.
@Freezed(toJson: false)
abstract class BootstrapUsageSnapshot with _$BootstrapUsageSnapshot {
  const factory BootstrapUsageSnapshot({
    @JsonKey(name: 'month_to_date_units') @Default(0) int monthToDateUnits,
    @JsonKey(name: 'unavailable') @Default(false) bool unavailable,
  }) = _BootstrapUsageSnapshot;

  factory BootstrapUsageSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BootstrapUsageSnapshotFromJson(json);
}

/// Arguments passed to CheckoutPage.
@Freezed(fromJson: false, toJson: false)
abstract class CheckoutArgs with _$CheckoutArgs {
  const factory CheckoutArgs({
    required String email,
    required String tier,
  }) = _CheckoutArgs;
}
