import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../services/oauth_service.dart';
import '../utils/security_utils.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/status_icon.dart';
import '../widgets/navigation/shared_app_bar.dart';
import '../widgets/sections/footer_section.dart';

/// Seconds to wait for the backend to complete the token exchange before
/// surfacing a timeout error to the user.
const int _kExchangeTimeoutSeconds = 15;

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

  /// True only when the backend has confirmed successful token exchange.
  /// Receiving a [code] alone does NOT constitute successful authentication.
  final bool success;

  const OAuthCallbackPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
    this.code,
    this.state,
    this.error,
    this.errorDescription,
    this.success = false,
  });

  @override
  State<OAuthCallbackPage> createState() => _OAuthCallbackPageState();
}

class _OAuthCallbackPageState extends State<OAuthCallbackPage> {
  final ScrollController _scrollController = ScrollController();

  /// Result of CSRF state validation; null = no code/state received yet.
  bool? _stateValid;

  /// True when the token-exchange confirmation window has expired.
  bool _exchangeTimedOut = false;

  Timer? _exchangeTimer;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('oauth_callback');
    _validateAndLog();
    _startExchangeTimerIfNeeded();
  }

  /// Start a watchdog timer when an authorization code has been received and
  /// the CSRF state check passed.  If the backend does not confirm a
  /// successful exchange within [_kExchangeTimeoutSeconds] seconds, transition
  /// to an error state instead of spinning forever.
  void _startExchangeTimerIfNeeded() {
    if (widget.code == null || widget.success) return;
    _exchangeTimer = Timer(
      Duration(seconds: _kExchangeTimeoutSeconds),
      () {
        if (mounted && !widget.success) {
          setState(() => _exchangeTimedOut = true);
          AnalyticsService.trackEvent(eventName: 'oauth_exchange_timeout');
        }
      },
    );
  }

  /// Validate CSRF state (RFC 6749 §10.12) then log callback events.
  ///
  /// When an authorization code arrives, the returned [state] is compared
  /// against the value stored in sessionStorage by [OAuthService]. A mismatch
  /// indicates a CSRF attack and must be treated as an error.
  void _validateAndLog() {
    if (widget.error != null) {
      // Error case: validate state if present, log regardless.
      if (widget.state != null) {
        _stateValid = OAuthService.validateCallback(returnedState: widget.state!);
        if (_stateValid == false) {
          ErrorTrackingService.captureMessage(
            'OAuth CSRF: state mismatch on error callback',
            severity: ErrorSeverity.error,
            extra: {'error': widget.error},
          );
        }
      }

      ErrorTrackingService.captureMessage(
        'OAuth callback error: ${widget.error}',
        severity: ErrorSeverity.warning,
        extra: {
          'error': widget.error,
          'error_description': widget.errorDescription,
          'has_state': widget.state != null,
          'has_code': widget.code != null,
          'state_valid': _stateValid,
        },
      );

      AnalyticsService.trackEvent(
        eventName: 'oauth_callback_error',
        parameters: {
          'error_type': widget.error ?? 'unknown',
        },
      );
    } else if (widget.code != null && widget.state != null) {
      // Authorization code received — validate CSRF state before proceeding.
      _stateValid = OAuthService.validateCallback(returnedState: widget.state!);

      if (_stateValid == false) {
        // State mismatch: potential CSRF attack. Log and refuse to exchange code.
        ErrorTrackingService.captureMessage(
          'OAuth CSRF: state mismatch on code callback — rejecting',
          severity: ErrorSeverity.error,
          extra: {
            'has_code': true,
            'state_length': widget.state!.length,
          },
        );
        AnalyticsService.trackEvent(eventName: 'oauth_csrf_rejected');
      } else {
        // State valid — safe to exchange code for tokens (backend handles this).
        AnalyticsService.trackEvent(
          eventName: 'oauth_callback_code_received',
          parameters: {'state_valid': true},
        );
      }
    } else if (widget.success) {
      // Track confirmed authentication (backend completed token exchange).
      AnalyticsService.trackEvent(
        eventName: 'oauth_callback_success',
        parameters: {'has_state': widget.state != null},
      );
    }
  }

  @override
  void dispose() {
    _exchangeTimer?.cancel();
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
                success: widget.success,
                stateValid: _stateValid,
                exchangeTimedOut: _exchangeTimedOut,
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

  /// True only when the backend has confirmed successful token exchange.
  final bool success;

  /// Null = no code/state received; true = CSRF state matched; false = mismatch.
  final bool? stateValid;

  /// True when the watchdog timer fired before the exchange was confirmed.
  final bool exchangeTimedOut;

  const _OAuthCallbackContent({
    this.code,
    this.state,
    this.error,
    this.errorDescription,
    this.success = false,
    this.stateValid,
    this.exchangeTimedOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

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
          child: _buildBody(context, isMobile),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isMobile) {
    if (error != null) return _buildErrorState(context, isMobile);
    if (success) return _buildSuccessState(context, isMobile);
    // CSRF check: code received but state is invalid — reject.
    if (code != null && stateValid == false) {
      return _buildCsrfErrorState(context, isMobile);
    }
    // Watchdog: exchange confirmation never arrived — surface an error.
    if (code != null && exchangeTimedOut) {
      return _buildExchangeTimeoutState(context, isMobile);
    }
    // Auth code received but token exchange not yet confirmed — do not show success.
    if (code != null) return _buildPendingExchangeState(context, isMobile);
    return _buildProcessingState(context, isMobile);
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

  /// Shows when auth code is received but token exchange is not yet confirmed.
  ///
  /// Receiving an authorization code is the *first* step of OAuth — the code
  /// must still be exchanged for tokens by the backend before authentication
  /// is complete. Do not display success UI until [success] is true.
  Widget _buildPendingExchangeState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.processing(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Completing Sign-In',
          style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
              .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Authorization code received. Completing sign-in with our servers — this will only take a moment.',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Shown when the returned OAuth state does not match sessionStorage — CSRF.
  Widget _buildCsrfErrorState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.error(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Authentication Failed',
          style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
              .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Security check failed: the request state did not match. '
          'This may indicate a CSRF attack. Please start the sign-in process again.',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
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
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      ],
    );
  }

  /// Shown when the token-exchange watchdog expires before the backend confirms.
  Widget _buildExchangeTimeoutState(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StatusIcon.error(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Sign-In Timed Out',
          style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL)
              .copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'The sign-in process took too long to complete. '
          'Please try again — if the problem persists, contact support.',
          style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
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
              onPressed: () => context.go('/login'),
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
