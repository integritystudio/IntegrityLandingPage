import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/hover_text_link.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('HoverTextLink', () {
    testWidgets('renders text with default color', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Test Link',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      expect(find.text('Test Link'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Test Link'));
      expect(textWidget.style?.color, equals(AppColors.gray400));
    });

    testWidgets('invokes onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Tap Me',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('applies custom style preserving all properties', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Styled',
            defaultColor: AppColors.gray300,
            hoverColor: AppColors.blue400,
            style: AppTypography.bodySM.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Styled'));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w500));
      expect(textWidget.style?.color, equals(AppColors.gray300));
      // #70 regression: fontSize from base style must survive copyWith(color:)
      expect(textWidget.style?.fontSize, equals(AppTypography.bodySM.fontSize));
    });

    testWidgets('renders padding when provided', (tester) async {
      const testPadding = EdgeInsets.symmetric(horizontal: 16.0);

      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Padded',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
            padding: testPadding,
          ),
        ),
      );

      expect(find.text('Padded'), findsOneWidget);
      final paddingFinder = find.descendant(
        of: find.byType(HoverTextLink),
        matching: find.byType(Padding),
      );
      expect(paddingFinder, findsOneWidget);
      final padding = tester.widget<Padding>(paddingFinder);
      expect(padding.padding, equals(testPadding));
    });

    testWidgets('omits Padding widget when padding is null', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'No Padding',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      final paddings = find.descendant(
        of: find.byType(HoverTextLink),
        matching: find.byType(Padding),
      );
      expect(paddings, findsNothing);
    });

    testWidgets('has Semantics with button role and label', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Semantic Link',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
            onTap: () {},
          ),
        ),
      );

      final semantics = tester.firstWidget<Semantics>(
        find.descendant(
          of: find.byType(HoverTextLink),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.label, equals('Semantic Link'));
      expect(semantics.properties.onTap, isNotNull);
    });

    testWidgets('uses click cursor', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Cursor Test',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      final mouseRegion = tester.widget<MouseRegion>(
        find.descendant(
          of: find.byType(HoverTextLink),
          matching: find.byType(MouseRegion),
        ),
      );
      expect(mouseRegion.cursor, equals(SystemMouseCursors.click));
    });

    testWidgets('changes color on hover', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'Hover Me',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      // Default state
      var textWidget = tester.widget<Text>(find.text('Hover Me'));
      expect(textWidget.style?.color, equals(AppColors.gray400));

      // Simulate hover enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
      await tester.pumpAndSettle();

      // Hover state
      textWidget = tester.widget<Text>(find.text('Hover Me'));
      expect(textWidget.style?.color, equals(AppColors.textPrimary));

      // Simulate hover exit (move far outside widget bounds)
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();

      // Back to default
      textWidget = tester.widget<Text>(find.text('Hover Me'));
      expect(textWidget.style?.color, equals(AppColors.gray400));
    });

    testWidgets('handles null onTap gracefully', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'No Action',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      // Tap should not crash
      await tester.tap(find.text('No Action'));
      await tester.pump();
      expect(find.text('No Action'), findsOneWidget);
    });

    // #69 regression: Semantics label must be set even without onTap
    testWidgets('has Semantics label even without onTap', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          HoverTextLink(
            text: 'No Action Link',
            defaultColor: AppColors.gray400,
            hoverColor: AppColors.textPrimary,
          ),
        ),
      );

      final semantics = tester.firstWidget<Semantics>(
        find.descendant(
          of: find.byType(HoverTextLink),
          matching: find.byType(Semantics),
        ),
      );
      expect(semantics.properties.label, equals('No Action Link'));
      expect(semantics.properties.button, isTrue);
      expect(semantics.properties.onTap, isNull);
    });
  });
}
