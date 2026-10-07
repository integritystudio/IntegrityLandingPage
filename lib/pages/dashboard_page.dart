import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/auth0_service.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
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

  /// Org to select once the list loads. Set when returning from a sub-page, so
  /// the user lands back on the org they were viewing rather than the first one.
  final String? initialOrgId;

  const DashboardArgs({required this.jwt, this.initialOrgId});
}

/// The org to show first: [preferredOrgId] when the list still contains it,
/// else the first org, or null for an empty list.
OrgSummary? pickActiveOrg(List<OrgSummary> orgs, String? preferredOrgId) {
  if (orgs.isEmpty) return null;
  return orgs.firstWhere(
    (org) => org.orgId == preferredOrgId,
    orElse: () => orgs.first,
  );
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

  /// The caller's email-domain team org, set only when they are not yet in it (CR54).
  TeamAvailable? _joinableTeam;
  bool _isJoiningTeam = false;
  String? _joinTeamError;

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
          _activeOrg = pickActiveOrg(response.orgs, widget.args.initialOrgId);
          _isLoading = false;
        });
        _fetchTeamStatus();
      case OrgListError():
        setState(() {
          _errorMessage = response.error;
          _isLoading = false;
        });
    }
  }

  Future<void> _fetchTeamStatus() async {
    final status = await DashboardService.fetchTeamStatus(jwt: widget.args.jwt);
    if (!mounted) return;
    setState(() {
      _joinableTeam = switch (status) {
        TeamAvailable(member: false) => status,
        _ => null,
      };
    });
  }

  /// Joins the team org, then reloads the org list with the team selected.
  Future<void> _joinTeam() async {
    setState(() {
      _isJoiningTeam = true;
      _joinTeamError = null;
    });

    final response = await DashboardService.joinTeam(jwt: widget.args.jwt);
    if (!mounted) return;

    switch (response) {
      case JoinTeamSuccess():
        setState(() {
          _isJoiningTeam = false;
          _joinableTeam = null;
        });
        await _reloadOrgsSelecting(response.teamId);
      case JoinTeamError():
        setState(() {
          _isJoiningTeam = false;
          _joinTeamError = response.error;
        });
    }
  }

  Future<void> _reloadOrgsSelecting(String orgId) async {
    final response = await DashboardService.fetchOrgList(jwt: widget.args.jwt);
    if (!mounted) return;
    if (response case OrgListSuccess(:final orgs)) {
      setState(() {
        _orgs = orgs;
        _activeOrg = pickActiveOrg(orgs, orgId);
      });
    }
  }

  Widget _buildJoinTeamCard(TeamAvailable team) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.users, color: AppColors.blue500, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Join your team',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your colleagues already use the ${team.teamName} organization. '
            'Join it as a member; your personal organization stays as it is.',
            style: AppTypography.bodySM.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          GradientButton(
            text: 'Join ${team.teamName}',
            onPressed: _isJoiningTeam ? null : _joinTeam,
            isLoading: _isJoiningTeam,
          ),
          if (_joinTeamError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _joinTeamError!,
              style: AppTypography.bodySM.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateTo(String route, Object extra) {
    context.go(route, extra: extra);
  }

  /// Opens the observability dashboard, a separate Auth0 app that signs the user
  /// in itself: no token is handed over (CR04). A launcher failure is reported,
  /// not thrown, as on the provision page.
  Future<void> _openObservability() async {
    try {
      await launchUrl(Uri.parse(ExternalUrls.dashboardApp));
    } catch (e, stackTrace) {
      ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: 'dashboard._openObservability',
        extra: {'url': ExternalUrls.dashboardApp},
      );
    }
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
      actions: [
        // Ends the Auth0 session too, so integritystudio.dev is signed out as well.
        TextButton.icon(
          onPressed: Auth0Service.logout,
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: const Text('Sign out'),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
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
          if (_joinableTeam case final team?) ...[
            _buildJoinTeamCard(team),
            const SizedBox(height: AppSpacing.xl),
          ],
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
              _navigateTo(
                Routes.usageSummary,
                UsageSummaryArgs(
                  orgId: current.orgId,
                  orgName: current.name,
                  jwt: widget.args.jwt,
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
          const SizedBox(height: AppSpacing.md),
          _buildNavCard(
            label: 'Observability',
            icon: LucideIcons.activity,
            description: 'View your traces, logs, metrics, and evaluations',
            onTap: _openObservability,
          ),
        ],
      ],
    );
  }
}
