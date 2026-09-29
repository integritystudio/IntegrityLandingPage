import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/auth0_service.dart';
import '../services/dashboard_service.dart';
import '../theme/theme.dart';
import '../utils/security_utils.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/gradient_page_shell.dart';
import 'dashboard_page.dart';
import 'provision_page.dart';

/// Where Auth0 returns the browser after Universal Login (`/callback?code=&state=`).
///
/// Exchanges the code for a session, then routes on the user's orgs: none yet means
/// a new account, which goes to /provision for its first API key (and on to checkout
/// for a paid tier); anyone else goes to the dashboard.
class CallbackPage extends StatefulWidget {
  final Uri uri;

  const CallbackPage({super.key, required this.uri});

  @override
  State<CallbackPage> createState() => _CallbackPageState();
}

class _CallbackPageState extends State<CallbackPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _complete();
  }

  Future<void> _complete() async {
    final Auth0CallbackResult result;
    try {
      result = await Auth0Service.handleCallback(widget.uri);
    } on Auth0Exception catch (e) {
      _fail(e.message);
      return;
    }

    final session = result.session;
    final orgs = await DashboardService.fetchOrgList(jwt: session.accessToken);
    if (!mounted) return;

    switch (orgs) {
      case OrgListSuccess(orgs: []):
        if (result.signup != null) {
          // Counted once the account exists, not when the form was submitted.
          AnalyticsService.trackFormSubmission(formType: 'signup_form', success: true);
          FacebookPixelService.trackLead(email: session.email);
        }
        context.go(
          Routes.provision,
          extra: ProvisionArgs(session: session, signup: result.signup),
        );
      case OrgListSuccess():
        context.go(Routes.dashboard, extra: DashboardArgs(jwt: session.accessToken));
      case OrgListError():
        _fail(orgs.error);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = SecurityUtils.sanitizeServerError(message));
  }

  @override
  Widget build(BuildContext context) {
    final error = _errorMessage;
    return GradientPageShell(
      onBack: error == null ? null : () => context.go(Routes.home),
      child: error == null
          ? const AuthProgress()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Alert.error(message: error),
                const SizedBox(height: AppSpacing.md),
                GradientButton(
                  text: 'Sign in again',
                  onPressed: () => Auth0Service.login(),
                ),
              ],
            ),
    );
  }
}

/// Opens the dashboard for a returning user who arrives without in-app state (a
/// reload, a bookmark, a new tab): restores the stored session, refreshing its
/// token if needed, or sends them to sign in.
class SessionRestorePage extends StatefulWidget {
  const SessionRestorePage({super.key});

  @override
  State<SessionRestorePage> createState() => _SessionRestorePageState();
}

class _SessionRestorePageState extends State<SessionRestorePage> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await Auth0Service.currentSession();
    if (!mounted) return;
    if (session == null) {
      context.go(Routes.login);
    } else {
      context.go(Routes.dashboard, extra: DashboardArgs(jwt: session.accessToken));
    }
  }

  @override
  Widget build(BuildContext context) =>
      const GradientPageShell(child: AuthProgress());
}

/// The "signing you in" spinner shared by the callback and restore pages.
class AuthProgress extends StatelessWidget {
  const AuthProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(color: AppColors.textPrimary),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Signing you in...',
          style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
        ),
      ],
    );
  }
}
