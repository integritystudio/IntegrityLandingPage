import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Gradient pill badge used in hero sections (careers, contact, features).
///
/// Renders a rounded pill with a blue→purple gradient background,
/// blue border, and optional leading icon.
///
/// Usage:
/// ```dart
/// GradientPillBadge(label: 'Join Our Team')
/// GradientPillBadge(icon: LucideIcons.checkCircle, label: 'SOC 2')
/// ```
class GradientPillBadge extends StatelessWidget {
  const GradientPillBadge({
    super.key,
    required this.label,
    this.icon,
    this.iconColor = AppColors.blue400,
  });

  final String label;

  /// Optional leading icon. When provided, renders before the label
  /// with [AppSpacing.sm] gap.
  final IconData? icon;

  /// Icon color. Defaults to [AppColors.blue400] to match the label text.
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue500.withValues(alpha: 0.2),
            AppColors.purple500.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(
          color: AppColors.blue500.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconSM, color: iconColor),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.blue400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
