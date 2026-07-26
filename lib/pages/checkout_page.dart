import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/provisioning_service.dart';
import '../services/url_launcher.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';

/// Checkout redirect page.
///
/// Creates a Stripe checkout session via the sender-worker and redirects
/// the browser to the Stripe-hosted payment page. On error, navigates
/// to /request_failure.
class CheckoutPage extends StatefulWidget {
  final CheckoutArgs args;

  const CheckoutPage({super.key, required this.args});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  @override
  void initState() {
    super.initState();
    _redirectToCheckout();
  }

  Future<void> _redirectToCheckout() async {
    final result = await ProvisioningService.createCheckoutSession(
      email: widget.args.email,
      tier: widget.args.tier,
    );
    if (!mounted) return;
    switch (result) {
      case CheckoutSuccess():
        launchUrl(result.checkoutUrl);
      case CheckoutError():
        // Enterprise has custom pricing; no Stripe price may be configured yet.
        // The org is provisioned — route to success so the user isn't stranded.
        if (widget.args.tier.toLowerCase() == SignupTiers.enterprise) {
          context.go('/request_success');
        } else {
          context.go('/request_failure');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Redirecting to payment...',
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.gray300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
