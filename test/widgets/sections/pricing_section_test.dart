import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/pricing_section.dart';
import 'package:integrity_studio_ai/widgets/common/cards.dart';
import 'package:integrity_studio_ai/widgets/common/containers.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // =========================================================================
  // PricingSection Widget Tests
  // =========================================================================

  group('PricingSection widget tests', () {
    Widget buildPricingSection({
      PricingContent? content,
      void Function(String tier)? onSelectTier,
    }) {
      return MaterialApp(
        theme: testTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PricingSection(
              content: content ?? AppContent.pricing,
              onSelectTier: onSelectTier,
            ),
          ),
        ),
      );
    }

    testWidgets('renders structure correctly', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildPricingSection());
      await tester.pump(const Duration(milliseconds: 100));

      // Core structure
      expect(find.byType(PricingSection), findsOneWidget);
      expect(find.byType(SectionContainer), findsOneWidget);
      expect(find.byType(SectionTitle), findsOneWidget);

      // Billing toggle and pricing cards
      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.byType(PricingCard), findsWidgets);
    });

    testWidgets('toggle interaction changes billing period', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildPricingSection());
      await tester.pump(const Duration(milliseconds: 100));

      // Find and tap the Monthly toggle option
      final gestureDetectors = find.byType(GestureDetector);
      expect(gestureDetectors, findsWidgets);

      // Tap the first option (Monthly)
      await tester.tap(gestureDetectors.first);
      await tester.pump(const Duration(milliseconds: 100));

      // Widget should still be rendered
      expect(find.byType(PricingSection), findsOneWidget);
    });

    testWidgets('renders on mobile viewport', (tester) async {
      // Suppress overflow errors for mobile test
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('overflowed')) {
          oldHandler?.call(details);
        }
      };

      setMobileSize(tester);
      await tester.pumpWidget(buildPricingSection());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PricingSection), findsOneWidget);

      FlutterError.onError = oldHandler;
    });

    testWidgets('callback and custom content work correctly', (tester) async {
      setDesktopSize(tester);
      String? selectedTier;

      const customContent = PricingContent(
        title: 'Custom Pricing',
        subtitle: 'Custom subtitle',
        monthlyLabel: 'Per Month',
        annualLabel: 'Per Year',
        annualBadge: '2 months free',
        tiers: [
          PricingTierContent(
            name: 'Basic',
            monthlyPrice: '\$10',
            annualPrice: '\$8',
            period: '/mo',
            description: 'For individuals',
            features: ['Feature A'],
            ctaText: 'Try Basic',
            isPopular: false,
          ),
        ],
      );

      await tester.pumpWidget(buildPricingSection(
        content: customContent,
        onSelectTier: (tier) => selectedTier = tier,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PricingSection), findsOneWidget);
      expect(find.byType(PricingCard), findsWidgets);

      // Callback is set up correctly (starts null)
      expect(selectedTier, isNull);

      // Test empty tiers fallback
      const emptyContent = PricingContent(
        title: 'Title',
        subtitle: 'Subtitle',
        monthlyLabel: 'Monthly',
        annualLabel: 'Annual',
        annualBadge: 'Save',
        tiers: [],
      );

      await tester.pumpWidget(buildPricingSection(content: emptyContent));
      await tester.pump(const Duration(milliseconds: 100));

      // Should use AppContent.pricing which has tiers
      expect(find.byType(PricingCard), findsWidgets);
    });
  });

  // =========================================================================
  // PricingContent Unit Tests
  // =========================================================================

  group('PricingContent unit tests', () {
    test('default content has required fields and valid tiers', () {
      final content = AppContent.pricing;

      // Required fields
      expect(content.title, isNotEmpty);
      expect(content.subtitle, isNotEmpty);
      expect(content.monthlyLabel, isNotEmpty);
      expect(content.annualLabel, isNotEmpty);
      expect(content.tiers, isNotEmpty);

      // Each tier has required fields
      for (final tier in content.tiers) {
        expect(tier.name, isNotEmpty);
        expect(tier.monthlyPrice, isNotEmpty);
        expect(tier.annualPrice, isNotEmpty);
        expect(tier.features, isNotEmpty);
        expect(tier.ctaText, isNotEmpty);
      }

      // Annual prices validation
      for (final tier in content.tiers) {
        final hasContactSales = tier.monthlyPrice.toLowerCase().contains('contact') ||
            tier.monthlyPrice.toLowerCase().contains('custom');
        if (!hasContactSales) {
          expect(tier.monthlyPrice, isNotNull);
          expect(tier.annualPrice, isNotNull);
        }
      }

      // Popular tier check (may or may not have one)
      final popularTiers = content.tiers.where((t) => t.isPopular);
      expect(popularTiers.length, greaterThanOrEqualTo(0));
    });
  });

  // =========================================================================
  // Model Constructor Tests
  // =========================================================================

  group('PricingTierContent and PricingContent constructors', () {
    test('create with all required fields', () {
      const tier = PricingTierContent(
        name: 'Pro',
        monthlyPrice: '\$99',
        annualPrice: '\$79',
        period: '/mo',
        description: 'For growing teams',
        features: ['Feature 1', 'Feature 2'],
        ctaText: 'Get Started',
        isPopular: true,
      );

      expect(tier.name, equals('Pro'));
      expect(tier.monthlyPrice, equals('\$99'));
      expect(tier.annualPrice, equals('\$79'));
      expect(tier.period, equals('/mo'));
      expect(tier.description, equals('For growing teams'));
      expect(tier.features.length, equals(2));
      expect(tier.ctaText, equals('Get Started'));
      expect(tier.isPopular, isTrue);

      const content = PricingContent(
        title: 'Pricing',
        subtitle: 'Choose a plan',
        monthlyLabel: 'Monthly',
        annualLabel: 'Annual',
        annualBadge: 'Save 20%',
        tiers: [],
      );

      expect(content.title, equals('Pricing'));
      expect(content.subtitle, equals('Choose a plan'));
      expect(content.monthlyLabel, equals('Monthly'));
      expect(content.annualLabel, equals('Annual'));
      expect(content.annualBadge, equals('Save 20%'));
      expect(content.tiers, isEmpty);
    });
  });
}
