import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/docs/doc_components.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

/// Finds a [Semantics] widget whose label exactly matches [label].
Finder findSemanticsLabel(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

void main() {
  // ==========================================================================
  // UNIT TESTS
  // ==========================================================================

  group('DocCalloutVariant', () {
    test('has all four variants', () {
      expect(DocCalloutVariant.values.length, 4);
      expect(DocCalloutVariant.values, contains(DocCalloutVariant.success));
      expect(DocCalloutVariant.values, contains(DocCalloutVariant.info));
      expect(DocCalloutVariant.values, contains(DocCalloutVariant.warning));
      expect(DocCalloutVariant.values, contains(DocCalloutVariant.danger));
    });
  });

  // ==========================================================================
  // WIDGET TESTS
  // ==========================================================================

  group('DocSection', () {
    testWidgets('renders correctly with all props and layout', (tester) async {
      await tester.pumpWidget(testableWidget(
        DocSection(
          icon: LucideIcons.activity,
          title: 'Test Section',
          child: const Text('Section content'),
        ),
      ));

      // Content renders
      expect(find.text('Test Section'), findsOneWidget);
      expect(find.text('Section content'), findsOneWidget);
      expect(find.byIcon(LucideIcons.activity), findsOneWidget);

      // Layout is correct
      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(DocSection),
          matching: find.byType(Column).first,
        ),
      );
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);

      // Custom accent color works
      await tester.pumpWidget(testableWidget(
        DocSection(
          icon: LucideIcons.shield,
          title: 'Custom Color',
          accentColor: AppColors.purple500,
          child: const Text('Content'),
        ),
      ));
      expect(find.text('Custom Color'), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        DocSection(
          icon: LucideIcons.activity,
          title: 'Semantics Test',
          child: const Text('Content'),
        ),
      ));

      expect(findSemanticsLabel('Semantics Test'), findsOneWidget);
    });
  });

  group('DocFeatureCard', () {
    testWidgets('renders correctly with all props', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocFeatureCard(
          icon: LucideIcons.zap,
          title: 'Fast Performance',
          description: 'Lightning fast execution',
        ),
      ));

      // Content renders
      expect(find.text('Fast Performance'), findsOneWidget);
      expect(find.text('Lightning fast execution'), findsOneWidget);
      expect(find.byIcon(LucideIcons.zap), findsOneWidget);

      // Has fixed width of 200
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocFeatureCard),
          matching: find.byType(Container).first,
        ),
      );
      expect(container.constraints?.maxWidth, kDocFeatureCardWidth);

      // Custom accent color works
      await tester.pumpWidget(testableWidget(
        const DocFeatureCard(
          icon: LucideIcons.database,
          title: 'Database',
          description: 'Persistent storage',
          accentColor: AppColors.success,
        ),
      ));
      expect(find.text('Database'), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocFeatureCard(
          icon: LucideIcons.zap,
          title: 'Speed',
          description: 'Very fast',
        ),
      ));

      expect(findSemanticsLabel('Speed: Very fast'), findsOneWidget);
    });
  });

  group('DocCodeBlock', () {
    testWidgets('renders code with correct styling', (tester) async {
      const multilineCode = '''
function example() {
  return 42;
}''';

      await tester.pumpWidget(testableWidget(
        const DocCodeBlock(code: multilineCode),
      ));

      // Code is displayed
      expect(find.text(multilineCode), findsOneWidget);

      // Code is selectable
      expect(find.byType(SelectableText), findsOneWidget);

      // Uses monospace font
      final text = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(text.style?.fontFamily, kDocCodeFontFamily);

      // Has full width
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocCodeBlock),
          matching: find.byType(Container).first,
        ),
      );
      expect(container.constraints?.minWidth, double.infinity);
    });

    testWidgets('has semantics label for both branches', (tester) async {
      // Without title
      await tester.pumpWidget(testableWidget(
        const DocCodeBlock(code: 'x = 1'),
      ));
      expect(findSemanticsLabel('Code block'), findsOneWidget);

      // With title — outer Semantics + inner codeWidget Semantics
      await tester.pumpWidget(testableWidget(
        const DocCodeBlock(code: 'x = 1', title: 'Example'),
      ));
      expect(findSemanticsLabel('Example'), findsWidgets);
    });
  });

  group('DocTable', () {
    testWidgets('renders headers and data rows correctly', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocTable(
          headers: ['Name', 'Type', 'Description'],
          rows: [
            ['A1', 'B1', 'C1'],
            ['A2', 'B2', 'C2'],
          ],
        ),
      ));

      // Headers render
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);

      // Data rows render
      expect(find.text('A1'), findsOneWidget);
      expect(find.text('B1'), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);
      expect(find.text('B2'), findsOneWidget);

      // Uses Table widget
      expect(find.byType(Table), findsOneWidget);

      // Empty table works
      await tester.pumpWidget(testableWidget(
        const DocTable(
          headers: ['Header'],
          rows: [],
        ),
      ));
      expect(find.text('Header'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocTable(
          headers: ['Col A', 'Col B'],
          rows: [['1', '2']],
        ),
      ));

      expect(findSemanticsLabel('Table: Col A, Col B'), findsOneWidget);
    });
  });

  group('DocBulletList', () {
    testWidgets('renders items with bullets and styling', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocBulletList(
          items: ['Item 1', 'Item 2', 'Item 3'],
        ),
      ));

      // Items render
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);

      // Bullet characters
      expect(find.textContaining(kDocBulletChar), findsNWidgets(3));

      // Correct alignment
      final column = tester.widget<Column>(
        find.descendant(
          of: find.byType(DocBulletList),
          matching: find.byType(Column).first,
        ),
      );
      expect(column.crossAxisAlignment, CrossAxisAlignment.start);

      // Custom bullet color works
      await tester.pumpWidget(testableWidget(
        const DocBulletList(
          items: ['Custom color item'],
          bulletColor: AppColors.purple500,
        ),
      ));
      expect(find.text('Custom color item'), findsOneWidget);

      // Empty list works
      await tester.pumpWidget(testableWidget(
        const DocBulletList(items: []),
      ));
      expect(find.byType(DocBulletList), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocBulletList(items: ['A', 'B']),
      ));

      expect(findSemanticsLabel('List: 2 items'), findsOneWidget);
    });
  });

  group('DocNumberedList', () {
    testWidgets('renders items with numbered circles', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocNumberedList(
          items: ['First', 'Second', 'Third'],
        ),
      ));

      // Items render
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);

      // Numbers render
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Numbers are in circular containers
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(DocNumberedList),
          matching: find.byType(Container),
        ),
      );
      final circleContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.shape == BoxShape.circle;
        }
        return false;
      });
      expect(circleContainers, isNotEmpty);

      // Custom accent color works
      await tester.pumpWidget(testableWidget(
        const DocNumberedList(
          items: ['Styled item'],
          accentColor: AppColors.warning,
        ),
      ));
      expect(find.text('Styled item'), findsOneWidget);

      // Handles large lists
      await tester.pumpWidget(testableWidget(
        DocNumberedList(
          items: List.generate(10, (i) => 'Item ${i + 1}'),
        ),
      ));
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocNumberedList(items: ['Step 1', 'Step 2', 'Step 3']),
      ));

      expect(findSemanticsLabel('Steps: 3 items'), findsOneWidget);
    });
  });

  group('DocCallout', () {
    testWidgets('all variants render with correct icons', (tester) async {
      final variantData = [
        (DocCallout.info(title: 'Info', message: 'msg'), LucideIcons.lightbulb),
        (DocCallout.success(title: 'Success', message: 'msg'), LucideIcons.checkCircle),
        (DocCallout.warning(title: 'Warning', message: 'msg'), LucideIcons.alertTriangle),
        (DocCallout.danger(title: 'Danger', message: 'msg'), LucideIcons.alertCircle),
      ];

      for (final (widget, icon) in variantData) {
        await tester.pumpWidget(testableWidget(widget));
        expect(find.byIcon(icon), findsOneWidget);
      }
    });

    testWidgets('renders message, items, and styling correctly', (tester) async {
      // Message only
      await tester.pumpWidget(testableWidget(
        const DocCallout(
          title: 'Title',
          message: 'This is the message',
          variant: DocCalloutVariant.info,
        ),
      ));
      expect(find.text('This is the message'), findsOneWidget);

      // Items only
      await tester.pumpWidget(testableWidget(
        const DocCallout(
          title: 'Title',
          items: ['Item A', 'Item B', 'Item C'],
          variant: DocCalloutVariant.info,
        ),
      ));
      expect(find.textContaining('Item A'), findsOneWidget);
      expect(find.textContaining('Item B'), findsOneWidget);
      expect(find.textContaining('Item C'), findsOneWidget);

      // Both message and items
      await tester.pumpWidget(testableWidget(
        const DocCallout(
          title: 'Both',
          message: 'Main message',
          items: ['Extra item'],
          variant: DocCalloutVariant.success,
        ),
      ));
      expect(find.text('Main message'), findsOneWidget);
      expect(find.textContaining('Extra item'), findsOneWidget);

      // Has left border accent
      await tester.pumpWidget(testableWidget(
        const DocCallout.info(
          title: 'Styled',
          message: 'With border',
        ),
      ));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocCallout),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);

      // Default variant is info
      await tester.pumpWidget(testableWidget(
        const DocCallout(
          title: 'Default',
          message: 'Default variant',
        ),
      ));
      expect(find.byIcon(LucideIcons.lightbulb), findsOneWidget);
    });

    testWidgets('has semantics label with variant', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocCallout.warning(
          title: 'Caution',
          message: 'Be careful',
        ),
      ));

      expect(findSemanticsLabel('warning callout: Caution'), findsOneWidget);
    });
  });

  group('DocStatCard', () {
    testWidgets('renders value and label text', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(value: '99.9%', label: 'Uptime'),
      ));

      expect(find.text('99.9%'), findsOneWidget);
      expect(find.text('Uptime'), findsOneWidget);
    });

    testWidgets('defaults accentColor to AppColors.blue400', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(value: '42', label: 'Items'),
      ));

      final valueText = tester.widget<Text>(find.text('42'));
      expect(valueText.style?.color, AppColors.blue400);
    });

    testWidgets('applies custom accentColor to value text', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(
          value: '100',
          label: 'Score',
          accentColor: AppColors.success,
        ),
      ));

      final valueText = tester.widget<Text>(find.text('100'));
      expect(valueText.style?.color, AppColors.success);
    });

    testWidgets('const constructor works with all-literal params', (tester) async {
      const widget = DocStatCard(value: 'v1.0', label: 'Version');
      await tester.pumpWidget(testableWidget(widget));

      expect(find.text('v1.0'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(value: '99.9%', label: 'Uptime'),
      ));

      expect(findSemanticsLabel('99.9% Uptime'), findsOneWidget);
    });

    testWidgets('defaults backgroundColor, borderColor, borderRadius', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(value: '1', label: 'Test'),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocStatCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.gray800);
      expect(decoration.border, Border.all(color: AppColors.gray700));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusMD),
      );
    });

    testWidgets('applies custom backgroundColor, borderColor, borderRadius', (tester) async {
      await tester.pumpWidget(testableWidget(
        DocStatCard(
          value: '99%',
          label: 'SLA',
          backgroundColor: AppColors.gray700,
          borderColor: AppColors.gray600,
          borderRadius: AppSpacing.radiusSM,
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocStatCard),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.gray700);
      expect(decoration.border, Border.all(color: AppColors.gray600));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusSM),
      );
    });

    testWidgets('applies custom valueStyle to value text', (tester) async {
      await tester.pumpWidget(testableWidget(
        DocStatCard(
          value: '87%',
          label: 'Coverage',
          valueStyle:
              AppTypography.headingSM.copyWith(color: AppColors.purple400),
        ),
      ));

      final valueText = tester.widget<Text>(find.text('87%'));
      expect(valueText.style?.fontSize, 24); // headingSM fontSize
      expect(valueText.style?.color, AppColors.purple400);
    });

    testWidgets('applies custom constraints to container', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(
          value: '50',
          label: 'Metrics',
          constraints: BoxConstraints(minWidth: 140, maxWidth: 180),
        ),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocStatCard),
          matching: find.byType(Container).first,
        ),
      );
      expect(
        container.constraints,
        const BoxConstraints(minWidth: 140, maxWidth: 180),
      );
    });

    testWidgets('valueStyle defaults to headingMD with accentColor',
        (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocStatCard(value: '10', label: 'Default'),
      ));

      final valueText = tester.widget<Text>(find.text('10'));
      expect(valueText.style?.fontSize, 36); // headingMD fontSize
      expect(valueText.style?.color, AppColors.blue400);
    });
  });

  group('DocInlineWarning', () {
    testWidgets('renders message and warning icon', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocInlineWarning(message: 'This is a warning'),
      ));

      expect(find.text('This is a warning'), findsOneWidget);
      expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);
    });

    testWidgets('renders with fullBorder variant', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocInlineWarning(message: 'Full border', fullBorder: true),
      ));

      expect(find.text('Full border'), findsOneWidget);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DocInlineWarning),
          matching: find.byType(Container).first,
        ),
      );
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration?.border, isNotNull);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(testableWidget(
        const DocInlineWarning(message: 'Careful now'),
      ));

      expect(findSemanticsLabel('Warning: Careful now'), findsOneWidget);
    });
  });
}
