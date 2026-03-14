import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// A trust/certification badge pill with an icon and label.
///
/// Used to display compliance, certification, or feature badges.
///
/// Usage:
/// ```dart
/// TrustBadge(
///   icon: LucideIcons.shieldCheck,
///   label: 'Enterprise Security',
/// )
/// ```
class TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const TrustBadge({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray300,
          ),
        ),
      ],
    );
  }
}
