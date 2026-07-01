import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../pages/status_result_page.dart';

/// Success page shown after a contact form submission succeeds.
class RequestSuccessPage extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const RequestSuccessPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    return StatusResultPage(
      analyticsPageName: 'request_success',
      statusType: StatusIconType.success,
      heading: 'Request Received',
      message: 'Thank you for reaching out. We\'ve received your message and will get back to you within 24 hours.',
      sectionTitle: 'What happens next?',
      items: [
        StatusResultItem(
          icon: LucideIcons.mail,
          label: 'You\'ll receive a confirmation email shortly',
          value: '',
        ),
        StatusResultItem(
          icon: LucideIcons.userCheck,
          label: 'Our team will review your request',
          value: '',
        ),
        StatusResultItem(
          icon: LucideIcons.messageCircle,
          label: 'We\'ll respond within 1 business day',
          value: '',
        ),
      ],
      actions: [
        StatusResultAction(
          text: 'Back to Home',
          onPressed: () => context.go('/'),
        ),
        StatusResultAction(
          text: 'Explore Features',
          onPressed: () => context.go('/features'),
          isPrimary: true,
        ),
      ],
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
    );
  }
}
