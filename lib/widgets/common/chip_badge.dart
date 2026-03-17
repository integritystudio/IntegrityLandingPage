import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class ChipBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final Color accentColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const ChipBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.accentColor,
    this.description,
    this.backgroundColor,
    this.borderColor,
    this.iconSize = 18,
    this.padding,
    this.borderRadius = AppSpacing.radiusFull,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
      decoration: BoxDecoration(
        color: backgroundColor ?? accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? accentColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: accentColor),
          const SizedBox(width: AppSpacing.sm),
          if (description == null)
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMD.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
