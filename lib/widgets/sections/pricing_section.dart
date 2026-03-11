import 'package:flutter/material.dart';
import '../../config/content.dart';
import '../../theme/theme.dart';
import '../../services/analytics.dart';
import '../common/cards.dart';
import '../common/containers.dart';

/// Pricing section with tier comparison
///
/// LEGAL NOTE: All pricing and features should be accurate.
/// Update this section when pricing changes.
///
/// Features:
/// - Externalized content via PricingContent (supports A/B testing)
/// - Monthly/Annual billing toggle
/// - Analytics tracking on pricing interactions
///
/// Usage:
/// ```dart
/// PricingSection(
///   content: PricingContent.current, // or AppContent.pricing
///   onSelectTier: (tier) => navigateToSignup(tier),
/// )
/// ```
class PricingSection extends StatefulWidget {
  final PricingContent content;
  final void Function(String tier)? onSelectTier;

  const PricingSection({
    super.key,
    this.content = const PricingContent(
      title: 'Simple, Transparent Pricing',
      subtitle: 'Start free, scale as you grow',
      monthlyLabel: 'Monthly',
      annualLabel: 'Annual',
      annualBadge: 'Save 20%',
      tiers: [],
    ),
    this.onSelectTier,
  });

  @override
  State<PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<PricingSection> {
  bool _isAnnual = true;

  // Use content from widget or fallback to AppContent
  PricingContent get _content =>
      widget.content.tiers.isEmpty ? AppContent.pricing : widget.content;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);

    return SectionContainer(
      id: 'pricing',
      child: Column(
        children: [
          // Section header
          SectionTitle(
            title: _content.title,
            subtitle: _content.subtitle,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Billing toggle
          _buildBillingToggle(),

          SizedBox(height: AppSpacing.sectionPadding(context) * 0.5),

          // Pricing cards
          if (isMobile)
            _buildMobilePricing()
          else
            _buildDesktopPricing(),

        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: AppDecorations.chip(radius: AppSpacing.radiusFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BillingOption(
            label: _content.monthlyLabel,
            isSelected: !_isAnnual,
            onTap: () {
              setState(() => _isAnnual = false);
              AnalyticsService.trackPricingToggle(isAnnual: false);
            },
          ),
          _BillingOption(
            label: _content.annualLabel,
            isSelected: _isAnnual,
            badge: _content.annualBadge,
            onTap: () {
              setState(() => _isAnnual = true);
              AnalyticsService.trackPricingToggle(isAnnual: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPricing() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _content.tiers.map((tier) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: PricingCard(
              tier: tier.name,
              price: _isAnnual ? tier.annualPrice : tier.monthlyPrice,
              period: tier.period,
              description: tier.description,
              features: tier.features,
              isPopular: tier.isPopular,
              ctaText: tier.ctaText,
              onCtaPressed: () {
                AnalyticsService.trackPricingView(tier.name);
                widget.onSelectTier?.call(tier.name);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobilePricing() {
    return Column(
      children: _content.tiers.map((tier) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: PricingCard(
            tier: tier.name,
            price: _isAnnual ? tier.annualPrice : tier.monthlyPrice,
            period: tier.period,
            description: tier.description,
            features: tier.features,
            isPopular: tier.isPopular,
            ctaText: tier.ctaText,
            onCtaPressed: () {
              AnalyticsService.trackPricingView(tier.name);
              widget.onSelectTier?.call(tier.name);
            },
          ),
        );
      }).toList(),
    );
  }
}

class _BillingOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final String? badge;
  final VoidCallback onTap;

  const _BillingOption({
    required this.label,
    required this.isSelected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gray700 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.buttonText.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.gray400,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: AppDecorations.gradientPill(),
                child: Text(
                  badge!,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
