import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/theme.dart';
import '../common/buttons.dart';
import '../common/cards.dart';

/// Demo video modal dialog.
///
/// Displays a demo video or placeholder content in a modal overlay.
/// Supports YouTube embed when video ID is provided.
class DemoModal extends StatelessWidget {
  /// YouTube video ID (optional).
  /// If null, shows placeholder content.
  final String? videoId;

  /// Callback when user wants to schedule a live demo.
  final VoidCallback? onScheduleDemo;

  const DemoModal({
    super.key,
    this.videoId,
    this.onScheduleDemo,
  });

  /// Show the demo modal dialog.
  static Future<void> show(
    BuildContext context, {
    String? videoId,
    VoidCallback? onScheduleDemo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => DemoModal(
        videoId: videoId,
        onScheduleDemo: onScheduleDemo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = ResponsiveUtils.isMobile(context);
    final modalWidth = isMobile ? screenSize.width * 0.95 : screenSize.width * 0.7;
    final modalHeight = isMobile ? screenSize.height * 0.5 : screenSize.height * 0.65;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.sm : AppSpacing.xl,
        vertical: AppSpacing.xl,
      ),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: modalHeight + 100,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    LucideIcons.x,
                    color: AppColors.gray400,
                    size: 24,
                  ),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Video/placeholder content
            Flexible(
              child: GlassCard(
                tier: GlassCardTier.primary,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Video area
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: modalHeight * 0.75,
                        ),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.gray800,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMD),
                          ),
                          child: videoId != null
                              ? _buildVideoPlayer()
                              : _buildPlaceholder(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // CTA section
                    _buildCTASection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    // Placeholder for YouTube embed
    // TODO: integrate youtube_player_iframe or similar package
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.playCircle,
            size: 64,
            color: AppColors.blue500.withValues(alpha: 0.8),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Demo video loading...',
            style: AppTypography.bodySM.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.play,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Demo Video Coming Soon',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'See how Integrity Studio helps teams monitor AI models, '
              'detect drift, and ensure compliance.',
              style: AppTypography.bodyMD.copyWith(color: AppColors.gray300),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onScheduleDemo != null)
          GradientButton(
            text: 'Schedule Live Demo',
            icon: LucideIcons.calendar,
            onPressed: () {
              Navigator.of(context).pop();
              onScheduleDemo!();
            },
          )
        else
          OutlineButton(
            text: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}
