import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';

/// A trust/certification badge pill with an icon and label.
///
/// Used to display compliance, certification, or feature badges.
///
/// Usage:
/// ```dart
/// // Custom icon
/// TrustBadge(
///   icon: LucideIcons.shieldCheck,
///   label: 'Enterprise Security',
/// )
///
/// // With check icon (default)
/// TrustBadge(
///   label: 'EU AI Act Ready',
/// )
/// ```
class TrustBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color iconColor;

  const TrustBadge({
    super.key,
    this.icon,
    required this.label,
    this.iconColor = AppColors.success,
  });

  @override
  Widget build(BuildContext context) {
    final displayIcon = icon ?? LucideIcons.check;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          displayIcon,
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
