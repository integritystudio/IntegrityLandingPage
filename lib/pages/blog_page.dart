import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/containers.dart';
import '../widgets/common/buttons.dart';

/// Blog listing page displaying available articles
///
/// Features:
/// - Responsive grid layout
/// - Blog post cards with metadata
/// - Links to static HTML blog content
/// - Maintains brand consistency
class BlogPage extends StatelessWidget {
  final VoidCallback? onBack;

  const BlogPage({
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
          SliverAppBar(
            backgroundColor: AppColors.gray900,
            floating: true,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              onPressed: onBack ?? () => context.go('/'),
            ),
            title: Text(
              'Blog',
              style: AppTypography.headingSM.copyWith(color: Colors.white),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: onBack ?? () => context.go('/'),
                  child: Text(
                    'Back to Home',
                    style: AppTypography.bodySM.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Header
          SliverToBoxAdapter(
            child: SectionContainer(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Insights & Research',
                    style: isMobile
                        ? AppTypography.headingLG.copyWith(fontSize: 32)
                        : AppTypography.headingLG,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Text(
                      'Deep dives into AI observability, market trends, regulatory compliance, and strategic insights for building trustworthy AI systems.',
                      style: AppTypography.bodyLG,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Blog posts
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSpacing.md : AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: _BlogPostCard(post: BlogContent.posts[index]),
                ),
                childCount: BlogContent.posts.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogPostCard extends StatefulWidget {
  final BlogPost post;

  const _BlogPostCard({required this.post});

  @override
  State<_BlogPostCard> createState() => _BlogPostCardState();
}

class _BlogPostCardState extends State<_BlogPostCard> {
  bool _isExpanded = false;
  bool _isHovered = false;

  void _navigateToPost(BuildContext context, String url, bool isInternal) {
    if (isInternal) {
      context.go(url);
    } else {
      final uri = Uri.parse(url);
      launchUrl(uri, webOnlyWindowName: '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: AppColors.gray800,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: _isHovered
                ? AppColors.blue500.withValues(alpha: 0.5)
                : AppColors.gray700,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.blue500.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main card content
            Padding(
              padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category and meta
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          widget.post.category,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.post.isSeries)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.purple500.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(
                              color: AppColors.purple500.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            '${widget.post.seriesArticles.length} Part Series',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.purple400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Text(
                        widget.post.date,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  Text(
                    widget.post.title,
                    style: AppTypography.headingSM.copyWith(
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // Subtitle
                  Text(
                    widget.post.subtitle,
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.blue400,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Description
                  Text(
                    widget.post.description,
                    style: AppTypography.bodyMD.copyWith(
                      color: AppColors.gray300,
                    ),
                  ),

                  // Stats
                  if (widget.post.stats.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.sm,
                      children: widget.post.stats.map((stat) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray900,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.trendingUp,
                                size: 14,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  stat,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.gray300,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Read time and CTA
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.clock,
                              size: 14,
                              color: AppColors.gray400,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              widget.post.readTime,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.gray400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (widget.post.isSeries)
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _isExpanded = !_isExpanded);
                            },
                            icon: Icon(
                              _isExpanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 16,
                            ),
                            label: Text(_isExpanded ? 'Hide Articles' : 'View Articles'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.blue400,
                            ),
                          )
                        else
                          GradientButton(
                            text: 'Read Article',
                            icon: LucideIcons.arrowRight,
                            onPressed: () => _navigateToPost(context, widget.post.url, widget.post.isInternal),
                          ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.clock,
                          size: 14,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          widget.post.readTime,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.gray400,
                          ),
                        ),
                        const Spacer(),
                        if (widget.post.isSeries)
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _isExpanded = !_isExpanded);
                            },
                            icon: Icon(
                              _isExpanded
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 16,
                            ),
                            label: Text(_isExpanded ? 'Hide Articles' : 'View Articles'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.blue400,
                            ),
                          )
                        else
                          GradientButton(
                            text: 'Read Article',
                            icon: LucideIcons.arrowRight,
                            onPressed: () => _navigateToPost(context, widget.post.url, widget.post.isInternal),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            // Expandable series articles
            if (widget.post.isSeries)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.gray900,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppSpacing.radiusLG),
                      bottomRight: Radius.circular(AppSpacing.radiusLG),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Divider(color: AppColors.gray700, height: 1),
                      // Overview link
                      _SeriesArticleItem(
                        title: 'Overview',
                        description: 'Executive summary and key findings',
                        url: widget.post.url,
                        isFirst: true,
                      ),
                      ...widget.post.seriesArticles.asMap().entries.map((entry) {
                        return _SeriesArticleItem(
                          title: entry.value.title,
                          description: entry.value.description,
                          url: entry.value.url,
                          isLast: entry.key == widget.post.seriesArticles.length - 1,
                        );
                      }),
                    ],
                  ),
                ),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
          ],
        ),
      ),
    );
  }
}

class _SeriesArticleItem extends StatefulWidget {
  final String title;
  final String description;
  final String url;
  final bool isFirst;
  final bool isLast;

  const _SeriesArticleItem({
    required this.title,
    required this.description,
    required this.url,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  State<_SeriesArticleItem> createState() => _SeriesArticleItemState();
}

class _SeriesArticleItemState extends State<_SeriesArticleItem> {
  bool _isHovered = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        label: widget.title,
        link: true,
        child: GestureDetector(
          onTap: _launchUrl,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.gray800 : Colors.transparent,
            borderRadius: widget.isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(AppSpacing.radiusLG),
                    bottomRight: Radius.circular(AppSpacing.radiusLG),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? AppColors.blue500.withValues(alpha: 0.2)
                      : AppColors.gray800,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
                child: Icon(
                  LucideIcons.fileText,
                  size: 16,
                  color: _isHovered ? AppColors.blue400 : AppColors.gray400,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.bodySM.copyWith(
                        color: _isHovered ? Colors.white : AppColors.gray300,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.description,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.externalLink,
                size: 16,
                color: _isHovered ? AppColors.blue400 : AppColors.gray500,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
