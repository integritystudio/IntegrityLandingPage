import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import '../sections/footer_section.dart';
import 'shared_app_bar.dart';

/// Standard scaffold for marketing sub-pages.
///
/// Encapsulates the recurring layout:
/// `Scaffold → SelectionArea → CustomScrollView → SharedAppBar.subPage() → [slivers] → FooterSection()`
///
/// Usage:
/// ```dart
/// SubPageShell(
///   onBack: widget.onBack,
///   onShowCookieSettings: widget.onShowCookieSettings,
///   slivers: [
///     SliverToBoxAdapter(child: _HeroSection()),
///     SliverToBoxAdapter(child: _ContentSection()),
///   ],
/// )
/// ```
class SubPageShell extends StatelessWidget {
  /// Callback for the back button in the app bar
  final VoidCallback? onBack;

  /// Callback for cookie settings in the footer
  final VoidCallback? onShowCookieSettings;

  /// Scroll controller for the CustomScrollView (optional)
  final ScrollController? controller;

  /// Content slivers rendered between the app bar and footer
  final List<Widget> slivers;

  const SubPageShell({
    super.key,
    required this.slivers,
    this.onBack,
    this.onShowCookieSettings,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SharedAppBar.subPage(onBack: onBack),
            ...slivers,
            SliverToBoxAdapter(
              child: FooterSection(onCookieSettings: onShowCookieSettings),
            ),
          ],
        ),
      ),
    );
  }
}
