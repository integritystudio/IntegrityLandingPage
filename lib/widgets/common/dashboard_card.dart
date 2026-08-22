import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// Shared content card for dashboard pages: bordered container with a header
/// row (bold [title] on the left, [trailing] or an inline loading spinner on
/// the right) followed by [children].
///
/// When [trailing] is non-null it replaces the spinner regardless of
/// [isLoading], so a page can show a status badge once data has arrived and a
/// spinner only while it is still pending.
class DashboardCard extends StatelessWidget {
  final String title;
  final bool isLoading;
  final Widget? trailing;
  final List<Widget> children;

  const DashboardCard({
    super.key,
    required this.title,
    required this.children,
    this.isLoading = false,
    this.trailing,
  });

  static const double _spinnerStrokeWidth = 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(borderColor: AppColors.gray700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (trailing != null)
                trailing!
              else if (isLoading)
                const SizedBox(
                  width: AppSpacing.iconSM,
                  height: AppSpacing.iconSM,
                  child: CircularProgressIndicator(
                    strokeWidth: _spinnerStrokeWidth,
                    valueColor: AlwaysStoppedAnimation(AppColors.blue500),
                  ),
                ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
