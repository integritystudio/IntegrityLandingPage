import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: GradientBackground(
        child: Center(
          child: ResponsiveContainer(
            maxWidth: 600,
            additionalPadding:
                EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Billing Status',
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Current plan and renewal information',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null)
                  _ErrorCard(
                    message: _errorMessage!,
                    onRetry: _fetchBillingStatus,
                  )
                else
                  _BillingCard(
                    billingStatus: _billingStatus,
                    isLoading: _isLoading,
                    onRefresh: _fetchBillingStatus,
                    renewalDateLabel: _billingStatus?.nextRenewalDate != null
                        ? _formatDate(_billingStatus!.nextRenewalDate!)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
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
    status == 'active' ||
        status == 'past_due' ||
        status == 'suspended' ||
        status == 'inactive' ||
        status == 'canceled',
    'Unknown billing status: $status',
  );
  return switch (status) {
    'active' => 'Active',
    'past_due' => 'Past Due',
    'suspended' => 'Suspended',
    _ => 'Inactive',
  };
}

class _BillingCard extends StatelessWidget {
  final BillingStatusData? billingStatus;
  final bool isLoading;
  final VoidCallback onRefresh;
  final String? renewalDateLabel;

  const _BillingCard({
    required this.billingStatus,
    required this.isLoading,
    required this.onRefresh,
    this.renewalDateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        border: Border.all(color: AppColors.gray700),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
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
                _StatusBadge(
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
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      ),
      child: Text(
        label,
        style: AppTypography.bodySM.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        border: Border.all(color: AppColors.gray700),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySM.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: onRetry,
                  text: 'Try again',
                  icon: LucideIcons.rotateCw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
