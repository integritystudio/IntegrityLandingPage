import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'containers.dart';

/// Scaffold shell for simple pages using a gradient background.
///
/// Provides the recurring layout:
/// `Scaffold(appBar: back button) -> GradientBackground -> Center -> ResponsiveContainer`
///
/// Used by checkout success, sender health, auth, and provision pages.
class GradientPageShell extends StatelessWidget {
  final VoidCallback? onBack;
  final double maxWidth;
  final Widget child;

  const GradientPageShell({
    super.key,
    this.onBack,
    this.maxWidth = 500,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              )
            : null,
      ),
      body: GradientBackground(
        child: Center(
          child: ResponsiveContainer(
            maxWidth: maxWidth,
            additionalPadding: EdgeInsets.all(
              isMobile ? AppSpacing.lg : AppSpacing.xl,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
