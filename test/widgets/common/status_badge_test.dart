import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/status_badge.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import 'package:integrity_studio_ai/theme/spacing.dart';
import '../../helpers/test_helpers.dart';

void main() {
  Widget build({String label = 'Active', Color color = AppColors.blue400}) {
    return testableWidget(Center(child: StatusBadge(label: label, color: color)));
  }

  group('StatusBadge', () {
    group('content rendering', () {
      testWidgets('renders label text', (tester) async {
        await tester.pumpWidget(build(label: 'Suspended'));
        expect(find.text('Suspended'), findsOneWidget);
      });

      testWidgets('renders exactly one Text widget', (tester) async {
        await tester.pumpWidget(build());
        expect(find.byType(Text), findsOneWidget);
      });
    });

    group('decoration', () {
      testWidgets('background is color with alpha 25', (tester) async {
        const c = AppColors.cyan400;
        await tester.pumpWidget(build(color: c));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final match = containers.any((container) {
          final dec = container.decoration;
          return dec is BoxDecoration && dec.color == c.withAlpha(25);
        });
        expect(match, isTrue);
      });

      testWidgets('border uses the same color', (tester) async {
        const c = AppColors.blue500;
        await tester.pumpWidget(build(color: c));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final match = containers.any((container) {
          final dec = container.decoration;
          if (dec is! BoxDecoration) return false;
          final border = dec.border;
          if (border is! Border) return false;
          return border.top.color == c;
        });
        expect(match, isTrue);
      });

      testWidgets('uses radiusSM border radius', (tester) async {
        await tester.pumpWidget(build());

        final containers = tester.widgetList<Container>(find.byType(Container));
        final match = containers.any((container) {
          final dec = container.decoration;
          return dec is BoxDecoration &&
              dec.borderRadius == BorderRadius.circular(AppSpacing.radiusSM);
        });
        expect(match, isTrue);
      });
    });

    group('text style', () {
      testWidgets('text color matches badge color', (tester) async {
        const c = AppColors.purple500;
        await tester.pumpWidget(build(color: c));

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.style?.color, equals(c));
      });

      testWidgets('text weight is w500', (tester) async {
        await tester.pumpWidget(build());

        final text = tester.widget<Text>(find.byType(Text));
        expect(text.style?.fontWeight, equals(FontWeight.w500));
      });
    });
  });
}
