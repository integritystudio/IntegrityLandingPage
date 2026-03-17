import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/status_icon.dart';
import '../widgets/navigation/sub_page_shell.dart';

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
    return SubPageShell(
      onBack: onBack,
      onShowCookieSettings: onShowCookieSettings,
      analyticsPageName: 'request_success',
      slivers: const [
        SliverToBoxAdapter(child: _SuccessHeroSection()),
      ],
    );
  }
}

class _SuccessHeroSection extends StatelessWidget {
  const _SuccessHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const StatusIcon.success(),
              const SizedBox(height: AppSpacing.xl),

              // Heading
              Text(
                'Request Received',
                style: (isMobile
                        ? AppTypography.headingLG
                        : AppTypography.headingXL)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Message
              Text(
                'Thank you for reaching out. We\'ve received your message and will get back to you within 24 hours.',
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // What happens next
              Container(
                padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.gray800,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(color: AppColors.gray700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next?',
                      style: AppTypography.headingSM.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildNextStep(
                      icon: LucideIcons.mail,
                      text: 'You\'ll receive a confirmation email shortly',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNextStep(
                      icon: LucideIcons.userCheck,
                      text: 'Our team will review your request',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNextStep(
                      icon: LucideIcons.messageCircle,
                      text: 'We\'ll respond within 1 business day',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Buttons
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  OutlineButton(
                    text: 'Back to Home',
                    onPressed: () => context.go('/'),
                  ),
                  GradientButton(
                    text: 'Explore Features',
                    onPressed: () => context.go('/features'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextStep({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.blue400,
          size: 20,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
          ),
        ),
      ],
    );
  }
}
