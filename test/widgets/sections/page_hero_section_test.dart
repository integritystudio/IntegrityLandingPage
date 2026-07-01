import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/sections/page_hero_section.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

void main() {
  const kAccentColor = AppColors.purple500;

  Widget buildHero({
    bool isMobile = false,
    Color accentColor = kAccentColor,
    String badgeText = 'Test Badge',
    String headline = 'Test Headline',
    String subheadline = 'Test subheadline text.',
    double? subheadlineMaxWidth,
    double? mobileHeadlineFontSize,
    Widget? extraContent,
  }) {
    return testableWidget(
      SingleChildScrollView(
        child: PageHeroSection(
          isMobile: isMobile,
          accentColor: accentColor,
          badgeIcon: LucideIcons.shieldCheck,
          badgeText: badgeText,
          headline: headline,
          subheadline: subheadline,
          subheadlineMaxWidth: subheadlineMaxWidth ?? 700,
          mobileHeadlineFontSize: mobileHeadlineFontSize ?? 28,
          extraContent: extraContent,
        ),
      ),
    );
  }

  group('PageHeroSection', () {
    group('content rendering', () {
      testWidgets('renders badgeText', (tester) async {
        await tester.pumpWidget(buildHero());
        expect(find.text('Test Badge'), findsOneWidget);
      });

      testWidgets('renders badgeIcon', (tester) async {
        await tester.pumpWidget(buildHero());
        expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
      });

      testWidgets('renders headline', (tester) async {
        await tester.pumpWidget(buildHero());
        expect(find.text('Test Headline'), findsOneWidget);
      });

      testWidgets('renders subheadline', (tester) async {
        await tester.pumpWidget(buildHero());
        expect(find.text('Test subheadline text.'), findsOneWidget);
      });
    });

    group('extraContent', () {
      testWidgets('extraContent is displayed when provided', (tester) async {
        await tester.pumpWidget(
          buildHero(extraContent: const Text('extra widget')),
        );
        expect(find.text('extra widget'), findsOneWidget);
      });

      testWidgets('extraContent is absent when not provided', (tester) async {
        await tester.pumpWidget(buildHero());
        expect(find.text('extra widget'), findsNothing);
      });
    });

    group('subheadlineMaxWidth constraint', () {
      testWidgets('applies subheadlineMaxWidth via ConstrainedBox', (tester) async {
        await tester.pumpWidget(buildHero(subheadlineMaxWidth: 400));
        final boxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
        expect(
          boxes.any((b) => b.constraints.maxWidth == 400),
          isTrue,
        );
      });
    });

    group('mobileHeadlineFontSize', () {
      testWidgets('applies custom mobile font size on mobile', (tester) async {
        await tester.pumpWidget(buildHero(isMobile: true, mobileHeadlineFontSize: 36));
        final headlineText = tester.widget<Text>(
          find.text('Test Headline'),
        );
        expect(headlineText.style?.fontSize, equals(36));
      });

      testWidgets('desktop does not apply mobileHeadlineFontSize', (tester) async {
        await tester.pumpWidget(buildHero(isMobile: false, mobileHeadlineFontSize: 36));
        final headlineText = tester.widget<Text>(
          find.text('Test Headline'),
        );
        // Desktop uses AppTypography.headingXL — fontSize should not be 36
        expect(headlineText.style?.fontSize, isNot(equals(36)));
      });
    });

    group('gradient background', () {
      testWidgets('renders outer Container with LinearGradient', (tester) async {
        await tester.pumpWidget(buildHero());
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasGradient = containers.any((c) =>
          c.decoration is BoxDecoration &&
          (c.decoration as BoxDecoration).gradient is LinearGradient,
        );
        expect(hasGradient, isTrue);
      });
    });
  });
}
