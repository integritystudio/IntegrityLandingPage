import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
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
        // Success icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success.withValues(alpha: 0.2),
                AppColors.blue500.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            LucideIcons.checkCircle2,
            color: AppColors.success,
            size: 40,
          ),
        ),
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
          'Your Google account has been connected successfully. You can now close this window or continue to your dashboard.',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
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
              text: 'Go to Dashboard',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, bool isMobile) {
    final errorMessage = errorDescription ??
        'An error occurred during authentication. Please try again.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Error icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.error.withValues(alpha: 0.2),
                AppColors.error.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            LucideIcons.xCircle,
            color: AppColors.error,
            size: 40,
          ),
        ),
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
        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Error code: $error',
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
        // Loading indicator
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blue500.withValues(alpha: 0.2),
                AppColors.purple500.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: AppColors.blue500.withValues(alpha: 0.3),
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue400),
              ),
            ),
          ),
        ),
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
