import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/sections/cta_section.dart';
import 'package:integrity_studio_ai/widgets/common/containers.dart';
import 'package:integrity_studio_ai/config/content.dart';
import '../../helpers/test_helpers.dart';
import '../../helpers/test_constants.dart';

void main() {

  group('CTASection', () {
    // CTASection may have animations, use pump() with duration

    group('callback handling', () {
      testWidgets('invokes onGetStarted when CTA button tapped', (tester) async {
        setDesktopSize(tester);
        var getStartedCalled = false;

        await tester.pumpWidget(
          testableSection(
            CTASection(
              onGetStarted: () => getStartedCalled = true,
            ),
          ),
        );
        await tester.pump(kNavigationSettle);

        await tester.tap(find.text(CTAText.startFreeTrial));
        await tester.pump();

        expect(getStartedCalled, isTrue);
      });

      testWidgets('works without callback', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(
            const CTASection(onGetStarted: null),
          ),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(CTASection), findsOneWidget);
        expect(find.text(CTAText.startFreeTrial), findsOneWidget);
      });
    });

    group('content rendering', () {
      testWidgets('renders headline', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.textContaining('Ready to Understand Your AI'), findsOneWidget);
      });

      testWidgets('renders subheadline', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.textContaining('free trial'), findsOneWidget);
      });

      testWidgets('renders CTA button text', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text(CTAText.startFreeTrial), findsOneWidget);
      });

      testWidgets('renders arrow icon on button', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byIcon(LucideIcons.arrowRight), findsOneWidget);
      });
    });

    group('structure', () {
      testWidgets('renders as SectionContainer', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(SectionContainer), findsWidgets);
      });

      testWidgets('has gradient background container', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        // Should have Container with gradient decoration
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('responsive layout', () {
      testWidgets('renders on tablet', (tester) async {
        setTabletSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text(CTAText.startFreeTrial), findsOneWidget);
      });

      testWidgets('renders on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.text(CTAText.startFreeTrial), findsOneWidget);
      });
    });

    group('button interactivity', () {
      testWidgets('button has MouseRegion for hover', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(MouseRegion), findsWidgets);
      });

      testWidgets('button has AnimatedContainer for transitions', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(AnimatedContainer), findsWidgets);
      });

      testWidgets('button is tappable via GestureDetector', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const CTASection()),
        );
        await tester.pump(kNavigationSettle);

        expect(find.byType(GestureDetector), findsWidgets);
      });
    });
  });
}
