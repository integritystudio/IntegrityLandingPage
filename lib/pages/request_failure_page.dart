import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../pages/status_result_page.dart';

/// Failure page shown when a contact form submission fails.
class RequestFailurePage extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const RequestFailurePage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    return StatusResultPage(
      analyticsPageName: 'request_failure',
      statusType: StatusIconType.warning,
      heading: 'Something Went Wrong',
      message: 'We couldn\'t send your message. This might be a temporary issue. Please try again or contact us directly.',
      sectionTitle: 'Alternative ways to reach us',
      items: [
        StatusResultItem(
          icon: LucideIcons.mail,
          label: 'Email us directly',
          value: CompanyInfo.email,
        ),
        StatusResultItem(
          icon: LucideIcons.refreshCw,
          label: 'Try submitting again',
          value: 'The form may work now',
        ),
      ],
      actions: [
        StatusResultAction(
          text: 'Back to Home',
          onPressed: () => context.go('/'),
        ),
        StatusResultAction(
          text: 'Try Again',
          onPressed: () => context.go('/contact'),
          isPrimary: true,
        ),
      ],
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
    );
  }
}
