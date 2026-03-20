import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/provisioning_service.dart';
import '../theme/theme.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

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
  static const _genericErrorMessage = 'Something went wrong. Please try again.';

  bool _isLoading = false;
  String? _errorMessage;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('provision');
  }

  /// Returns a sanitized user-facing error message.
  ///
  /// Passes through short single-line messages that are likely user-friendly.
  /// Falls back to a generic message for verbose or multi-line server errors.
  static String _sanitizeError(String raw) {
    if (raw.length > 120 || raw.contains('\n') || raw.contains(' at ')) {
      return _genericErrorMessage;
    }
    return raw;
  }

  Future<void> _provisionApiKey() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final event = ProvisioningEvent(
      userId: widget.auth.email.toLowerCase().trim(),
      action: 'provision',
      sentAt: DateTime.now().toUtc(),
    );

    final response = await ProvisioningService.sendEvent(
      event,
      jwt: widget.auth.jwt,
    );

    if (!mounted) return;

    switch (response) {
      case ProvisioningSuccess():
        setState(() {
          _apiKey = response.apiKey;
          _isLoading = false;
        });
        AnalyticsService.trackEvent(eventName: 'api_key_provisioned');
      case ProvisioningError():
        setState(() {
          _errorMessage = _sanitizeError(response.error);
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
                  decoration: BoxDecoration(
                    color: AppColors.gray800,
                    border: Border.all(color: AppColors.gray700),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        widget.auth.email,
                        style: AppTypography.bodySM.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error message
                if (_errorMessage != null) ...[
                  Alert.error(message: _errorMessage!),
                  const SizedBox(height: AppSpacing.md),
                ],

                // API Key display
                if (_apiKey != null) ...[
                  Text(
                    'Your API Key',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.gray300,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    _apiKey!,
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.blue400,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
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
