import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/pages/comparison_page.dart';
import 'package:integrity_studio_ai/config/content.dart';
import '../helpers/test_helpers.dart';

void main() {

  group('ComparisonPage', () {
    group('content models', () {
      test('ComparisonFeature creates with all fields', () {
        const feature = ComparisonFeature(
          feature: 'Test Feature',
          ourValue: 'Full support',
          theirValue: 'Limited',
          ourSupport: true,
          theirSupport: false,
        );

        expect(feature.feature, equals('Test Feature'));
        expect(feature.ourValue, equals('Full support'));
        expect(feature.theirValue, equals('Limited'));
        expect(feature.ourSupport, isTrue);
        expect(feature.theirSupport, isFalse);
      });

      test('ComparisonFeature has correct defaults', () {
        const feature = ComparisonFeature(
          feature: 'Test',
        );

        expect(feature.ourSupport, isTrue);
        expect(feature.theirSupport, isTrue);
        expect(feature.ourValue, isNull);
        expect(feature.theirValue, isNull);
      });

      test('MigrationStep creates with all fields', () {
        const step = MigrationStep(
          number: 1,
          title: 'First Step',
          description: 'Do this first',
          codeSnippet: 'npm install',
          docsUrl: '/docs/install',
        );

        expect(step.number, equals(1));
        expect(step.title, equals('First Step'));
        expect(step.description, equals('Do this first'));
        expect(step.codeSnippet, equals('npm install'));
        expect(step.docsUrl, equals('/docs/install'));
      });

      test('MigrationStep optional fields default to null', () {
        const step = MigrationStep(
          number: 1,
          title: 'Step',
          description: 'Description',
        );

        expect(step.codeSnippet, isNull);
        expect(step.docsUrl, isNull);
      });
    });

    group('WhyLabs comparison content', () {
      test('has correct competitor name', () {
        expect(
          ComparisonPageVariants.whylabs.competitorName,
          equals('WhyLabs'),
        );
      });

      test('has shutdown status message', () {
        expect(
          ComparisonPageVariants.whylabs.competitorStatus,
          contains('shutdown'),
        );
      });

      test('has key differentiators', () {
        final diffs = ComparisonPageVariants.whylabs.keyDifferentiators;
        expect(diffs, isNotEmpty);
        expect(diffs.length, greaterThanOrEqualTo(3));
      });

      test('has feature comparison items', () {
        final features = ComparisonPageVariants.whylabs.featureComparison;
        expect(features, isNotEmpty);
        // Should have core features
        expect(
          features.any((f) => f.feature.contains('LLM')),
          isTrue,
        );
        expect(
          features.any((f) => f.feature.contains('EU AI Act')),
          isTrue,
        );
      });

      test('has migration steps', () {
        final steps = ComparisonPageVariants.whylabs.migrationSteps;
        expect(steps, isNotEmpty);
        expect(steps.length, equals(5));
        // Steps should be numbered sequentially
        for (var i = 0; i < steps.length; i++) {
          expect(steps[i].number, equals(i + 1));
        }
      });

      test('has special offer', () {
        expect(ComparisonPageVariants.whylabs.specialOfferBadge, isNotNull);
        expect(ComparisonPageVariants.whylabs.specialOfferText, isNotNull);
        expect(
          ComparisonPageVariants.whylabs.specialOfferText,
          contains('WHYLABS2025'),
        );
      });

      test('has reasons to choose both platforms', () {
        expect(ComparisonPageVariants.whylabs.whyChooseUs, isNotEmpty);
        expect(ComparisonPageVariants.whylabs.whyChooseThem, isNotEmpty);
        // Fair comparison should have reasons for competitor too
        expect(
          ComparisonPageVariants.whylabs.whyChooseThem.length,
          greaterThanOrEqualTo(2),
        );
      });

      test('migration steps include code snippets', () {
        final steps = ComparisonPageVariants.whylabs.migrationSteps;
        final stepsWithCode =
            steps.where((s) => s.codeSnippet != null).toList();
        expect(stepsWithCode, isNotEmpty);
      });
    });

    group('Arize comparison content', () {
      test('has correct competitor name', () {
        expect(ComparisonPageVariants.arize.competitorName, equals('Arize AI'));
      });

      test('has key differentiators', () {
        final diffs = ComparisonPageVariants.arize.keyDifferentiators;
        expect(diffs, isNotEmpty);
      });

      test('has no shutdown status (active competitor)', () {
        expect(ComparisonPageVariants.arize.competitorStatus, isNull);
      });

      test('has empty migration steps (not needed for active competitor)', () {
        expect(ComparisonPageVariants.arize.migrationSteps, isEmpty);
      });
    });

    // =========================================================================
    // WhyLabs page static structure tests - share widget state via setUpAll()
    // =========================================================================
    group('WhyLabs page structure tests', () {
      // Shared widget for static structure verification tests
      late Widget whylabsPage;

      setUpAll(() {
        whylabsPage = MaterialApp(
          theme: testTheme,
          home: ComparisonPage.whylabs(),
        );
      });

      group('hero section', () {
        testWidgets('renders hero section with headline', (tester) async {
          setDesktopSize(tester);
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          expect(find.text('WhyLabs Alternative'), findsOneWidget);
          expect(find.textContaining('WhyLabs Is Shutting Down'), findsOneWidget);
        });

        testWidgets('renders shutdown status badge', (tester) async {
          setDesktopSize(tester);
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          expect(
            find.textContaining('shutdown March 9, 2025'),
            findsOneWidget,
          );
          expect(find.byIcon(LucideIcons.alertTriangle), findsWidgets);
        });
      });

      group('sections with key lookup', () {
        testWidgets('renders special offer banner', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 1200));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for special offer section
          final section = find.byKey(const Key('special-offer-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('WhyLabs Migration Special')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.textContaining('WHYLABS2025')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.gift)),
            findsOneWidget,
          );
        });

        testWidgets('renders key differentiators section', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 2000));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for differentiators section
          final section = find.byKey(const Key('key-differentiators-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Why Switch to Integrity Studio?')),
            findsOneWidget,
          );
          // Check for differentiator items with checkmarks
          expect(
            find.descendant(of: section, matching: find.byIcon(LucideIcons.check)),
            findsWidgets,
          );
        });

        testWidgets('renders feature comparison table', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 2500));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for feature comparison section
          final section = find.byKey(const Key('feature-comparison-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Feature Comparison')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Integrity Studio')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('WhyLabs')),
            findsWidgets,
          ); // In header and content
          expect(
            find.descendant(of: section, matching: find.byType(DataTable)),
            findsOneWidget,
          );
        });

        testWidgets('renders who should choose sections', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 3000));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for who should choose section
          final section = find.byKey(const Key('who-should-choose-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.textContaining('Choose Integrity Studio if')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.textContaining('Consider WhyLabs if')),
            findsOneWidget,
          );
        });

        testWidgets('renders migration guide section', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 4000));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for migration steps section
          final section = find.byKey(const Key('migration-steps-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Migration Guide')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Export Your WhyLabs Data')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.textContaining('under 1 hour')),
            findsOneWidget,
          );
        });

        testWidgets('renders code snippets in migration steps', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 4000));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for migration steps section
          final section = find.byKey(const Key('migration-steps-section'));
          // Find code snippets
          expect(
            find.descendant(of: section, matching: find.textContaining('from whylogs import why')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.textContaining('from integritystudio import')),
            findsOneWidget,
          );
        });

        testWidgets('renders final CTA section', (tester) async {
          // Use taller screen to ensure sliver is built (list virtualization)
          setScreenSize(tester, const Size(1440, 5000));
          await tester.pumpWidget(whylabsPage);
          await tester.pump();
          await tester.pump();

          // Use key-based lookup for final CTA section
          final section = find.byKey(const Key('final-cta-section'));
          expect(section, findsOneWidget);
          expect(
            find.descendant(of: section, matching: find.text('Ready to Make the Switch?')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: section, matching: find.text('Schedule Demo')),
            findsOneWidget,
          );
        });
      });
    });

    // =========================================================================
    // WhyLabs page interaction tests - require fresh state per test
    // =========================================================================
    group('WhyLabs page interaction tests', () {
      testWidgets('calls onBack callback when back button pressed',
          (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: ComparisonPage.whylabs(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byIcon(LucideIcons.arrowLeft));
        await tester.pump();

        expect(backCalled, isTrue);
      });

      testWidgets('calls onBack when Back to Home pressed', (tester) async {
        setDesktopSize(tester);
        var backCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: ComparisonPage.whylabs(onBack: () => backCalled = true),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text('Back to Home'));
        await tester.pump();

        expect(backCalled, isTrue);
      });
    });

    // =========================================================================
    // Arize page structure tests - share widget state via setUpAll()
    // =========================================================================
    group('Arize page structure tests', () {
      // Shared widget for Arize page structure tests
      late Widget arizePage;

      setUpAll(() {
        arizePage = MaterialApp(
          theme: testTheme,
          home: ComparisonPage.arize(),
        );
      });

      testWidgets('renders hero section without shutdown badge', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(arizePage);
        await tester.pump();
        await tester.pump();

        expect(find.text('Arize AI Alternative'), findsOneWidget);
        // Should not have shutdown warning for active competitor
        expect(
          find.byIcon(LucideIcons.alertTriangle),
          findsNothing,
        );
      });

      testWidgets('does not render migration steps for active competitor',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(arizePage);
        await tester.pump();
        await tester.pump();

        // Migration Guide section should not exist for active competitors (no key present)
        expect(find.byKey(const Key('migration-steps-section')), findsNothing);
        expect(find.text('Migration Guide'), findsNothing);
      });
    });

    group('responsive design', () {
      testWidgets('renders correctly on tablet', (tester) async {
        setTabletSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: ComparisonPage.whylabs(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(ComparisonPage), findsOneWidget);
      });

      testWidgets('renders correctly on desktop', (tester) async {
        setDesktopSize(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: testTheme,
            home: ComparisonPage.whylabs(),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(ComparisonPage), findsOneWidget);
        expect(find.text('WhyLabs Alternative'), findsOneWidget);
      });
    });

    group('code snippet functionality', () {
      // Reuse WhyLabs page widget for code snippet tests
      late Widget whylabsPage;

      setUpAll(() {
        whylabsPage = MaterialApp(
          theme: testTheme,
          home: ComparisonPage.whylabs(),
        );
      });

      testWidgets('code snippet has copy button', (tester) async {
        // Use taller screen to ensure sliver is built (list virtualization)
        setScreenSize(tester, const Size(1440, 4000));
        await tester.pumpWidget(whylabsPage);
        await tester.pump();
        await tester.pump();

        // Use key-based lookup for migration steps section
        final section = find.byKey(const Key('migration-steps-section'));
        // Find copy buttons within migration section
        expect(
          find.descendant(of: section, matching: find.text('Copy')),
          findsWidgets,
        );
        expect(
          find.descendant(of: section, matching: find.byIcon(LucideIcons.copy)),
          findsWidgets,
        );
      });
    });

    group('AppContent accessors', () {
      test('whylabsComparison accessor returns WhyLabs content', () {
        final content = AppContent.whylabsComparison;
        expect(content.competitorName, equals('WhyLabs'));
      });

      test('arizeComparison accessor returns Arize content', () {
        final content = AppContent.arizeComparison;
        expect(content.competitorName, equals('Arize AI'));
      });
    });

    group('factory constructors', () {
      test('whylabs factory creates correct page', () {
        final page = ComparisonPage.whylabs();
        expect(page.content.competitorName, equals('WhyLabs'));
      });

      test('arize factory creates correct page', () {
        final page = ComparisonPage.arize();
        expect(page.content.competitorName, equals('Arize AI'));
      });
    });
  });
}
