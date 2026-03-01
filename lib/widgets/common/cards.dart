import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import 'buttons.dart';
import 'containers.dart';

/// Glass morphism card with performance optimization
///
/// IMPORTANT: BackdropFilter is disabled on web for performance.
/// On web, we use a solid semi-transparent background instead.
///
/// Tiers:
/// - primary: Full glass effect (native only), used for hero CTAs
/// - secondary: Subtle effect, used for feature cards
/// - tertiary: Solid with gradient border, used for content cards
///
/// Usage:
/// ```dart
/// GlassCard(
///   tier: GlassCardTier.secondary,
///   enableHover: true,
///   child: FeatureContent(),
/// )
/// ```
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool enableHover;
  final GlassCardTier tier;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.enableHover = false,
    this.tier = GlassCardTier.secondary,
    this.onTap,
    this.semanticLabel,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  EdgeInsets get _padding =>
      widget.padding ?? const EdgeInsets.all(AppSpacing.cardPadding);

  @override
  Widget build(BuildContext context) {
    // Performance: Disable BackdropFilter on web
    final useBackdropFilter =
        !kIsWeb && widget.tier == GlassCardTier.primary;

    final content = Semantics(
      label: widget.semanticLabel,
      container: widget.semanticLabel != null,
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
        onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: widget.enableHover && _isHovered
                ? Matrix4.translationValues(0.0, -4.0, 0.0)
                : Matrix4.identity(),
            decoration: _buildDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
              child: useBackdropFilter
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Padding(padding: _padding, child: widget.child),
                    )
                  : Padding(padding: _padding, child: widget.child),
            ),
          ),
        ),
      ),
    );

    return content;
  }

  BoxDecoration _buildDecoration() {
    switch (widget.tier) {
      case GlassCardTier.primary:
        return BoxDecoration(
          color: kIsWeb
              ? AppColors.gray900.withValues(alpha: 0.95)
              : AppColors.gray900.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: _isHovered
                ? AppColors.blue500.withValues(alpha: 0.5)
                : AppColors.gray700.withValues(alpha: 0.5),
            width: _isHovered ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDefault,
              blurRadius: _isHovered ? 32 : 24,
              offset: Offset(0, _isHovered ? 12 : 8),
            ),
            if (_isHovered)
              BoxShadow(
                color: AppColors.blue500.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 8),
              ),
          ],
        );

      case GlassCardTier.secondary:
        return BoxDecoration(
          color: AppColors.gray800.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          border: Border.all(
            color: _isHovered
                ? AppColors.blue500.withValues(alpha: 0.4)
                : AppColors.gray700.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDefault,
              blurRadius: _isHovered ? 24 : 16,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        );

      case GlassCardTier.tertiary:
        return BoxDecoration(
          color: AppColors.gray800,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: _isHovered
                ? AppColors.gray600
                : AppColors.gray700,
            width: 1,
          ),
        );
    }
  }
}

/// Tier levels for glass cards
enum GlassCardTier {
  /// Full glass effect with blur (native only)
  primary,

  /// Subtle glass effect
  secondary,

  /// Solid card with border
  tertiary,
}

/// Feature card with icon container
///
/// Usage:
/// ```dart
/// FeatureCard(
///   icon: LucideIcons.activity,
///   title: 'LLM Monitoring',
///   description: 'Track every LLM call...',
///   features: ['Token usage', 'Cost attribution'],
/// )
/// ```
class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String>? features;
  final VoidCallback? onTap;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.features,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.secondary,
      enableHover: true,
      onTap: onTap,
      semanticLabel: '$title feature card',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container with gradient
          GradientIconContainer(icon: icon),

          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            title,
            style: AppTypography.headingSM,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Description
          Text(
            description,
            style: AppTypography.bodyMD,
          ),

          if (features != null && features!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            // Feature bullets
            BulletList(items: features!),
          ],
        ],
      ),
    );
  }
}

/// Stat card for displaying metrics
///
/// Usage:
/// ```dart
/// StatCard(
///   value: '99.9%',
///   label: 'Uptime SLA',
/// )
/// ```
class StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTypography.statValue.copyWith(
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.statLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Pricing card for tier display
///
/// Usage:
/// ```dart
/// PricingCard(
///   tier: 'Team',
///   price: '\$99',
///   period: '/month',
///   features: ['100K traces/month', '30-day retention'],
///   isPopular: true,
///   ctaText: 'Start Free Trial',
///   onCtaPressed: () => signUp(),
/// )
/// ```
class PricingCard extends StatelessWidget {
  final String tier;
  final String price;
  final String? period;
  final String? description;
  final List<String> features;
  final bool isPopular;
  final String ctaText;
  final VoidCallback? onCtaPressed;

  const PricingCard({
    super.key,
    required this.tier,
    required this.price,
    this.period,
    this.description,
    required this.features,
    this.isPopular = false,
    required this.ctaText,
    this.onCtaPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: isPopular ? GlassCardTier.primary : GlassCardTier.secondary,
      enableHover: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Popular badge
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: AppDecorations.gradientPill(),
              child: Text(
                'Most Popular',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (isPopular) const SizedBox(height: AppSpacing.md),

          // Tier name
          Text(tier, style: AppTypography.headingSM),

          const SizedBox(height: AppSpacing.sm),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  price,
                  style: AppTypography.headingLG.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (period != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    period!,
                    style: AppTypography.bodyMD,
                  ),
                ),
            ],
          ),

          if (description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(description!, style: AppTypography.bodySM),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),

          // Features list
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.checkCircle,
                      size: 20,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(feature, style: AppTypography.bodySM),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: AppSpacing.md),

          // CTA - stays at bottom
          isPopular
              ? GradientButton(
                  text: ctaText,
                  onPressed: onCtaPressed,
                  fullWidth: true,
                )
              : OutlineButton(
                  text: ctaText,
                  onPressed: onCtaPressed,
                  fullWidth: true,
                ),
        ],
      ),
    );
  }
}
