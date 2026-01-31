import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/cards.dart';
import '../common/containers.dart';
import '../common/buttons.dart';

/// Resources section with documentation, blog posts, and lead magnets.
///
/// Content pillars: EU AI Act Compliance, LLM Cost Optimization,
/// Agent Observability, Technical Tutorials
///
/// Features:
/// - Documentation category cards
/// - Featured blog post previews
/// - Lead magnet downloads (EU AI Act Checklist, LLM Cost Calculator)
/// - Dual CTAs for blog and docs
///
/// Usage:
/// ```dart
/// ResourcesSection(
///   content: ResourcesContent.current, // or AppContent.resources
/// )
/// ```
class ResourcesSection extends StatelessWidget {
  final ResourcesContent content;

  const ResourcesSection({
    super.key,
    this.content = const ResourcesContent(
      sectionId: 'resources',
      title: 'Resources',
      subtitle: '',
      documentation: [],
      featuredPosts: [],
      leadMagnets: [],
      blogCtaText: 'View All',
      blogCtaUrl: '/blog',
      docsCtaText: 'Browse Docs',
      docsCtaUrl: '/docs',
    ),
  });

  // Use content from widget or fallback to AppContent
  ResourcesContent get _content =>
      content.documentation.isEmpty ? AppContent.resources : content;

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

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Featured blog posts
          _buildBlogSection(context),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Documentation categories
          _buildDocumentationSection(context),

          const SizedBox(height: AppSpacing.xxl),

          // CTAs
          _buildCTARow(context),
        ],
      ),
    );
  }

  Widget _buildDocumentationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documentation',
          style: AppTypography.headingSM,
        ),
        const SizedBox(height: AppSpacing.lg),
        Builder(
          builder: (context) => ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            children: _content.documentation
                .map((doc) => _DocCategoryCard(
                      category: doc,
                      onTap: () {
                        AnalyticsService.trackFeatureInteraction(
                          'docs_${doc.title}',
                        );
                        context.go(doc.url);
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBlogSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest from the Blog',
          style: AppTypography.headingSM,
        ),
        const SizedBox(height: AppSpacing.lg),
        Builder(
          builder: (context) => ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            children: _content.featuredPosts
                .map((post) => _BlogPostCard(
                      post: post,
                      onTap: () {
                        AnalyticsService.trackBlogPostClick(post.slug);
                        context.go('/blog');
                      },
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCTARow(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.md,
      children: [
        Builder(
          builder: (ctx) => GradientButton(
            text: _content.docsCtaText,
            onPressed: () {
              AnalyticsService.trackCTAClick(
                buttonName: _content.docsCtaText,
                location: 'resources_section',
              );
              ctx.go(_content.docsCtaUrl);
            },
          ),
        ),
        OutlineButton(
          text: _content.blogCtaText,
          onPressed: () {
            AnalyticsService.trackCTAClick(
              buttonName: _content.blogCtaText,
              location: 'resources_section',
            );
            context.go(_content.blogCtaUrl);
          },
        ),
      ],
    );
  }
}

/// Documentation category card.
class _DocCategoryCard extends StatelessWidget {
  final DocCategoryContent category;
  final VoidCallback? onTap;

  const _DocCategoryCard({
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.tertiary,
      enableHover: true,
      onTap: onTap,
      semanticLabel: '${category.title} documentation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientIconContainer.translucent(
            icon: category.icon,
            color: AppColors.blue500,
            iconColor: AppColors.blue400,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            category.title,
            style: AppTypography.headingSM,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            category.description,
            style: AppTypography.bodySM,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          // Popular topics
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: category.popularTopics.take(3).map((topic) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: AppDecorations.chip(
                  backgroundColor: AppColors.gray700.withValues(alpha: 0.5),
                ),
                child: Text(
                  topic,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.gray300,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Blog post preview card.
class _BlogPostCard extends StatelessWidget {
  final BlogPostPreviewContent post;
  final VoidCallback? onTap;

  const _BlogPostCard({
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tier: GlassCardTier.tertiary,
      enableHover: true,
      onTap: onTap,
      semanticLabel: '${post.title} blog post',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: AppDecorations.translucentIconBox(
              _getCategoryColor(post.category),
              radius: AppSpacing.radiusSM,
            ),
            child: Text(
              post.category,
              style: AppTypography.caption.copyWith(
                color: _getCategoryColor(post.category),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            post.title,
            style: AppTypography.headingSM,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Excerpt
          Text(
            post.excerpt,
            style: AppTypography.bodySM,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Meta info
          Row(
            children: [
              if (post.author != null) ...[
                Text(
                  post.author!,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 4,
                  height: 4,
                  decoration: AppDecorations.separatorDot,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                post.readTime,
                style: AppTypography.caption.copyWith(
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Read more link
          Row(
            children: [
              Text(
                'Read More',
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.blue400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.blue400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'compliance':
        return AppColors.purple400;
      case 'cost optimization':
        return AppColors.success;
      case 'best practices':
        return AppColors.blue400;
      default:
        return AppColors.indigo400;
    }
  }
}
