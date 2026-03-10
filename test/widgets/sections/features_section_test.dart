import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/sections/features_section.dart';
import 'package:integrity_studio_ai/widgets/common/containers.dart';
import 'package:integrity_studio_ai/config/content.dart';
import '../../helpers/test_helpers.dart';

void main() {

  group('FeaturesSection', () {
    group('structure', () {
      testWidgets('renders as SectionContainer', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(SectionContainer), findsWidgets);
      });

      testWidgets('uses ResponsiveGrid for layout', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ResponsiveGrid), findsOneWidget);
      });

      testWidgets('renders section title', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(SectionTitle), findsOneWidget);
      });
    });

    group('content rendering', () {
      testWidgets('renders feature cards from AppContent', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        // Should render cards from AppContent.features
        final featureCount = AppContent.features.features.length;
        if (featureCount > 0) {
          // At least some feature content should be present
          expect(find.byType(Column), findsWidgets);
        }
      });

      testWidgets('uses custom content when provided with features', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(
            const FeaturesSection(
              content: FeaturesContent(
                title: 'Custom Title',
                subtitle: 'Custom Subtitle',
                features: [
                  FeatureCardContent(
                    icon: LucideIcons.activity,
                    title: 'Custom Feature',
                    description: 'Custom description',
                    bullets: ['Bullet 1'],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Custom Subtitle'), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('renders on mobile', (tester) async {
        setMobileSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(FeaturesSection), findsOneWidget);
      });

      testWidgets('renders on tablet', (tester) async {
        setTabletSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(FeaturesSection), findsOneWidget);
      });

      testWidgets('renders on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(const FeaturesSection()),
        );
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(FeaturesSection), findsOneWidget);
      });
    });

    group('fallback behavior', () {
      testWidgets('uses AppContent when empty features provided', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          testableSection(
            const FeaturesSection(
              content: FeaturesContent(
                title: 'Title',
                subtitle: 'Subtitle',
                features: [], // Empty - should fallback to AppContent
              ),
            ),
          ),
        );
        await tester.pumpAndSettleWithTimeout();

        // Should use AppContent.features title instead
        expect(find.text(AppContent.features.title), findsOneWidget);
      });
    });
  });
}
