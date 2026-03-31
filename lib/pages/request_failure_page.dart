import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../pages/status_result_page.dart';

/// Failure page shown when a contact form submission or signup fails.
class RequestFailurePage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;
  final String? error;

  const RequestFailurePage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
    this.error,
  });

  @override
  State<RequestFailurePage> createState() => _RequestFailurePageState();
}

class _RequestFailurePageState extends State<RequestFailurePage> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect to signin if user already exists
    if (_isUserAlreadyExists(widget.error)) {
      Future.microtask(() {
        if (mounted) {
          try {
            context.go('/signin');
          } catch (_) {
            // GoRouter not available (e.g., in tests)
          }
        }
      });
    }
  }

  bool _isUserAlreadyExists(String? error) {
    if (error == null) return false;
    final lowerError = error.toLowerCase();
    return lowerError.contains('already') ||
           lowerError.contains('exists') ||
           lowerError.contains('duplicate');
  }

  @override
  Widget build(BuildContext context) {
    return _RequestFailurePageContent(
      error: widget.error,
      onBack: widget.onBack,
      onShowCookieSettings: widget.onShowCookieSettings,
    );
  }
}

class _RequestFailurePageContent extends StatelessWidget {
  final String? error;
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const _RequestFailurePageContent({
    this.error,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isUserExists = _isUserAlreadyExists(error);

    if (isUserExists) {
      return StatusResultPage(
        analyticsPageName: 'request_failure_user_exists',
        statusType: StatusIconType.warning,
        heading: 'Account Already Exists',
        message: 'An account with this email address is already registered. Sign in to your existing account instead.',
        sectionTitle: 'Next steps',
        items: [
          StatusResultItem(
            icon: LucideIcons.mail,
            label: 'Your email',
            value: 'Already has an active account',
          ),
          StatusResultItem(
            icon: LucideIcons.logIn,
            label: 'Sign in now',
            value: 'Access your existing account',
          ),
        ],
        actions: [
          StatusResultAction(
            text: 'Back to Home',
            onPressed: () => context.go('/'),
          ),
          StatusResultAction(
            text: 'Go to Sign In',
            onPressed: () => context.go('/signin'),
            isPrimary: true,
          ),
        ],
        onBack: onBack,
        onShowCookieSettings: onShowCookieSettings,
      );
    }

    return StatusResultPage(
      analyticsPageName: 'request_failure',
      statusType: StatusIconType.warning,
      heading: 'Something Went Wrong',
      message: 'We couldn\'t process your request. This might be a temporary issue. Please try again or contact us directly.',
      sectionTitle: 'Alternative ways to reach us',
      items: [
        StatusResultItem(
          icon: LucideIcons.mail,
          label: 'Email us directly',
          value: CompanyInfo.email,
        ),
        StatusResultItem(
          icon: LucideIcons.refreshCw,
          label: 'Try again',
          value: 'The request may work now',
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

  bool _isUserAlreadyExists(String? error) {
    if (error == null) return false;
    final lowerError = error.toLowerCase();
    return lowerError.contains('already') ||
           lowerError.contains('exists') ||
           lowerError.contains('duplicate');
  }
}
