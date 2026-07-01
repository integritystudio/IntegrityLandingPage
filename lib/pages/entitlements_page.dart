import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/dashboard_scaffold.dart';
import '../widgets/common/error_card.dart';
import '../widgets/common/status_badge.dart';

/// Arguments passed to EntitlementsPage via GoRouter state.extra.
class EntitlementsArgs {
  final String orgId;
  final String orgName;
  final String jwt;

  const EntitlementsArgs({
    required this.orgId,
    required this.orgName,
    required this.jwt,
  });
}

/// Page displaying feature entitlements (enabled/disabled flags and limits)
/// for an organization's current plan.
class EntitlementsPage extends StatefulWidget {
  final EntitlementsArgs args;
  final VoidCallback? onBack;

  const EntitlementsPage({
    super.key,
    required this.args,
    this.onBack,
  });

  @override
  State<EntitlementsPage> createState() => _EntitlementsPageState();
}

class _EntitlementsPageState extends State<EntitlementsPage> {
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;
  EntitlementsData? _data;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('entitlements');
    _fetchEntitlements();
  }

  Future<void> _fetchEntitlements() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await DashboardService.fetchEntitlements(
        orgId: widget.args.orgId,
        jwt: widget.args.jwt,
      );

      if (!mounted) return;

      switch (response) {
        case EntitlementsSuccess():
          setState(() {
            _data = response.data;
            _isLoading = false;
          });
        case EntitlementsError():
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
      title: 'Entitlements',
      subtitle: widget.args.orgName.isNotEmpty
          ? widget.args.orgName
          : 'Feature flags and limits for your plan',
      onBack: widget.onBack,
      children: [
        if (_errorMessage != null)
          ErrorCard(
            message: _errorMessage!,
            onRetry: _fetchEntitlements,
          )
        else
          _EntitlementsCard(
            data: _data,
            isLoading: _isLoading,
            onRefresh: _fetchEntitlements,
          ),
      ],
    );
  }
}

class _EntitlementsCard extends StatelessWidget {
  final EntitlementsData? data;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _EntitlementsCard({
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
                'Feature Entitlements',
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
          if (data != null && data!.entitlements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _EntitlementsGrid(entitlements: data!.entitlements),
          ] else if (!isLoading) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'No entitlements found for this organization.',
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

class _EntitlementsGrid extends StatelessWidget {
  final Map<String, Object?> entitlements;

  const _EntitlementsGrid({required this.entitlements});

  String _formatKey(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final entries = entitlements.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EntitlementRow(
          feature: 'Feature',
          displayValue: 'Value',
          isHeader: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: _EntitlementRow(
              feature: _formatKey(entry.key),
              displayValue: _formatValue(entry.value),
              isEnabled: entry.value is bool ? entry.value as bool : null,
            ),
          ),
        ),
      ],
    );
  }

  String _formatValue(Object? value) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Enabled' : 'Disabled';
    return value.toString();
  }
}

class _EntitlementRow extends StatelessWidget {
  final String feature;
  final String displayValue;
  final bool isHeader;
  final bool? isEnabled;

  const _EntitlementRow({
    required this.feature,
    required this.displayValue,
    this.isHeader = false,
    this.isEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? AppTypography.bodySM.copyWith(
            color: AppColors.gray400,
            fontWeight: FontWeight.w500,
          )
        : AppTypography.bodySM.copyWith(color: AppColors.gray300);

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(feature, style: style),
        ),
        if (isHeader)
          Expanded(
            flex: 2,
            child: Text(displayValue, style: style, textAlign: TextAlign.right),
          )
        else if (isEnabled != null)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(
                label: displayValue,
                color: isEnabled! ? AppColors.success : AppColors.gray500,
              ),
            ),
          )
        else
          Expanded(
            flex: 2,
            child: Text(displayValue, style: style, textAlign: TextAlign.right),
          ),
      ],
    );
  }
}
