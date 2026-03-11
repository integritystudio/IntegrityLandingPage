import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/content/constants.dart';
import '../../theme/theme.dart';

/// Navigation link item configuration
class NavItem {
  final String text;
  final String? route;
  final String? sectionId;
  final VoidCallback? onTap;

  const NavItem({
    required this.text,
    this.route,
    this.sectionId,
    this.onTap,
  });
}

/// Shared app bar for all pages
///
/// Supports two modes:
/// 1. Landing page mode: scroll-based navigation with [scrollController]
/// 2. Sub-page mode: route-based navigation with back button
class SharedAppBar extends StatelessWidget {
  /// Scroll controller for landing page scroll-to-section navigation
  final ScrollController? scrollController;

  /// Callback when back button is pressed (sub-pages only)
  final VoidCallback? onBack;

  /// Whether to show the back button
  final bool showBackButton;

  /// Custom navigation items (optional, defaults to standard nav)
  final List<NavItem>? navItems;

  /// Section keys for scroll-to navigation
  final Map<String, GlobalKey>? sectionKeys;

  /// CTA button text
  final String ctaText;

  /// CTA button route
  final String ctaRoute;

  const SharedAppBar({
    super.key,
    this.scrollController,
    this.onBack,
    this.showBackButton = false,
    this.navItems,
    this.sectionKeys,
    this.ctaText = 'Get Started',
    this.ctaRoute = '/signup?tier=Team',
  });

  /// Factory for landing page with scroll navigation
  factory SharedAppBar.landing({
    required ScrollController scrollController,
    required Map<String, GlobalKey> sectionKeys,
  }) {
    return SharedAppBar(
      scrollController: scrollController,
      sectionKeys: sectionKeys,
      showBackButton: false,
    );
  }

  /// Factory for sub-pages with route navigation
  factory SharedAppBar.subPage({
    VoidCallback? onBack,
    List<NavItem>? navItems,
  }) {
    return SharedAppBar(
      showBackButton: true,
      onBack: onBack,
      navItems: navItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    // Use desktop breakpoint for inline nav — 7 nav items + CTA overflows
    // the actions row at tablet widths (768-1023px).
    final useCompactNav = !ResponsiveUtils.isDesktop(context);

    return SliverAppBar(
      backgroundColor: AppColors.gray900.withValues(alpha: 0.95),
      floating: true,
      pinned: true,
      elevation: 0,
      toolbarHeight: isMobile ? 56 : 64,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
              tooltip: 'Back',
            )
          : null,
      title: _buildTitle(context, isMobile),
      actions: useCompactNav
          ? _buildMobileActions(context)
          : _buildDesktopActions(context),
    );
  }

  Widget _buildTitle(BuildContext context, bool isMobile) {
    return Semantics(
      label: 'Navigate to home',
      button: true,
      child: GestureDetector(
        onTap: () {
        if (scrollController != null) {
          scrollController!.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          context.go('/');
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.shield,
            color: AppColors.blue500,
            size: isMobile ? 24 : 28,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              CompanyInfo.name,
              style: (isMobile ? AppTypography.headingSM : AppTypography.headingMD)
                  .copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      ),
    );
  }

  List<Widget> _buildMobileActions(BuildContext context) {
    final items = _getNavItems(context);

    return [
      PopupMenuButton<String>(
        icon: const Icon(LucideIcons.menu, color: Colors.white),
        color: AppColors.gray800,
        onSelected: (value) => _handleNavSelection(context, value),
        itemBuilder: (context) => items
            .map((item) => PopupMenuItem<String>(
                  value: item.sectionId ?? item.route ?? item.text,
                  child: Text(
                    item.text,
                    style: AppTypography.bodySM.copyWith(color: Colors.white),
                  ),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _buildDesktopActions(BuildContext context) {
    final items = _getNavItems(context);

    return [
      ...items.map((item) => NavLink(
            text: item.text,
            onTap: () => _handleNavItem(context, item),
          )),
      const SizedBox(width: AppSpacing.md),
      Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: TextButton(
          onPressed: () => context.go(ctaRoute),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.blue600,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
          ),
          child: Text(
            ctaText,
            style: AppTypography.bodySM.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];
  }

  List<NavItem> _getNavItems(BuildContext context) {
    if (navItems != null) return navItems!;

    // Default nav items depend on whether we're in landing or sub-page mode
    if (scrollController != null) {
      // Landing page: scroll-based nav
      return const [
        NavItem(text: 'Features', sectionId: 'features'),
        NavItem(text: 'About', sectionId: 'about'),
        NavItem(text: 'Team', sectionId: 'team'),
        NavItem(text: 'Blog', sectionId: 'resources'),
        NavItem(text: 'Pricing', sectionId: 'pricing'),
        NavItem(text: 'Contact', sectionId: 'contact'),
        NavItem(text: 'Docs', route: Routes.docs),
      ];
    } else {
      // Sub-page: route-based nav (Team omitted — About scrolls nearby)
      return const [
        NavItem(text: 'Features', route: '/?section=features'),
        NavItem(text: 'About', route: '/?section=about'),
        NavItem(text: 'Pricing', route: '/pricing'),
        NavItem(text: 'Contact', route: '/contact'),
        NavItem(text: 'Docs', route: Routes.docs),
      ];
    }
  }

  void _handleNavItem(BuildContext context, NavItem item) {
    if (item.onTap != null) {
      item.onTap!();
    } else if (item.sectionId != null && sectionKeys != null) {
      _scrollToSection(item.sectionId!);
    } else if (item.route != null) {
      context.go(item.route!);
    }
  }

  void _handleNavSelection(BuildContext context, String value) {
    // Check if it's a section ID or route
    if (sectionKeys?.containsKey(value) == true) {
      _scrollToSection(value);
    } else if (value.startsWith('/')) {
      context.go(value);
    } else {
      // Try as section, fallback to route
      if (scrollController != null && sectionKeys?.containsKey(value) == true) {
        _scrollToSection(value);
      } else {
        context.go('/$value');
      }
    }
  }

  void _scrollToSection(String sectionId) {
    final key = sectionKeys?[sectionId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
}

/// Navigation link with hover effect
class NavLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const NavLink({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  State<NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        label: widget.text,
        button: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              widget.text,
              style: AppTypography.bodySM.copyWith(
                color: _isHovered ? AppColors.blue400 : AppColors.gray300,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
