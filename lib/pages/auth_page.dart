import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/auth0_service.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/gradient_page_shell.dart';

/// Sign-in page.
///
/// Credentials are entered on Auth0's Universal Login page, never here. Signing in
/// there starts the Auth0 session integritystudio.dev shares, so the observability
/// dashboard opens without a second login. Password reset is offered on that page.
class AuthPage extends StatefulWidget {
  final VoidCallback? onBack;

  const AuthPage({super.key, this.onBack});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('auth_signin');
  }

  void _signIn() {
    setState(() => _isRedirecting = true);
    Auth0Service.login();
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = AppTypography.bodySM.copyWith(
      color: AppColors.gray300,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.gray300,
    );

    return GradientPageShell(
      onBack: widget.onBack,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign In',
            style: AppTypography.headingLG.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Access your account. You will sign in on our secure login page, '
            'where you can also reset your password.',
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientButton(
            onPressed: _isRedirecting ? null : _signIn,
            isLoading: _isRedirecting,
            text: 'Continue to Sign In',
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: GestureDetector(
              onTap: () => context.go(Routes.signup),
              child: Text("Don't have an account? Sign up", style: linkStyle),
            ),
          ),
        ],
      ),
    );
  }
}
