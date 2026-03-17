import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/vertical_indicator_list.dart';
import 'package:integrity_studio_ai/theme/spacing.dart';

void main() {
  group('VerticalIndicatorList', () {
    // -------------------------------------------------------------------------
    // Row count
    // -------------------------------------------------------------------------

    group('renders correct number of rows', () {
      testWidgets('renders three rows for itemCount 3', (tester) async {
        final builtIndicatorIndices = <int>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 3,
              indicatorBuilder: (index, isLast) {
                builtIndicatorIndices.add(index);
                return Text('indicator-$index');
              },
              contentBuilder: (index, isLast) => Text('content-$index'),
            ),
          ),
        ));

        expect(find.text('indicator-0'), findsOneWidget);
        expect(find.text('indicator-1'), findsOneWidget);
        expect(find.text('indicator-2'), findsOneWidget);
        expect(find.text('content-0'), findsOneWidget);
        expect(find.text('content-1'), findsOneWidget);
        expect(find.text('content-2'), findsOneWidget);
      });

      testWidgets('renders five rows for itemCount 5', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 5,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) => Text('c-$index'),
            ),
          ),
        ));

        for (var i = 0; i < 5; i++) {
          expect(find.text('i-$i'), findsOneWidget);
          expect(find.text('c-$i'), findsOneWidget);
        }
      });
    });

    // -------------------------------------------------------------------------
    // indicatorBuilder called for each index
    // -------------------------------------------------------------------------

    group('indicatorBuilder', () {
      testWidgets('is called with each index in order', (tester) async {
        final capturedIndices = <int>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 4,
              indicatorBuilder: (index, isLast) {
                capturedIndices.add(index);
                return Text('ind-$index');
              },
              contentBuilder: (index, isLast) => Text('cnt-$index'),
            ),
          ),
        ));

        expect(capturedIndices, equals([0, 1, 2, 3]));
      });

      testWidgets('receives correct isLast value', (tester) async {
        final capturedIsLast = <bool>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 3,
              indicatorBuilder: (index, isLast) {
                capturedIsLast.add(isLast);
                return Text('ind-$index');
              },
              contentBuilder: (index, isLast) => Text('cnt-$index'),
            ),
          ),
        ));

        expect(capturedIsLast, equals([false, false, true]));
      });
    });

    // -------------------------------------------------------------------------
    // contentBuilder called with correct isLast
    // -------------------------------------------------------------------------

    group('contentBuilder isLast', () {
      testWidgets('passes isLast=false for all items except the last',
          (tester) async {
        final capturedIsLast = <bool>[];
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 3,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) {
                capturedIsLast.add(isLast);
                return Text('c-$index');
              },
            ),
          ),
        ));

        expect(capturedIsLast[0], isFalse);
        expect(capturedIsLast[1], isFalse);
        expect(capturedIsLast[2], isTrue);
      });

      testWidgets('passes isLast=true for index 0 when itemCount is 1',
          (tester) async {
        bool? capturedIsLast;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 1,
              indicatorBuilder: (index, isLast) => const Text('ind'),
              contentBuilder: (index, isLast) {
                capturedIsLast = isLast;
                return const Text('cnt');
              },
            ),
          ),
        ));

        expect(capturedIsLast, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Spacing between items
    // -------------------------------------------------------------------------

    group('spacing', () {
      testWidgets('applies default spacing as bottom padding on non-last items',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 2,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) => Text('c-$index'),
            ),
          ),
        ));

        // The first item (not last) should be wrapped in a Padding with bottom
        // equal to AppSpacing.md (16).
        final paddings = tester
            .widgetList<Padding>(find.byType(Padding))
            .where((p) =>
                p.padding == const EdgeInsets.only(bottom: AppSpacing.md))
            .toList();

        expect(paddings.length, greaterThanOrEqualTo(1));
      });

      testWidgets('applies custom spacing when provided', (tester) async {
        const customSpacing = 32.0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 2,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) => Text('c-$index'),
              spacing: customSpacing,
            ),
          ),
        ));

        final paddings = tester
            .widgetList<Padding>(find.byType(Padding))
            .where((p) =>
                p.padding ==
                const EdgeInsets.only(bottom: customSpacing))
            .toList();

        expect(paddings.length, greaterThanOrEqualTo(1));
      });

      testWidgets('last item has no bottom padding', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 2,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) => Text('c-$index'),
            ),
          ),
        ));

        // The last item row should NOT be wrapped in Padding with bottom spacing.
        // Find the Row containing the last content widget and verify no ancestor
        // Padding immediately wrapping it has a bottom inset equal to AppSpacing.md.
        final lastContent = find.text('c-1');
        expect(lastContent, findsOneWidget);

        // Walk up: there should be no Padding(bottom: AppSpacing.md) that is a
        // direct structural wrapper of the last item.
        final paddingsWithSpacing = tester
            .widgetList<Padding>(find.byType(Padding))
            .where((p) =>
                p.padding == const EdgeInsets.only(bottom: AppSpacing.md))
            .toList();

        // There is 1 non-last item, so exactly 1 spacing padding should exist.
        expect(paddingsWithSpacing.length, equals(1));
      });
    });

    // -------------------------------------------------------------------------
    // Zero items
    // -------------------------------------------------------------------------

    group('zero items', () {
      testWidgets('renders an empty Column with no children', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 0,
              indicatorBuilder: (index, isLast) => Text('i-$index'),
              contentBuilder: (index, isLast) => Text('c-$index'),
            ),
          ),
        ));

        // The widget itself should exist.
        expect(find.byType(VerticalIndicatorList), findsOneWidget);

        // No indicator or content text should appear.
        expect(find.textContaining('i-'), findsNothing);
        expect(find.textContaining('c-'), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // Single item
    // -------------------------------------------------------------------------

    group('single item', () {
      testWidgets('renders one row with isLast=true', (tester) async {
        bool? capturedIsLast;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 1,
              indicatorBuilder: (index, isLast) => const Text('only-indicator'),
              contentBuilder: (index, isLast) {
                capturedIsLast = isLast;
                return const Text('only-content');
              },
            ),
          ),
        ));

        expect(find.text('only-indicator'), findsOneWidget);
        expect(find.text('only-content'), findsOneWidget);
        expect(capturedIsLast, isTrue);
      });

      testWidgets('renders no spacing padding for a single item',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              itemCount: 1,
              indicatorBuilder: (index, isLast) => const Text('ind'),
              contentBuilder: (index, isLast) => const Text('cnt'),
            ),
          ),
        ));

        final spacingPaddings = tester
            .widgetList<Padding>(find.byType(Padding))
            .where((p) =>
                p.padding == const EdgeInsets.only(bottom: AppSpacing.md))
            .toList();

        expect(spacingPaddings, isEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Key forwarding
    // -------------------------------------------------------------------------

    group('key', () {
      testWidgets('accepts and applies an optional Key', (tester) async {
        const widgetKey = Key('test-vertical-indicator-list');
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: VerticalIndicatorList(
              key: widgetKey,
              itemCount: 1,
              indicatorBuilder: (index, isLast) => const Text('ind'),
              contentBuilder: (index, isLast) => const Text('cnt'),
            ),
          ),
        ));

        expect(find.byKey(widgetKey), findsOneWidget);
      });
    });
  });
}
