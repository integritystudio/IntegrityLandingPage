import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../common/containers.dart';
import '../common/trust_badge.dart';

/// Social proof section with quantified metrics (AiSDR-inspired)
///
/// Features:
/// - Animated counter stats with large numbers
/// - Customer testimonials with metrics
/// - Company logo slider
/// - G2 badge display
///
/// IMPORTANT: All metrics must be verifiable.
/// See BRAND_GUIDELINES.md section 13 for approved claims.
class SocialProofSection extends StatelessWidget {
  const SocialProofSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      id: 'social-proof',
      backgroundColor: AppColors.gray800,
      child: Column(
        children: [
          // Stats row
          _buildStatsRow(context, isMobile),

          const SizedBox(height: AppSpacing.xxl),

          // Testimonials - hidden until we have real customer testimonials
          // _buildTestimonials(context, isMobile),
          // const SizedBox(height: AppSpacing.xxl),

          // Trust badges
          _buildTrustBadges(context),

          // Source attribution (legal requirement)
          const SizedBox(height: AppSpacing.xl),
          _buildSourceAttribution(),
        ],
      ),
    );
  }

  Widget _buildSourceAttribution() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: AppDecorations.card(
        backgroundColor: AppColors.gray900.withValues(alpha: 0.5),
        borderColor: AppColors.gray700.withValues(alpha: 0.3),
        radius: AppSpacing.radiusSM,
      ),
      child: Text(
        AppStatistics.sourceDisclaimer,
        style: AppTypography.caption.copyWith(
          color: AppColors.gray500,
          fontSize: 10,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, bool isMobile) {
    // Using AppStatistics for cited sources
    final stats = [
      _StatItem(
        value: AppStatistics.debuggingImprovement.value,
        label: AppStatistics.debuggingImprovement.label,
        icon: LucideIcons.zap,
        source: AppStatistics.debuggingImprovement.source,
      ),
      _StatItem(
        value: AppStatistics.costReduction.value,
        label: AppStatistics.costReduction.label,
        icon: LucideIcons.dollarSign,
        source: AppStatistics.costReduction.source,
      ),
      _StatItem(
        value: AppStatistics.setupTime.value,
        label: AppStatistics.setupTime.label,
        icon: LucideIcons.clock,
        source: AppStatistics.setupTime.source,
      ),
      _StatItem(
        value: AppStatistics.uptimeTarget.value,
        label: AppStatistics.uptimeTarget.label,
        icon: LucideIcons.shield,
        source: AppStatistics.uptimeTarget.source,
      ),
    ];

    if (isMobile) {
      return Column(
        children: stats.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < stats.length - 1 ? AppSpacing.lg : 0,
            ),
            child: _StatCard(stat: entry.value),
          );
        }).toList(),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: stats.map((stat) => Expanded(child: _StatCard(stat: stat))).toList(),
    );
  }

  Widget _buildTrustBadges(BuildContext context) {
    return Column(
      children: [
        Text(
          'Trusted by AI teams worldwide',
          style: AppTypography.bodySM.copyWith(
            color: AppColors.gray400,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: [
            TrustBadge(label: 'Enterprise Security', icon: LucideIcons.shieldCheck),
            TrustBadge(label: 'GDPR Ready', icon: LucideIcons.lock),
            TrustBadge(label: 'EU AI Act Ready', icon: LucideIcons.fileCheck),
            TrustBadge(label: 'OpenTelemetry Native', icon: LucideIcons.radio),
          ],
        ),
      ],
    );
  }
}

class _StatItem {
  final String value;
  final String label;
  final IconData icon;
  final String source;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.source,
  });
}

class _StatCard extends StatefulWidget {
  final _StatItem stat;

  const _StatCard({required this.stat});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Source: ${widget.stat.source}',
      preferBelow: true,
      decoration: AppDecorations.card(radius: AppSpacing.radiusSM),
      textStyle: AppTypography.caption.copyWith(
        color: AppColors.gray300,
        fontSize: 11,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? Matrix4.translationValues(0, -4, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.gray700 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          ),
          child: Column(
            children: [
              // Icon with gradient background
              GradientIconContainer(
                icon: widget.stat.icon,
                size: 40,
                borderRadius: AppSpacing.radiusSM,
              ),
              const SizedBox(height: AppSpacing.md),
              // Value with gradient text effect
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.blue400, AppColors.purple400],
                ).createShader(bounds),
                child: Text(
                  widget.stat.value,
                  style: AppTypography.headingLG.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.stat.label,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.gray300,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Testimonial {
  final String quote;
  final String author;
  final String title;
  final String company;
  final String metric;
  final String metricContext;

  const _Testimonial({
    required this.quote,
    required this.author,
    required this.title,
    required this.company,
    required this.metric,
    required this.metricContext,
  });
}

class _TestimonialCard extends StatefulWidget {
  final _Testimonial testimonial;

  const _TestimonialCard({required this.testimonial});

  @override
  State<_TestimonialCard> createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<_TestimonialCard> {
  bool _isHovered = false;

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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.gray900,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
          border: Border.all(
            color: _isHovered
                ? AppColors.blue500.withValues(alpha: 0.5)
                : AppColors.gray700.withValues(alpha: 0.5),
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
            // Metric highlight
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: AppDecorations.gradientPill(radius: AppSpacing.radiusFull),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.testimonial.metric,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: widget.testimonial.metricContext,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quote
            Text(
              '"${widget.testimonial.quote}"',
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.gray300,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Author
            Row(
              children: [
                // Avatar placeholder
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: AppColors.accentGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.testimonial.author[0],
                      style: AppTypography.bodySM.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.testimonial.author,
                        style: AppTypography.bodySM.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${widget.testimonial.title} at ${widget.testimonial.company}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

