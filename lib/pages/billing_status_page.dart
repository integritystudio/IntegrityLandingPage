import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/dashboard_card.dart';
import '../widgets/common/dashboard_scaffold.dart';
import '../widgets/common/error_card.dart';
import '../widgets/common/status_badge.dart';

/// Arguments passed to BillingStatusPage via GoRouter state.extra.
class BillingStatusArgs {
  final String orgId;
  final String jwt;

  const BillingStatusArgs({required this.orgId, required this.jwt});
}

/// Dashboard page showing an organization's current plan, billing status,
/// and next renewal date.
class BillingStatusPage extends StatefulWidget {
  final BillingStatusArgs args;
  final VoidCallback? onBack;

  const BillingStatusPage({
    super.key,
    required this.args,
    this.onBack,
  });

  @override
  State<BillingStatusPage> createState() => _BillingStatusPageState();
}

class _BillingStatusPageState extends State<BillingStatusPage> {
  bool _isLoading = false;
  bool _isPortalLoading = false;
  String? _errorMessage;
  BillingStatusData? _billingStatus;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('billing_status');
    _fetchBillingStatus();
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${_monthNames[local.month - 1]} ${local.day}, ${local.year}';
  }

  Future<void> _fetchBillingStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await DashboardService.fetchBillingStatus(
      orgId: widget.args.orgId,
      jwt: widget.args.jwt,
    );

    if (!mounted) return;

    switch (response) {
      case BillingStatusSuccess():
        setState(() {
          _billingStatus = response.data;
          _isLoading = false;
        });
      case BillingStatusError():
        setState(() {
          _errorMessage = response.error;
          _isLoading = false;
        });
    }
  }

  Future<void> _openBillingPortal() =>
      _openStripeUrl(() => DashboardService.fetchBillingPortalUrl(
            orgId: widget.args.orgId,
            jwt: widget.args.jwt,
          ));

  /// Starts Stripe Checkout for the org's current plan, giving an org with no
  /// Stripe customer one. The plan comes from the loaded billing status rather
  /// than a hardcoded tier, and the org id from the route — the sender-worker's
  /// email-based checkout resolves a *different* org for anyone in more than one.
  ///
  /// There is no plan picker here on purpose. Once a subscription exists, Stripe's
  /// own portal handles upgrades and downgrades (`subscription_update` is enabled
  /// on the live portal configuration), so this only has to get the org over the
  /// line from "no billing account" to "has one".
  Future<void> _startCheckout() {
    final plan = _billingStatus?.planKey ?? '';
    return _openStripeUrl(() => DashboardService.createCheckoutSession(
          orgId: widget.args.orgId,
          jwt: widget.args.jwt,
          plan: plan,
        ));
  }

  /// Both billing CTAs resolve to a Stripe-hosted https URL and open it, sharing
  /// the loading flag, the scheme check, and the error surface.
  Future<void> _openStripeUrl(
    Future<BillingPortalResponse> Function() request,
  ) async {
    setState(() => _isPortalLoading = true);

    final response = await request();

    if (!mounted) return;
    setState(() => _isPortalLoading = false);

    switch (response) {
      case BillingPortalSuccess():
        final uri = Uri.tryParse(response.url);
        if (uri != null && uri.scheme == 'https') {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid billing portal URL.')),
          );
        }
      case BillingPortalError():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Billing Status',
      subtitle: 'Current plan and renewal information',
      onBack: widget.onBack,
      children: [
        if (_errorMessage != null)
          ErrorCard(
            message: _errorMessage!,
            onRetry: _fetchBillingStatus,
          )
        else
          _BillingCard(
            billingStatus: _billingStatus,
            isLoading: _isLoading,
            isPortalLoading: _isPortalLoading,
            onRefresh: _fetchBillingStatus,
            onManageBilling: _openBillingPortal,
            onStartCheckout: _startCheckout,
            renewalDateLabel: _billingStatus?.nextRenewalDate != null
                ? _formatDate(_billingStatus!.nextRenewalDate!)
                : null,
          ),
      ],
    );
  }
}

Color _statusColor(String status) {
  assert(
    status == 'active' || status == 'past_due' || status == 'inactive' || status == 'canceled',
    'Unknown billing status: $status',
  );
  return switch (status) {
    'active' => AppColors.success,
    'past_due' => AppColors.warning,
    _ => AppColors.error,
  };
}

String _statusLabel(String status) {
  assert(
    status == 'active' || status == 'past_due' || status == 'inactive' || status == 'canceled',
    'Unknown billing status: $status',
  );
  return switch (status) {
    'active' => 'Active',
    'past_due' => 'Past Due',
    _ => 'Inactive',
  };
}

class _BillingCard extends StatelessWidget {
  final BillingStatusData? billingStatus;
  final bool isLoading;
  final bool isPortalLoading;
  final VoidCallback onRefresh;
  final VoidCallback onManageBilling;
  final VoidCallback onStartCheckout;
  final String? renewalDateLabel;

  const _BillingCard({
    required this.billingStatus,
    required this.isLoading,
    required this.isPortalLoading,
    required this.onRefresh,
    required this.onManageBilling,
    required this.onStartCheckout,
    this.renewalDateLabel,
  });

  /// Enterprise is billed by contract and has no Stripe price, so self-serve
  /// checkout would fail server-side. Such an org legitimately has no Stripe
  /// customer and should be offered neither CTA.
  bool get _isContractBilled =>
      billingStatus?.planKey == SignupTiers.enterprise;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: billingStatus?.planDisplayName.isNotEmpty == true
          ? billingStatus!.planDisplayName
          : 'Plan',
      isLoading: isLoading,
      trailing: billingStatus != null
          ? StatusBadge(
              label: _statusLabel(billingStatus!.billingStatus),
              color: _statusColor(billingStatus!.billingStatus),
            )
          : null,
      children: [
        if (billingStatus != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: LucideIcons.tag,
            label: 'Plan',
            value: billingStatus!.planKey.isNotEmpty
                ? billingStatus!.planKey
                : '—',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: LucideIcons.calendar,
            label: billingStatus!.cancelAtPeriodEnd
                ? 'Cancels on'
                : 'Renews on',
            value: renewalDateLabel ?? '—',
          ),
        ],
        if (billingStatus != null && !billingStatus!.hasBillingAccount) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _isContractBilled
                ? 'This organization is billed by contract. Contact support to make changes.'
                : 'No billing account yet. Choose a plan to set one up.',
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                onPressed: isLoading ? null : onRefresh,
                text: 'Refresh',
                icon: LucideIcons.rotateCw,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Until an org has a Stripe customer there is no portal session to
            // create and POST /billing-portal answers 404, so the CTA switches to
            // checkout rather than offering a button that cannot work. Contract-
            // billed orgs get neither.
            Expanded(
              child: _isContractBilled
                  ? const SizedBox.shrink()
                  : GradientButton(
                      onPressed: (isLoading || isPortalLoading)
                          ? null
                          : (billingStatus?.hasBillingAccount ?? false)
                              ? onManageBilling
                              : onStartCheckout,
                      isLoading: isPortalLoading,
                      text: (billingStatus?.hasBillingAccount ?? false)
                          ? 'Manage Billing'
                          : 'Choose a plan',
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.gray400),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
        ),
        Text(
          value,
          style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
        ),
      ],
    );
  }
}
