import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import '../common/containers.dart';

/// Full-page scaffold shared by all documentation pages.
///
/// Provides: dark background, [DocPageAppBar], hero section, constrained
/// content area (max 900 px), and [DocPageFooter]. Pages supply the
/// page-specific hero and content widgets via [heroBuilder] and [content].
class DocsPageScaffold extends StatelessWidget {
  const DocsPageScaffold({
    super.key,
    required this.title,
    required this.heroBuilder,
    required this.content,
    this.onBack,
  });

  final String title;

  /// Builder called with the current [isMobile] value so the hero section can
  /// adapt its layout without computing the breakpoint itself.
  final Widget Function(bool isMobile) heroBuilder;

  final Widget content;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          DocPageAppBar(title: title, onBack: onBack),
          SliverToBoxAdapter(child: heroBuilder(isMobile)),
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: content,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: DocPageFooter()),
        ],
      ),
    );
  }
}

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
