import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? child;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Gradient? iconBackgroundGradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final double? iconSize;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.child,
    this.iconColor,
    this.iconBackgroundColor,
    this.iconBackgroundGradient,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.padding,
    this.width,
    this.titleStyle,
    this.descriptionStyle,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.blue400;
    final resolvedIconSize = iconSize ?? 20.0;
    final resolvedBorderRadius = borderRadius ?? AppSpacing.radiusSM;

    Widget iconWidget = Icon(
      icon,
      size: resolvedIconSize,
      color: resolvedIconColor,
    );

    if (iconBackgroundColor != null || iconBackgroundGradient != null) {
      iconWidget = Container(
        decoration: BoxDecoration(
          color: iconBackgroundColor,
          gradient: iconBackgroundGradient,
        ),
        child: iconWidget,
      );
    }

    final card = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.gray700,
        borderRadius: BorderRadius.circular(resolvedBorderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.gray600,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle ??
                      AppTypography.bodyMD.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (description != null)
                  Text(
                    description!,
                    style: descriptionStyle ??
                        AppTypography.bodySM.copyWith(
                          color: AppColors.gray400,
                        ),
                  ),
                if (child != null) child!,
              ],
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return card;
  }
}
