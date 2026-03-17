import 'package:flutter/material.dart';
import '../../services/analytics.dart';
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
class SubPageShell extends StatefulWidget {
  /// Callback for the back button in the app bar
  final VoidCallback? onBack;

  /// Callback for cookie settings in the footer
  final VoidCallback? onShowCookieSettings;

  /// Scroll controller for the CustomScrollView (optional)
  final ScrollController? controller;

  /// Content slivers rendered between the app bar and footer
  final List<Widget> slivers;

  /// Optional page name for analytics tracking; fires trackPageView once on init
  final String? analyticsPageName;

  const SubPageShell({
    super.key,
    required this.slivers,
    this.onBack,
    this.onShowCookieSettings,
    this.controller,
    this.analyticsPageName,
  });

  @override
  State<SubPageShell> createState() => _SubPageShellState();
}

class _SubPageShellState extends State<SubPageShell> {
  @override
  void initState() {
    super.initState();
    if (widget.analyticsPageName != null) {
      AnalyticsService.trackPageView(widget.analyticsPageName!);
    }
  }

  @override
  void didUpdateWidget(SubPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analyticsPageName != null &&
        widget.analyticsPageName != oldWidget.analyticsPageName) {
      AnalyticsService.trackPageView(widget.analyticsPageName!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: widget.controller,
          slivers: [
            SharedAppBar.subPage(onBack: widget.onBack),
            ...widget.slivers,
            SliverToBoxAdapter(
              child: FooterSection(onCookieSettings: widget.onShowCookieSettings),
            ),
          ],
        ),
      ),
    );
  }
}
