import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/about_section.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('AboutSection', () {
    group('widget structure', () {
      testWidgets('renders section title', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.about.title), findsOneWidget);
      });

      testWidgets('renders section subtitle', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.about.subtitle), findsOneWidget);
      });

      testWidgets('renders mission statement', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.about.missionStatement), findsOneWidget);
      });

      testWidgets('renders vision statement', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.about.visionStatement), findsOneWidget);
      });

      testWidgets('renders all 4 company values', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        for (final value in AppContent.about.values) {
          expect(find.text(value.title), findsOneWidget);
        }
      });

      testWidgets('renders team member names', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        for (final member in AppContent.about.team) {
          expect(find.text(member.name), findsOneWidget);
        }
      });

      testWidgets('renders location info', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.textContaining(AppContent.about.locationCity), findsWidgets);
      });

      testWidgets('renders founding year', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.textContaining(AppContent.about.foundedYear), findsWidgets);
      });
    });

    group('accessibility', () {
      testWidgets('mission and vision cards are accessible', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(testableSection(const AboutSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text('Our Mission'), findsOneWidget);
        expect(find.text('Our Vision'), findsOneWidget);

        semanticsHandle.dispose();
      });
    });
  });
}
