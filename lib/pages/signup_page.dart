import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../config/content.dart';
import '../config/content/constants.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/cards.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/form_fields.dart';
import '../services/contact_service.dart';

/// Signup page with tier selection.
///
/// Displays a signup form pre-populated with the selected pricing tier.
/// On successful signup, redirects to Calendly for onboarding.
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
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();

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
    _nameController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  String get _tierDisplayName {
    switch (widget.tier.toLowerCase()) {
      case 'starter':
        return 'Starter';
      case 'growth':
        return 'Growth';
      case 'scale':
        return 'Scale';
      case 'enterprise':
        return 'Enterprise';
      default:
        return widget.tier;
    }
  }

  String get _tierDescription {
    switch (widget.tier.toLowerCase()) {
      case 'starter':
        return 'Perfect for small teams getting started with AI observability.';
      case 'growth':
        return 'For growing teams that need advanced monitoring features.';
      case 'scale':
        return 'For organizations with complex AI infrastructure needs.';
      case 'enterprise':
        return 'Custom solutions with dedicated support and SLAs.';
      default:
        return 'Get started with Integrity Studio.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: GradientBackground(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: AppColors.gray900.withValues(alpha: 0.95),
              floating: true,
              pinned: true,
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                onPressed: widget.onBack ?? () => context.go('/'),
                tooltip: 'Back to home',
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shield, color: AppColors.blue500, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      CompanyInfo.name,
                      style: AppTypography.headingSM.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            SliverToBoxAdapter(
              child: ResponsiveContainer(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: AppSpacing.section,
                    horizontal: isMobile ? AppSpacing.md : AppSpacing.xl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: _buildSignupForm(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
              'Start Your Free Trial',
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

            // Name field
            FormTextField(
              label: 'Full Name',
              value: _nameController.text,
              onChanged: (value) => _nameController.text = value,
              required: true,
              errorText: _fieldErrors['name'],
            ),
            const SizedBox(height: AppSpacing.md),

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

            // Company field
            FormTextField(
              label: 'Company Name',
              value: _companyController.text,
              onChanged: (value) => _companyController.text = value,
              errorText: _fieldErrors['company'],
            ),
            const SizedBox(height: AppSpacing.lg),

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
              text: _isSubmitting ? 'Creating Account...' : 'Start Free Trial',
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
    final features = [
      '14-day free trial',
      'No credit card required',
      'Cancel anytime',
    ];

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

  Future<void> _handleSubmit() async {
    // Clear previous errors
    setState(() {
      _fieldErrors.clear();
      _errorMessage = null;
    });

    // Validate fields
    bool hasError = false;

    if (_nameController.text.trim().isEmpty) {
      _fieldErrors['name'] = 'Please enter your name';
      hasError = true;
    }

    if (_emailController.text.trim().isEmpty) {
      _fieldErrors['email'] = 'Please enter your email';
      hasError = true;
    } else if (!_isValidEmail(_emailController.text)) {
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

    // Track signup
    AnalyticsService.trackFormSubmit('signup_form');
    FacebookPixelService.trackLead(email: _emailController.text);

    try {
      final response = await ContactService.submitForm(
        ContactFormPayload(
          formData: ContactFormData(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            organization: _companyController.text.trim().isNotEmpty
                ? _companyController.text.trim()
                : null,
            message: 'Signup request for ${widget.tier} tier',
          ),
        ),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      switch (response) {
        case ContactFormSuccess():
          context.go('/request_success');
        case ContactFormError(:final error, :final fieldErrors):
          if (fieldErrors != null) {
            // Validation errors — show inline so user can fix
            setState(() => _fieldErrors.addAll(fieldErrors));
          } else {
            // Network/server error — redirect to failure page
            context.go('/request_failure');
          }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      context.go('/request_failure');
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }
}
