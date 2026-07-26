import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/auth_storage.dart';
import '../services/provisioning_service.dart';
import '../theme/theme.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';
import '../utils/security_utils.dart';
import '../widgets/common/copyable_code_field.dart';

/// Provision API key page.
///
/// Displays user email and a button to provision an API key using
/// the authenticated JWT. Shows the generated API key in a copyable
/// code block.
class ProvisionPage extends StatefulWidget {
  final AuthSuccess auth;
  final VoidCallback? onBack;

  const ProvisionPage({
    super.key,
    required this.auth,
    this.onBack,
  });

  @override
  State<ProvisionPage> createState() => _ProvisionPageState();
}

class _ProvisionPageState extends State<ProvisionPage> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _apiKey;
  BootstrapSuccess? _bootstrapResult;
  bool _pageViewTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageViewTracked) {
      _pageViewTracked = true;
      AnalyticsService.trackPageView('provision');
    }
  }

  Future<void> _provisionApiKey() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = widget.auth.email.toLowerCase().trim();
    final event = ProvisioningEvent(
      action: 'provision_api_key',
      name: email.split('@')[0],
      email: email,
    );

    final response = await ProvisioningService.sendEvent(
      event,
      jwt: widget.auth.jwt,
    );

    if (!mounted) return;

    switch (response) {
      case ProvisioningSuccess():
        AuthStorage.saveJwt(widget.auth.jwt);
        setState(() {
          _apiKey = response.apiKey;
          _isLoading = false;
        });
        AnalyticsService.trackEvent(eventName: 'api_key_provisioned');
        _loadBootstrap();
      case ProvisioningError():
        setState(() {
          _errorMessage = SecurityUtils.sanitizeServerError(response.error);
          _isLoading = false;
        });
    }
  }

  Future<void> _goToDashboard() async {
    // Use hash fragment so the token is not sent to the server, not stored
    // in browser history as a queryable entry, and not included in Referer.
    final encoded = Uri.encodeComponent(widget.auth.jwt);
    final uri = Uri.parse('${ExternalUrls.dashboardApp}#access_token=$encoded');
    await launchUrl(uri);
  }

  Future<void> _loadBootstrap() async {
    final result = await ProvisioningService.bootstrap(jwt: widget.auth.jwt);
    if (!mounted) return;
    switch (result) {
      case BootstrapSuccess():
        setState(() => _bootstrapResult = result);
      case BootstrapError():
        await ErrorTrackingService.captureException(
          Exception(result.error),
          context: 'ProvisionPage._loadBootstrap',
        );
    }
  }

  Widget _buildOrgContextCard(BootstrapSuccess bootstrap) {
    final org = bootstrap.activeOrg;
    final usage = bootstrap.usageSnapshot;
    final entitlements = bootstrap.entitlements;
    final orgName = SecurityUtils.sanitizeUserInput(org.name);
    final planKey = SecurityUtils.sanitizeUserInput(org.planKey);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card(borderColor: AppColors.gray700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  orgName,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gray700,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Text(
                  planKey,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
              ),
            ],
          ),
          if (entitlements.monthlyUnits > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${usage.monthToDateUnits} / ${entitlements.monthlyUnits} units this month',
              style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
            ),
          ],
        ],
      ),
    );
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
            maxWidth: 500,
            additionalPadding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Provision API Key',
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Get your API key to start using Integrity',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Email badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: AppDecorations.card(borderColor: AppColors.gray700),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        SecurityUtils.sanitizeUserInput(widget.auth.email),
                        style: AppTypography.bodySM.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error message
                if (_errorMessage != null)
                  Alert.error(message: _errorMessage!),

                // API Key display
                if (_apiKey != null) ...[
                  CopyableCodeField(
                    label: 'Your API Key',
                    code: _apiKey!,
                  ),
                  if (_bootstrapResult != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildOrgContextCard(_bootstrapResult!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  GradientButton(
                    onPressed: _goToDashboard,
                    text: 'Go to Dashboard',
                  ),
                ] else ...[
                  // Provision button
                  GradientButton(
                    onPressed: _isLoading ? null : _provisionApiKey,
                    isLoading: _isLoading,
                    text: 'Generate API Key',
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
