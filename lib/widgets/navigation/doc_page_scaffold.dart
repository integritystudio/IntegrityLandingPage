import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';

/// Shared AppBar for documentation pages.
///
/// Provides consistent navigation with back button, title, and "Back to Home" action.
class DocPageAppBar extends StatelessWidget {
  /// Page title displayed in the app bar
  final String title;

  /// Callback when back button is pressed
  final VoidCallback? onBack;

  const DocPageAppBar({
    super.key,
    required this.title,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.gray900,
      floating: true,
      pinned: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: onBack ?? () => context.go('/'),
      ),
      title: Text(
        title,
        style: AppTypography.headingSM.copyWith(color: Colors.white),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextButton(
            onPressed: onBack ?? () => context.go('/'),
            child: Text(
              'Back to Home',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.blue400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared footer for documentation pages.
///
/// Displays "Built with OpenTelemetry and SigNoz" and copyright.
class DocPageFooter extends StatelessWidget {
  const DocPageFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: Center(
        child: Column(
          children: [
            Text(
              'Built with OpenTelemetry and SigNoz',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray400,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '\u00A9 2026 Integrity Studio LLC',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.gray400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
