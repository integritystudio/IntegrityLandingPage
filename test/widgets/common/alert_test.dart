import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/alert.dart';
import 'package:integrity_studio_ai/theme/colors.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // Alert Widget Tests
  // ==========================================================================

  group('Alert', () {
    testWidgets('renders all variants with correct icons', (tester) async {
      final variantData = [
        (AlertVariant.success, LucideIcons.checkCircle, 'Success message'),
        (AlertVariant.error, LucideIcons.alertCircle, 'Error message'),
        (AlertVariant.warning, LucideIcons.alertTriangle, 'Warning message'),
        (AlertVariant.info, LucideIcons.info, 'Info message'),
      ];

      for (final (variant, expectedIcon, message) in variantData) {
        await tester.pumpWidget(
          testableWidget(
            Alert(
              variant: variant,
              message: message,
            ),
          ),
        );

        expect(find.byIcon(expectedIcon), findsOneWidget,
            reason: '$variant should show $expectedIcon');
        expect(find.text(message), findsOneWidget);
      }
    });

    testWidgets('factory constructors create correct variants', (tester) async {
      final factoryData = [
        (Alert.success(message: 'Success!'), LucideIcons.checkCircle, 'Success!'),
        (Alert.error(message: 'Error!'), LucideIcons.alertCircle, 'Error!'),
        (Alert.warning(message: 'Warning!'), LucideIcons.alertTriangle, 'Warning!'),
        (Alert.info(message: 'Info!'), LucideIcons.info, 'Info!'),
      ];

      for (final (alert, expectedIcon, message) in factoryData) {
        await tester.pumpWidget(testableWidget(alert));

        expect(find.byIcon(expectedIcon), findsOneWidget);
        expect(find.text(message), findsOneWidget);
      }
    });

    testWidgets('renders title conditionally', (tester) async {
      // With title
      await tester.pumpWidget(
        testableWidget(
          const Alert(
            variant: AlertVariant.success,
            title: 'Success Title',
            message: 'Success message',
          ),
        ),
      );

      expect(find.text('Success Title'), findsOneWidget);
      expect(find.text('Success message'), findsOneWidget);

      // Without title
      await tester.pumpWidget(
        testableWidget(
          const Alert(
            variant: AlertVariant.success,
            message: 'Success message only',
          ),
        ),
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.length, equals(1));
    });

    testWidgets('handles dismissible states correctly', (tester) async {
      var dismissed = false;

      // Dismissible with callback - shows button and calls callback
      await tester.pumpWidget(
        testableWidget(
          Alert(
            variant: AlertVariant.info,
            message: 'Dismissible alert',
            dismissible: true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      expect(dismissed, isTrue);

      // Not dismissible - no button
      await tester.pumpWidget(
        testableWidget(
          const Alert(
            variant: AlertVariant.info,
            message: 'Non-dismissible alert',
            dismissible: false,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.x), findsNothing);

      // Dismissible but no callback - no button
      await tester.pumpWidget(
        testableWidget(
          const Alert(
            variant: AlertVariant.info,
            message: 'Alert without callback',
            dismissible: true,
            onDismiss: null,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets('uses custom icon when provided', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const Alert(
            variant: AlertVariant.success,
            message: 'Custom icon alert',
            icon: LucideIcons.star,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.star), findsOneWidget);
      expect(find.byIcon(LucideIcons.checkCircle), findsNothing);
    });

    testWidgets('has proper accessibility and semantics', (tester) async {
      for (final variant in [AlertVariant.success, AlertVariant.error]) {
        await tester.pumpWidget(
          testableWidget(
            Alert(
              variant: variant,
              message: '${variant.name} alert',
            ),
          ),
        );

        expect(find.byType(Semantics), findsWidgets);
      }
    });

    testWidgets('applies correct styling and colors per variant', (tester) async {
      final colorData = [
        (AlertVariant.success, LucideIcons.checkCircle, AppColors.success),
        (AlertVariant.error, LucideIcons.alertCircle, AppColors.error),
      ];

      for (final (variant, icon, expectedColor) in colorData) {
        await tester.pumpWidget(
          testableWidget(
            Alert(
              variant: variant,
              message: '${variant.name} styled',
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
        final iconWidget = tester.widget<Icon>(find.byIcon(icon));
        expect(iconWidget.color, equals(expectedColor),
            reason: '$variant should use $expectedColor');
      }
    });
  });

  // ==========================================================================
  // AnimatedAlert Widget Tests
  // ==========================================================================

  group('AnimatedAlert', () {
    testWidgets('renders and animates correctly', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const AnimatedAlert(
            variant: AlertVariant.success,
            message: 'Animated alert',
          ),
        ),
      );

      // Animation widgets should be present
      expect(find.byType(AnimatedAlert), findsOneWidget);

      // Animation should complete
      await tester.pumpAndSettleWithTimeout();
      expect(find.text('Animated alert'), findsOneWidget);
    });

    testWidgets('handles auto dismiss behavior', (tester) async {
      var dismissed = false;

      // With auto dismiss duration - should dismiss
      await tester.pumpWidget(
        testableWidget(
          AnimatedAlert(
            variant: AlertVariant.info,
            message: 'Auto dismiss alert',
            autoDismissDuration: const Duration(milliseconds: 500),
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.text('Auto dismiss alert'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettleWithTimeout();
      expect(dismissed, isTrue);

      // Without auto dismiss duration - should persist
      dismissed = false;
      await tester.pumpWidget(
        testableWidget(
          AnimatedAlert(
            variant: AlertVariant.info,
            message: 'Persistent alert',
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 2));
      expect(dismissed, isFalse);
      expect(find.text('Persistent alert'), findsOneWidget);
    });

    testWidgets('supports manual dismiss and title', (tester) async {
      var dismissed = false;

      // Manual dismiss
      await tester.pumpWidget(
        testableWidget(
          AnimatedAlert(
            variant: AlertVariant.warning,
            message: 'Dismissible animated alert',
            dismissible: true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      await tester.pumpAndSettleWithTimeout();
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettleWithTimeout();
      expect(dismissed, isTrue);

      // With title
      await tester.pumpWidget(
        testableWidget(
          const AnimatedAlert(
            variant: AlertVariant.success,
            title: 'Animated Title',
            message: 'Animated message',
          ),
        ),
      );

      await tester.pumpAndSettleWithTimeout();
      expect(find.text('Animated Title'), findsOneWidget);
      expect(find.text('Animated message'), findsOneWidget);
    });
  });
}
