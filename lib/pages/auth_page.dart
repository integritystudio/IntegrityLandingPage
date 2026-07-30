import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/contact_service.dart';
import '../services/provisioning_service.dart';
import 'dashboard_page.dart';
import '../theme/theme.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';
import '../utils/security_utils.dart';
import '../widgets/common/form_fields.dart';

enum AuthMode { signUp, signIn }

extension AuthModeX on AuthMode {
  /// Get the route path for this auth mode.
  String get routePath => this == AuthMode.signUp ? Routes.signup : Routes.login;

  /// Get the page title for this auth mode.
  String get title => this == AuthMode.signUp ? 'Create Account' : 'Sign In';

  /// Get the button text for this auth mode.
  String get buttonText => this == AuthMode.signUp ? 'Sign Up' : 'Sign In';

  /// Get the analytics page view name for this auth mode.
  String get pageViewName => this == AuthMode.signUp ? 'auth_signup' : 'auth_signin';

  /// Get the page subtitle for this auth mode.
  String get pageSubtitle => this == AuthMode.signUp
      ? 'Get your API key to access the Integrity API'
      : 'Access your account';

  /// Get the toggle mode prompt for this auth mode.
  String get toggleModePrompt => this == AuthMode.signUp
      ? "Already have an account? Sign in"
      : "Don't have an account? Sign up";
}

/// Authentication page for signup and signin.
///
/// Displays a form with email and password fields. SignUp variant
/// includes password confirmation field.
class AuthPage extends StatefulWidget {
  final AuthMode mode;
  final VoidCallback? onBack;

  /// When true, opens directly in forgot-password mode instead of the
  /// sign-in form. Used by the `/forgot-password` deep-link route.
  final bool initialForgotPassword;

  const AuthPage({
    super.key,
    required this.mode,
    this.onBack,
    this.initialForgotPassword = false,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late AuthMode _mode;
  late TapGestureRecognizer _toggleModeRecognizer;
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isLoading = false;
  String? _errorMessage;

  bool _isForgotPasswordMode = false;
  bool _forgotPasswordSent = false;

  bool _pageViewTracked = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _isForgotPasswordMode = widget.initialForgotPassword;
    _toggleModeRecognizer = TapGestureRecognizer()..onTap = _toggleMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageViewTracked) {
      _pageViewTracked = true;
      AnalyticsService.trackPageView(_mode.pageViewName);
    }
  }

  @override
  void dispose() {
    _toggleModeRecognizer.dispose();
    super.dispose();
  }

  String get _pageTitle => _mode.title;

  String get _pageSubtitle => _mode.pageSubtitle;

  String get _submitButtonText => _mode.buttonText;

  String get _toggleModeText => _mode.toggleModePrompt;

  bool get _isPasswordValid =>
      _password.isNotEmpty &&
      _password.length >= PasswordPolicy.minLength &&
      _password.length <= PasswordPolicy.maxLength;

