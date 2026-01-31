import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../common/containers.dart';
import '../common/x_icon.dart';

/// Launch URL with web-compatible mode
Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  const mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
  await launchUrl(uri, mode: mode);
}

/// Footer section with links and legal information
///
/// LEGAL REQUIREMENT: Must include links to:
/// - Privacy Policy
/// - Terms of Service
/// - Cookie Settings (GDPR)
///
/// Usage:
/// ```dart
/// FooterSection(
///   onCookieSettings: () => showCookieBanner(),
///   onNavigateToBlog: () => Navigator.pushNamed(context, '/blog'),
/// )
/// ```
class FooterSection extends StatelessWidget {
  final VoidCallback? onCookieSettings;
  final VoidCallback? onNavigateToBlog;

  const FooterSection({
    super.key,
    this.onCookieSettings,
    this.onNavigateToBlog,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final currentYear = DateTime.now().year;

    return Container(
      color: AppColors.gray900,
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
        ),
        child: Column(
          children: [
            if (isMobile) _buildMobileLayout(context) else _buildDesktopLayout(context),
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.gray700),
            const SizedBox(height: AppSpacing.lg),
            // Compliance disclaimer (legal requirement)
            _buildComplianceDisclaimer(isMobile),
            const SizedBox(height: AppSpacing.lg),
            _buildBottomBar(currentYear, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand column
        Expanded(
          flex: 2,
          child: _buildBrandColumn(),
        ),
        // Link columns
        ..._linkSections.map((section) => Expanded(
              child: _buildLinkColumn(context, section),
            )),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandColumn(),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.lg,
          children: _linkSections.map((section) {
            return SizedBox(
              width: 150,
              child: _buildLinkColumn(context, section),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IntegrityStudio',
          style: AppTypography.headingSM.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'Enterprise-grade AI observability platform for monitoring, debugging, and optimizing LLM applications.',
            style: AppTypography.bodySM,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _SocialLink(
              iconWidget: const XIcon(size: 20, color: AppColors.gray400),
              url: ExternalUrls.x,
              label: 'X',
            ),
            const SizedBox(width: AppSpacing.md),
            const _SocialLink(
              icon: LucideIcons.linkedin,
              url: ExternalUrls.linkedIn,
              label: 'LinkedIn',
            ),
            const SizedBox(width: AppSpacing.md),
            const _SocialLink(
              icon: LucideIcons.github,
              url: ExternalUrls.github,
              label: 'GitHub',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkColumn(BuildContext context, _LinkSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: AppTypography.bodyMD.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...section.links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FooterLink(
                text: link.text,
                onTap: () {
                  // Handle blog navigation specially
                  if (link.url == Routes.blog) {
                    if (onNavigateToBlog != null) {
                      onNavigateToBlog!();
                    } else {
                      context.go(Routes.blog);
                    }
                  } else if (link.url.startsWith('http')) {
                    // External URLs - launch in browser
                    _launchUrl(link.url);
                  } else if (link.url.startsWith('#')) {
                    // Anchor links - navigate to home
                    context.go(Routes.home);
                  } else {
                    // Internal routes - navigate directly
                    context.go(link.url);
                  }
                },
              ),
            )),
      ],
    );
  }

  Widget _buildComplianceDisclaimer(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.md : AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      decoration: AppDecorations.card(
        backgroundColor: AppColors.gray800.withValues(alpha: 0.5),
        borderColor: AppColors.gray700.withValues(alpha: 0.5),
        radius: AppSpacing.radiusSM,
      ),
      child: Text(
        ComplianceDisclaimers.general,
        style: AppTypography.caption.copyWith(
          color: AppColors.gray500,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomBar(int year, bool isMobile) {
    return Builder(
      builder: (context) {
        if (isMobile) {
          return Column(
            children: [
              Text(
                '$year Integrity Studio. All rights reserved.',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _FooterLink(
                    text: 'Privacy',
                    onTap: () => context.go(Routes.privacy),
                  ),
                  _FooterLink(
                    text: 'Terms',
                    onTap: () => context.go(Routes.terms),
                  ),
                  _FooterLink(
                    text: 'Cookies',
                    onTap: () => context.go(Routes.cookies),
                  ),
                  _FooterLink(
                    text: 'Accessibility',
                    onTap: () => context.go(Routes.accessibility),
                  ),
                  _FooterLink(
                    text: 'Cookie Settings',
                    onTap: onCookieSettings,
                  ),
                ],
              ),
            ],
          );
        }

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            Text(
              '$year Integrity Studio. All rights reserved.',
              style: AppTypography.caption,
            ),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _FooterLink(
                  text: 'Privacy Policy',
                  onTap: () => context.go(Routes.privacy),
                ),
                _FooterLink(
                  text: 'Terms of Service',
                  onTap: () => context.go(Routes.terms),
                ),
                _FooterLink(
                  text: 'Cookie Policy',
                  onTap: () => context.go(Routes.cookies),
                ),
                _FooterLink(
                  text: 'Accessibility',
                  onTap: () => context.go(Routes.accessibility),
                ),
                _FooterLink(
                  text: 'Cookie Settings',
                  onTap: onCookieSettings,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SocialLink extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String url;
  final String label;

  const _SocialLink({
    this.icon,
    this.iconWidget,
    required this.url,
    required this.label,
  }) : assert(icon != null || iconWidget != null,
            'Either icon or iconWidget must be provided');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: IconButton(
        icon: iconWidget ?? Icon(icon, size: 20),
        color: AppColors.gray400,
        hoverColor: AppColors.gray700,
        onPressed: () => _launchUrl(url),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const _FooterLink({
    required this.text,
    this.onTap,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: AppTypography.bodySM.copyWith(
            color: _isHovered ? AppColors.textPrimary : AppColors.gray400,
          ),
        ),
      ),
    );
  }
}

class _LinkSection {
  final String title;
  final List<_LinkItem> links;

  const _LinkSection({
    required this.title,
    required this.links,
  });
}

class _LinkItem {
  final String text;
  final String url;
  const _LinkItem({
    required this.text,
    required this.url,
  });
}

List<_LinkSection> get _linkSections => [
  _LinkSection(
    title: 'Product',
    links: [
      _LinkItem(text: 'Features', url: '/features'),
      _LinkItem(text: 'Pricing', url: Routes.pricing),
      _LinkItem(text: 'Documentation', url: Routes.docs),
      _LinkItem(text: 'API Reference', url: Routes.api),
    ],
  ),
  _LinkSection(
    title: 'Company',
    links: [
      _LinkItem(text: 'About', url: Routes.about),
      _LinkItem(text: 'Blog', url: Routes.blog),
      _LinkItem(text: 'Sources', url: Routes.sources),
      _LinkItem(text: 'Careers', url: Routes.careers),
      _LinkItem(text: 'Contact', url: Routes.contact),
    ],
  ),
  _LinkSection(
    title: 'Resources',
    links: [
      _LinkItem(text: 'Help Center', url: '/support'),
      _LinkItem(text: 'Status', url: Routes.status),
      _LinkItem(text: 'Security', url: Routes.security),
    ],
  ),
];
