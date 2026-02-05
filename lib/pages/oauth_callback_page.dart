import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../utils/security_utils.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/status_icon.dart';
import '../widgets/navigation/shared_app_bar.dart';
import '../widgets/sections/footer_section.dart';

/// OAuth callback page for handling Google OAuth redirects.
///
/// Extracts authorization code and state from query parameters
/// and displays appropriate status to the user.
class OAuthCallbackPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;
  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;

  const OAuthCallbackPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
    this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  @override
  State<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('oauth_callback');
    _logOAuthCallback();
  }

  /// Log OAuth callback events to Sentry and analytics for monitoring.
  void _logOAuthCallback() {
    if (widget.error != null) {
      // Log OAuth error to Sentry for monitoring
      ErrorTrackingService.captureMessage(
        'OAuth callback error: ${widget.error}',
        severity: ErrorSeverity.warning,
        extra: {
          'error': widget.error,
          'error_description': widget.errorDescription,
          'has_state': widget.state != null,
          'has_code': widget.code != null,
        },
      );

      // Track for analytics
      AnalyticsService.trackEvent(
        eventName: 'oauth_callback_error',
        parameters: {
          'error_type': widget.error ?? 'unknown',
        },
      );
    } else if (widget.code != null) {
      // Track successful OAuth callback
      AnalyticsService.trackEvent(
        eventName: 'oauth_callback_success',
        parameters: {
          'has_state': widget.state != null,
        },
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SharedAppBar.subPage(onBack: widget.onBack),
            SliverToBoxAdapter(
              child: _OAuthCallbackContent(
                code: widget.code,
                state: widget.state,
                error: widget.error,
                errorDescription: widget.errorDescription,
              ),
            ),
            SliverToBoxAdapter(
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OAuthCallbackContent extends StatelessWidget {
  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;

  const _OAuthCallbackContent({
    this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    // Determine status based on query parameters
    final hasError = error != null;
    final hasCode = code != null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: isMobile ? 48 : 80,
      ),
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: hasError
              ? _buildErrorState(context, isMobile)
              : hasCode
                  ? _buildSuccessState(context, isMobile)
                  : _buildProcessingState(context, isMobile),
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.success(),
        const SizedBox(height: AppSpacing.xl),

        // Heading
        Text(
          'Authentication Successful',
          style:
              (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
                  .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        // Message
        Text(
          'Your Google account has been connected successfully. You can now close this window or continue to the site.',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Buttons - Fixed Issue #13: Removed misleading "Go to Dashboard" button
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            OutlineButton(
              text: 'Back to Home',
              onPressed: () => context.go('/'),
            ),
            GradientButton(
              text: 'Continue',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, bool isMobile) {
    // Sanitize all external input to prevent XSS attacks
    final sanitizedError = SecurityUtils.sanitizeErrorCode(error);
    final sanitizedDescription = errorDescription != null
        ? SecurityUtils.sanitizeUserInput(errorDescription)
        : null;

    final errorMessage = sanitizedDescription ??
        'An error occurred during authentication. Please try again.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.error(),
        const SizedBox(height: AppSpacing.xl),

        // Heading
        Text(
          'Authentication Failed',
          style:
              (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
                  .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        // Error message
        Text(
          errorMessage,
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
        if (sanitizedError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Error code: $sanitizedError',
            style: AppTypography.bodySM.copyWith(color: AppColors.gray500),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        // Buttons
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            OutlineButton(
              text: 'Back to Home',
              onPressed: () => context.go('/'),
            ),
            GradientButton(
              text: 'Try Again',
              onPressed: () => context.go('/demo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessingState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.processing(),
        const SizedBox(height: AppSpacing.xl),

        // Heading
        Text(
          'Processing Authentication',
          style:
              (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
                  .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        // Message
        Text(
          'Please wait while we complete the authentication process...',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
