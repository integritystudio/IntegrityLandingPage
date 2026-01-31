import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/content.dart';
import '../theme/theme.dart';
import '../widgets/common/buttons.dart';
import '../widgets/common/containers.dart';

/// Generic comparison/migration page for competitor alternatives.
///
/// Displays:
/// - Hero with urgency messaging (if competitor is shutting down)
/// - Key differentiators
/// - Feature comparison table
/// - Migration steps (if applicable)
/// - Special offers
/// - CTAs throughout
class ComparisonPage extends StatelessWidget {
  final ComparisonPageContent content;
  final VoidCallback? onBack;

  const ComparisonPage({
    super.key,
    required this.content,
    this.onBack,
  });

  /// Factory constructor for WhyLabs migration page
  factory ComparisonPage.whylabs({VoidCallback? onBack}) {
    return ComparisonPage(
      content: ComparisonPageVariants.whylabs,
      onBack: onBack,
    );
  }

  /// Factory constructor for Arize comparison page
  factory ComparisonPage.arize({VoidCallback? onBack}) {
    return ComparisonPage(
      content: ComparisonPageVariants.arize,
      onBack: onBack,
    );
  }

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
              '${content.competitorName} Alternative',
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

          // Hero Section
          SliverToBoxAdapter(
            key: const Key('comparison-hero-section'),
            child: _HeroSection(
              content: content,
              isMobile: isMobile,
            ),
          ),

          // Special Offer Banner (if applicable)
          if (content.specialOfferBadge != null)
            SliverToBoxAdapter(
              key: const Key('special-offer-section'),
              child: _SpecialOfferBanner(content: content),
            ),

          // Key Differentiators
          SliverToBoxAdapter(
            key: const Key('key-differentiators-section'),
            child: _KeyDifferentiatorsSection(
              content: content,
              isMobile: isMobile,
            ),
          ),

          // Feature Comparison Table
          SliverToBoxAdapter(
            key: const Key('feature-comparison-section'),
            child: _FeatureComparisonSection(
              content: content,
              isMobile: isMobile,
            ),
          ),

          // Who Should Choose sections
          SliverToBoxAdapter(
            key: const Key('who-should-choose-section'),
            child: _WhoShouldChooseSection(
              content: content,
              isMobile: isMobile,
            ),
          ),

          // Migration Steps (if applicable)
          if (content.migrationSteps.isNotEmpty)
            SliverToBoxAdapter(
              key: const Key('migration-steps-section'),
              child: _MigrationStepsSection(
                content: content,
                isMobile: isMobile,
              ),
            ),

          // Final CTA Section
          SliverToBoxAdapter(
            key: const Key('final-cta-section'),
            child: _FinalCTASection(
              content: content,
              isMobile: isMobile,
            ),
          ),

