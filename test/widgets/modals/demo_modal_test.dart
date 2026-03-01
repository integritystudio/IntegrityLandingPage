import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/modals/demo_modal.dart';
import '../../helpers/test_helpers.dart';

void main() {

  group('DemoModal', () {
    group('rendering', () {
      testWidgets('renders without video ID', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        // Tap button to open modal
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
      });

      testWidgets('renders with video ID', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context, videoId: 'abc123'),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsOneWidget);
        expect(find.textContaining('Demo video loading'), findsOneWidget);
      });

      testWidgets('shows placeholder when no video ID', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Demo Video Coming Soon'), findsOneWidget);
      });

      testWidgets('shows description text in placeholder', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Integrity Studio'), findsWidgets);
      });
    });

    group('close button', () {
      testWidgets('has close button', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // Find close icon button
        expect(find.byType(IconButton), findsWidgets);
      });

      testWidgets('tapping close button dismisses modal', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsOneWidget);

        // Find and tap close button (first IconButton)
        final closeButtons = find.byType(IconButton);
        await tester.tap(closeButtons.first);
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsNothing);
      });
    });

    group('CTA section', () {
      testWidgets('shows Close button when no onScheduleDemo', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Close'), findsOneWidget);
      });

      testWidgets('shows Schedule Live Demo button when onScheduleDemo provided', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(
                  context,
                  onScheduleDemo: () {},
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Schedule Live Demo'), findsOneWidget);
      });

      testWidgets('tapping Schedule Live Demo calls callback and closes modal', (tester) async {
        setDesktopSize(tester);
        var scheduleCalled = false;

        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(
                  context,
                  onScheduleDemo: () => scheduleCalled = true,
                ),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Schedule Live Demo'));
        await tester.pumpAndSettle();

        expect(scheduleCalled, isTrue);
        expect(find.byType(DemoModal), findsNothing);
      });

      testWidgets('tapping Close button closes modal', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsNothing);
      });
    });

    group('responsive layout', () {
      // Note: Mobile viewport has known overflow issues
      testWidgets(
        'renders on mobile viewport',
        (tester) async {
          setMobileSize(tester);
          await tester.pumpWidget(
            testableWidget(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => DemoModal.show(context),
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open Modal'));
          await tester.pumpAndSettle();

          expect(find.byType(DemoModal), findsOneWidget);
        },
      );

      testWidgets('renders on tablet viewport', (tester) async {
        setTabletSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsOneWidget);
      });
    });

    group('barrier behavior', () {
      testWidgets('modal can be dismissed by tapping barrier', (tester) async {
        setDesktopSize(tester);
        await tester.pumpWidget(
          testableWidget(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DemoModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsOneWidget);

        // Tap outside the dialog to dismiss
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byType(DemoModal), findsNothing);
      });
    });
  });

  group('DemoModal widget direct', () {
    testWidgets('can be constructed directly', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        testableWidget(
          const Scaffold(
            body: Dialog(
              child: DemoModal(),
            ),
          ),
        ),
      );

      expect(find.byType(DemoModal), findsOneWidget);
    });

    testWidgets('accepts videoId parameter', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(
        testableWidget(
          const Scaffold(
            body: Dialog(
              child: DemoModal(videoId: 'test123'),
            ),
          ),
        ),
      );

      expect(find.textContaining('Demo video loading'), findsOneWidget);
    });
  });
}
