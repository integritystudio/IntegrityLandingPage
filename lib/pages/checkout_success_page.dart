import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/analytics.dart';
import '../theme/theme.dart';
import '../utils/security_utils.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/gradient_page_shell.dart';

/// Post-payment confirmation page.
///
/// Shown after Stripe redirects back on successful checkout. Prompts the user
/// to sign in with their registered email to provision their API key.
class CheckoutSuccessPage extends StatefulWidget {
  final String email;
  final String tier;
  final VoidCallback? onBack;

  const CheckoutSuccessPage({
    super.key,
    required this.email,
    required this.tier,
    this.onBack,
  });

  @override
  State<CheckoutSuccessPage> createState() => _CheckoutSuccessPageState();
}

class _CheckoutSuccessPageState extends State<CheckoutSuccessPage> {
  bool _pageViewTracked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageViewTracked) {
      _pageViewTracked = true;
      AnalyticsService.trackPageView('checkout_success');
      AnalyticsService.trackEvent(eventName: 'checkout_completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sanitizedEmail = SecurityUtils.sanitizeUserInput(widget.email);
    final sanitizedTier = SecurityUtils.sanitizeUserInput(widget.tier);

    return GradientPageShell(
      onBack: widget.onBack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.success,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Payment received',
            style: AppTypography.headingLG.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your $sanitizedTier subscription is active. Sign in with $sanitizedEmail to provision your API key.',
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.gray300,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          GradientButton(
            onPressed: () => context.go('/login'),
            text: 'Sign In to Activate',
          ),
        ],
      ),
    );
  }
}
