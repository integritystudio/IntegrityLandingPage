import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/models.dart';

void main() {
  group('HeroContent', () {
    test('constructs with required fields', () {
      const hero = HeroContent(
        badge: 'New',
        headline: 'Test Headline',
        subheadline: 'Test Sub',
        primaryCTA: 'Start',
        secondaryCTA: 'Demo',
        trustIndicators: ['SOC 2', 'HIPAA'],
      );
      expect(hero.badge, 'New');
      expect(hero.headline, 'Test Headline');
      expect(hero.trustIndicators, hasLength(2));
    });
  });

  group('PricingTierContent', () {
    test('constructs with defaults', () {
      const tier = PricingTierContent(
        name: 'Free',
        monthlyPrice: '\$0',
        annualPrice: '\$0',
        features: ['Feature 1'],
        ctaText: 'Get Started',
      );
      expect(tier.isPopular, false);
      expect(tier.period, isNull);
      expect(tier.description, isNull);
    });

    test('constructs with optional fields', () {
      const tier = PricingTierContent(
        name: 'Pro',
        monthlyPrice: '\$49',
        annualPrice: '\$39',
        period: '/mo',
        description: 'Best for teams',
        features: ['A', 'B'],
        isPopular: true,
        ctaText: 'Upgrade',
      );
      expect(tier.isPopular, true);
      expect(tier.period, '/mo');
    });
  });

  group('PricingContent', () {
    test('constructs with tiers list', () {
      const pricing = PricingContent(
        title: 'Pricing',
        subtitle: 'Plans',
        monthlyLabel: 'Monthly',
        annualLabel: 'Annual',
        annualBadge: 'Save 20%',
        tiers: [],
      );
      expect(pricing.tiers, isEmpty);
    });
  });

  group('FeatureCardContent', () {
    test('constructs with icon', () {
      const card = FeatureCardContent(
        icon: Icons.star,
        title: 'Feature',
        description: 'Desc',
        bullets: ['bullet1'],
      );
      expect(card.icon, Icons.star);
      expect(card.bullets, hasLength(1));
    });
  });

  group('CTAContent', () {
    test('constructs with all fields', () {
      const cta = CTAContent(
        headline: 'Ready?',
        subheadline: 'Start now',
        primaryCTA: 'Go',
        secondaryCTA: 'Demo',
      );
      expect(cta.headline, 'Ready?');
    });
  });

  group('TestimonialContent', () {
    test('constructs with optional metric fields', () {
      const testimonial = TestimonialContent(
        quote: 'Great product',
        author: 'Jane',
        role: 'CTO',
        company: 'Acme',
        metric: '40%',
        metricContext: 'reduction',
      );
      expect(testimonial.metric, '40%');
      expect(testimonial.avatarAsset, isNull);
    });
  });

  group('StatusMetricContent', () {
    test('defaults to operational', () {
      const metric = StatusMetricContent(
        label: 'Uptime',
        value: '99.9%',
      );
      expect(metric.isOperational, true);
      expect(metric.sublabel, isNull);
    });
  });

  group('StatusServiceContent', () {
    test('defaults to operational', () {
      const service = StatusServiceContent(
        name: 'API',
        status: 'Operational',
      );
      expect(service.isOperational, true);
    });
  });

  group('FooterLink', () {
    test('defaults to not external', () {
      const link = FooterLink(label: 'Privacy', url: '/privacy');
      expect(link.isExternal, false);
    });

    test('can be external', () {
      const link = FooterLink(
        label: 'GitHub',
        url: 'https://github.com',
        isExternal: true,
      );
      expect(link.isExternal, true);
    });
  });

  group('ComparisonFeature', () {
    test('defaults support to true', () {
      const feature = ComparisonFeature(feature: 'SSO');
      expect(feature.ourSupport, true);
      expect(feature.theirSupport, true);
    });
  });

  group('MigrationStep', () {
    test('optional fields are null by default', () {
      const step = MigrationStep(
        number: 1,
        title: 'Install SDK',
        description: 'Run npm install',
      );
      expect(step.codeSnippet, isNull);
      expect(step.docsUrl, isNull);
    });
  });

  group('ContactFormFieldContent', () {
    test('defaults required to false', () {
      const field = ContactFormFieldContent(
        name: 'email',
        label: 'Email',
        placeholder: 'you@example.com',
        type: 'email',
      );
      expect(field.required, false);
      expect(field.options, isNull);
    });
  });

  group('LeadMagnetContent', () {
    test('defaults requiresEmail to true', () {
      const magnet = LeadMagnetContent(
        icon: Icons.download,
        title: 'Guide',
        description: 'PDF guide',
        format: 'PDF',
        ctaText: 'Download',
        url: '/guide.pdf',
      );
      expect(magnet.requiresEmail, true);
    });
  });
}
