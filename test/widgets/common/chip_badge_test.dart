import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/chip_badge.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:integrity_studio_ai/theme/spacing.dart';
import '../../helpers/test_helpers.dart';

void main() {
  Widget buildChipBadge({
    IconData icon = LucideIcons.shield,
    String label = 'Test Label',
    String? description,
    Color accentColor = AppColors.blue500,
    Color? backgroundColor,
    Color? borderColor,
    double iconSize = 18,
    EdgeInsetsGeometry? padding,
    double borderRadius = AppSpacing.radiusFull,
  }) {
    return testableWidget(
      Center(
        child: ChipBadge(
          icon: icon,
          label: label,
          description: description,
          accentColor: accentColor,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          iconSize: iconSize,
          padding: padding,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  group('ChipBadge', () {
    // -------------------------------------------------------------------------
    // Content rendering
    // -------------------------------------------------------------------------

    group('content rendering', () {
      testWidgets('renders icon', (tester) async {
        await tester.pumpWidget(buildChipBadge(icon: LucideIcons.shield));
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('renders label text', (tester) async {
        await tester.pumpWidget(buildChipBadge(label: 'My Badge'));
        expect(find.text('My Badge'), findsOneWidget);
      });

      testWidgets('renders description text when provided', (tester) async {
        await tester.pumpWidget(buildChipBadge(
          label: 'Title',
          description: 'Some description',
        ));
        expect(find.text('Title'), findsOneWidget);
        expect(find.text('Some description'), findsOneWidget);
      });

      testWidgets('does not render description text when null', (tester) async {
        await tester.pumpWidget(buildChipBadge(
          label: 'Label Only',
          description: null,
        ));
        expect(find.text('Label Only'), findsOneWidget);
        // Only one Text widget should be present (label)
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('renders Column when description is provided', (tester) async {
        await tester.pumpWidget(buildChipBadge(
          label: 'Title',
          description: 'Detail',
        ));
        // Column containing both label and description
        final columns = tester
            .widgetList<Column>(find.byType(Column))
            .where((c) => c.crossAxisAlignment == CrossAxisAlignment.start)
            .toList();
        expect(columns, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Color behavior
    // -------------------------------------------------------------------------

    group('accentColor', () {
      testWidgets('icon uses accentColor', (tester) async {
        const accent = AppColors.purple500;
        await tester.pumpWidget(buildChipBadge(
          icon: LucideIcons.star,
          accentColor: accent,
        ));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.star));
        expect(icon.color, equals(accent));
      });
    });

    // -------------------------------------------------------------------------
    // Default background color
    // -------------------------------------------------------------------------

    group('default backgroundColor', () {
      testWidgets('defaults to accentColor with alpha 0.15', (tester) async {
        const accent = AppColors.blue500;
        await tester.pumpWidget(buildChipBadge(accentColor: accent));

        final expectedBg = accent.withValues(alpha: 0.15);
        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasExpectedBg = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.color == expectedBg;
        });
        expect(hasExpectedBg, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Default border color
    // -------------------------------------------------------------------------

    group('default borderColor', () {
      testWidgets('defaults to accentColor with alpha 0.5', (tester) async {
        const accent = AppColors.blue500;
        await tester.pumpWidget(buildChipBadge(accentColor: accent));

        final expectedBorder = accent.withValues(alpha: 0.5);
        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasExpectedBorder = containers.any((c) {
          final dec = c.decoration;
          if (dec is! BoxDecoration) return false;
          final border = dec.border;
          if (border is! Border) return false;
          return border.top.color == expectedBorder;
        });
        expect(hasExpectedBorder, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Border radius
    // -------------------------------------------------------------------------

    group('borderRadius', () {
      testWidgets('defaults to pill shape (radiusFull)', (tester) async {
        await tester.pumpWidget(buildChipBadge());

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasPill = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.borderRadius ==
                  BorderRadius.circular(AppSpacing.radiusFull);
        });
        expect(hasPill, isTrue);
      });

      testWidgets('uses custom borderRadius when provided', (tester) async {
        const customRadius = AppSpacing.radiusLG;
        await tester.pumpWidget(
          buildChipBadge(borderRadius: customRadius),
        );

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomRadius = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.borderRadius == BorderRadius.circular(customRadius);
        });
        expect(hasCustomRadius, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Custom padding
    // -------------------------------------------------------------------------

    group('padding', () {
      testWidgets('accepts custom padding', (tester) async {
        const customPadding = EdgeInsets.all(AppSpacing.xl);
        await tester.pumpWidget(buildChipBadge(padding: customPadding));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomPadding = containers.any((c) => c.padding == customPadding);
        expect(hasCustomPadding, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Custom iconSize
    // -------------------------------------------------------------------------

    group('iconSize', () {
      testWidgets('uses custom iconSize when provided', (tester) async {
        await tester.pumpWidget(
          buildChipBadge(icon: LucideIcons.check, iconSize: 28),
        );
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.check));
        expect(icon.size, equals(28));
      });
    });

    // -------------------------------------------------------------------------
    // Color overrides
    // -------------------------------------------------------------------------

    group('color overrides', () {
      testWidgets('uses custom backgroundColor when provided', (tester) async {
        const customBg = AppColors.gray800;
        await tester.pumpWidget(buildChipBadge(backgroundColor: customBg));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomBg = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.color == customBg;
        });
        expect(hasCustomBg, isTrue);
      });

      testWidgets('uses custom borderColor when provided', (tester) async {
        const customBorder = AppColors.cyan400;
        await tester.pumpWidget(buildChipBadge(borderColor: customBorder));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomBorder = containers.any((c) {
          final dec = c.decoration;
          if (dec is! BoxDecoration) return false;
          final border = dec.border;
          if (border is! Border) return false;
          return border.top.color == customBorder;
        });
        expect(hasCustomBorder, isTrue);
      });
    });
  });
}
