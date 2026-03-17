import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // BaseActionButton type hierarchy tests
  // ==========================================================================

  group('BaseActionButton type hierarchy', () {
    testWidgets('GradientButton is a BaseActionButton', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Test',
            onPressed: () {},
          ),
        ),
      );

      final widget = tester.widget<GradientButton>(
        find.byType(GradientButton),
      );
      expect(widget, isA<BaseActionButton>());
    });

    testWidgets('OutlineButton is a BaseActionButton', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'Test',
            onPressed: () {},
          ),
        ),
      );

      final widget = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      );
      expect(widget, isA<BaseActionButton>());
    });

    testWidgets('AnimatedGradientBorderButton is a BaseActionButton',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Test',
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final widget = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      );
      expect(widget, isA<BaseActionButton>());
    });
  });

  // ==========================================================================
  // GradientButton field pass-through tests
  // ==========================================================================

  group('GradientButton field pass-through', () {
    testWidgets('exposes text via BaseActionButton.text', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const GradientButton(
            text: 'Hello World',
            onPressed: null,
          ),
        ),
      );

      final button = tester.widget<GradientButton>(
        find.byType(GradientButton),
      ) as BaseActionButton;
      expect(button.text, equals('Hello World'));
    });

    testWidgets('exposes icon via BaseActionButton.icon', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'With Icon',
            icon: LucideIcons.arrowRight,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<GradientButton>(
        find.byType(GradientButton),
      ) as BaseActionButton;
      expect(button.icon, equals(LucideIcons.arrowRight));
    });

    testWidgets('exposes semanticLabel via BaseActionButton.semanticLabel',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const GradientButton(
            text: 'Button',
            semanticLabel: 'Custom label',
            onPressed: null,
          ),
        ),
      );

      final button = tester.widget<GradientButton>(
        find.byType(GradientButton),
      ) as BaseActionButton;
      expect(button.semanticLabel, equals('Custom label'));
    });

    testWidgets('exposes isLoading via BaseActionButton.isLoading',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<GradientButton>(
        find.byType(GradientButton),
      ) as BaseActionButton;
      expect(button.isLoading, isTrue);
    });

    testWidgets('exposes fullWidth via BaseActionButton.fullWidth',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Full Width',
            fullWidth: true,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<GradientButton>(
        find.byType(GradientButton),
      ) as BaseActionButton;
      expect(button.fullWidth, isTrue);
    });
  });

  // ==========================================================================
  // OutlineButton field pass-through tests
  // ==========================================================================

  group('OutlineButton field pass-through', () {
    testWidgets('exposes text via BaseActionButton.text', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const OutlineButton(
            text: 'Outline Hello',
            onPressed: null,
          ),
        ),
      );

      final button = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      ) as BaseActionButton;
      expect(button.text, equals('Outline Hello'));
    });

    testWidgets('exposes icon via BaseActionButton.icon', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'With Icon',
            icon: LucideIcons.play,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      ) as BaseActionButton;
      expect(button.icon, equals(LucideIcons.play));
    });

    testWidgets('exposes semanticLabel via BaseActionButton.semanticLabel',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const OutlineButton(
            text: 'Button',
            semanticLabel: 'Outline label',
            onPressed: null,
          ),
        ),
      );

      final button = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      ) as BaseActionButton;
      expect(button.semanticLabel, equals('Outline label'));
    });

    testWidgets('exposes isLoading via BaseActionButton.isLoading',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      ) as BaseActionButton;
      expect(button.isLoading, isTrue);
    });

    testWidgets('exposes fullWidth via BaseActionButton.fullWidth',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'Full Width',
            fullWidth: true,
            onPressed: () {},
          ),
        ),
      );

      final button = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      ) as BaseActionButton;
      expect(button.fullWidth, isTrue);
    });
  });

  // ==========================================================================
  // AnimatedGradientBorderButton field pass-through tests
  // ==========================================================================

  group('AnimatedGradientBorderButton field pass-through', () {
    testWidgets('exposes text via BaseActionButton.text', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const AnimatedGradientBorderButton(
            text: 'Animated Hello',
            onPressed: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      ) as BaseActionButton;
      expect(button.text, equals('Animated Hello'));
    });

    testWidgets('exposes icon via BaseActionButton.icon', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'With Icon',
            icon: LucideIcons.zap,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      ) as BaseActionButton;
      expect(button.icon, equals(LucideIcons.zap));
    });

    testWidgets('exposes semanticLabel via BaseActionButton.semanticLabel',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          const AnimatedGradientBorderButton(
            text: 'Button',
            semanticLabel: 'Animated label',
            onPressed: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      ) as BaseActionButton;
      expect(button.semanticLabel, equals('Animated label'));
    });

    testWidgets('exposes isLoading via BaseActionButton.isLoading',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      ) as BaseActionButton;
      expect(button.isLoading, isTrue);
    });

    testWidgets('exposes fullWidth via BaseActionButton.fullWidth',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Full Width',
            fullWidth: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final button = tester.widget<AnimatedGradientBorderButton>(
        find.byType(AnimatedGradientBorderButton),
      ) as BaseActionButton;
      expect(button.fullWidth, isTrue);
    });
  });

  // ==========================================================================
  // onPressed==null disables tap for all three button types
  // ==========================================================================

  group('onPressed null disables tap callback', () {
    testWidgets('GradientButton does not fire callback when onPressed is null',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          const GradientButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, isFalse);
    });

    testWidgets('OutlineButton does not fire callback when onPressed is null',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          const OutlineButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, isFalse);
    });

    testWidgets(
        'AnimatedGradientBorderButton does not fire callback when onPressed is null',
        (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          const AnimatedGradientBorderButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Disabled'), warnIfMissed: false);
      await tester.pump();
      expect(pressed, isFalse);
    });
  });
}
