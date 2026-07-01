import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/containers.dart';

/// Final call-to-action section
///
/// Usage:
/// ```dart
/// CTASection(
///   onGetStarted: () => scrollTo('signup'),
/// )
/// ```
class CTASection extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const CTASection({
    super.key,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      id: 'cta',
      child: Container(
        padding: EdgeInsets.all(isMobile ? AppSpacing.xl : AppSpacing.xxl),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue500.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Ready to Understand Your AI?',
              style: isMobile
                  ? AppTypography.headingMD.copyWith(color: Colors.white)
                  : AppTypography.headingLG.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                'Start your free trial today. No credit card required.',
                style: AppTypography.bodyLG.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _CTAButton(
              onPressed: () {
                AnalyticsService.trackCTAClick(
                  buttonName: 'Start Free Trial',
                  location: 'cta_section',
                  ctaType: 'primary',
                );
                onGetStarted?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CTAButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _CTAButton({this.onPressed});

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        label: 'Get started',
        button: true,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Start Free Trial',
                style: AppTypography.buttonText.copyWith(
                  color: AppColors.blue600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                LucideIcons.arrowRight,
                size: 20,
                color: AppColors.blue600,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
