import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import 'package:integrity_studio_ai/widgets/common/cards.dart';
import 'package:integrity_studio_ai/config/content.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // GlassCard Tests
  // ==========================================================================

  group('GlassCard', () {
    testWidgets('renders content with all tiers, semantics, cursor, and onTap',
        (tester) async {
      // Test all tiers render correctly
      for (final tier in GlassCardTier.values) {
        await tester.pumpWidget(
          testableWidget(
            GlassCard(
              tier: tier,
              child: Text('Tier: ${tier.name}'),
            ),
          ),
        );
        expect(find.text('Tier: ${tier.name}'), findsOneWidget);
      }

      // Test semantic label
      await tester.pumpWidget(
        testableWidget(
          const GlassCard(
            semanticLabel: 'Test card',
            child: Text('Content'),
          ),
        ),
      );
      expect(find.byType(Semantics), findsWidgets);

      // Test pointer cursor and onTap callback
      var tapped = false;
      await tester.pumpWidget(
        testableWidget(
          GlassCard(
            onTap: () => tapped = true,
            child: const Text('Tap me'),
          ),
        ),
      );
      expect(find.byType(MouseRegion), findsWidgets);

      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  // ==========================================================================
  // FeatureCard Tests
  // ==========================================================================

  group('FeatureCard', () {
    testWidgets('renders icon, title, description, features, and handles onTap',
        (tester) async {
      // Test basic rendering with features list
      await tester.pumpWidget(
        testableWidget(
          const FeatureCard(
            icon: Icons.star,
            title: 'Feature Title',
            description: 'Feature description text',
            features: ['Feature 1', 'Feature 2', 'Feature 3'],
          ),
        ),
      );

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Feature Title'), findsOneWidget);
      expect(find.text('Feature description text'), findsOneWidget);
      expect(find.text('Feature 1'), findsOneWidget);
      expect(find.text('Feature 2'), findsOneWidget);
      expect(find.text('Feature 3'), findsOneWidget);

      // Test onTap callback
      var tapped = false;
      await tester.pumpWidget(
        testableWidget(
          FeatureCard(
            icon: Icons.check,
            title: 'Clickable',
            description: 'Test',
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Clickable').first);
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  // ==========================================================================
  // StatCard Tests
  // ==========================================================================

  group('StatCard', () {
    testWidgets('renders value, label, and has semantic label', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const StatCard(
            value: '99.9%',
            label: 'Uptime',
          ),
        ),
      );

      expect(find.text('99.9%'), findsOneWidget);
      expect(find.text('Uptime'), findsOneWidget);
      expect(find.byType(Semantics), findsWidgets);
    });
  });

  // ==========================================================================
  // PricingCard Tests
  // ==========================================================================

  group('PricingCard', () {
    testWidgets('renders tier, price, period, description, features, and CTA',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const PricingCard(
            tier: 'Pro',
            price: '\$99',
            period: '/month',
            description: 'For growing teams',
            features: [
              'Unlimited users',
              'Advanced analytics',
              'Priority support',
            ],
            ctaText: 'Start Free Trial',
          ),
        ),
      );

      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('\$99'), findsOneWidget);
      expect(find.text('/month'), findsOneWidget);
      expect(find.text('For growing teams'), findsOneWidget);
      expect(find.text('Unlimited users'), findsOneWidget);
      expect(find.text('Advanced analytics'), findsOneWidget);
      expect(find.text('Priority support'), findsOneWidget);
      expect(find.byIcon(LucideIcons.checkCircle), findsNWidgets(3));
      expect(find.text(CTAText.startFreeTrial), findsOneWidget);
    });

    testWidgets(
        'popular tier shows badge, uses GradientButton, and primary GlassCard',
        (tester) async {
      // Test popular tier
      await tester.pumpWidget(
        testableWidget(
          const PricingCard(
            tier: 'Team',
            price: '\$79',
            features: ['Feature 1'],
            ctaText: 'Subscribe',
            isPopular: true,
          ),
        ),
      );

      expect(find.text('Most Popular'), findsOneWidget);
      expect(find.byType(GradientButton), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);

      // Test non-popular tier
      await tester.pumpWidget(
        testableWidget(
          const PricingCard(
            tier: 'Starter',
            price: '\$0',
            features: ['Feature 1'],
            ctaText: 'Get Started',
            isPopular: false,
          ),
        ),
      );

      expect(find.text('Most Popular'), findsNothing);
      expect(find.byType(OutlineButton), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);
    });

    testWidgets('invokes onCtaPressed callback when CTA tapped', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        testableWidget(
          PricingCard(
            tier: 'Pro',
            price: '\$99',
            features: const ['Feature 1'],
            ctaText: 'Subscribe',
            onCtaPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.text('Subscribe'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('handles overflow and renders at various viewports',
        (tester) async {
      // Test long price text without overflow
      await tester.pumpWidget(
        testableWidget(
          const SizedBox(
            width: 200,
            child: PricingCard(
              tier: 'Enterprise',
              price: 'Custom Pricing',
              features: ['Feature 1'],
              ctaText: 'Contact Sales',
            ),
          ),
        ),
      );
      expect(find.text('Enterprise'), findsOneWidget);
      expect(find.textContaining('Custom'), findsOneWidget);

      // Test feature rows with proper alignment
      await tester.pumpWidget(
        testableWidget(
          const PricingCard(
            tier: 'Pro',
            price: '\$99',
            features: [
              'Short feature',
              'A much longer feature description that spans multiple lines',
            ],
            ctaText: 'Subscribe',
          ),
        ),
      );
      expect(find.text('Short feature'), findsOneWidget);
      expect(
          find.textContaining('A much longer feature description'),
          findsOneWidget);

      // Test tablet width with multiple cards
      setTabletSize(tester);
      await tester.pumpWidget(
        testableWidget(
          const Row(
            children: [
              Expanded(
                child: PricingCard(
                  tier: 'Starter',
                  price: 'Free',
                  features: ['50K traces/month', '7-day retention'],
                  ctaText: 'Get Started',
                ),
              ),
              Expanded(
                child: PricingCard(
                  tier: 'Team',
                  price: '\$79',
                  period: '/month',
                  features: ['500K traces/month', '30-day retention'],
                  ctaText: 'Start Trial',
                  isPopular: true,
                ),
              ),
              Expanded(
                child: PricingCard(
                  tier: 'Enterprise',
                  price: 'Custom',
                  features: ['Unlimited traces', '1-year retention'],
                  ctaText: 'Contact Sales',
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.text('Enterprise'), findsOneWidget);

      // Test mobile width
      setMobileSize(tester);
      await tester.pumpWidget(
        testableSection(
          const Column(
            children: [
              PricingCard(
                tier: 'Starter',
                price: 'Free',
                features: ['50K traces/month'],
                ctaText: 'Get Started',
              ),
              PricingCard(
                tier: 'Team',
                price: '\$79',
                period: '/month',
                features: ['500K traces/month'],
                ctaText: 'Start Trial',
                isPopular: true,
              ),
            ],
          ),
        ),
      );
      expect(find.text('Starter'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
    });
  });
}
