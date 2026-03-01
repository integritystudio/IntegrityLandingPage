import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/cards.dart';
import '../common/containers.dart';
import '../common/buttons.dart';

/// Services section showcasing platform offerings.
///
/// Displays the six core services with detailed capability lists.
/// Aligned with Content Strategy positioning as "The EU AI Act-Ready
/// Observability Platform".
///
/// Features:
/// - Externalized content via ServicesContent (supports A/B testing)
/// - Responsive grid layout (1/2/3 columns)
/// - Analytics tracking on service interactions
/// - Optional CTA linking to service details
///
/// Usage:
/// ```dart
/// ServicesSection(
///   content: ServicesContent.current, // or AppContent.services
/// )
/// ```
class ServicesSection extends StatelessWidget {
  final ServicesContent content;

  const ServicesSection({
    super.key,
    this.content = const ServicesContent(
      sectionId: 'services',
      title: 'Platform Services',
      subtitle: 'Comprehensive AI Observability for Enterprise',
      description: '',
      services: [],
      ctaText: 'Start Free Trial',
      ctaUrl: '/signup?tier=Team',
    ),
  });

  // Use content from widget or fallback to AppContent
  ServicesContent get _content =>
      content.services.isEmpty ? AppContent.services : content;

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      id: _content.sectionId,
      backgroundColor: AppColors.gray900,
      child: Column(
        children: [
          // Section header
          SectionTitle(
            title: _content.title,
            subtitle: _content.subtitle,
          ),

          if (_content.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Text(
                _content.description,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
          ],

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.75),

          // Services grid
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: _content.services
                .map((service) => _ServiceCard(
                      service: service,
                      onTap: () {
                        AnalyticsService.trackFeatureInteraction(service.title);
                      },
                    ))
                .toList(),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // CTA button
          GradientButton(
            text: _content.ctaText,
            onPressed: () {
              AnalyticsService.trackCTAClick(
                buttonName: _content.ctaText,
                location: 'services_section',
              );
              context.go(_content.ctaUrl);
            },
          ),
        ],
      ),
    );
  }
}

/// Individual service card with icon, description, and capabilities.
class _ServiceCard extends StatelessWidget {
  final ServiceItemContent service;
  final VoidCallback? onTap;

  const _ServiceCard({
    required this.service,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.secondary,
      enableHover: true,
      onTap: onTap,
      semanticLabel: '${service.title} service card',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container with gradient
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
            ),
            child: Icon(
              service.icon,
              size: 28,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            service.title,
            style: AppTypography.headingSM,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Description
          Text(
            service.description,
            style: AppTypography.bodyMD,
          ),

          const SizedBox(height: AppSpacing.lg),

          // Capabilities list
          ...service.capabilities.map((capability) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: AppColors.blue500,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        capability,
                        style: AppTypography.bodySM,
                      ),
                    ),
                  ],
                ),
              )),

          // Optional CTA link
          if (service.ctaText != null && service.ctaUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () {
                AnalyticsService.trackCTAClick(
                  buttonName: service.ctaText!,
                  location: 'service_card_${service.title}',
                );
                final url = service.ctaUrl!;
                if (url.startsWith('/')) {
                  context.go(url);
                } else {
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    service.ctaText!,
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    LucideIcons.arrowRight,
                    size: 16,
                    color: AppColors.blue400,
                  ),
                ],
              ),
            ),
          ],

          // Compliance disclaimer (legal requirement)
          if (service.disclaimer != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.gray800.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                border: Border.all(
                  color: AppColors.gray700.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                service.disclaimer!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.gray500,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
