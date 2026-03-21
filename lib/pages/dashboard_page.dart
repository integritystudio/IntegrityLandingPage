import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/cards.dart';
import '../widgets/common/containers.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final org = _activeOrg;

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
                  'Dashboard',
                  style: AppTypography.headingMD
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  _ErrorCard(message: _errorMessage!, onRetry: _fetchOrgs)
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
                    onTap: () => _navigateTo(
                      Routes.billingStatus,
                      BillingStatusArgs(
                        orgId: org!.orgId,
                        jwt: widget.args.jwt,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildNavCard(
                    label: 'Usage',
                    icon: LucideIcons.barChart2,
                    description: 'Monthly usage summary by metric',
                    onTap: () => _navigateTo(
                      Routes.usageSummary,
                      UsageSummaryArgs(
                        orgId: org!.orgId,
                        orgName: org.name,
                        jwt: widget.args.jwt,
                        monthlyUnitsQuota: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildNavCard(
                    label: 'Quota',
                    icon: LucideIcons.gauge,
                    description: 'Minute burst and monthly quota limits',
                    onTap: () => _navigateTo(
                      Routes.quotaStatus,
                      QuotaStatusArgs(
                        orgId: org!.orgId,
                        orgName: org.name,
                        jwt: widget.args.jwt,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildNavCard(
                    label: 'Entitlements',
                    icon: LucideIcons.shieldCheck,
                    description: 'Feature flags for your plan',
                    onTap: () => _navigateTo(
                      Routes.entitlements,
                      EntitlementsArgs(
                        orgId: org!.orgId,
                        orgName: org.name,
                        jwt: widget.args.jwt,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
          Text(
            message,
            style: AppTypography.bodyMD.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlineButton(text: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
