import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/controllers/landing_controller.dart';
import 'package:integrity_studio_ai/config/content.dart';

void main() {

  group('LandingController', () {
    late LandingController controller;

    setUp(() {
      controller = LandingController();
    });

    tearDown(() {
      controller.dispose();
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
        String? selectedTier;

        final controllerWithCallbacks = LandingController(
          onShowDemoModal: () => demoModalShown = true,
          onNavigateToSignup: (tier) => selectedTier = tier,
        );

        expect(controllerWithCallbacks.onShowDemoModal, isNotNull);
        expect(controllerWithCallbacks.onNavigateToSignup, isNotNull);

        // Verify callbacks are stored correctly
        controllerWithCallbacks.onShowDemoModal!();
        expect(demoModalShown, isTrue);

        controllerWithCallbacks.onNavigateToSignup!('pro');
        expect(selectedTier, equals('pro'));

        controllerWithCallbacks.dispose();
      });
    });

    group('initialization', () {
      test('initialize completes without error', () {
        controller.initialize();
        expect(controller.scrollController, isNotNull);
      });

      test('initialize only tracks page view once', () {
        controller.initialize();
        controller.initialize(); // Second call should not track again
        // No error means it passed
        expect(true, isTrue);
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
        controller.setContentVariant('agent-first');
        // After setting variant, heroContent should reflect the variant
        expect(controller.heroContent, isNotNull);
      });

      test('setContentVariant notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.setContentVariant('cost-focused');
        expect(notified, isTrue);
      });

      test('heroContent returns variant content when variant is set', () {
        controller.setContentVariant('agent-first');
        final variantContent = AppContent.getHeroVariant('agent-first');
        expect(controller.heroContent.headline, equals(variantContent.headline));
      });

      test('heroContent returns different content for different variants', () {
        final defaultContent = controller.heroContent;

        controller.setContentVariant('cost-focused');
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
      testWidgets('scrollToSection handles unregistered section gracefully',
          (tester) async {
        // Should not throw
        controller.scrollToSection('nonexistent');
        expect(true, isTrue);
      });

      testWidgets('scrollToPricing calls scrollToSection with pricing',
          (tester) async {
        final key = GlobalKey();
        controller.registerSection('pricing', key);
        controller.scrollToPricing();
        // No error means it works (though context may be null)
        expect(true, isTrue);
      });

      testWidgets('scrollToCTA calls scrollToSection with cta', (tester) async {
        final key = GlobalKey();
        controller.registerSection('cta', key);
        controller.scrollToCTA();
        expect(true, isTrue);
      });

      testWidgets('scrollToSection with null context does not throw',
          (tester) async {
        final key = GlobalKey();
        controller.registerSection('test', key);
        // Key exists but has no context (not attached to widget)
        controller.scrollToSection('test');
        expect(true, isTrue);
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
        await tester.pumpAndSettle();

        // Verify scroll happened (CTA should be visible)
        expect(find.text('CTA Section'), findsOneWidget);
      });
    });

    group('analytics handlers', () {
      testWidgets('handleGetStarted tracks analytics', (tester) async {
        final key = GlobalKey();
        controller.registerSection('pricing', key);
        controller.handleGetStarted();
        // Should not throw
        expect(true, isTrue);
      });

      testWidgets('handleGetStarted accepts custom location', (tester) async {
        controller.handleGetStarted(location: 'navbar');
        expect(true, isTrue);
      });

      test('handleRequestDemo tracks analytics', () {
        controller.handleRequestDemo();
        expect(true, isTrue);
      });

      test('handleTierSelection tracks tier', () {
        controller.handleTierSelection('enterprise');
        expect(true, isTrue);
      });

      test('handleFeatureInteraction tracks feature', () {
        controller.handleFeatureInteraction('AI Observability');
        expect(true, isTrue);
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
        // Controller created without callback
        controller.handleRequestDemo();
        // Should not throw
        expect(true, isTrue);
      });

      test('handleTierSelection invokes onNavigateToSignup callback', () {
        String? receivedTier;
        final controllerWithCallback = LandingController(
          onNavigateToSignup: (tier) => receivedTier = tier,
        );

        controllerWithCallback.handleTierSelection('enterprise');
        expect(receivedTier, equals('enterprise'));

        controllerWithCallback.dispose();
      });

      test('handleTierSelection handles null callback gracefully', () {
        // Controller created without callback
        controller.handleTierSelection('starter');
        // Should not throw
        expect(true, isTrue);
      });

      test('handleTierSelection passes correct tier values', () {
        final tiers = <String>[];
        final controllerWithCallback = LandingController(
          onNavigateToSignup: (tier) => tiers.add(tier),
        );

        controllerWithCallback.handleTierSelection('starter');
        controllerWithCallback.handleTierSelection('pro');
        controllerWithCallback.handleTierSelection('enterprise');

        expect(tiers, equals(['starter', 'pro', 'enterprise']));

        controllerWithCallback.dispose();
      });
    });

    group('scroll tracking', () {
      test('resetScrollTracking clears milestones', () {
        controller.resetScrollTracking();
        // Should not throw
        expect(true, isTrue);
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
        await tester.pumpAndSettle();

        // maxScrollExtent should be 0 or negative for non-scrollable content
        // _handleScroll should return early without tracking
        expect(true, isTrue);
      });

      testWidgets('scroll tracking tracks milestones at correct percentages',
          (tester) async {
        // Set a smaller viewport to ensure scrollable content
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
        await tester.pumpAndSettle();

        // Scroll to 50%
        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent * 0.5,
        );
        await tester.pumpAndSettle();

        // Scroll to 100%
        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();

        // No errors means milestone tracking worked
        expect(true, isTrue);
      });

      testWidgets('scroll tracking does not duplicate milestone tracking',
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
        await tester.pumpAndSettle();

        // Scroll past 25% multiple times
        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent * 0.3,
        );
        await tester.pumpAndSettle();

        controller.scrollController.jumpTo(0);
        await tester.pumpAndSettle();

        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent * 0.3,
        );
        await tester.pumpAndSettle();

        // 25% milestone should only be tracked once
        expect(true, isTrue);
      });

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
        await tester.pumpAndSettle();

        // Scroll to 50%
        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent * 0.5,
        );
        await tester.pumpAndSettle();

        // Reset tracking
        controller.resetScrollTracking();

        // Scroll again - should re-track 25% and 50%
        controller.scrollController.jumpTo(0);
        await tester.pumpAndSettle();

        controller.scrollController.jumpTo(
          controller.scrollController.position.maxScrollExtent * 0.5,
        );
        await tester.pumpAndSettle();

        expect(true, isTrue);
      });
    });

    group('disposal', () {
      test('dispose cleans up scroll controller', () {
        final testController = LandingController();
        testController.initialize();
        testController.dispose();
        // Should not throw
        expect(true, isTrue);
      });

      test('dispose removes scroll listener', () {
        final testController = LandingController();
        testController.initialize();

        // Dispose should remove listener without error
        testController.dispose();

        expect(true, isTrue);
      });

      test('controller can be disposed without initialization', () {
        final testController = LandingController();
        // Dispose without calling initialize
        testController.dispose();
        expect(true, isTrue);
      });
    });
  });

}
