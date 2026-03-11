import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:integrity_studio_ai/config/content.dart';
import 'package:integrity_studio_ai/widgets/common/buttons.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // GradientButton Tests
  // ==========================================================================

  group('GradientButton', () {
    testWidgets('handles callbacks, loading, and icons correctly',
        (tester) async {
      // Test 1: Normal state with callback
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Test Button',
            icon: LucideIcons.arrowRight,
            onPressed: () => pressed = true,
          ),
        ),
      );

      // Verify normal state
      expect(find.text('Test Button'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowRight), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Test tap invokes callback
      await tester.tap(find.text('Test Button'));
      await tester.pump();
      expect(pressed, isTrue);

      // Test 2: Loading state - hides text and icon, shows spinner
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Loading',
            icon: LucideIcons.arrowRight,
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Loading'), findsNothing);
      expect(find.byIcon(LucideIcons.arrowRight), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Test 3: Disabled state (onPressed: null)
      await tester.pumpWidget(
        testableWidget(
          const GradientButton(
            text: 'Disabled Button',
            onPressed: null,
          ),
        ),
      );

      expect(find.text('Disabled Button'), findsOneWidget);
    });

    testWidgets('has proper structure with GestureDetector and Semantics',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          GradientButton(
            text: 'Test',
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.byType(Semantics), findsWidgets);
    });
  });

  // ==========================================================================
  // OutlineButton Tests
  // ==========================================================================

  group('OutlineButton', () {
    testWidgets('handles callbacks, loading, icon, and structure correctly',
        (tester) async {
      // Test 1: Normal state with callback and icon
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'Outline Test',
            icon: LucideIcons.play,
            onPressed: () => pressed = true,
          ),
        ),
      );

      // Verify normal state
      expect(find.text('Outline Test'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsWidgets);

      // Test tap invokes callback
      await tester.tap(find.text('Outline Test'));
      await tester.pump();
      expect(pressed, isTrue);

      // Test 2: Loading state - shows spinner
      await tester.pumpWidget(
        testableWidget(
          OutlineButton(
            text: 'Test',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Test 3: Disabled state (onPressed: null)
      await tester.pumpWidget(
        testableWidget(
          const OutlineButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ),
      );

      expect(find.text('Disabled'), findsOneWidget);
    });
  });

  // ==========================================================================
  // AppTextButton Tests
  // ==========================================================================

  group('AppTextButton', () {
    testWidgets('handles callbacks and icons with leading option correctly',
        (tester) async {
      // Test 1: Callback and trailing icon
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          AppTextButton(
            text: 'Link',
            icon: LucideIcons.externalLink,
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.text('Link'), findsOneWidget);
      expect(find.byIcon(LucideIcons.externalLink), findsOneWidget);

      // Test tap invokes callback
      await tester.tap(find.text('Link'));
      await tester.pump();
      expect(pressed, isTrue);

      // Test 2: Leading icon option
      await tester.pumpWidget(
        testableWidget(
          AppTextButton(
            text: 'Back',
            icon: LucideIcons.arrowLeft,
            iconLeading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Back'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowLeft), findsOneWidget);
    });
  });

  // ==========================================================================
  // AppIconButton Tests
  // ==========================================================================

  group('AppIconButton', () {
    testWidgets('handles callbacks, tooltip, and custom size correctly',
        (tester) async {
      // Test 1: Callback and rendering
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          AppIconButton(
            icon: LucideIcons.menu,
            tooltip: 'Open menu',
            onPressed: () => pressed = true,
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.menu), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);

      // Test tap invokes callback
      await tester.tap(find.byIcon(LucideIcons.menu));
      await tester.pump();
      expect(pressed, isTrue);

      // Test 2: Custom icon size
      await tester.pumpWidget(
        testableWidget(
          AppIconButton(
            icon: LucideIcons.x,
            size: 32,
            onPressed: () {},
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(LucideIcons.x));
      expect(icon.size, equals(32));
    });
  });

  // ==========================================================================
  // AnimatedGradientBorderButton Tests
  // ==========================================================================

  group('AnimatedGradientBorderButton', () {
    testWidgets('handles callbacks and loading state correctly',
        (tester) async {
      // Test 1: Normal state with callback
      var pressed = false;
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Animated Button',
            onPressed: () => pressed = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Animated Button'), findsOneWidget);

      // Test tap invokes callback
      await tester.tap(find.text('Animated Button'));
      await tester.pump();
      expect(pressed, isTrue);

      // Test 2: Loading state - shows spinner, hides text
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Test',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Test'), findsNothing);

      // Test 3: Disabled state (onPressed: null)
      await tester.pumpWidget(
        testableWidget(
          const AnimatedGradientBorderButton(
            text: 'Disabled Animated',
            onPressed: null,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Disabled Animated'), findsOneWidget);
    });

    testWidgets('has animation with CustomPaint and proper structure',
        (tester) async {
      await tester.pumpWidget(
        testableWidget(
          AnimatedGradientBorderButton(
            text: 'Get Started',
            onPressed: () {},
          ),
        ),
      );

      // Animation should be running - pump a few frames
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Verify structure
      expect(find.byType(AnimatedGradientBorderButton), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Semantics), findsWidgets);
      expect(find.text(CTAText.getStarted), findsOneWidget);
    });
  });
}
