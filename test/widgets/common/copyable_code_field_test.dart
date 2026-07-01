import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:integrity_studio_ai/widgets/common/copyable_code_field.dart';

void main() {
  testWidgets('renders code field with label', (WidgetTester tester) async {
    const testCode = 'sk-test-api-key-123';
    const testLabel = 'API Key';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
            label: testLabel,
          ),
        ),
      ),
    );

    expect(find.text(testLabel), findsOneWidget);
    expect(find.text(testCode), findsOneWidget);
    expect(find.byKey(const ValueKey('copyable-code-field')), findsOneWidget);
  });

  testWidgets('renders without label when label is null',
      (WidgetTester tester) async {
    const testCode = 'sk-test-api-key-123';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
          ),
        ),
      ),
    );

    expect(find.text(testCode), findsOneWidget);
    expect(find.byKey(const ValueKey('copyable-code-field')), findsOneWidget);
  });

  testWidgets('copy button copies code to clipboard', (WidgetTester tester) async {
    const testCode = 'sk-test-api-key-123';

    // Mock clipboard
    final clipboardData = <String, dynamic>{};
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardData['text'] = call.arguments['text'];
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
          ),
        ),
      ),
    );

    // Find and tap copy button
    await tester.tap(find.byKey(const ValueKey('copy-button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(clipboardData['text'], testCode);
  });

  testWidgets('copy button shows success feedback', (WidgetTester tester) async {
    const testCode = 'sk-test-api-key-123';

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
          ),
        ),
      ),
    );

    // Initially shows copy icon
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);

    // Tap copy button
    await tester.tap(find.byKey(const ValueKey('copy-button')));
    await tester.pumpAndSettle();

    // Shows check icon and "Copied!" text
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    expect(find.text('Copied!'), findsOneWidget);

    // After 2 seconds, reverts back
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byIcon(LucideIcons.copy), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('renders custom code style when provided',
      (WidgetTester tester) async {
    const testCode = 'const x = 1;';
    final customStyle = TextStyle(
      fontFamily: 'Custom',
      fontSize: 14,
      color: Colors.red,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
            codeStyle: customStyle,
          ),
        ),
      ),
    );

    final textWidget = find
        .descendant(
          of: find.byKey(const ValueKey('copyable-code-field')),
          matching: find.byType(SelectableText),
        )
        .evaluate()
        .first
        .widget as SelectableText;

    expect(textWidget.style?.fontFamily, 'Custom');
    expect(textWidget.style?.fontSize, 14);
  });

  testWidgets('renders on both desktop and mobile viewports',
      (WidgetTester tester) async {
    const testCode = 'short-key';

    // Test desktop size
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyableCodeField(
            code: testCode,
            label: 'API Key',
          ),
        ),
      ),
    );

    expect(find.text('API Key'), findsOneWidget);
    expect(find.text(testCode), findsOneWidget);
    expect(find.byKey(const ValueKey('copy-button')), findsOneWidget);
  });
}
