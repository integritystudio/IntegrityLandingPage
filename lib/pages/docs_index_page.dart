import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/navigation/doc_page_scaffold.dart';

/// Documentation index page.
///
/// Landing page for /docs that links to all documentation sections.
class DocsIndexPage extends StatelessWidget {
  final VoidCallback? onBack;

  const DocsIndexPage({
    super.key,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.gray900,
      body: CustomScrollView(
        slivers: [
          // App bar
          DocPageAppBar(title: 'Documentation', onBack: onBack),

          // Hero Section
          SliverToBoxAdapter(
            child: _HeroSection(isMobile: isMobile),
          ),

          // Documentation Cards
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Browse Documentation',
                    style: AppTypography.headingMD.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DocsGrid(isMobile: isMobile),
                ],
              ),
            ),
          ),

          // Quick Links Section
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: const _QuickLinksSection(),
            ),
          ),

          // Footer
          const SliverToBoxAdapter(child: DocPageFooter()),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final bool isMobile;

  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.gray900,
            AppColors.gray800.withValues(alpha: 0.5),
            AppColors.gray900,
          ],
        ),
      ),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(
                  color: AppColors.blue500.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.bookOpen,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Developer Resources',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Headline
            Text(
              'Integrity Studio Documentation',
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 28)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                'Everything you need to integrate, configure, and get the most out of Integrity Studio. From quick start guides to API references.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Search hint
            Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.gray800,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
                border: Border.all(color: AppColors.gray700),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.search, size: 20, color: AppColors.gray500),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      'Search documentation...',
                      style: AppTypography.bodyMD.copyWith(
                        color: AppColors.gray500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray700,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                    ),
                    child: Text(
                      '\u2318K',
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.gray400,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocsGrid extends StatelessWidget {
  final bool isMobile;

  const _DocsGrid({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final docs = [
      _DocCategory(
        icon: LucideIcons.rocket,
        title: 'Getting Started',
        description: 'Quick start guides to get your first traces flowing in under ${PlatformMetrics.setupTime}.',
        url: '/docs/quickstart',
        color: AppColors.success,
        topics: ['Python SDK', 'TypeScript', 'OpenTelemetry', 'Dashboard'],
      ),
      _DocCategory(
        icon: LucideIcons.code2,
        title: 'API Reference',
        description: 'Complete API documentation with examples for all endpoints and SDK methods.',
        url: '/api',
        color: const Color(0xFF06B6D4),
        topics: ['Trace Ingestion', 'Query API', 'Alerts API', 'Auth'],
      ),
      _DocCategory(
        icon: LucideIcons.plug,
        title: 'Integrations',
        description: 'OpenTelemetry interoperability, backend compatibility, and data flow.',
        url: '/docs/integrations',
        color: AppColors.purple500,
        topics: ['OpenTelemetry', 'Dual Export', 'SigNoz', 'Langtrace'],
      ),
      _DocCategory(
        icon: LucideIcons.bell,
        title: 'Alerts & Monitoring',
        description: 'Configure budget alerts, anomaly detection, and incident routing.',
        url: '/docs/alerts',
        color: AppColors.warning,
        topics: ['Budget Alerts', 'Anomaly', 'PagerDuty', 'Slack'],
      ),
      _DocCategory(
        icon: LucideIcons.gitBranch,
        title: 'Distributed Tracing',
        description: 'End-to-end request tracing, span analysis, and performance debugging.',
        url: '/docs/tracing',
        color: AppColors.blue500,
        topics: ['Spans', 'Context', 'Correlation', 'Latency'],
      ),
      _DocCategory(
        icon: LucideIcons.activity,
        title: 'Observability Guide',
        description: 'Context management, token optimization, and cost efficiency strategies.',
        url: '/docs/llm-observability',
        color: AppColors.blue400,
        topics: ['Tokens', 'Cost', 'Context', 'Metrics'],
      ),
      _DocCategory(
        icon: LucideIcons.shield,
        title: 'Compliance',
        description: 'EU AI Act preparation, audit trails, and governance configuration.',
        url: '/compliance',
        color: const Color(0xFF8B5CF6),
        topics: ['EU AI Act', 'Risk Class', 'Audit Trails', 'GDPR'],
        comingSoon: true,
      ),
      _DocCategory(
        icon: LucideIcons.bot,
        title: 'Agent Observability',
        description: 'Monitor AI agents, tool calls, reasoning chains, and decision trees.',
        url: '/docs/agents',
        color: const Color(0xFFEC4899),
        topics: ['LangChain', 'Tool Calls', 'Reasoning', 'Multi-step'],
        comingSoon: true,
      ),
    ];

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: docs.map((doc) => _DocCard(doc: doc, isMobile: isMobile)).toList(),
    );
  }
}

class _DocCategory {
  final IconData icon;
  final String title;
  final String description;
  final String url;
  final Color color;
  final List<String> topics;
  final bool comingSoon;

  const _DocCategory({
    required this.icon,
    required this.title,
    required this.description,
    required this.url,
    required this.color,
    required this.topics,
    this.comingSoon = false,
  });
}

class _DocCard extends StatelessWidget {
  final _DocCategory doc;
  final bool isMobile;

  const _DocCard({required this.doc, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final cardWidth = isMobile ? double.infinity : 420.0;

    return Semantics(
      label: doc.title,
      button: true,
      child: GestureDetector(
        onTap: doc.comingSoon
            ? null
            : () => context.go(doc.url),
        child: MouseRegion(
        cursor: doc.comingSoon ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.gray800,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            border: Border.all(
              color: doc.comingSoon ? AppColors.gray700 : doc.color.withValues(alpha: 0.3),
            ),
          ),
          child: Opacity(
            opacity: doc.comingSoon ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: doc.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                      ),
                      child: Icon(doc.icon, color: doc.color, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  doc.title,
                                  style: AppTypography.headingSM.copyWith(
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (doc.comingSoon) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray700,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                                  ),
                                  child: Text(
                                    'Coming Soon',
                                    style: AppTypography.bodySM.copyWith(
                                      color: AppColors.gray400,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!doc.comingSoon)
                      Icon(
                        LucideIcons.arrowRight,
                        size: 18,
                        color: AppColors.gray500,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  doc.description,
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: doc.topics
                      .map((topic) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: doc.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                            ),
                            child: Text(
                              topic,
                              style: AppTypography.bodySM.copyWith(
                                color: doc.color,
                                fontSize: 11,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _QuickLinksSection extends StatelessWidget {
  const _QuickLinksSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Links',
            style: AppTypography.headingSM.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.md,
            children: [
              _QuickLink(
                icon: LucideIcons.code,
                label: 'GitHub',
                url: 'https://github.com/integritystudio',
              ),
              _QuickLink(
                icon: LucideIcons.messageCircle,
                label: 'Discord',
                url: 'https://discord.gg/integritystudio',
              ),
              _QuickLink(
                icon: LucideIcons.mail,
                label: 'Support',
                url: '/contact',
              ),
              _QuickLink(
                icon: LucideIcons.fileText,
                label: 'Changelog',
                url: '/blog',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      link: true,
      child: GestureDetector(
        onTap: () async {
          if (url.startsWith('http')) {
            final uri = Uri.parse(url);
            const mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
            await launchUrl(uri, mode: mode);
          } else {
            context.go(url);
          }
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.gray400),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.bodyMD.copyWith(
                  color: AppColors.gray300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
