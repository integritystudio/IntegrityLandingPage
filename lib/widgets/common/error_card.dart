import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';
import 'buttons.dart';

/// Shared error card with message and retry button.
///
/// Used across dashboard sub-pages (billing, usage, quota, entitlements)
/// and the main dashboard hub.
///
/// Usage:
/// ```dart
/// ErrorCard(
///   message: 'Failed to load data',
///   onRetry: _fetchData,
/// )
/// ```
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecorations.card(borderColor: AppColors.gray700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, size: 16, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySM.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  onPressed: onRetry,
                  text: 'Try again',
                  icon: LucideIcons.rotateCw,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
