import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/colors.dart';

/// Displays a status icon with gradient background for success/error/processing states.
///
/// Provides consistent styling across success, error, and processing states
/// used in OAuth callback, request success, and request failure pages.
class StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color primaryColor;
  final Color? secondaryColor;
  final double outerSize;
  final double iconSize;
  final bool isAnimated;
  final String? semanticLabel;

  const StatusIcon({
    super.key,
    required this.icon,
    required this.primaryColor,
    this.secondaryColor,
    this.outerSize = 80,
    this.iconSize = 40,
    this.isAnimated = false,
    this.semanticLabel,
  });

  /// Success state with check icon and green/blue gradient
  const StatusIcon.success({super.key})
      : icon = LucideIcons.checkCircle2,
        primaryColor = AppColors.success,
        secondaryColor = AppColors.blue500,
        outerSize = 80,
        iconSize = 40,
        isAnimated = false,
        semanticLabel = 'Success';

  /// Error state with X icon and red gradient
  const StatusIcon.error({super.key})
      : icon = LucideIcons.xCircle,
        primaryColor = AppColors.error,
        secondaryColor = null,
        outerSize = 80,
        iconSize = 40,
        isAnimated = false,
        semanticLabel = 'Error';

  /// Warning state with alert icon and orange/yellow gradient
  const StatusIcon.warning({super.key})
      : icon = LucideIcons.alertCircle,
        primaryColor = AppColors.error,
        secondaryColor = AppColors.warning,
        outerSize = 80,
        iconSize = 40,
        isAnimated = false,
        semanticLabel = 'Warning';

  /// Processing/loading state with spinning indicator
  const StatusIcon.processing({super.key})
      : icon = LucideIcons.loader2,
        primaryColor = AppColors.blue500,
        secondaryColor = AppColors.purple500,
        outerSize = 80,
        iconSize = 32,
        isAnimated = true,
        semanticLabel = 'Processing';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? _getDefaultLabel(),
      child: Container(
        width: outerSize,
        height: outerSize,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withValues(alpha: 0.2),
              (secondaryColor ?? primaryColor).withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(outerSize / 2),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: isAnimated ? _buildAnimatedIcon() : _buildStaticIcon(),
        ),
      ),
    );
  }

  Widget _buildStaticIcon() {
    return Icon(
      icon,
      color: primaryColor,
      size: iconSize,
    );
  }

  Widget _buildAnimatedIcon() {
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
      ),
    );
  }

  String _getDefaultLabel() {
    if (icon == LucideIcons.checkCircle2) return 'Success';
    if (icon == LucideIcons.xCircle) return 'Error';
    if (icon == LucideIcons.alertCircle) return 'Warning';
    if (icon == LucideIcons.loader2) return 'Processing';
    return 'Status';
  }
}
