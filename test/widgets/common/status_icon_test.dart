import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/status_icon.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  group('StatusIcon', () {
    group('success factory', () {
      testWidgets('displays check icon', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        expect(find.byIcon(LucideIcons.checkCircle2), findsOneWidget);
      });

      testWidgets('uses success color', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.success));
      });

      testWidgets('has correct semantic label', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        final semantics = tester.getSemantics(find.byType(StatusIcon));
        expect(semantics.label, equals('Success'));
      });

      testWidgets('has correct size', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.constraints?.maxWidth, equals(80));
        expect(container.constraints?.maxHeight, equals(80));
      });
    });

    group('error factory', () {
      testWidgets('displays X icon', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.error()),
        ));

        expect(find.byIcon(LucideIcons.xCircle), findsOneWidget);
      });

      testWidgets('uses error color', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.error()),
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.error));
      });

      testWidgets('has correct semantic label', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.error()),
        ));

        final semantics = tester.getSemantics(find.byType(StatusIcon));
        expect(semantics.label, equals('Error'));
      });
    });

    group('warning factory', () {
      testWidgets('displays alert icon', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.warning()),
        ));

        expect(find.byIcon(LucideIcons.alertCircle), findsOneWidget);
      });

      testWidgets('has correct semantic label', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.warning()),
        ));

        final semantics = tester.getSemantics(find.byType(StatusIcon));
        expect(semantics.label, equals('Warning'));
      });
    });

    group('processing factory', () {
      testWidgets('displays circular progress indicator', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.processing()),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('does not display static icon', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.processing()),
        ));

        expect(find.byIcon(LucideIcons.loader2), findsNothing);
      });

      testWidgets('has correct semantic label', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.processing()),
        ));

        final semantics = tester.getSemantics(find.byType(StatusIcon));
        expect(semantics.label, equals('Processing'));
      });
    });

    group('custom constructor', () {
      testWidgets('accepts custom icon', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: StatusIcon(
              icon: LucideIcons.info,
              primaryColor: AppColors.info,
            ),
          ),
        ));

        expect(find.byIcon(LucideIcons.info), findsOneWidget);
      });

      testWidgets('accepts custom colors', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: StatusIcon(
              icon: LucideIcons.info,
              primaryColor: AppColors.info,
              secondaryColor: AppColors.purple500,
            ),
          ),
        ));

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, equals(AppColors.info));
      });

      testWidgets('accepts custom size', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: StatusIcon(
              icon: LucideIcons.info,
              primaryColor: AppColors.info,
              outerSize: 100,
              iconSize: 50,
            ),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        expect(container.constraints?.maxWidth, equals(100));
      });

      testWidgets('accepts custom semantic label', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: StatusIcon(
              icon: LucideIcons.info,
              primaryColor: AppColors.info,
              semanticLabel: 'Information',
            ),
          ),
        ));

        final semantics = tester.getSemantics(find.byType(StatusIcon));
        expect(semantics.label, equals('Information'));
      });

      testWidgets('animated flag shows progress indicator', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: StatusIcon(
              icon: LucideIcons.loader2,
              primaryColor: AppColors.blue500,
              isAnimated: true,
            ),
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(LucideIcons.loader2), findsNothing);
      });
    });

    group('visual appearance', () {
      testWidgets('has gradient background', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());
      });

      testWidgets('has circular border', (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: StatusIcon.success()),
        ));

        final container = tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, isNotNull);
        expect(decoration.border, isNotNull);
      });
    });
  });
}
