import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/sections/services_section.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ServicesSection', () {
    group('widget structure', () {
      testWidgets('renders section title', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.services.title), findsOneWidget);
      });

      testWidgets('renders section subtitle', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.services.subtitle), findsOneWidget);
      });

      testWidgets('renders all 6 service titles', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        for (final service in AppContent.services.services) {
          expect(find.text(service.title), findsOneWidget);
        }
      });

      testWidgets('renders service descriptions', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        for (final service in AppContent.services.services) {
          expect(find.text(service.description), findsOneWidget);
        }
      });

      testWidgets('renders section CTA button', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text(AppContent.services.ctaText), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('service cards are accessible', (tester) async {
        setScreenSize(tester, TestScreenSizes.desktopLarge);
        final semanticsHandle = tester.ensureSemantics();
        await tester.pumpWidget(testableSection(const ServicesSection()));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text('LLM Monitoring & Tracing'), findsOneWidget);

        semanticsHandle.dispose();
      });
    });
  });
}
