import 'package:flutter/material.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
      ),
      child: Text(
        label,
        style: AppTypography.bodySM.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
