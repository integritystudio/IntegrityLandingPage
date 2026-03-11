/// Pricing section content.
library;

import 'models.dart';
import 'constants.dart';

/// Pricing content variants.
abstract final class PricingContentVariants {
  /// Current production content
  /// Updated per audit: 50K traces free tier (vs 10K)
  static const current = PricingContent(
    title: 'Simple, Transparent Pricing',
    subtitle: 'Start free, scale as you grow',
    monthlyLabel: PricingConstants.monthlyLabel,
    annualLabel: PricingConstants.annualLabel,
    annualBadge: PricingConstants.annualDiscount,
    tiers: _currentTiers,
  );

  /// Legacy content (pre-audit) - kept for rollback
  static const legacy = PricingContent(
    title: 'Simple, Transparent Pricing',
    subtitle: 'Start free, scale as you grow',
    monthlyLabel: PricingConstants.monthlyLabel,
    annualLabel: PricingConstants.annualLabel,
    annualBadge: PricingConstants.annualDiscount,
    tiers: _legacyTiers,
  );

  // Current tier definitions
  static const _currentTiers = [
    PricingTierContent(
      name: 'Starter',
      monthlyPrice: 'Free',
      annualPrice: 'Free',
      description: 'For individual developers',
      features: [
        '50K traces/month', // Increased from 10K per audit
        '7-day retention',
        'Basic dashboards',
        'Email support',
        'Community access',
      ],
      ctaText: CTAText.getStarted,
    ),
    PricingTierContent(
      name: 'Team',
      monthlyPrice: r'$99',
      annualPrice: r'$79',
      period: '/month',
      description: 'For growing teams',
      features: [
        '500K traces/month', // Scaled up proportionally
        '30-day retention',
        'Advanced analytics',
        'Priority support',
        'Team collaboration',
        'Custom alerts',
        'EU AI Act reports',
      ],
      isPopular: true,
      ctaText: CTAText.startFreeTrial,
    ),
    PricingTierContent(
      name: 'Enterprise',
      monthlyPrice: 'Custom',
      annualPrice: 'Custom',
      description: 'For large organizations',
      features: [
        'Unlimited traces',
        '1-year retention',
        'SSO/SAML',
        'Dedicated support',
        'Custom integrations',
        'SLA guarantee',
        'On-premise option',
        'Compliance dashboard',
      ],
      ctaText: CTAText.contactSales,
    ),
  ];

  // Legacy tier definitions
  static const _legacyTiers = [
    PricingTierContent(
      name: 'Starter',
      monthlyPrice: 'Free',
      annualPrice: 'Free',
      description: 'For individual developers',
      features: [
        '10K traces/month',
        '7-day retention',
        'Basic dashboards',
        'Email support',
        'Community access',
      ],
      ctaText: CTAText.getStarted,
    ),
    PricingTierContent(
      name: 'Team',
      monthlyPrice: r'$99',
      annualPrice: r'$79',
      period: '/month',
      description: 'For growing teams',
      features: [
        '100K traces/month',
        '30-day retention',
        'Advanced analytics',
        'Priority support',
        'Team collaboration',
        'Custom alerts',
      ],
      isPopular: true,
      ctaText: CTAText.startFreeTrial,
    ),
    PricingTierContent(
      name: 'Enterprise',
      monthlyPrice: 'Custom',
      annualPrice: 'Custom',
      description: 'For large organizations',
      features: [
        'Unlimited traces',
        '1-year retention',
        'SSO/SAML',
        'Dedicated support',
        'Custom integrations',
        'SLA guarantee',
        'On-premise option',
      ],
      ctaText: CTAText.contactSales,
    ),
  ];
}
