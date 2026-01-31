import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme.dart';
import '../config/content.dart';
import '../config/content/constants.dart';
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

/// Main landing page composing all sections.
///
/// Features:
/// - Smooth scroll navigation between sections
/// - Scroll depth tracking for analytics
/// - Responsive layout with accessibility support
/// - Semantic regions for screen readers
class LandingPage extends StatefulWidget {
  final VoidCallback? onShowCookieSettings;

  const LandingPage({
    super.key,
    this.onShowCookieSettings,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final ScrollController _scrollController = ScrollController();

  // Section keys for scroll navigation
  final _sectionKeys = <String, GlobalKey>{
    'hero': GlobalKey(),
    'features-explorer': GlobalKey(),
    'social-proof': GlobalKey(),
    'features': GlobalKey(),
    'services': GlobalKey(),
    'about': GlobalKey(),
    'resources': GlobalKey(),
    'contact': GlobalKey(),
    'status': GlobalKey(),
    'pricing': GlobalKey(),
    'cta': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    AnalyticsService.trackPageView('landing');
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final percentage = ((_scrollController.offset / maxScroll) * 100).round();
    AnalyticsService.trackScrollDepth(percentage);
  }

  void _scrollToSection(String sectionName) {
    final key = _sectionKeys[sectionName];
    if (key?.currentContext == null) return;

    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header navigation
            _buildHeaderNav(context, isMobile),

            _buildSection(
              key: _sectionKeys['hero']!,
              label: 'Hero section',
              child: HeroSection(
                onGetStarted: () => _scrollToSection('pricing'),
                onWatchDemo: _handleWatchDemo,
              ),
            ),
            // Tabbed feature explorer (AiSDR-inspired interactive tabs)
            _buildSection(
              key: _sectionKeys['features-explorer']!,
              label: 'Feature explorer section',
              child: const TabbedFeaturesSection(),
            ),
            // Social proof section - hidden until we have real testimonials
            // _buildSection(
            //   key: _sectionKeys['social-proof']!,
            //   label: 'Social proof section',
            //   child: const SocialProofSection(),
            // ),
            _buildSection(
              key: _sectionKeys['features']!,
              label: 'Features section',
              child: const FeaturesSection(),
            ),
            // Services section (platform capabilities)
            _buildSection(
              key: _sectionKeys['services']!,
              label: 'Services section',
              child: const ServicesSection(),
            ),
            // About section (company story, values, team)
            _buildSection(
              key: _sectionKeys['about']!,
              label: 'About section',
              child: const AboutSection(),
            ),
            // Resources section (docs, blog, lead magnets)
            _buildSection(
              key: _sectionKeys['resources']!,
              label: 'Resources section',
              child: const ResourcesSection(),
            ),
            _buildSection(
              key: _sectionKeys['pricing']!,
              label: 'Pricing section',
              child: PricingSection(
                onSelectTier: _handleSelectTier,
              ),
            ),
            // Contact section (form, contact methods)
            _buildSection(
              key: _sectionKeys['contact']!,
              label: 'Contact section',
              child: const ContactSection(),
            ),
            _buildSection(
              key: _sectionKeys['status']!,
              label: 'Status section',
              child: const StatusSection(),
            ),
            _buildSection(
              key: _sectionKeys['cta']!,
              label: 'Call to action section',
              child: CTASection(
                onGetStarted: () => _scrollToSection('pricing'),
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
        onTap: () => _scrollController.animateTo(
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
                  _buildPopupMenuItem('Blog', 'resources'),
                  _buildPopupMenuItem('Pricing', 'pricing'),
                  _buildPopupMenuItem('Contact', 'contact'),
                ],
              ),
            ]
          : [
              // Desktop: inline nav links
              _NavLink(
                text: 'Features',
                onTap: () => _scrollToSection('features'),
              ),
              _NavLink(
                text: 'About',
                onTap: () => _scrollToSection('about'),
              ),
              _NavLink(
                text: 'Blog',
                onTap: () => _scrollToSection('resources'),
              ),
              _NavLink(
                text: 'Pricing',
                onTap: () => _scrollToSection('pricing'),
              ),
              _NavLink(
                text: 'Contact',
                onTap: () => _scrollToSection('contact'),
              ),
              const SizedBox(width: AppSpacing.md),
              // CTA button
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: () => _scrollToSection('pricing'),
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
    _scrollToSection(value);
  }

  void _handleWatchDemo() {
    AnalyticsService.trackDemoRequest();
    DemoModal.show(
      context,
      onScheduleDemo: () => _launchCalendly(),
    );
  }

  void _handleSelectTier(String tier) {
    AnalyticsService.trackPricingView(tier);
    context.go('/signup?tier=$tier');
  }

  Future<void> _launchCalendly() async {
    final uri = Uri.parse(ExternalUrls.calendlyDemo);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Navigation link for header
class _NavLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _NavLink({
    required this.text,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            widget.text,
            style: AppTypography.bodySM.copyWith(
              color: _isHovered ? AppColors.blue400 : AppColors.gray300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
