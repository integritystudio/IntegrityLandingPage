import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/info_card.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:integrity_studio_ai/theme/spacing.dart';
import '../../helpers/test_helpers.dart';

void main() {
  Widget buildInfoCard({
    IconData icon = LucideIcons.info,
    String title = 'Test Title',
    String? description,
    Widget? child,
    Color? iconColor,
    Color? iconBackgroundColor,
    Gradient? iconBackgroundGradient,
    EdgeInsets? iconContainerPadding,
    double? iconContainerBorderRadius,
    Color? backgroundColor,
    Color? borderColor,
    double? borderRadius,
    EdgeInsets? padding,
    double? width,
    TextStyle? titleStyle,
    TextStyle? descriptionStyle,
    double? iconSize,
    double? iconSpacing,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return testableWidget(
      Center(
        child: InfoCard(
          icon: icon,
          title: title,
          description: description,
          iconColor: iconColor,
          iconBackgroundColor: iconBackgroundColor,
          iconBackgroundGradient: iconBackgroundGradient,
          iconContainerPadding: iconContainerPadding,
          iconContainerBorderRadius: iconContainerBorderRadius,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          borderRadius: borderRadius,
          padding: padding,
          width: width,
          titleStyle: titleStyle,
          descriptionStyle: descriptionStyle,
          iconSize: iconSize,
          iconSpacing: iconSpacing,
          onTap: onTap,
          trailingWidget: trailingWidget,
          child: child,
        ),
      ),
    );
  }

  group('InfoCard', () {
    // -------------------------------------------------------------------------
    // Content rendering
    // -------------------------------------------------------------------------

    group('content rendering', () {
      testWidgets('renders icon with required params only', (tester) async {
        await tester.pumpWidget(buildInfoCard(icon: LucideIcons.shield));
        expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      });

      testWidgets('renders title with required params only', (tester) async {
        await tester.pumpWidget(buildInfoCard(title: 'My Title'));
        expect(find.text('My Title'), findsOneWidget);
      });

      testWidgets('renders description when provided', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          title: 'Title',
          description: 'Some description text',
        ));
        expect(find.text('Some description text'), findsOneWidget);
      });

      testWidgets('does not render description when null', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          title: 'Title Only',
          description: null,
        ));
        expect(find.text('Title Only'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('renders child widget when provided', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          child: const Text('Custom child content'),
        ));
        expect(find.text('Custom child content'), findsOneWidget);
      });

      testWidgets('renders description above child when both provided',
          (tester) async {
        await tester.pumpWidget(buildInfoCard(
          description: 'Description text',
          child: const Text('Child widget'),
        ));
        expect(find.text('Description text'), findsOneWidget);
        expect(find.text('Child widget'), findsOneWidget);

        // Description should appear before child in widget tree (Column order)
        final descOffset =
            tester.getTopLeft(find.text('Description text')).dy;
        final childOffset = tester.getTopLeft(find.text('Child widget')).dy;
        expect(descOffset, lessThan(childOffset));
      });
    });

    // -------------------------------------------------------------------------
    // Icon color
    // -------------------------------------------------------------------------

    group('iconColor', () {
      testWidgets('uses blue400 as default icon color', (tester) async {
        await tester.pumpWidget(
            buildInfoCard(icon: LucideIcons.info, iconColor: null));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.info));
        expect(icon.color, equals(AppColors.blue400));
      });

      testWidgets('uses custom iconColor when provided', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.star,
          iconColor: AppColors.cyan400,
        ));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.star));
        expect(icon.color, equals(AppColors.cyan400));
      });
    });

    // -------------------------------------------------------------------------
    // Icon background
    // -------------------------------------------------------------------------

    group('iconBackgroundColor', () {
      testWidgets('wraps icon in colored container when iconBackgroundColor set',
          (tester) async {
        const bgColor = AppColors.gray800;
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.zap,
          iconBackgroundColor: bgColor,
        ));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasColoredBg = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.color == bgColor;
        });
        expect(hasColoredBg, isTrue);
      });

      testWidgets('no icon background container when iconBackgroundColor null',
          (tester) async {
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.zap,
          iconBackgroundColor: null,
          iconBackgroundGradient: null,
        ));

        // There should be no BoxDecoration with a solid color matching a
        // background-wrapping hue (we simply verify no extra colored container
        // exists beyond the card itself, which uses gray700)
        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final extraColoredBgs = containers.where((c) {
          final dec = c.decoration;
          if (dec is! BoxDecoration) return false;
          return dec.color != null &&
              dec.color != AppColors.gray700 &&
              dec.gradient == null;
        }).toList();
        expect(extraColoredBgs, isEmpty);
      });
    });

    group('iconBackgroundGradient', () {
      testWidgets(
          'wraps icon in gradient container when iconBackgroundGradient set',
          (tester) async {
        const gradient = LinearGradient(
          colors: [AppColors.blue500, AppColors.purple500],
        );
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.activity,
          iconBackgroundGradient: gradient,
        ));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasGradientBg = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.gradient == gradient;
        });
        expect(hasGradientBg, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Background color
    // -------------------------------------------------------------------------

    group('backgroundColor', () {
      testWidgets('defaults to gray700', (tester) async {
        await tester.pumpWidget(buildInfoCard());

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasGray700 = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.color == AppColors.gray700;
        });
        expect(hasGray700, isTrue);
      });

      testWidgets('uses custom backgroundColor when provided', (tester) async {
        const customBg = AppColors.gray800;
        await tester.pumpWidget(buildInfoCard(backgroundColor: customBg));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomBg = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.color == customBg;
        });
        expect(hasCustomBg, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Border color
    // -------------------------------------------------------------------------

    group('borderColor', () {
      testWidgets('defaults to gray600 border', (tester) async {
        await tester.pumpWidget(buildInfoCard());

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasGray600Border = containers.any((c) {
          final dec = c.decoration;
          if (dec is! BoxDecoration) return false;
          final border = dec.border;
          if (border is! Border) return false;
          return border.top.color == AppColors.gray600;
        });
        expect(hasGray600Border, isTrue);
      });

      testWidgets('uses custom borderColor when provided', (tester) async {
        const customBorder = AppColors.blue400;
        await tester.pumpWidget(buildInfoCard(borderColor: customBorder));

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

    // -------------------------------------------------------------------------
    // Border radius
    // -------------------------------------------------------------------------

    group('borderRadius', () {
      testWidgets('defaults to radiusSM', (tester) async {
        await tester.pumpWidget(buildInfoCard());

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasDefaultRadius = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.borderRadius ==
                  BorderRadius.circular(AppSpacing.radiusSM);
        });
        expect(hasDefaultRadius, isTrue);
      });

      testWidgets('uses custom borderRadius when provided', (tester) async {
        const customRadius = AppSpacing.radiusLG;
        await tester.pumpWidget(buildInfoCard(borderRadius: customRadius));

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
    // Padding
    // -------------------------------------------------------------------------

    group('padding', () {
      testWidgets('defaults to EdgeInsets.all(AppSpacing.md)', (tester) async {
        await tester.pumpWidget(buildInfoCard());

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasDefaultPadding = containers.any(
          (c) => c.padding == const EdgeInsets.all(AppSpacing.md),
        );
        expect(hasDefaultPadding, isTrue);
      });

      testWidgets('uses custom padding when provided', (tester) async {
        const customPadding = EdgeInsets.all(AppSpacing.xl);
        await tester.pumpWidget(buildInfoCard(padding: customPadding));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasCustomPadding =
            containers.any((c) => c.padding == customPadding);
        expect(hasCustomPadding, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Fixed width
    // -------------------------------------------------------------------------

    group('width', () {
      testWidgets('constrains width with SizedBox when width provided',
          (tester) async {
        const fixedWidth = 300.0;
        await tester.pumpWidget(buildInfoCard(width: fixedWidth));

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final hasFixedWidth =
            sizedBoxes.any((s) => s.width == fixedWidth);
        expect(hasFixedWidth, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Icon size
    // -------------------------------------------------------------------------

    group('iconSize', () {
      testWidgets('defaults to size 20', (tester) async {
        await tester.pumpWidget(
            buildInfoCard(icon: LucideIcons.info, iconSize: null));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.info));
        expect(icon.size, equals(20));
      });

      testWidgets('uses custom iconSize when provided', (tester) async {
        await tester.pumpWidget(
            buildInfoCard(icon: LucideIcons.info, iconSize: 32));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.info));
        expect(icon.size, equals(32));
      });
    });

    // -------------------------------------------------------------------------
    // Text style overrides
    // -------------------------------------------------------------------------

    group('titleStyle', () {
      testWidgets('applies custom titleStyle when provided', (tester) async {
        const customStyle = TextStyle(fontSize: 24, color: AppColors.cyan400);
        await tester.pumpWidget(buildInfoCard(
          title: 'Styled Title',
          titleStyle: customStyle,
        ));

        final titleWidget = tester.widget<Text>(find.text('Styled Title'));
        expect(titleWidget.style?.fontSize, equals(24));
        expect(titleWidget.style?.color, equals(AppColors.cyan400));
      });
    });

    group('descriptionStyle', () {
      testWidgets('applies custom descriptionStyle when provided',
          (tester) async {
        const customStyle =
            TextStyle(fontSize: 12, color: AppColors.gray300);
        await tester.pumpWidget(buildInfoCard(
          description: 'Styled description',
          descriptionStyle: customStyle,
        ));

        final descWidget =
            tester.widget<Text>(find.text('Styled description'));
        expect(descWidget.style?.fontSize, equals(12));
        expect(descWidget.style?.color, equals(AppColors.gray300));
      });
    });

    // -------------------------------------------------------------------------
    // Icon container padding / border radius
    // -------------------------------------------------------------------------

    group('iconContainerPadding', () {
      testWidgets('applies padding inside icon container when set',
          (tester) async {
        const containerPadding = EdgeInsets.all(AppSpacing.sm);
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.zap,
          iconBackgroundColor: AppColors.gray800,
          iconContainerPadding: containerPadding,
        ));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasPaddedContainer = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.color == AppColors.gray800 &&
              c.padding == containerPadding;
        });
        expect(hasPaddedContainer, isTrue);
      });
    });

    group('iconContainerBorderRadius', () {
      testWidgets('applies border radius to icon container when set',
          (tester) async {
        const radius = AppSpacing.radiusSM;
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.zap,
          iconBackgroundColor: AppColors.gray800,
          iconContainerBorderRadius: radius,
        ));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasRoundedContainer = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.color == AppColors.gray800 &&
              dec.borderRadius == BorderRadius.circular(radius);
        });
        expect(hasRoundedContainer, isTrue);
      });

      testWidgets('no border radius on icon container when null', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          icon: LucideIcons.zap,
          iconBackgroundColor: AppColors.gray800,
          iconContainerBorderRadius: null,
        ));

        final containers =
            tester.widgetList<Container>(find.byType(Container));
        final hasNullRadiusContainer = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.color == AppColors.gray800 &&
              dec.borderRadius == null;
        });
        expect(hasNullRadiusContainer, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Icon spacing
    // -------------------------------------------------------------------------

    group('iconSpacing', () {
      testWidgets('uses AppSpacing.sm as default gap between icon and text',
          (tester) async {
        await tester.pumpWidget(buildInfoCard());

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((s) => s.width == AppSpacing.sm), isTrue);
      });

      testWidgets('uses custom iconSpacing when provided', (tester) async {
        await tester.pumpWidget(buildInfoCard(iconSpacing: AppSpacing.md));

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        expect(sizedBoxes.any((s) => s.width == AppSpacing.md), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // onTap / trailingWidget
    // -------------------------------------------------------------------------

    group('onTap', () {
      testWidgets('wraps card in InkWell when onTap provided', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildInfoCard(
          onTap: () => tapped = true,
        ));

        expect(find.byType(InkWell), findsOneWidget);
        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });

      testWidgets('no InkWell when onTap is null', (tester) async {
        await tester.pumpWidget(buildInfoCard(onTap: null));
        expect(find.byType(InkWell), findsNothing);
      });
    });

    group('trailingWidget', () {
      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWidget(buildInfoCard(
          trailingWidget: const Icon(LucideIcons.chevronRight),
        ));
        expect(find.byIcon(LucideIcons.chevronRight), findsOneWidget);
      });

      testWidgets('no trailing widget when null', (tester) async {
        await tester.pumpWidget(buildInfoCard(trailingWidget: null));
        expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
      });
    });
  });
}
