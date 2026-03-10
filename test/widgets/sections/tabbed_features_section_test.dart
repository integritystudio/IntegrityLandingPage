import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/sections/tabbed_features_section.dart';
import '../../helpers/test_helpers.dart';

// Use larger desktop size to avoid overflow issues with tab row
void setLargeDesktopSize(WidgetTester tester) {
  setScreenSize(tester, const Size(1920, 1080));
}

void main() {
  group('TabbedFeaturesSection', () {
    // =========================================================================
    // Section Header
    // =========================================================================

    testWidgets('renders section header with title and subtitle', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Everything you need for AI observability'), findsOneWidget);
      expect(find.text('Purpose-built tools for LLM applications'), findsOneWidget);
    });

    // =========================================================================
    // Feature Tabs
    // =========================================================================

    testWidgets('renders all feature tabs with icons on desktop', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      // Tab titles
      expect(find.text('Real-Time Tracing'), findsOneWidget);
      expect(find.text('Cost Analytics'), findsOneWidget);
      expect(find.text('EU AI Act Tools'), findsOneWidget);
      expect(find.text('Quality Metrics'), findsOneWidget);

      // Tab icons
      expect(find.byIcon(LucideIcons.activity), findsWidgets);
      expect(find.byIcon(LucideIcons.dollarSign), findsWidgets);
      expect(find.byIcon(LucideIcons.shieldCheck), findsWidgets);
      expect(find.byIcon(LucideIcons.barChart3), findsWidgets);

      // First tab content visible by default
      expect(find.text('See every decision your AI makes'), findsOneWidget);
    });

    testWidgets('renders short tab titles on mobile', (tester) async {
      setMobileSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Tracing'), findsOneWidget);
      expect(find.text('Costs'), findsOneWidget);
      expect(find.text('Compliance'), findsOneWidget);
      expect(find.text('Quality'), findsOneWidget);
    });

    // =========================================================================
    // Feature Content (tab interactions require fresh state)
    // =========================================================================

    testWidgets('shows Real-Time Tracing content by default with stat card', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      // Title and description
      expect(find.text('See every decision your AI makes'), findsOneWidget);
      expect(find.textContaining('Full visibility into LLM calls'), findsOneWidget);
      expect(find.text('73% faster issue resolution'), findsOneWidget);

      // Benefits with checkmarks
      expect(find.text('Complete request/response logging'), findsOneWidget);
      expect(find.text('Token usage analytics'), findsOneWidget);
      expect(find.text('Custom trace attributes'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsWidgets);

      // Stat card
      expect(find.text('73%'), findsOneWidget);
      expect(find.text('faster debugging'), findsOneWidget);
    });

    testWidgets('switches to Cost Analytics content when tab tapped', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      await tester.tap(find.text('Cost Analytics'));
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Stop overpaying for AI infrastructure'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('avg cost savings'), findsOneWidget);
    });

    testWidgets('switches to EU AI Act Tools content when tab tapped', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      await tester.tap(find.text('EU AI Act Tools'));
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Compliance preparation, simplified'), findsOneWidget);
      expect(find.text('Risk category assessment'), findsOneWidget);
      expect(find.text('Automated documentation'), findsOneWidget);
      expect(find.text('Audit trail exports'), findsOneWidget);
      expect(find.text('EU data residency option'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('traceability coverage'), findsOneWidget);
    });

    testWidgets('switches to Quality Metrics content when tab tapped', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      await tester.tap(find.text('Quality Metrics'));
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Measure what matters for AI quality'), findsOneWidget);
      expect(find.text('Quality scoring'), findsOneWidget);
      expect(find.text('Hallucination detection'), findsOneWidget);
      expect(find.text('A/B testing support'), findsOneWidget);
      expect(find.text('Alerting on quality drops'), findsOneWidget);
      expect(find.text('5x'), findsOneWidget);
      expect(find.text('faster QA cycles'), findsOneWidget);
    });

    // =========================================================================
    // Responsive Design
    // =========================================================================

    testWidgets('renders correctly across all screen sizes', (tester) async {
      // Mobile
      setMobileSize(tester);
      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Everything you need for AI observability'), findsOneWidget);
      expect(find.text('Tracing'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);

      // Tablet
      setTabletSize(tester);
      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Everything you need for AI observability'), findsOneWidget);

      // Desktop
      setLargeDesktopSize(tester);
      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.text('Everything you need for AI observability'), findsOneWidget);
      expect(find.text('Real-Time Tracing'), findsOneWidget);
    });

    // =========================================================================
    // Animations
    // =========================================================================

    testWidgets('uses animation widgets for content and tabs', (tester) async {
      setLargeDesktopSize(tester);

      await tester.pumpWidget(
        testableSection(const TabbedFeaturesSection()),
      );
      await tester.pumpAndSettleWithTimeout();

      expect(find.byType(AnimatedSwitcher), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsWidgets);
    });
  });
}
