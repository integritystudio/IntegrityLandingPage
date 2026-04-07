import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/cards.dart';
import '../widgets/common/dashboard_scaffold.dart';
import '../widgets/common/error_card.dart';
import 'billing_status_page.dart';
import 'entitlements_page.dart';
import 'quota_status_page.dart';
import 'usage_summary_page.dart';

/// Arguments passed to DashboardPage via GoRouter state.extra.
class DashboardArgs {
  final String jwt;

  const DashboardArgs({required this.jwt});
}

/// Hub page: fetches the authenticated user's org list, provides an org
/// switcher dropdown, and navigates to billing/usage/quota/entitlements.
class DashboardPage extends StatefulWidget {
  final DashboardArgs args;
  final VoidCallback? onBack;

  const DashboardPage({
    super.key,
    required this.args,
    this.onBack,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<OrgSummary> _orgs = const [];
  OrgSummary? _activeOrg;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('dashboard');
    _fetchOrgs();
  }

  Future<void> _fetchOrgs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await DashboardService.fetchOrgList(jwt: widget.args.jwt);

    if (!mounted) return;

    switch (response) {
      case OrgListSuccess():
        setState(() {
          _orgs = response.orgs;
          _activeOrg = response.orgs.isNotEmpty ? response.orgs.first : null;
          _isLoading = false;
        });
      case OrgListError():
        setState(() {
          _errorMessage = response.error;
          _isLoading = false;
        });
    }
  }

  void _navigateTo(String route, Object extra) {
    context.go(route, extra: extra);
  }

  Widget _buildOrgSwitcher() {
    return DropdownButton<String>(
      value: _activeOrg?.orgId,
      dropdownColor: AppColors.backgroundSecondary,
      style: AppTypography.bodyMD.copyWith(color: AppColors.textPrimary),
      underline: const SizedBox.shrink(),
      icon: const Icon(LucideIcons.chevronDown, size: 16),
      items: _orgs
          .map(
            (org) => DropdownMenuItem<String>(
              value: org.orgId,
              child: Text(org.name),
            ),
          )
          .toList(),
      onChanged: (orgId) {
        if (orgId == null) return;
        final selected = _orgs.firstWhere((o) => o.orgId == orgId);
        setState(() => _activeOrg = selected);
      },
    );
  }

  Widget _buildNavCard({
    required String label,
    required IconData icon,
    required String description,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      enableHover: true,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue500, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySM
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = _activeOrg;

    return DashboardScaffold(
      title: 'Dashboard',
      titleStyle: AppTypography.headingMD,
      onBack: widget.onBack,
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_errorMessage != null)
          ErrorCard(message: _errorMessage!, onRetry: _fetchOrgs)
        else if (_orgs.isEmpty)
          Text(
            'No organizations found.',
            style: AppTypography.bodyMD
                .copyWith(color: AppColors.textSecondary),
          )
        else ...[
          if (_orgs.length > 1) ...[
            Text(
              'Organization',
              style: AppTypography.bodySM
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildOrgSwitcher(),
            const SizedBox(height: AppSpacing.xl),
          ] else ...[
            Text(
              org?.name ?? '',
              style: AppTypography.bodyMD
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          _buildNavCard(
            label: 'Billing',
            icon: LucideIcons.creditCard,
            description: 'Plan, billing status, renewal date',
            onTap: () {
              final current = _activeOrg;
              if (current == null) return;
              _navigateTo(
                Routes.billingStatus,
                BillingStatusArgs(
                  orgId: current.orgId,
                  jwt: widget.args.jwt,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildNavCard(
            label: 'Usage',
            icon: LucideIcons.barChart2,
            description: 'Monthly usage summary by metric',
            onTap: () {
              final current = _activeOrg;
              if (current == null) return;
              // monthlyUnitsQuota: quota reference line; 0 = disabled
              // until per-org quota is loaded via QuotaStatusPage.
              _navigateTo(
                Routes.usageSummary,
                UsageSummaryArgs(
                  orgId: current.orgId,
                  orgName: current.name,
                  jwt: widget.args.jwt,
                  monthlyUnitsQuota: 0,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildNavCard(
            label: 'Quota',
            icon: LucideIcons.gauge,
            description: 'Minute burst and monthly quota limits',
            onTap: () {
              final current = _activeOrg;
              if (current == null) return;
              _navigateTo(
                Routes.quotaStatus,
                QuotaStatusArgs(
                  orgId: current.orgId,
                  orgName: current.name,
                  jwt: widget.args.jwt,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _buildNavCard(
            label: 'Entitlements',
            icon: LucideIcons.shieldCheck,
            description: 'Feature flags for your plan',
            onTap: () {
              final current = _activeOrg;
              if (current == null) return;
              _navigateTo(
                Routes.entitlements,
                EntitlementsArgs(
                  orgId: current.orgId,
                  orgName: current.name,
                  jwt: widget.args.jwt,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
