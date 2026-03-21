import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

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
  String? _errorMessage;
  QuotaStatusData? _data;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('quota_status');
    _fetchQuotaStatus();
  }

  Future<void> _fetchQuotaStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
                  'Quota Status',
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.args.orgName.isNotEmpty
                      ? widget.args.orgName
                      : 'Minute burst and monthly usage limits',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null)
                  _ErrorCard(
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
            ),
          ),
        ),
      ),
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
                'Quota Usage',
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue500),
                  ),
                ),
            ],
          ),
          if (data != null) ...[
            const SizedBox(height: AppSpacing.md),
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
              limit: data!.monthlyLimit ?? 0,
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
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int used;
  final int limit;

  const _QuotaRow({
    required this.icon,
    required this.label,
    required this.used,
    required this.limit,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = limit > 0;
    final ratio = hasLimit ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio >= 0.90
        ? AppColors.error
        : ratio >= 0.75
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
              '$label: $used${hasLimit ? ' / $limit' : ''}',
              style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
            ),
          ],
        ),
        if (hasLimit) ...[
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
