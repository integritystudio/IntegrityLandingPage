import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/dashboard_service.dart';
import '../services/provisioning_service.dart';
import '../services/url_launcher.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';

/// Checkout redirect page.
///
/// Resolves the signed-in user's active org through /bootstrap, creates a Stripe
/// checkout session for it through api-gateway's org-scoped route (owner or
/// billing_admin only), and redirects the browser to the Stripe-hosted payment
/// page. On error, navigates to /request_failure.
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
    final bootstrap = await ProvisioningService.bootstrap(jwt: widget.args.jwt);
    if (!mounted) return;
    if (bootstrap is! BootstrapSuccess) {
      _routeAfterFailure();
      return;
    }
    final result = await DashboardService.createCheckoutSession(
      orgId: bootstrap.activeOrg.id,
      jwt: widget.args.jwt,
      plan: widget.args.tier.toLowerCase(),
    );
    if (!mounted) return;
    switch (result) {
      case BillingPortalSuccess():
        launchUrl(result.url);
      case BillingPortalError():
        _routeAfterFailure();
    }
  }

  /// Enterprise has custom pricing; no Stripe price may be configured yet. The
  /// org is provisioned, so route to success and do not strand the user.
  void _routeAfterFailure() {
    if (widget.args.tier.toLowerCase() == SignupTiers.enterprise) {
      context.go('/request_success');
    } else {
      context.go('/request_failure');
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
