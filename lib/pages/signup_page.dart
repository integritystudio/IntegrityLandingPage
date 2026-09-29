import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/theme.dart';
import '../config/content.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../services/contact_service.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/cards.dart';
import '../widgets/common/form_fields.dart';
import '../widgets/common/gradient_page_shell.dart';
import '../services/auth0_service.dart';
import '../services/content_loader.dart';

/// Signup page with tier selection.
///
/// Collects the tier, the email and (enterprise) the company name, then opens
/// Auth0's sign-up screen; the password is set there, never on this site. The
/// tier and company ride the redirect as a [SignupIntent] that the callback uses
/// to provision the org and, for a paid tier, continue to checkout.
class SignupPage extends StatefulWidget {
  final String tier;
  final VoidCallback? onBack;

  const SignupPage({
    super.key,
    required this.tier,
    this.onBack,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  bool get _isEnterprise => widget.tier.toLowerCase() == SignupTiers.enterprise;

  bool _isSubmitting = false;
  bool _agreedToTerms = false;
  String? _errorMessage;
  final Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('signup');
    AnalyticsService.trackPricingView(widget.tier);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  String get _tierDisplayName {
    final name = widget.tier;
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1).toLowerCase();
  }

  String get _tierDescription => ContentLoader.signupDescription(widget.tier);

  @override
  Widget build(BuildContext context) {
    return GradientPageShell(
      onBack: widget.onBack ?? () => context.go('/'),
      scrollable: true,
      child: _buildSignupForm(),
    );
  }

  Widget _buildSignupForm() {
    return GlassCard(
      tier: GlassCardTier.primary,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tier badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '$_tierDisplayName Plan',
                    style: AppTypography.bodySM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Header
            Text(
              ContentLoader.signupHeading(widget.tier),
              style: AppTypography.headingMD.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _tierDescription,
              style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle, color: AppColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySM.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Email field
            FormTextField(
              label: 'Work Email',
              value: _emailController.text,
              onChanged: (value) => _emailController.text = value,
              type: FormTextFieldType.email,
              required: true,
              errorText: _fieldErrors['email'],
            ),
            const SizedBox(height: AppSpacing.md),

            // Enterprise names its org after the company.
            if (_isEnterprise) ...[
              FormTextField(
                label: 'Company Name',
                value: _companyController.text,
                onChanged: (value) => _companyController.text = value,
                errorText: _fieldErrors['company'],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),

            // Terms checkbox
            InkWell(
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) => setState(() => _agreedToTerms = value ?? false),
                    activeColor: AppColors.blue500,
                    side: BorderSide(color: AppColors.gray500),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: AppTypography.bodySM.copyWith(color: AppColors.gray300),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: AppTypography.bodySM.copyWith(
                                color: AppColors.blue400,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTypography.bodySM.copyWith(
                                color: AppColors.blue400,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Submit button
            GradientButton(
              text: _isSubmitting
                  ? 'Redirecting...'
                  : ContentLoader.signupCta(widget.tier),
              icon: _isSubmitting ? null : LucideIcons.arrowRight,
              onPressed: _isSubmitting ? null : _handleSubmit,
              fullWidth: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Features list
            _buildFeaturesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = ContentLoader.signupFeatures(widget.tier);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: features.map((feature) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.check, color: AppColors.success, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                feature,
                style: AppTypography.caption.copyWith(color: AppColors.gray400),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _handleSubmit() {
    // Clear previous errors
    setState(() {
      _fieldErrors.clear();
      _errorMessage = null;
    });

    // Validate fields
    bool hasError = false;
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _fieldErrors['email'] = 'Please enter your email';
      hasError = true;
    } else if (!ContactService.isValidEmail(email)) {
      _fieldErrors['email'] = 'Please enter a valid email';
      hasError = true;
    }

    if (!_agreedToTerms) {
      _errorMessage = 'Please agree to the Terms of Service and Privacy Policy';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isSubmitting = true);

    final company = _companyController.text.trim();
    Auth0Service.login(
      loginHint: email,
      signup: SignupIntent(
        tier: widget.tier,
        orgName: _isEnterprise && company.isNotEmpty ? company : null,
      ),
    );
  }
}