          // Footer spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.xxxl),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _HeroSection({
    required this.content,
    required this.isMobile,
  });

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
            // Status badge (e.g., "Shutting Down")
            if (content.competitorStatus != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.alertTriangle,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      content.competitorStatus!,
                      style: AppTypography.bodySM.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Headline
            Text(
              content.heroHeadline,
              style: isMobile
                  ? AppTypography.headingLG.copyWith(fontSize: 32)
                  : AppTypography.headingXL,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subheadline
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Text(
                content.heroSubheadline,
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // CTA Button
            Builder(
              builder: (context) => GradientButton(
                text: content.heroCtaText,
                icon: LucideIcons.arrowRight,
                onPressed: () => context.go(
                  '/signup?ref=${content.competitorName.toLowerCase()}',
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Migration time estimate
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 16,
                  color: AppColors.gray400,
                ),
                Text(
                  content.migrationTimeEstimate,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.gray400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialOfferBanner extends StatelessWidget {
  final ComparisonPageContent content;

  const _SpecialOfferBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blue600.withValues(alpha: 0.2),
            AppColors.purple600.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: AppColors.blue500.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.blue500.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: const Icon(
              LucideIcons.gift,
              color: AppColors.blue400,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.specialOfferBadge!,
                  style: AppTypography.bodySM.copyWith(
                    color: AppColors.blue400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content.specialOfferText ?? '',
                  style: AppTypography.bodyMD.copyWith(
                    color: AppColors.gray300,
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

class _KeyDifferentiatorsSection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _KeyDifferentiatorsSection({
    required this.content,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why Switch to Integrity Studio?',
            style: isMobile
                ? AppTypography.headingMD
                : AppTypography.headingLG.copyWith(fontSize: 32),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: content.keyDifferentiators.map((diff) {
              return _DifferentiatorCard(text: diff);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DifferentiatorCard extends StatelessWidget {
  final String text;

  const _DifferentiatorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
            ),
            child: const Icon(
              LucideIcons.check,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              text,
              style: AppTypography.bodyMD.copyWith(
                color: AppColors.gray200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureComparisonSection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _FeatureComparisonSection({
    required this.content,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feature Comparison',
            style: isMobile
                ? AppTypography.headingMD
                : AppTypography.headingLG.copyWith(fontSize: 32),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: AppColors.gray800,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              border: Border.all(color: AppColors.gray700),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.gray900),
                  dataRowColor: WidgetStateProperty.all(AppColors.gray800),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Feature',
                        style: AppTypography.bodySM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray300,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Integrity Studio',
                        style: AppTypography.bodySM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.blue400,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        content.competitorName,
                        style: AppTypography.bodySM.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                  ],
                  rows: content.featureComparison.map((feature) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            feature.feature,
                            style: AppTypography.bodyMD.copyWith(
                              color: AppColors.gray200,
                            ),
                          ),
                        ),
                        DataCell(_buildFeatureCell(
                          supported: feature.ourSupport,
                          value: feature.ourValue,
                          isOurs: true,
                        )),
                        DataCell(_buildFeatureCell(
                          supported: feature.theirSupport,
                          value: feature.theirValue,
                          isOurs: false,
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCell({
    required bool supported,
    String? value,
    required bool isOurs,
  }) {
    final color = supported
        ? (isOurs ? AppColors.success : AppColors.gray400)
        : AppColors.error;
    final icon = supported ? LucideIcons.check : LucideIcons.x;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        if (value != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.bodySM.copyWith(
              color: supported ? AppColors.gray300 : AppColors.gray500,
            ),
          ),
        ],
      ],
    );
  }
}

class _WhoShouldChooseSection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _WhoShouldChooseSection({
    required this.content,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainer(
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Column(
              children: [
                _ChoiceCard(
                  title: 'Choose Integrity Studio if you need...',
                  items: content.whyChooseUs,
                  isHighlighted: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ChoiceCard(
                  title: 'Consider ${content.competitorName} if you prefer...',
                  items: content.whyChooseThem,
                  isHighlighted: false,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ChoiceCard(
                    title: 'Choose Integrity Studio if you need...',
                    items: content.whyChooseUs,
                    isHighlighted: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: _ChoiceCard(
                    title: 'Consider ${content.competitorName} if you prefer...',
                    items: content.whyChooseThem,
                    isHighlighted: false,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool isHighlighted;

  const _ChoiceCard({
    required this.title,
    required this.items,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.blue500.withValues(alpha: 0.1)
            : AppColors.gray800,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(
          color: isHighlighted
              ? AppColors.blue500.withValues(alpha: 0.3)
              : AppColors.gray700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingSM.copyWith(
              color: isHighlighted ? AppColors.blue400 : AppColors.gray300,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isHighlighted ? LucideIcons.check : LucideIcons.circle,
                      size: 16,
                      color: isHighlighted
                          ? AppColors.success
                          : AppColors.gray500,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.bodyMD.copyWith(
                          color: AppColors.gray300,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MigrationStepsSection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _MigrationStepsSection({
    required this.content,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.gray800.withValues(alpha: 0.5),
      child: SectionContainer(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? AppSpacing.xl : AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Migration Guide',
              style: isMobile
                  ? AppTypography.headingMD
                  : AppTypography.headingLG.copyWith(fontSize: 32),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              content.migrationTimeEstimate,
              style: AppTypography.bodyLG.copyWith(
                color: AppColors.gray400,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...content.migrationSteps.map((step) => _MigrationStepCard(
                  step: step,
                  isMobile: isMobile,
                )),
          ],
        ),
      ),
    );
  }
}

class _MigrationStepCard extends StatelessWidget {
  final MigrationStep step;
  final bool isMobile;

  const _MigrationStepCard({
    required this.step,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Center(
                  child: Text(
                    '${step.number}',
                    style: AppTypography.bodySM.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  step.title,
                  style: AppTypography.headingSM.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            step.description,
            style: AppTypography.bodyMD.copyWith(
              color: AppColors.gray300,
            ),
          ),
          if (step.codeSnippet != null) ...[
            const SizedBox(height: AppSpacing.md),
            _CodeSnippet(code: step.codeSnippet!),
          ],
          if (step.docsUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => _launchUrl(step.docsUrl!),
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: const Text('View Documentation'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}

class _CodeSnippet extends StatefulWidget {
  final String code;

  const _CodeSnippet({required this.code});

  @override
  State<_CodeSnippet> createState() => _CodeSnippetState();
}

class _CodeSnippetState extends State<_CodeSnippet> {
  bool _copied = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray900,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AppColors.gray700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppColors.gray800,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusMD),
                topRight: Radius.circular(AppSpacing.radiusMD),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.gray400,
                  ),
                ),
                TextButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(
                    _copied ? LucideIcons.check : LucideIcons.copy,
                    size: 14,
                  ),
                  label: Text(_copied ? 'Copied!' : 'Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _copied ? AppColors.success : AppColors.gray400,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              widget.code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.gray300,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalCTASection extends StatelessWidget {
  final ComparisonPageContent content;
  final bool isMobile;

  const _FinalCTASection({
    required this.content,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
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
              'Ready to Make the Switch?',
              style: isMobile
                  ? AppTypography.headingMD
                  : AppTypography.headingLG,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Start your free trial today. Migrate your ${content.competitorName} setup '
                'and get the same powerful observability with active support and EU AI Act compliance.',
                style: AppTypography.bodyLG,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              alignment: WrapAlignment.center,
              children: [
                Builder(
                  builder: (ctx) => GradientButton(
                    text: content.heroCtaText,
                    icon: LucideIcons.arrowRight,
                    onPressed: () => ctx.go(
                      '/signup?ref=${content.competitorName.toLowerCase()}',
                    ),
                  ),
                ),
                OutlineButton(
                  text: 'Schedule Demo',
                  icon: LucideIcons.calendar,
                  onPressed: () => _launchUrl('https://calendly.com/alyshialedlie/30min'),
                ),
              ],
            ),
            if (content.specialOfferText != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                content.specialOfferText!,
                style: AppTypography.bodySM.copyWith(
                  color: AppColors.blue400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri);
  }
}
