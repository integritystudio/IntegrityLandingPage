import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/contact_service.dart';
import '../services/provisioning_service.dart';
import '../theme/theme.dart';
import '../widgets/common/alert.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/form_fields.dart';

enum AuthMode { signUp, signIn }

/// Authentication page for signup and signin.
///
/// Displays a form with email and password fields. SignUp variant
/// includes password confirmation field.
class AuthPage extends StatefulWidget {
  final AuthMode mode;
  final VoidCallback? onBack;

  const AuthPage({
    super.key,
    required this.mode,
    this.onBack,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _genericErrorMessage = 'Something went wrong. Please try again.';

  late AuthMode _mode;
  late TapGestureRecognizer _toggleModeRecognizer;
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool _pageViewTracked = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _toggleModeRecognizer = TapGestureRecognizer()..onTap = _toggleMode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pageViewTracked) {
      _pageViewTracked = true;
      AnalyticsService.trackPageView(
        _mode == AuthMode.signUp ? 'auth_signup' : 'auth_signin',
      );
    }
  }

  @override
  void dispose() {
    _toggleModeRecognizer.dispose();
    super.dispose();
  }

  String get _pageTitle =>
      _mode == AuthMode.signUp ? 'Create Account' : 'Sign In';

  String get _pageSubtitle =>
      _mode == AuthMode.signUp
          ? 'Get your API key to access the Integrity API'
          : 'Access your account';

  String get _submitButtonText =>
      _mode == AuthMode.signUp ? 'Sign Up' : 'Sign In';

  String get _toggleModeText =>
      _mode == AuthMode.signUp
          ? "Already have an account? Sign in"
          : "Don't have an account? Sign up";

  static const _minPasswordLength = 8;
  static const _maxPasswordLength = 128;

  bool get _isPasswordValid =>
      _password.isNotEmpty &&
      _password.length >= _minPasswordLength &&
      _password.length <= _maxPasswordLength;

  /// Returns a sanitized user-facing error message.
  ///
  /// Passes through short single-line messages that are likely user-friendly.
  /// Falls back to a generic message for verbose or multi-line server errors.
  static String _sanitizeError(String raw) {
    if (raw.length > 120 || raw.contains('\n') || raw.contains(' at ')) {
      return _genericErrorMessage;
    }
    return raw;
  }

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
      _errorMessage = null;
      _password = '';
      _confirmPassword = '';
      _showPassword = false;
      _showConfirmPassword = false;
      // _email is intentionally preserved so the user does not have to re-type
      // it after switching between sign-up and sign-in modes.
    });
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
        context.go(Routes.provision, extra: response);
      case AuthError():
        setState(() {
          _errorMessage = _sanitizeError(response.error);
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final spacingAfterSubtitle = _mode == AuthMode.signUp ? AppSpacing.lg : AppSpacing.md;
    final spacingBetweenFields = _mode == AuthMode.signUp ? AppSpacing.md : AppSpacing.lg;

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
            child: Column(
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

                // Password field
                FormTextField(
                  label: 'Password',
                  value: _password,
                  onChanged: (value) => setState(() {
                    _password = value;
                    _errorMessage = null;
                  }),
                  placeholder: 'Minimum 8 characters',
                  enabled: !_isLoading,
                ),
                SizedBox(height: spacingBetweenFields),

                // Confirm password field (signup only)
                if (_mode == AuthMode.signUp) ...[
                  FormTextField(
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
            ),
          ),
        ),
      ),
    );
  }
}