  bool get _isFormValid {
    if (_email.isEmpty || !ContactService.isValidEmail(_email)) return false;
    if (!_isPasswordValid) return false;
    if (_mode == AuthMode.signUp) {
      return _confirmPassword.isNotEmpty && _confirmPassword == _password;
    }
    return true;
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == AuthMode.signUp ? AuthMode.signIn : AuthMode.signUp;
      _isForgotPasswordMode = false;
      _forgotPasswordSent = false;
      _errorMessage = null;
      _password = '';
      _confirmPassword = '';
      // _email is intentionally preserved so the user does not have to re-type
      // it after switching between sign-up and sign-in modes.
    });
  }

  void _enterForgotPasswordMode() {
    setState(() {
      _isForgotPasswordMode = true;
      _forgotPasswordSent = false;
      _errorMessage = null;
    });
  }

  void _exitForgotPasswordMode() {
    setState(() {
      _isForgotPasswordMode = false;
      _forgotPasswordSent = false;
      _errorMessage = null;
    });
  }

  Future<void> _submitForgotPassword() async {
    if (_email.isEmpty || !ContactService.isValidEmail(_email)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await ProvisioningService.forgotPassword(_email);
    if (!mounted) return;

    switch (response) {
      case ForgotPasswordSuccess():
        setState(() {
          _isLoading = false;
          _forgotPasswordSent = true;
        });
      case ForgotPasswordError():
        setState(() {
          _errorMessage = SecurityUtils.sanitizeServerError(response.error);
          _isLoading = false;
        });
    }
  }

  Future<void> _submit() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = _mode == AuthMode.signUp
        ? await ProvisioningService.signUp(_email, _password)
        : await ProvisioningService.signIn(_email, _password);

    if (!mounted) return;

    switch (response) {
      case AuthSuccess():
        setState(() => _isLoading = false);
        // Sign-in: user already has an API key — go straight to the dashboard.
        // Sign-up: go to provisioning to generate the first API key.
        if (_mode == AuthMode.signIn) {
          context.go(Routes.dashboard, extra: DashboardArgs(jwt: response.jwt));
        } else {
          context.go(Routes.provision, extra: response);
        }
      case AuthError():
        setState(() {
          _errorMessage = SecurityUtils.sanitizeServerError(response.error);
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: GradientBackground(
        child: Center(
          child: ResponsiveContainer(
            maxWidth: 500,
            additionalPadding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
            child: _isForgotPasswordMode
                ? _buildForgotPasswordView()
                : _buildAuthForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordView() {
    final title = _forgotPasswordSent ? 'Check Your Email' : 'Reset Password';
    final subtitle = _forgotPasswordSent
        ? 'A password reset link has been sent to $_email. Check your inbox and follow the link to set a new password.'
        : 'Enter your email address and we\u2019ll send you a reset link.';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headingLG.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        if (_forgotPasswordSent) ...[
          Alert.success(message: subtitle),
        ] else ...[
          Text(
            subtitle,
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.gray300,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_errorMessage != null)
            Alert.error(message: _errorMessage!),

          FormTextField(
            label: 'Email Address',
            value: _email,
            onChanged: (value) => setState(() {
              _email = value;
              _errorMessage = null;
            }),
            type: FormTextFieldType.email,
            placeholder: 'you@example.com',
            enabled: !_isLoading,
          ),
          const SizedBox(height: AppSpacing.lg),

          GradientButton(
            onPressed: _email.isNotEmpty &&
                    ContactService.isValidEmail(_email) &&
                    !_isLoading
                ? _submitForgotPassword
                : null,
            isLoading: _isLoading,
            text: 'Send Reset Link',
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        Center(
          child: GestureDetector(
            onTap: _exitForgotPasswordMode,
            child: Text(
              'Back to sign in',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray300,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.gray300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    final spacingAfterSubtitle = _mode == AuthMode.signUp ? AppSpacing.lg : AppSpacing.md;
    final spacingBetweenFields = _mode == AuthMode.signUp ? AppSpacing.md : AppSpacing.lg;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _pageTitle,
          style: AppTypography.headingLG.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Subtitle
        Text(
          _pageSubtitle,
          style: AppTypography.bodyMD.copyWith(
            color: AppColors.gray300,
          ),
        ),
        SizedBox(height: spacingAfterSubtitle),

        // Error message
        if (_errorMessage != null)
          Alert.error(message: _errorMessage!),

        // Email field
        FormTextField(
          label: 'Email Address',
          value: _email,
          onChanged: (value) => setState(() {
            _email = value;
            _errorMessage = null;
          }),
          type: FormTextFieldType.email,
          placeholder: 'you@example.com',
          enabled: !_isLoading,
        ),
        SizedBox(height: spacingBetweenFields),

        // Password field \u2014 keyed on mode so Flutter discards the widget
        // (and its internal TextEditingController) when mode toggles, preventing
        // the displayed text from persisting after _toggleMode() clears the state.
        FormTextField(
          key: ValueKey('password_${_mode.name}'),
          label: 'Password',
          value: _password,
          onChanged: (value) => setState(() {
            _password = value;
            _errorMessage = null;
          }),
          placeholder: '${PasswordPolicy.minLength}\u2013${PasswordPolicy.maxLength} characters',
          enabled: !_isLoading,
        ),
        SizedBox(height: spacingBetweenFields),

        // Confirm password field (signup only)
        if (_mode == AuthMode.signUp) ...[
          FormTextField(
            key: const ValueKey('confirm_password'),
            label: 'Confirm Password',
            value: _confirmPassword,
            onChanged: (value) => setState(() {
              _confirmPassword = value;
              _errorMessage = null;
            }),
            placeholder: 'Re-enter your password',
            enabled: !_isLoading,
          ),
          SizedBox(height: AppSpacing.lg),
        ],

        // Forgot password link (sign-in only, appears above submit button)
        if (_mode == AuthMode.signIn) ...[
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _enterForgotPasswordMode,
              child: Text(
                'Forgot password?',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray300,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gray300,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Submit button
        GradientButton(
          onPressed: _isFormValid && !_isLoading ? _submit : null,
          isLoading: _isLoading,
          text: _submitButtonText,
        ),
        const SizedBox(height: AppSpacing.md),

        // Toggle mode link
        Center(
          child: RichText(
            text: TextSpan(
              text: _toggleModeText,
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray300,
              ),
              recognizer: _toggleModeRecognizer,
            ),
          ),
        ),
      ],
    );
  }
}
