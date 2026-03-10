import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/widgets/common/form_fields.dart';
import '../../helpers/test_helpers.dart';

void main() {
  // ==========================================================================
  // UNIT TESTS - FormTextFieldType
  // ==========================================================================

  group('FormTextFieldType', () {
    test('has all expected types', () {
      expect(FormTextFieldType.values.length, equals(4));
      expect(FormTextFieldType.values, contains(FormTextFieldType.text));
      expect(FormTextFieldType.values, contains(FormTextFieldType.email));
      expect(FormTextFieldType.values, contains(FormTextFieldType.phone));
      expect(FormTextFieldType.values, contains(FormTextFieldType.url));
    });
  });

  // ==========================================================================
  // WIDGET TESTS - FormTextField
  // ==========================================================================

  group('FormTextField', () {
    testWidgets('renders all elements correctly', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: 'test@example.com',
            onChanged: (_) {},
            required: true,
            placeholder: 'you@example.com',
          ),
        ),
      );

      // Label with required indicator
      expect(find.text('Email *'), findsOneWidget);
      // Current value
      expect(find.text('test@example.com'), findsOneWidget);
      // Placeholder (in hint)
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('handles error states correctly', (tester) async {
      // With error text
      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: '',
            onChanged: (_) {},
            errorText: 'Please enter a valid email',
          ),
        ),
      );
      expect(find.text('Please enter a valid email'), findsOneWidget);

      // Empty error text should not show error
      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: '',
            onChanged: (_) {},
            errorText: '',
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);

      // Null error text (default)
      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: '',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('calls onChanged and respects disabled state', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: '',
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'new@example.com');
      expect(changedValue, equals('new@example.com'));

      // Test disabled state
      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: 'test@example.com',
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      );

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('supports all keyboard types', (tester) async {
      for (final type in FormTextFieldType.values) {
        await tester.pumpWidget(
          testableWidget(
            FormTextField(
              label: type.name,
              value: '',
              onChanged: (_) {},
              type: type,
            ),
          ),
        );
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text(type.name), findsOneWidget);
      }
    });

    testWidgets('accepts focus node and text input action', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        testableWidget(
          FormTextField(
            label: 'Email',
            value: '',
            onChanged: (_) {},
            focusNode: focusNode,
            textInputAction: TextInputAction.next,
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      focusNode.dispose();
    });
  });

  // ==========================================================================
  // WIDGET TESTS - FormTextArea
  // ==========================================================================

  group('FormTextArea', () {
    testWidgets('renders all elements correctly', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: 'Hello world',
            onChanged: (_) {},
            required: true,
            placeholder: 'Enter your message...',
          ),
        ),
      );

      expect(find.text('Message *'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Enter your message...'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('supports rows and character limit configuration', (tester) async {
      // Default rows
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: '',
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);

      // Custom rows
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: '',
            onChanged: (_) {},
            rows: 10,
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);

      // With maxLength
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: '',
            onChanged: (_) {},
            maxLength: 500,
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);

      // Hidden counter
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: 'Test',
            onChanged: (_) {},
            maxLength: 500,
            showCharacterCount: false,
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('renders error text when provided', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: '',
            onChanged: (_) {},
            errorText: 'Message is required',
          ),
        ),
      );

      expect(find.text('Message is required'), findsOneWidget);
    });

    testWidgets('calls onChanged and respects disabled state', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: '',
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New message');
      expect(changedValue, equals('New message'));

      // Test disabled state
      await tester.pumpWidget(
        testableWidget(
          FormTextArea(
            label: 'Message',
            value: 'Existing message',
            onChanged: (_) {},
            enabled: false,
          ),
        ),
      );

      final textField = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });
  });

  // ==========================================================================
  // WIDGET TESTS - FormSelect
  // ==========================================================================

  group('FormSelect', () {
    testWidgets('renders all elements correctly', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          FormSelect<String>(
            label: 'Country',
            value: 'us',
            items: const [
              DropdownMenuItem(value: 'us', child: Text('USA')),
              DropdownMenuItem(value: 'uk', child: Text('UK')),
            ],
            onChanged: (_) {},
            required: true,
            placeholder: 'Select a country',
          ),
        ),
      );

      expect(find.text('Country *'), findsOneWidget);
      expect(find.text('USA'), findsOneWidget);
    });

    testWidgets('renders error text when provided', (tester) async {
      await tester.pumpWidget(
        testableWidget(
          FormSelect<String>(
            label: 'Country',
            value: null,
            items: const [
              DropdownMenuItem(value: 'us', child: Text('USA')),
            ],
            onChanged: (_) {},
            errorText: 'Please select a country',
          ),
        ),
      );

      expect(find.text('Please select a country'), findsOneWidget);
    });

    testWidgets('calls onChanged when selection changes', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        testableWidget(
          FormSelect<String>(
            label: 'Country',
            value: null,
            items: const [
              DropdownMenuItem(value: 'us', child: Text('USA')),
              DropdownMenuItem(value: 'uk', child: Text('UK')),
            ],
            onChanged: (value) => selectedValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettleWithTimeout();

      await tester.tap(find.text('UK').last);
      await tester.pumpAndSettleWithTimeout();

      expect(selectedValue, equals('uk'));
    });

    testWidgets('respects disabled state', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        testableWidget(
          FormSelect<String>(
            label: 'Country',
            value: 'us',
            items: const [
              DropdownMenuItem(value: 'us', child: Text('USA')),
              DropdownMenuItem(value: 'uk', child: Text('UK')),
            ],
            onChanged: (value) => selectedValue = value,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettleWithTimeout();

      expect(selectedValue, isNull);
    });

    testWidgets('works with different value types', (tester) async {
      // Int values
      int? intValue;
      await tester.pumpWidget(
        testableWidget(
          FormSelect<int>(
            label: 'Age',
            value: null,
            items: const [
              DropdownMenuItem(value: 18, child: Text('18')),
              DropdownMenuItem(value: 21, child: Text('21')),
            ],
            onChanged: (value) => intValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettleWithTimeout();
      await tester.tap(find.text('21').last);
      await tester.pumpAndSettleWithTimeout();

      expect(intValue, equals(21));

      // Enum values
      _TestEnum? enumValue;
      await tester.pumpWidget(
        testableWidget(
          FormSelect<_TestEnum>(
            label: 'Priority',
            value: null,
            items: const [
              DropdownMenuItem(value: _TestEnum.low, child: Text('Low')),
              DropdownMenuItem(value: _TestEnum.high, child: Text('High')),
            ],
            onChanged: (value) => enumValue = value,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<_TestEnum>));
      await tester.pumpAndSettleWithTimeout();
      await tester.tap(find.text('High').last);
      await tester.pumpAndSettleWithTimeout();

      expect(enumValue, equals(_TestEnum.high));
    });
  });
}

enum _TestEnum { low, high }
