import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../services/analytics.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/cards.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/x_icon.dart';
import '../widgets/decorative/animated_orb.dart';
import '../widgets/sections/footer_section.dart';

/// Dedicated About page with visually engaging design.
///
/// Features:
/// - Hero section with split layout (text left, visual right)
/// - By the Numbers stats section
/// - Mission & Vision dual column blocks
/// - Story timeline with numbered visual cards
/// - Core values grid
/// - Team section with intro statement
/// - CTA footer
///
/// Design inspired by enterprise SaaS aesthetics with dark theme,
/// gradient accents, and split layouts.
class AboutPage extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onShowCookieSettings;

  const AboutPage({
    super.key,
    this.onBack,
    this.onShowCookieSettings,
  });

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    AnalyticsService.trackPageView('about');
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
            // App bar
            _buildAppBar(context),

            // Hero Section
            SliverToBoxAdapter(
              child: _AboutHeroSection(
                onGetStarted: () => _launchUrl(ExternalUrls.calendlyDemo),
              ),
            ),

            // By the Numbers
            const SliverToBoxAdapter(
              child: _StatsSection(),
            ),

            // Mission & Vision
            const SliverToBoxAdapter(
              child: _MissionVisionSection(),
            ),

            // Our Story Timeline
            const SliverToBoxAdapter(
              child: _StoryTimelineSection(),
            ),

            // Our Values
            const SliverToBoxAdapter(
              child: _ValuesSection(),
            ),

            // Meet the Team
            const SliverToBoxAdapter(
              child: _TeamSection(),
            ),

            // CTA Section
            SliverToBoxAdapter(
              child: _AboutCTASection(
                onScheduleDemo: () => _launchUrl(ExternalUrls.calendlyDemo),
              ),
            ),

            // Footer
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

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.gray900,
      floating: true,
      pinned: true,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        onPressed: widget.onBack ?? () => context.go('/'),
      ),
      title: Text(
        'About Us',
        style: AppTypography.headingSM.copyWith(color: Colors.white),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: TextButton(
            onPressed: widget.onBack ?? () => context.go('/'),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}

// =============================================================================
// HERO SECTION
// =============================================================================

class _AboutHeroSection extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const _AboutHeroSection({this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Container(
      decoration: AppDecorations.gradientBackground,
      child: Stack(
        children: [
          // Decorative orbs
          const DecorativeOrbs(),

          SectionContainer(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 60 : 100,
            ),
            child: isMobile
                ? _buildMobileLayout(context)
                : _buildDesktopLayout(context, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildTextContent(context, true),
        const SizedBox(height: AppSpacing.xxl),
        _buildVisualElement(context, true),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: _buildTextContent(context, false),
        ),
        const SizedBox(width: AppSpacing.xxl),
        Expanded(
          flex: 4,
          child: _buildVisualElement(context, false),
        ),
      ],
    );
  }

  Widget _buildTextContent(BuildContext context, bool isMobile) {
    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: AppDecorations.statusBadge(AppColors.blue500, opacity: 0.1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: AppDecorations.successDot,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Est. ${CompanyInfo.foundedYear}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.blue400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

        // Headline
        Semantics(
          header: true,
          child: Text(
            'Building Trust in\nAI Systems',
            style: isMobile
                ? AppTypography.headingXL.copyWith(fontSize: 36)
                : AppTypography.headingXL,
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
          ),
        ),

        SizedBox(height: isMobile ? AppSpacing.md : AppSpacing.lg),

        // Subheadline
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 500,
          ),
          child: Text(
            'Integrity Studio provides enterprise AI observability, governance, '
            'and compliance tools that your organization depends on.',
            style: AppTypography.bodyLG,
            textAlign: isMobile ? TextAlign.center : TextAlign.left,
          ),
        ),

        SizedBox(height: isMobile ? AppSpacing.lg : AppSpacing.xl),

        // Anchor points
        _buildAnchorPoints(isMobile),

        SizedBox(height: isMobile ? AppSpacing.xl : AppSpacing.xxl),

        // CTA
        if (isMobile)
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: 'Schedule Demo',
              icon: LucideIcons.calendar,
              onPressed: onGetStarted,
              fullWidth: true,
            ),
          )
        else
          GradientButton(
            text: 'Schedule Demo',
            icon: LucideIcons.calendar,
            onPressed: onGetStarted,
          ),
      ],
    );
  }

  Widget _buildAnchorPoints(bool isMobile) {
    final points = [
      'Enterprise-grade observability built for LLM applications',
      'Purpose-built compliance and audit capabilities',
      'Trusted by teams navigating regulatory change',
    ];

    return Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: points.map((point) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          children: [
            const Icon(
              LucideIcons.check,
              size: 16,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                point,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray300,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildVisualElement(BuildContext context, bool isMobile) {
    // Layered stack visualization representing the platform
    return Container(
      height: isMobile ? 280 : 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gray800.withValues(alpha: 0.8),
            AppColors.gray900.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(
          color: AppColors.gray700.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withValues(alpha: 0.1),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gradient orb inside
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.indigo500.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Layered content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLayerRow(
                  icon: LucideIcons.users,
                  title: 'Application Layer',
                  subtitle: 'User feedback & interactions',
                  color: AppColors.purple500,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildLayerRow(
                  icon: LucideIcons.gitBranch,
                  title: 'Orchestration Layer',
                  subtitle: 'Chain performance & guardrails',
                  color: AppColors.indigo500,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildLayerRow(
                  icon: LucideIcons.bot,
                  title: 'Agentic Layer',
                  subtitle: 'Tool calls & reasoning chains',
                  color: AppColors.blue500,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildLayerRow(
                  icon: LucideIcons.activity,
                  title: 'Model / LLM Layer',
                  subtitle: 'Token usage, latency & costs',
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STATS SECTION
// =============================================================================

class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final stats = [
      _StatData('6', 'Team Members', AppColors.blue500),
      _StatData('12+', 'Avg Yrs Experience', AppColors.indigo500),
      _StatData('2025', 'Founded', AppColors.purple500),
      _StatData('Austin, TX', 'Headquarters', AppColors.blue500),
    ];

    return SectionContainer(
      backgroundColor: AppColors.gray800.withValues(alpha: 0.5),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            'By the Numbers',
            style: AppTypography.headingSM.copyWith(
              color: AppColors.gray400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ResponsiveGrid(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            spacing: AppSpacing.lg,
            children: stats.map((stat) => _StatCard(stat: stat)).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String value;
  final String label;
  final Color accent;

  const _StatData(this.value, this.label, this.accent);
}

class _StatCard extends StatelessWidget {
  final _StatData stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border(
          bottom: BorderSide(
            color: stat.accent,
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              style: (isMobile ? AppTypography.headingMD : AppTypography.headingLG).copyWith(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            stat.label,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray400,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MISSION & VISION SECTION
// =============================================================================

class _MissionVisionSection extends StatelessWidget {
  const _MissionVisionSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final content = AppContent.about;

    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: isMobile
          ? Column(
              children: [
                _MissionVisionCard(
                  icon: LucideIcons.target,
                  title: 'Our Mission',
                  content: content.missionStatement,
                  accentColor: AppColors.blue500,
                ),
                const SizedBox(height: AppSpacing.lg),
                _MissionVisionCard(
                  icon: LucideIcons.eye,
                  title: 'Our Vision',
                  content: content.visionStatement,
                  accentColor: AppColors.indigo500,
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MissionVisionCard(
                    icon: LucideIcons.target,
                    title: 'Our Mission',
                    content: content.missionStatement,
                    accentColor: AppColors.blue500,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _MissionVisionCard(
                    icon: LucideIcons.eye,
                    title: 'Our Vision',
                    content: content.visionStatement,
                    accentColor: AppColors.indigo500,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MissionVisionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color accentColor;

  const _MissionVisionCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: accentColor),
              const SizedBox(width: AppSpacing.md),
              Text(
                title,
                style: AppTypography.headingSM.copyWith(
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            content,
            style: AppTypography.bodyLG.copyWith(
              color: AppColors.gray300,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STORY TIMELINE SECTION
// =============================================================================

class _StoryTimelineSection extends StatelessWidget {
  const _StoryTimelineSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    final storySteps = [
      _StoryStep(
        number: '01',
        title: 'The Problem',
        icon: LucideIcons.alertCircle,
        color: AppColors.blue500,
        content:
            'Integrity Studio was founded with a clear purpose: to solve the visibility problem '
            'in production AI systems. As LLMs and AI agents became critical to business operations, '
            'we saw teams struggling with black-box AI decisions, unpredictable costs, and looming '
            'regulatory requirements like the EU AI Act.',
      ),
      _StoryStep(
        number: '02',
        title: 'The Insight',
        icon: LucideIcons.layers,
        color: AppColors.indigo500,
        content:
            'Our founders built observability tools at scale before, and recognized that AI systems '
            'needed purpose-built monitoring—not retrofitted APM solutions. We designed Integrity Studio '
            'from the ground up for the unique challenges of LLM applications: token-level cost attribution, '
            'multi-step agent tracing, and compliance documentation that satisfies auditors.',
      ),
      _StoryStep(
        number: '03',
        title: 'The Mission',
        icon: LucideIcons.target,
        color: AppColors.purple500,
        content:
            'Today, we help AI teams ship reliable, compliant applications faster. Our platform provides '
            'the visibility they need to debug issues, optimize costs, and demonstrate governance to '
            'stakeholders—all from a single pane of glass.',
      ),
    ];

    return SectionContainer(
      backgroundColor: AppColors.gray800.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            'Our Story',
            style: AppTypography.headingMDResponsive(context),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (isMobile)
            Column(
              children: storySteps
                  .map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _StoryCard(step: step),
                      ))
                  .toList(),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: storySteps
                  .map((step) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: _StoryCard(step: step),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StoryStep {
  final String number;
  final String title;
  final IconData icon;
  final Color color;
  final String content;

  const _StoryStep({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
  });
}

class _StoryCard extends StatelessWidget {
  final _StoryStep step;

  const _StoryCard({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: AppColors.gray700.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Text(
                  step.number,
                  style: AppTypography.caption.copyWith(
                    color: step.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(step.icon, size: 20, color: step.color),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.title,
            style: AppTypography.headingSM.copyWith(
              color: step.color,
            ),
          ),
          Container(
            width: 40,
            height: 2,
            margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
            color: step.color.withValues(alpha: 0.5),
          ),
          Text(
            step.content,
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.gray300,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VALUES SECTION
// =============================================================================

class _ValuesSection extends StatelessWidget {
  const _ValuesSection();

  @override
  Widget build(BuildContext context) {
    final content = AppContent.about;

    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.isMobile(context) ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            'Our Values',
            style: AppTypography.headingMDResponsive(context),
          ),
          const SizedBox(height: AppSpacing.xl),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            spacing: AppSpacing.xl,
            children: content.values
                .map((value) => _ValueCard(value: value))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final CompanyValueContent value;

  const _ValueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with subtle background
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppColors.blue500.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                radius: 1.5,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
            child: GradientIconContainer(
              icon: value.icon,
              borderRadius: AppSpacing.radiusMD,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value.title,
            style: AppTypography.headingSM,
          ),
          Container(
            width: 30,
            height: 2,
            margin: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Text(
            value.description,
            style: AppTypography.bodySM.copyWith(
              color: AppColors.gray300,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEAM SECTION
// =============================================================================

class _TeamSection extends StatelessWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final content = AppContent.about;

    return SectionContainer(
      backgroundColor: AppColors.gray800.withValues(alpha: 0.3),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Text(
            'Meet the Team',
            style: AppTypography.headingMDResponsive(context),
          ),
          const SizedBox(height: AppSpacing.md),
          // Team introduction statement
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              'A diverse team of AI experts, regulatory specialists, and infrastructure engineers—'
              'united by the mission to make AI systems trustworthy and observable.',
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.gray400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            spacing: AppSpacing.xl,
            children: content.team
                .map((member) => _TeamMemberCard(member: member))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatefulWidget {
  final TeamMemberContent member;

  const _TeamMemberCard({required this.member});

  @override
  State<_TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<_TeamMemberCard> {
  bool _isHovered = false;

  Color get _roleBadgeColor {
    final role = widget.member.role.toLowerCase();
    if (role.contains('founder') || role.contains('ceo') || role.contains('president')) {
      return AppColors.purple500;
    } else if (role.contains('chief') || role.contains('head')) {
      return AppColors.indigo500;
    }
    return AppColors.blue500;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.identity(),
        child: GlassCard(
          tier: GlassCardTier.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with hover effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: _isHovered
                    ? Matrix4.diagonal3Values(1.05, 1.05, 1)
                    : Matrix4.identity(),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.gray700,
                  backgroundImage: widget.member.avatarAsset != null
                      ? AssetImage(widget.member.avatarAsset!)
                      : null,
                  child: widget.member.avatarAsset == null
                      ? Text(
                          widget.member.name.split(' ').map((n) => n[0]).join(),
                          style: AppTypography.headingMDResponsive(context).copyWith(
                            color: AppColors.blue400,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              Text(
                widget.member.name,
                style: AppTypography.headingSM,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _roleBadgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: _roleBadgeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  widget.member.role,
                  style: AppTypography.caption.copyWith(
                    color: _roleBadgeColor,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Bio
              Text(
                widget.member.bio,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray300,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Social links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.member.linkedInUrl != null)
                    _SocialIconButton(
                      icon: LucideIcons.linkedin,
                      url: widget.member.linkedInUrl!,
                      tooltip: 'LinkedIn',
                      hoverColor: AppColors.blue500,
                    ),
                  if (widget.member.websiteUrl != null)
                    _SocialIconButton(
                      icon: LucideIcons.globe,
                      url: widget.member.websiteUrl!,
                      tooltip: 'Website',
                      hoverColor: AppColors.indigo500,
                    ),
                  if (widget.member.xUrl != null)
                    _SocialIconButton(
                      iconBuilder: (color) => XIcon(size: 20, color: color),
                      url: widget.member.xUrl!,
                      tooltip: 'X',
                      hoverColor: AppColors.purple500,
                    ),
                  if (widget.member.githubUrl != null)
                    _SocialIconButton(
                      icon: LucideIcons.github,
                      url: widget.member.githubUrl!,
                      tooltip: 'GitHub',
                      hoverColor: AppColors.gray300,
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

class _SocialIconButton extends StatefulWidget {
  final IconData? icon;
  final Widget Function(Color color)? iconBuilder;
  final String url;
  final String tooltip;
  final Color hoverColor;

  const _SocialIconButton({
    this.icon,
    this.iconBuilder,
    required this.url,
    required this.tooltip,
    required this.hoverColor,
  }) : assert(icon != null || iconBuilder != null,
            'Either icon or iconBuilder must be provided');

  @override
  State<_SocialIconButton> createState() => _SocialIconButtonState();
}

class _SocialIconButtonState extends State<_SocialIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _isHovered ? widget.hoverColor : AppColors.gray400;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _isHovered
              ? Matrix4.diagonal3Values(1.2, 1.2, 1)
              : Matrix4.identity(),
          child: IconButton(
            icon: widget.iconBuilder != null
                ? widget.iconBuilder!(color)
                : Icon(widget.icon, size: 20, color: color),
            hoverColor: widget.hoverColor.withValues(alpha: 0.1),
            onPressed: () => launchUrl(Uri.parse(widget.url)),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CTA SECTION
// =============================================================================

class _AboutCTASection extends StatelessWidget {
  final VoidCallback? onScheduleDemo;

  const _AboutCTASection({this.onScheduleDemo});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
      ),
      child: Container(
        padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxl),
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
              "Let's Talk About Trustworthy AI",
              style: isMobile
                  ? AppTypography.headingMD
                  : AppTypography.headingLG,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Whether you\'re evaluating AI observability solutions, have questions about '
                'EU AI Act compliance, or want to see how we can help your team—we\'re here.',
                style: AppTypography.bodyLG.copyWith(
                  color: AppColors.gray300,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                GradientButton(
                  text: 'Schedule Demo',
                  icon: LucideIcons.calendar,
                  onPressed: onScheduleDemo,
                ),
                OutlineButton(
                  text: 'Contact Us',
                  icon: LucideIcons.mail,
                  onPressed: () => launchUrl(Uri.parse('mailto:${CompanyInfo.email}')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
