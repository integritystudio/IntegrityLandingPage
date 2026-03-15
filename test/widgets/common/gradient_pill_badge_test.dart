import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/gradient_pill_badge.dart';
import 'package:integrity_studio_ai/theme/theme.dart';
import '../../helpers/test_helpers.dart';

void main() {
  Widget buildBadge({
    String label = 'Test Badge',
    IconData? icon,
    Color? iconColor,
  }) {
    return testableWidget(
      Center(
        child: GradientPillBadge(
          label: label,
          icon: icon,
          iconColor: iconColor ?? AppColors.blue400,
        ),
      ),
    );
  }

  group('GradientPillBadge', () {
    group('content rendering', () {
      testWidgets('renders label text', (tester) async {
        await tester.pumpWidget(buildBadge());
        expect(find.text('Test Badge'), findsOneWidget);
      });

      testWidgets('renders icon when provided', (tester) async {
        await tester.pumpWidget(
          buildBadge(icon: LucideIcons.checkCircle),
        );
        expect(find.byIcon(LucideIcons.checkCircle), findsOneWidget);
      });

      testWidgets('omits icon when not provided', (tester) async {
        await tester.pumpWidget(buildBadge());
        expect(find.byType(Icon), findsNothing);
      });
    });

    group('styling', () {
      testWidgets('has gradient decoration', (tester) async {
        await tester.pumpWidget(buildBadge());
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasGradient = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration && dec.gradient is LinearGradient;
        });
        expect(hasGradient, isTrue);
      });

      testWidgets('has pill border radius', (tester) async {
        await tester.pumpWidget(buildBadge());
        final containers = tester.widgetList<Container>(find.byType(Container));
        final hasPillRadius = containers.any((c) {
          final dec = c.decoration;
          return dec is BoxDecoration &&
              dec.borderRadius ==
                  BorderRadius.circular(AppSpacing.radiusFull);
        });
        expect(hasPillRadius, isTrue);
      });

      testWidgets('label uses blue400 color', (tester) async {
        await tester.pumpWidget(buildBadge());
        final text = tester.widget<Text>(find.text('Test Badge'));
        expect(text.style?.color, equals(AppColors.blue400));
      });

      testWidgets('icon uses default blue400 color', (tester) async {
        await tester.pumpWidget(
          buildBadge(icon: LucideIcons.checkCircle),
        );
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.checkCircle));
        expect(icon.color, equals(AppColors.blue400));
      });

      testWidgets('icon uses custom color when provided', (tester) async {
        await tester.pumpWidget(buildBadge(
          label: 'Test',
          icon: LucideIcons.checkCircle,
          iconColor: AppColors.success,
        ));
        final icon = tester.widget<Icon>(find.byIcon(LucideIcons.checkCircle));
        expect(icon.color, equals(AppColors.success));
      });
    });
  });
}
