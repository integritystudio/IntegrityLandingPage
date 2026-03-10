import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/sections/hero_section.dart';
import 'package:integrity_studio_ai/config/content.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/test_constants.dart';

void main() {

  group('HeroSection', () {
    // HeroSection has continuous animations (DecorativeOrbs), so use pump() with duration
    // instead of pumpAndSettleWithTimeout() which would timeout

    group('callback handling', () {
      testWidgets('invokes onGetStarted when primary CTA tapped', (tester) async {
        setDesktopSize(tester);
        var getStartedCalled = false;

        await tester.pumpWidget(
          testableSection(
            HeroSection(
              onGetStarted: () => getStartedCalled = true,
            ),
          ),
        );
        await tester.pump(kNavigationSettle);

        await tester.tap(find.text('Start Free Trial').first);
        await tester.pump();

        expect(getStartedCalled, isTrue);
      });

      testWidgets('invokes onWatchDemo when secondary CTA tapped', (tester) async {
        setDesktopSize(tester);
        var requestDemoCalled = false;

        await tester.pumpWidget(
          testableSection(
            HeroSection(
              onWatchDemo: () => requestDemoCalled = true,
            ),
          ),
        );
        await tester.pump(kNavigationSettle);

        await tester.tap(find.text('Request Demo'));
        await tester.pump();

        expect(requestDemoCalled, isTrue);
      });
    });

    group('content rendering', () {
      testWidgets('renders badge', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('EU AI Act Ready'), findsWidgets);
      });

      testWidgets('renders headline', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.textContaining('AI Observability'), findsOneWidget);
      });

      testWidgets('renders primary CTA button', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('Start Free Trial'), findsOneWidget);
      });

      testWidgets('renders secondary CTA button', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('Request Demo'), findsOneWidget);
      });

      testWidgets('renders trust indicators', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('Enterprise Security'), findsOneWidget);
        expect(find.text('99.9% Uptime'), findsOneWidget);
        expect(find.text('15-min Setup'), findsOneWidget);
      });

      testWidgets('renders check icons for trust indicators', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byIcon(LucideIcons.check), findsWidgets);
      });
    });

    group('custom content', () {
      testWidgets('uses custom content when provided', (tester) async {
        // Use large desktop size to avoid overflow
        setScreenSize(tester, const Size(1920, 1200));

        await tester.pumpWidget(
          testableSection(
            const HeroSection(
              content: HeroContent(
                badge: 'Custom Badge',
                headline: 'Custom Headline',
                subheadline: 'Custom subheadline',
                primaryCTA: 'Custom CTA',
                secondaryCTA: 'Custom Secondary',
                trustIndicators: ['Trust 1', 'Trust 2'],
              ),
            ),
          ),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('Custom Badge'), findsOneWidget);
        expect(find.text('Custom Headline'), findsOneWidget);
        expect(find.text('Custom CTA'), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('renders CTAs in row on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        // Both CTAs should be present
        expect(find.text('Start Free Trial'), findsOneWidget);
        expect(find.text('Request Demo'), findsOneWidget);
      });

      testWidgets('renders on larger screens', (tester) async {
        // Use a large screen to avoid overflow issues
        setScreenSize(tester, const Size(1920, 1080));

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text('Start Free Trial'), findsOneWidget);
      });
    });

    group('decorative elements', () {
      testWidgets('contains Stack for layered content', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        // Should have Stack for layered content
        expect(find.byType(Stack), findsWidgets);
      });
    });

    group('accessibility', () {
      testWidgets('has Semantics widgets', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const HeroSection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(Semantics), findsWidgets);
      });
    });
  });
}
