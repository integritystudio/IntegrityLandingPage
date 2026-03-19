import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/modals/api_key_modal.dart';
import '../../helpers/test_helpers.dart';

void main() {
  const testApiKey = 'sk-test-api-key-12345';

  group('ApiKeyModal', () {
    group('rendering', () {
      testWidgets('renders modal with API key', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        // Tap button to open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byKey(const ValueKey('api-key-modal')), findsOneWidget);
        expect(find.text('Your API Key'), findsOneWidget);
        expect(find.text(testApiKey), findsOneWidget);
      });

      testWidgets('displays API key in copyable field', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(
          find.byKey(const ValueKey('api-key-field')),
          findsOneWidget,
        );
        expect(find.text(testApiKey), findsOneWidget);
      });

      testWidgets('shows warning alert with non-dismissible message',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.text('Save this key now'), findsOneWidget);
        expect(
          find.textContaining('will not be shown again'),
          findsOneWidget,
        );
      });
    });

    group('confirm button', () {
      testWidgets('has confirm button with correct text', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(
          find.byKey(const ValueKey('api-key-confirm-button')),
          findsOneWidget,
        );
        expect(find.text("I've copied my API key"), findsOneWidget);
      });

      testWidgets('tapping confirm button closes modal', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('api-key-confirm-button')));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsNothing);
      });
    });

    group('barrier behavior', () {
      testWidgets('barrier is not dismissible (non-dismissible modal)',
          (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsOneWidget);

        // Try to tap outside the dialog to dismiss (barrier tap)
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettleWithTimeout();

        // Modal should still be visible (not dismissible)
        expect(find.byType(ApiKeyModal), findsOneWidget);
      });

      testWidgets('pressing escape does not dismiss modal', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        // Simulate escape key press
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettleWithTimeout();

        // Modal should still be visible
        expect(find.byType(ApiKeyModal), findsOneWidget);
      });
    });

    group('responsive layout', () {
      testWidgets('renders on mobile viewport without overflow',
          (tester) async {
        setMobileSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsOneWidget);
        expect(find.text('Your API Key'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsOneWidget);
      });

      testWidgets('renders on desktop viewport', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        expect(find.byType(ApiKeyModal), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('has icon for visual emphasis', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        // Find icon widgets
        expect(find.byType(Icon), findsWidgets);
      });

      testWidgets('modal has defined semantic structure', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ApiKeyModal.show(context, apiKey: testApiKey),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettleWithTimeout();

        // Verify modal contains expected text elements
        expect(find.text('Your API Key'), findsOneWidget);
        expect(find.text("I've copied my API key"), findsOneWidget);
      });
    });
  });

  group('ApiKeyModal direct instantiation', () {
    testWidgets('can be constructed directly in Dialog',
        (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        testableWidget(
          const Dialog(
            child: ApiKeyModal(
              apiKey: testApiKey,
            ),
          ),
        ),
      );

      expect(find.byType(ApiKeyModal), findsOneWidget);
      expect(find.text('Your API Key'), findsOneWidget);
      expect(find.text(testApiKey), findsOneWidget);
    });

    testWidgets('displays different API keys correctly', (tester) async {
      setDesktopSize(tester);
      const differentKey = 'sk-prod-key-abcdef-12345';

      await tester.pumpWidget(
        testableWidget(
          const Dialog(
            child: ApiKeyModal(
              apiKey: differentKey,
            ),
          ),
        ),
      );

      expect(find.text(differentKey), findsOneWidget);
    });
  });
}
