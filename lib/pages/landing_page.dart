import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../config/content/constants.dart';
import '../controllers/landing_controller.dart';
import '../widgets/modals/demo_modal.dart';
import '../widgets/sections/hero_section.dart';
import '../widgets/sections/tabbed_features_section.dart';
import '../widgets/sections/features_section.dart';
import '../widgets/sections/services_section.dart';
import '../widgets/sections/about_section.dart';
import '../widgets/sections/resources_section.dart';
import '../widgets/sections/contact_section.dart';
import '../widgets/sections/pricing_section.dart';
import '../widgets/sections/status_section.dart';
import '../widgets/sections/cta_section.dart';
import '../widgets/sections/footer_section.dart';
import '../widgets/common/hover_text_link.dart';

/// Main landing page composing all sections.
///
/// Features:
/// - Smooth scroll navigation between sections
/// - Scroll depth tracking for analytics
/// - Responsive layout with accessibility support
/// - Semantic regions for screen readers
class LandingPage extends StatefulWidget {
  final VoidCallback? onShowCookieSettings;
  final String? scrollToSection;

  const LandingPage({
    super.key,
    this.onShowCookieSettings,
    this.scrollToSection,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final LandingController _controller;

  // Section IDs for registration with the controller
  static const _sectionIds = [
    'hero',
    'features-explorer',
    'social-proof',
    'features',
    'services',
    'about',
    'team',
    'resources',
    'contact',
    'status',
    'pricing',
    'cta',
  ];

  @override
  void initState() {
    super.initState();
    _controller = LandingController(
      onShowDemoModal: _showDemoModal,
    );

    // Register section keys
    for (final id in _sectionIds) {
      _controller.registerSection(id, GlobalKey());
    }

    _controller.initialize();

    // Scroll to section if specified (after first frame)
    if (widget.scrollToSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.scrollToSection(widget.scrollToSection!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useCompactNav = !ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _controller.scrollController,
          slivers: [
            // Header navigation (compact menu for mobile + tablet)
            _buildHeaderNav(context, useCompactNav),

            _buildSection(
              key: _controller.getSectionKey('hero'),
              label: 'Hero section',
              child: HeroSection(
                onGetStarted: () => context.go(Routes.signupTeam),
                onWatchDemo: _handleWatchDemo,
              ),
            ),
            // Tabbed feature explorer (AiSDR-inspired interactive tabs)
            _buildSection(
              key: _controller.getSectionKey('features-explorer'),
              label: 'Feature explorer section',
              child: const TabbedFeaturesSection(),
            ),
            // Social proof section - hidden until we have real testimonials
            // _buildSection(
            //   key: _controller.getSectionKey('social-proof'),
            //   label: 'Social proof section',
            //   child: const SocialProofSection(),
            // ),
            _buildSection(
              key: _controller.getSectionKey('features'),
              label: 'Features section',
              child: const FeaturesSection(),
            ),
            // Services section (platform capabilities)
            _buildSection(
              key: _controller.getSectionKey('services'),
              label: 'Services section',
              child: const ServicesSection(),
            ),
            // About section (company story, values, team)
            _buildSection(
              key: _controller.getSectionKey('about'),
              label: 'About section',
              child: AboutSection(
                teamKey: _controller.getSectionKey('team'),
              ),
            ),
            // Resources section (docs, blog, lead magnets)
            _buildSection(
              key: _controller.getSectionKey('resources'),
              label: 'Resources section',
              child: const ResourcesSection(),
            ),
            _buildSection(
              key: _controller.getSectionKey('pricing'),
              label: 'Pricing section',
              child: PricingSection(
                onSelectTier: _handleSelectTier,
              ),
            ),
            // Contact section (form, contact methods)
            _buildSection(
              key: _controller.getSectionKey('contact'),
              label: 'Contact section',
              child: const ContactSection(),
            ),
            _buildSection(
              key: _controller.getSectionKey('status'),
              label: 'Status section',
              child: const StatusSection(),
            ),
            _buildSection(
              key: _controller.getSectionKey('cta'),
              label: 'Call to action section',
              child: CTASection(
                onGetStarted: () => context.go(Routes.signupTeam),
              ),
            ),
            _buildSection(
              label: 'Footer section',
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a semantic sliver section.
  SliverToBoxAdapter _buildSection({
    GlobalKey? key,
    required String label,
    required Widget child,
  }) {
    Widget content = child;

    if (key != null) {
      content = KeyedSubtree(key: key, child: content);
    }

    return SliverToBoxAdapter(
      child: Semantics(
        label: label,
        child: content,
      ),
    );
  }

  Widget _buildHeaderNav(BuildContext context, bool isMobile) {
    return SliverAppBar(
      backgroundColor: AppColors.gray900.withValues(alpha: 0.95),
      floating: true,
      pinned: true,
      elevation: 0,
      toolbarHeight: isMobile ? 56 : 64,
      title: GestureDetector(
        onTap: () => _controller.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ),
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
                style: (isMobile ? AppTypography.headingSM : AppTypography.headingMD).copyWith(
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: isMobile
          ? [
              // Mobile: hamburger menu
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.menu, color: Colors.white),
                color: AppColors.gray800,
                onSelected: _handleNavItemSelected,
                itemBuilder: (context) => [
                  _buildPopupMenuItem('Features', 'features'),
                  _buildPopupMenuItem('About', 'about'),
                  _buildPopupMenuItem('Team', 'team'),
                  _buildPopupMenuItem('Blog', 'resources'),
                  _buildPopupMenuItem('Pricing', 'pricing'),
                  _buildPopupMenuItem('Docs', Routes.docs),
                  _buildPopupMenuItem('Contact', 'contact'),
                ],
              ),
            ]
          : [
              // Desktop: inline nav links
              HoverTextLink(
                text: 'Features',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('features'),
              ),
              HoverTextLink(
                text: 'About',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('about'),
              ),
              HoverTextLink(
                text: 'Team',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('team'),
              ),
              HoverTextLink(
                text: 'Blog',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('resources'),
              ),
              HoverTextLink(
                text: 'Pricing',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('pricing'),
              ),
              HoverTextLink(
                text: 'Docs',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => context.go(Routes.docs),
              ),
              HoverTextLink(
                text: 'Contact',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('contact'),
              ),
              const SizedBox(width: AppSpacing.md),
              // CTA button
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: () => _controller.scrollToSection('pricing'),
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
                    'Get Started',
                    style: AppTypography.bodySM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(String text, String value) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        text,
        style: AppTypography.bodySM.copyWith(color: Colors.white),
      ),
    );
  }

  void _handleNavItemSelected(String value) {
    if (value.startsWith('/')) {
      context.go(value);
    } else {
      _controller.scrollToSection(value);
    }
  }

  void _handleWatchDemo() {
    _controller.handleRequestDemo();
  }

  void _showDemoModal() {
    if (!mounted) return;
    DemoModal.show(
      context,
      onScheduleDemo: () {
        if (mounted) context.go('/demo');
      },
    );
  }

  void _handleSelectTier(String tier) {
    // PricingSection already tracks analytics; just navigate
    if (mounted) context.go('/signup?tier=$tier');
  }
}

