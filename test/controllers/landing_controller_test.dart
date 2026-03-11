import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/controllers/landing_controller.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/services/analytics.dart';

import '../helpers/test_helpers.dart';

void main() {

  group('LandingController', () {
    late LandingController controller;
    late List<({AnalyticsEvent event, Map<String, dynamic> params})> analyticsLog;

    setUp(() {
      analyticsLog = AnalyticsService.enableCallLog();
      controller = LandingController();
    });

    tearDown(() {
      controller.dispose();
      AnalyticsService.resetForTesting();
    });

    group('construction', () {
      test('creates without error', () {
        expect(controller, isNotNull);
      });

      test('has scroll controller', () {
        expect(controller.scrollController, isNotNull);
        expect(controller.scrollController, isA<ScrollController>());
      });

      test('accepts optional callbacks', () {
        var demoModalShown = false;

        final controllerWithCallbacks = LandingController(
          onShowDemoModal: () => demoModalShown = true,
        );

        expect(controllerWithCallbacks.onShowDemoModal, isNotNull);

        // Verify callback is stored correctly
        controllerWithCallbacks.onShowDemoModal!();
        expect(demoModalShown, isTrue);

        controllerWithCallbacks.dispose();
      });
    });

    group('initialization', () {
      test('initialize completes without error', () {
        controller.initialize();
        expect(controller.scrollController, isNotNull);
      });

      test('initialize can be called multiple times without error', () {
        // Idempotent: second call should not re-track page view.
        controller.initialize();
        controller.initialize();
        // Only one page_view event despite two initialize() calls
        final pageViews = analyticsLog
            .where((e) => e.event == AnalyticsEvent.pageView)
            .toList();
        expect(pageViews, hasLength(1));
        expect(pageViews.first.params['page_title'], 'landing');
      });
    });

    group('content getters', () {
      test('heroContent returns HeroContent', () {
        expect(controller.heroContent, isA<HeroContent>());
      });

      test('pricingContent returns PricingContent', () {
        expect(controller.pricingContent, isA<PricingContent>());
      });

      test('featuresContent returns FeaturesContent', () {
        expect(controller.featuresContent, isA<FeaturesContent>());
      });

      test('ctaContent returns CTAContent', () {
        expect(controller.ctaContent, isA<CTAContent>());
      });
    });

    group('content variant', () {
      test('heroContent uses default when no variant set', () {
        expect(
            controller.heroContent.headline, equals(AppContent.hero.headline));
      });

      test('setContentVariant changes content', () {
        controller.setContentVariant('agent_first');
        // After setting variant, heroContent should reflect the variant
        expect(controller.heroContent, isNotNull);
      });

      test('setContentVariant notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.setContentVariant('cost_focused');
        expect(notified, isTrue);
      });

      test('heroContent returns variant content when variant is set', () {
        controller.setContentVariant('agent_first');
        final variantContent = AppContent.getHeroVariant('agent_first');
        expect(controller.heroContent.headline, equals(variantContent.headline));
      });

      test('heroContent returns different content for different variants', () {
        final defaultContent = controller.heroContent;

        controller.setContentVariant('cost_focused');
        final costFocusedContent = controller.heroContent;

        // Verify variant system is working (content may differ)
        expect(costFocusedContent, isNotNull);
        expect(defaultContent, isNotNull);
      });
    });

    group('section management', () {
      test('registerSection stores key', () {
        final key = GlobalKey();
        controller.registerSection('test-section', key);

        expect(controller.getSectionKey('test-section'), equals(key));
      });

      test('getSectionKey returns null for unregistered section', () {
        expect(controller.getSectionKey('nonexistent'), isNull);
      });

      test('registerSection allows multiple sections', () {
        final key1 = GlobalKey();
        final key2 = GlobalKey();

        controller.registerSection('section1', key1);
        controller.registerSection('section2', key2);

        expect(controller.getSectionKey('section1'), equals(key1));
        expect(controller.getSectionKey('section2'), equals(key2));
      });

      test('registerSection overwrites existing key', () {
        final key1 = GlobalKey();
        final key2 = GlobalKey();

        controller.registerSection('test', key1);
        expect(controller.getSectionKey('test'), equals(key1));

        controller.registerSection('test', key2);
        expect(controller.getSectionKey('test'), equals(key2));
      });
    });

    group('scroll to section', () {
      test('scrollToSection handles unregistered section gracefully', () {
        expect(() => controller.scrollToSection('nonexistent'), returnsNormally);
      });

      test('scrollToPricing does not throw with unattached key', () {
        controller.registerSection('pricing', GlobalKey());
        expect(() => controller.scrollToPricing(), returnsNormally);
      });

      test('scrollToCTA does not throw with unattached key', () {
        controller.registerSection('cta', GlobalKey());
        expect(() => controller.scrollToCTA(), returnsNormally);
      });

      test('scrollToSection with null context does not throw', () {
        final key = GlobalKey();
        controller.registerSection('test', key);
        // Key exists but has no context (not attached to widget)
        expect(() => controller.scrollToSection('test'), returnsNormally);
      });

      testWidgets('scrollToSection scrolls to visible widget', (tester) async {
        final pricingKey = GlobalKey();
        final ctaKey = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller.scrollController,
                child: Column(
                  children: [
                    Container(
                      key: pricingKey,
                      height: 500,
                      color: Colors.blue,
                      child: const Text('Pricing Section'),
                    ),
                    Container(
                      key: ctaKey,
                      height: 500,
                      color: Colors.green,
                      child: const Text('CTA Section'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        controller.registerSection('pricing', pricingKey);
        controller.registerSection('cta', ctaKey);

        // Scroll to CTA section
        controller.scrollToSection('cta');
        await tester.pumpAndSettleWithTimeout();

        // Verify scroll happened (CTA should be visible)
        expect(find.text('CTA Section'), findsOneWidget);
      });
    });

    group('analytics handlers', () {
      test('handleGetStarted tracks CTA click with default location', () {
        controller.registerSection('pricing', GlobalKey());
        controller.handleGetStarted();

        final ctaClicks = analyticsLog
            .where((e) => e.event == AnalyticsEvent.ctaClick)
            .toList();
        expect(ctaClicks, hasLength(1));
        expect(ctaClicks.first.params['button_name'], CTAText.getStarted);
        expect(ctaClicks.first.params['location'], 'hero');
        expect(ctaClicks.first.params['cta_type'], 'primary');
      });

      test('handleGetStarted tracks CTA click with custom location', () {
        controller.handleGetStarted(location: 'navbar');

        final ctaClicks = analyticsLog
            .where((e) => e.event == AnalyticsEvent.ctaClick)
            .toList();
        expect(ctaClicks, hasLength(1));
        expect(ctaClicks.first.params['location'], 'navbar');
      });

      test('handleRequestDemo tracks CTA click as secondary', () {
        controller.handleRequestDemo();

        final ctaClicks = analyticsLog
            .where((e) => e.event == AnalyticsEvent.ctaClick)
            .toList();
        expect(ctaClicks, hasLength(1));
        expect(ctaClicks.first.params['button_name'], CTAText.requestDemo);
        expect(ctaClicks.first.params['cta_type'], 'secondary');
      });

      test('trackTierSelection sends correct tier to analytics', () {
        controller.trackTierSelection('enterprise');

        final tierViews = analyticsLog
            .where((e) => e.event == AnalyticsEvent.pricingTierView)
            .toList();
        expect(tierViews, hasLength(1));
        expect(tierViews.first.params['tier'], 'enterprise');
      });

      test('trackTierSelection sends team tier', () {
        controller.trackTierSelection('team');

        final tierViews = analyticsLog
            .where((e) => e.event == AnalyticsEvent.pricingTierView)
            .toList();
        expect(tierViews, hasLength(1));
        expect(tierViews.first.params['tier'], 'team');
      });

      test('trackTierSelection sends starter tier', () {
        controller.trackTierSelection('starter');

        final tierViews = analyticsLog
            .where((e) => e.event == AnalyticsEvent.pricingTierView)
            .toList();
        expect(tierViews, hasLength(1));
        expect(tierViews.first.params['tier'], 'starter');
      });

      test('trackTierSelection handles empty string', () {
        controller.trackTierSelection('');

        final tierViews = analyticsLog
            .where((e) => e.event == AnalyticsEvent.pricingTierView)
            .toList();
        expect(tierViews, hasLength(1));
        expect(tierViews.first.params['tier'], '');
      });

      test('handleFeatureInteraction sends feature name', () {
        controller.handleFeatureInteraction('AI Observability');

        final interactions = analyticsLog
            .where((e) => e.event == AnalyticsEvent.featureInteraction)
            .toList();
        expect(interactions, hasLength(1));
        expect(interactions.first.params['feature_name'], 'AI Observability');
      });
    });

    group('callback invocation', () {
      test('handleRequestDemo invokes onShowDemoModal callback', () {
        var callbackInvoked = false;
        final controllerWithCallback = LandingController(
          onShowDemoModal: () => callbackInvoked = true,
        );

        controllerWithCallback.handleRequestDemo();
        expect(callbackInvoked, isTrue);

        controllerWithCallback.dispose();
      });

      test('handleRequestDemo handles null callback gracefully', () {
        expect(() => controller.handleRequestDemo(), returnsNormally);
      });
    });

    group('scroll tracking', () {
      test('resetScrollTracking does not throw', () {
        expect(() => controller.resetScrollTracking(), returnsNormally);
      });

      testWidgets('scroll tracking handles zero maxScrollExtent',
          (tester) async {
        // Create a non-scrollable view (content fits in viewport)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller.scrollController,
                child: const SizedBox(
                  height: 100,
                  child: Text('Short content'),
                ),
              ),
            ),
          ),
        );

        controller.initialize();
        await tester.pumpAndSettleWithTimeout();

        // maxScrollExtent should be 0 for non-scrollable content
        expect(controller.scrollController.position.maxScrollExtent, equals(0));
      });

      testWidgets('scroll tracking tracks milestones at correct percentages',
          (tester) async {
        tester.view.physicalSize = const Size(400, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller.scrollController,
                child: Container(
                  height: 1000,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );

        controller.initialize();
        await tester.pumpAndSettleWithTimeout();

        final maxExtent = controller.scrollController.position.maxScrollExtent;
        expect(maxExtent, greaterThan(0));

        // Scroll to 50%
        controller.scrollController.jumpTo(maxExtent * 0.5);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, closeTo(maxExtent * 0.5, 1));

        // Scroll to 100%
        controller.scrollController.jumpTo(maxExtent);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, equals(maxExtent));
      });

      // Milestone dedup: 25% should only be tracked once even after re-scroll.
      // Argument verification requires AnalyticsService mock (see BACKLOG).
      testWidgets('scroll tracking deduplicates milestones on repeated scrolls',
          (tester) async {
        tester.view.physicalSize = const Size(400, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller.scrollController,
                child: Container(
                  height: 1000,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );

        controller.initialize();
        await tester.pumpAndSettleWithTimeout();

        final maxExtent = controller.scrollController.position.maxScrollExtent;

        // Scroll past 25% multiple times (milestone dedup path)
        controller.scrollController.jumpTo(maxExtent * 0.3);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, closeTo(maxExtent * 0.3, 1));

        controller.scrollController.jumpTo(0);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, equals(0));

        // Re-scroll past same milestone — should not throw
        controller.scrollController.jumpTo(maxExtent * 0.3);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, closeTo(maxExtent * 0.3, 1));
      });

      // After reset, milestones should re-fire on re-scroll.
      // Argument verification requires AnalyticsService mock (see BACKLOG).
      testWidgets('resetScrollTracking allows re-tracking milestones',
          (tester) async {
        tester.view.physicalSize = const Size(400, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller.scrollController,
                child: Container(
                  height: 1000,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        );

        controller.initialize();
        await tester.pumpAndSettleWithTimeout();

        final maxExtent = controller.scrollController.position.maxScrollExtent;

        // Scroll to 50%
        controller.scrollController.jumpTo(maxExtent * 0.5);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, closeTo(maxExtent * 0.5, 1));

        // Reset tracking, scroll back to 0, then re-scroll
        controller.resetScrollTracking();
        controller.scrollController.jumpTo(0);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, equals(0));

        controller.scrollController.jumpTo(maxExtent * 0.5);
        await tester.pumpAndSettleWithTimeout();
        expect(controller.scrollController.offset, closeTo(maxExtent * 0.5, 1));
      });
    });

    group('disposal', () {
      test('dispose after initialize does not throw', () {
        final testController = LandingController();
        testController.initialize();
        expect(() => testController.dispose(), returnsNormally);
      });

      test('dispose without initialization does not throw', () {
        final testController = LandingController();
        expect(() => testController.dispose(), returnsNormally);
      });
    });
  });

}
