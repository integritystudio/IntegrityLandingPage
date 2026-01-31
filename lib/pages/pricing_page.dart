import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/sections/pricing_section.dart';
import '../widgets/sections/footer_section.dart';

/// Standalone pricing page with full pricing details.
///
/// Features:
/// - Hero section with value proposition
/// - Full pricing tier comparison
/// - FAQ section
/// - CTA to contact sales
class PricingPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const PricingPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('pricing');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: SelectionArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              key: const Key('pricing-hero-section'),
              child: const _PricingHeroSection(),
            ),
            SliverToBoxAdapter(
              key: const Key('pricing-tiers-section'),
              child: PricingSection(
                onSelectTier: (tier) => _handleSelectTier(context, tier),
              ),
            ),
            SliverToBoxAdapter(
              key: const Key('faq-section'),
              child: const _FAQSection(),
            ),
            SliverToBoxAdapter(
              key: const Key('pricing-cta-section'),
              child: const _PricingCTASection(),
            ),
            SliverToBoxAdapter(
              key: const Key('footer-section'),
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SliverAppBar(
      backgroundColor: AppColors.gray900.withValues(alpha: 0.95),
      floating: true,
      pinned: true,
      elevation: 0,
      toolbarHeight: isMobile ? 56 : 64,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: widget.onBack ?? () => context.go('/'),
        tooltip: 'Back',
      ),
      title: GestureDetector(
        onTap: () => context.go('/'),
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
                style: (isMobile
                        ? AppTypography.headingSM
                        : AppTypography.headingMD)
                    .copyWith(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!isMobile) ...[
          _NavLink(
            text: 'Features',
            onTap: () => context.go('/'),
          ),
          _NavLink(
            text: 'About',
            onTap: () => context.go('/about'),
          ),
          _NavLink(
            text: 'Contact',
            onTap: () => context.go('/contact'),
          ),
          const SizedBox(width: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: TextButton(
              onPressed: () => context.go('/signup'),
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
      ],
    );
  }

  void _handleSelectTier(BuildContext context, String tier) {
    AnalyticsService.trackPricingView(tier);
    context.go('/signup?tier=$tier');
  }
}

class _PricingHeroSection extends StatelessWidget {
  const _PricingHeroSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: isMobile ? 48 : 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray800,
            AppColors.gray900,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue500.withValues(alpha: 0.2),
                  AppColors.purple500.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: AppColors.blue500.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Simple, Transparent Pricing',
              style: AppTypography.bodySM.copyWith(
                color: AppColors.blue400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Choose Your Plan',
            style: (isMobile ? AppTypography.headingLG : AppTypography.headingXL).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Text(
              'Start free and scale as your AI operations grow. All plans include core observability features.',
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQSection extends StatelessWidget {
  const _FAQSection();

  static const _faqs = [
    {
      'question': 'Can I switch plans at any time?',
      'answer':
          'Yes, you can upgrade or downgrade your plan at any time. Changes take effect immediately, and billing is prorated.',
    },
    {
      'question': 'What happens when I exceed my token limit?',
      'answer':
          'You\'ll receive alerts as you approach your limit. You can either upgrade your plan or purchase additional tokens at our standard overage rate.',
    },
    {
      'question': 'Do you offer a free trial?',
      'answer':
          'Our Starter plan is free forever with 100K tokens/month. For Enterprise features, we offer a 14-day free trial with full access.',
    },
    {
      'question': 'What payment methods do you accept?',
      'answer':
          'We accept all major credit cards, ACH transfers, and wire transfers for Enterprise accounts. Annual billing is available for additional savings.',
    },
    {
      'question': 'Is there a setup fee?',
      'answer':
          'No setup fees for any plan. Enterprise customers receive complimentary onboarding and integration support.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      color: AppColors.gray800,
      child: Column(
        children: [
          Text(
            'Frequently Asked Questions',
            style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: _faqs.map((faq) => _FAQItem(faq: faq)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final Map<String, String> faq;

  const _FAQItem({required this.faq});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.faq['question']!,
                        style: AppTypography.bodyLG.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? LucideIcons.minus : LucideIcons.plus,
                      color: AppColors.gray400,
                      size: 20,
                    ),
                  ],
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.faq['answer']!,
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PricingCTASection extends StatelessWidget {
  const _PricingCTASection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: EdgeInsets.all(isMobile ? AppSpacing.xl : AppSpacing.xxl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.blue600.withValues(alpha: 0.2),
                AppColors.purple600.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(
              color: AppColors.blue500.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Need a Custom Solution?',
                style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Our Enterprise plan offers unlimited tokens, dedicated support, custom integrations, and SLAs tailored to your needs.',
                style: AppTypography.bodyLG.copyWith(color: AppColors.gray400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              GradientButton(
                text: 'Contact Sales',
                onPressed: () =>
                    context.go('/contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _NavLink({required this.text, required this.onTap});

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
