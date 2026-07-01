import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
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

  Future<void> _openBillingPortal() async {
    setState(() => _isPortalLoading = true);

    final response = await DashboardService.fetchBillingPortalUrl(
      orgId: widget.args.orgId,
      jwt: widget.args.jwt,
    );

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
  final String? renewalDateLabel;

  const _BillingCard({
    required this.billingStatus,
    required this.isLoading,
    required this.isPortalLoading,
    required this.onRefresh,
    required this.onManageBilling,
    this.renewalDateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(borderColor: AppColors.gray700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                billingStatus?.planDisplayName.isNotEmpty == true
                    ? billingStatus!.planDisplayName
                    : 'Plan',
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (billingStatus != null)
                StatusBadge(
                  label: _statusLabel(billingStatus!.billingStatus),
                  color: _statusColor(billingStatus!.billingStatus),
                )
              else if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.blue500),
                  ),
                ),
            ],
          ),
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
              Expanded(
                child: GradientButton(
                  onPressed: (isLoading || isPortalLoading) ? null : onManageBilling,
                  isLoading: isPortalLoading,
                  text: 'Manage Billing',
                ),
              ),
            ],
          ),
        ],
      ),
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
