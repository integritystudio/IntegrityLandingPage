import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme.dart';
import '../config/content/constants.dart';
import '../controllers/landing_controller.dart';
import '../services/analytics.dart';
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
  /// Navigate the current tab rather than opening a new one — url_launcher's
  /// web default is `_blank`, but leaving the marketing site to sign in should
  /// read as a redirect, not a popup.
  static const String _sameTab = '_self';

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
                onGetStarted: () => context.go(Routes.signupGrowth),
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
                onGetStarted: () => context.go(Routes.signupGrowth),
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
                  _buildPopupMenuItem('Contact', 'contact'),
                  _buildPopupMenuItem('Docs', Routes.docs),
                  _buildPopupMenuItem(CTAText.logIn, ExternalUrls.dashboardApp),
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
                text: 'Contact',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => _controller.scrollToSection('contact'),
              ),
              HoverTextLink(
                text: 'Docs',
                defaultColor: AppColors.gray300,
                hoverColor: AppColors.blue400,
                style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                onTap: () => context.go(Routes.docs),
              ),
              const SizedBox(width: AppSpacing.md),
              // Log In button (existing customers -> dashboard SPA's Auth0 login)
              _buildLoginButton(context),
              const SizedBox(width: AppSpacing.sm),
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

  /// Log In button sending existing customers to the dashboard SPA, which
  /// runs its own Auth0 Universal Login (auth code + PKCE).
  Widget _buildLoginButton(BuildContext context) {
    return Semantics(
      label: CTAText.logIn,
      button: true,
      child: TextButton.icon(
        onPressed: _handleLogIn,
        icon: const Icon(
          LucideIcons.logIn,
          size: AppSpacing.md,
          color: AppColors.gray300,
        ),
        label: Text(
          CTAText.logIn,
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray300,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
        ),
      ),
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
    // An absolute URL (scheme present) leaves the app; an app path routes
    // in-place; anything else names a section on this page.
    if (Uri.parse(value).hasScheme) {
      _launchExternal(value);
    } else if (value.startsWith('/')) {
      context.go(value);
    } else {
      _controller.scrollToSection(value);
    }
  }

  /// Send an existing customer to the dashboard SPA, which owns the Auth0
  /// Universal Login redirect. This site never handles their credentials.
  void _handleLogIn() => _launchExternal(ExternalUrls.dashboardApp);

  /// Open an off-site URL, reporting rather than throwing on failure — an
  /// unavailable launcher must not take down the homepage (see #55).
  Future<void> _launchExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), webOnlyWindowName: _sameTab);
    } catch (e, stackTrace) {
      ErrorTrackingService.captureException(
        e,
        stackTrace: stackTrace,
        context: 'landing._launchExternal',
        extra: {'url': url},
      );
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

