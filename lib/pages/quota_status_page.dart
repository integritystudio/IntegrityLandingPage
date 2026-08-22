import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/dashboard_card.dart';
import '../widgets/common/dashboard_scaffold.dart';
import '../widgets/common/error_card.dart';
import '../widgets/common/status_badge.dart';

/// Arguments passed to QuotaStatusPage via GoRouter state.extra.
class QuotaStatusArgs {
  final String orgId;
  final String orgName;
  final String jwt;

  const QuotaStatusArgs({
    required this.orgId,
    required this.orgName,
    required this.jwt,
  });
}

/// Page displaying per-org quota usage (minute burst + monthly limits).
class QuotaStatusPage extends StatefulWidget {
  final QuotaStatusArgs args;
  final VoidCallback? onBack;

  const QuotaStatusPage({
    super.key,
    required this.args,
    this.onBack,
  });

  @override
  State<QuotaStatusPage> createState() => _QuotaStatusPageState();
}

class _QuotaStatusPageState extends State<QuotaStatusPage> {
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;
  QuotaStatusData? _data;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('quota_status');
    _fetchQuotaStatus();
  }

  Future<void> _fetchQuotaStatus() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await DashboardService.fetchQuotaStatus(
        orgId: widget.args.orgId,
        jwt: widget.args.jwt,
      );

      if (!mounted) return;

      switch (response) {
        case QuotaStatusSuccess():
          setState(() {
            _data = response.data;
            _isLoading = false;
          });
        case QuotaStatusError():
          setState(() {
            _errorMessage = response.error;
            _isLoading = false;
          });
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Quota Status',
      subtitle: widget.args.orgName.isNotEmpty
          ? widget.args.orgName
          : 'Minute burst and monthly usage limits',
      onBack: widget.onBack,
      children: [
        if (_errorMessage != null)
          ErrorCard(
            message: _errorMessage!,
            onRetry: _fetchQuotaStatus,
          )
        else
          _QuotaCard(
            data: _data,
            isLoading: _isLoading,
            onRefresh: _fetchQuotaStatus,
          ),
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  final QuotaStatusData? data;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _QuotaCard({
    required this.data,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      title: 'Quota Usage',
      isLoading: isLoading,
      children: [
        if (data != null) ...[
          const SizedBox(height: AppSpacing.sm),
          if (data!.planKey != null) ...[
            StatusBadge(
              label: _formatPlanKey(data!.planKey!),
              color: AppColors.blue500,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _QuotaRow(
            icon: LucideIcons.zap,
            label: 'Minute',
            used: data!.minuteUsed,
            limit: data!.minuteLimit,
          ),
          const SizedBox(height: AppSpacing.sm),
          _QuotaRow(
            icon: LucideIcons.calendar,
            label: 'Monthly',
            used: data!.monthlyUsed,
            limit: data!.monthlyLimit,
          ),
        ] else if (!isLoading) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'No quota data available.',
            style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
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
    );
  }
}

class _QuotaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int used;

  /// Null means unlimited — show label only, no progress bar.
  final int? limit;

  const _QuotaRow({
    required this.icon,
    required this.label,
    required this.used,
    required this.limit,
  });

  String _limitLabel() {
    if (limit == null) return '$used (Unlimited)';
    return '$used / $limit';
  }

  @override
  Widget build(BuildContext context) {
    final ratio = limit != null && limit! > 0
        ? (used / limit!).clamp(0.0, 1.0)
        : 0.0;
    final barColor = ratio >= QuotaThresholds.danger
        ? AppColors.error
        : ratio >= QuotaThresholds.warning
            ? AppColors.warning
            : AppColors.blue500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.gray400),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$label: ${_limitLabel()}',
              style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
            ),
          ],
        ),
        if (limit != null) ...[
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.gray700,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatPlanKey(String key) => key
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
