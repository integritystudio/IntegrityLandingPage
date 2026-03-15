import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content.dart';
import '../services/analytics.dart';
import '../services/content_loader.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/gradient_pill_badge.dart';
import '../widgets/navigation/shared_app_bar.dart';
import '../widgets/sections/contact_section.dart';
import '../widgets/sections/footer_section.dart';
import '../widgets/sections/marketing_hero_section.dart';

/// Standalone contact page with multiple contact options.
///
/// Features:
/// - Hero section with contact context
/// - Contact form for inquiries
/// - Direct contact methods (email, calendar, social)
/// - Office/support hours information
class ContactPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;
  final String? ref;

  const ContactPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
    this.ref,
  });

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('contact', ref: widget.ref);
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
            SharedAppBar.subPage(onBack: widget.onBack),
            SliverToBoxAdapter(
              child: MarketingHeroSection(
                isMobile: ResponsiveUtils.isMobile(context),
                badge: const GradientPillBadge(label: "We're Here to Help"),
                headline: 'Get in Touch',
                subheadline:
                    'Have questions about AI observability? Need help with integration? Our team is ready to assist you.',
              ),
            ),
            const SliverToBoxAdapter(child: _QuickContactSection()),
            SliverToBoxAdapter(child: ContactSection(ref: widget.ref)),
            const SliverToBoxAdapter(child: _SupportInfoSection()),
            SliverToBoxAdapter(
              child: FooterSection(
                onCookieSettings: widget.onShowCookieSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickContactSection extends StatelessWidget {
  const _QuickContactSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            alignment: WrapAlignment.center,
            children: [
              _QuickContactCard(
                icon: LucideIcons.mail,
                title: 'Email Us',
                subtitle: CompanyInfo.email,
                onTap: () => _launchUrl('mailto:${CompanyInfo.email}'),
              ),
              _QuickContactCard(
                icon: LucideIcons.calendar,
                title: 'Schedule a Demo',
                subtitle: ContentLoader.contactScheduleDemoValue,
                onTap: () => context.go('/demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _QuickContactCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickContactCard> createState() => _QuickContactCardState();
}

class _QuickContactCardState extends State<_QuickContactCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Semantics(
        label: widget.title,
        button: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 280,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.gray800 : AppColors.gray800,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            border: Border.all(
              color: _isHovered ? AppColors.blue500 : AppColors.gray700,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.blue500.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.blue500.withValues(alpha: 0.2),
                      AppColors.purple500.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.blue400,
                  size: 24,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.title,
                style: AppTypography.bodyLG.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.subtitle,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _SupportInfoSection extends StatelessWidget {
  const _SupportInfoSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPadding(context),
        vertical: AppSpacing.sectionPadding(context),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text(
                'Support Information',
                style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG)
                    .copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppColors.gray800,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
                  border: Border.all(color: AppColors.gray700),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: LucideIcons.clock,
                      label: 'Response Time',
                      value: 'Within 24 hours for all inquiries',
                    ),
                    const Divider(color: AppColors.gray700, height: 32),
                    _InfoRow(
                      icon: LucideIcons.headphones,
                      label: 'Enterprise Support',
                      value: '24/7 dedicated support for Enterprise plans',
                    ),
                    const Divider(color: AppColors.gray700, height: 32),
                    _InfoRow(
                      icon: LucideIcons.globe,
                      label: 'Coverage',
                      value: 'Global support across all time zones',
                    ),
                    const Divider(color: AppColors.gray700, height: 32),
                    _InfoRow(
                      icon: LucideIcons.bookOpen,
                      label: 'Documentation',
                      value: 'Comprehensive guides and API reference',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlineButton(
                    text: 'View Documentation',
                    onPressed: () {
                      // Navigate to docs when available
                      AnalyticsService.trackCTAClick(
                        buttonName: 'View Documentation',
                        location: 'contact_page',
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  GradientButton(
                    text: 'Check Status',
                    onPressed: () async {
                      final uri = Uri.parse(ExternalUrls.statusPage);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.blue400, size: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMD.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
