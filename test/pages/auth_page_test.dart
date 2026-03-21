import 'package:flutter_test/flutter_test.dart';
import 'package:integrity_studio_ai/config/content/constants.dart';

/// Boundary-value tests for PasswordPolicy validation.
///
/// These tests verify that passwords at exactly minLength and maxLength pass
/// the validation formula used by AuthPage._isPasswordValid:
///   password.length >= PasswordPolicy.minLength &&
///   password.length <= PasswordPolicy.maxLength
///
/// Placed here (not in constants_test.dart) so they can grow into full widget
/// tests for AuthPage when the provisioning UI matures.
void main() {
  group('PasswordPolicy boundary validation', () {
    bool isPasswordValid(String password) =>
        password.isNotEmpty &&
        password.length >= PasswordPolicy.minLength &&
        password.length <= PasswordPolicy.maxLength;

    test('password of exactly minLength (8) passes validation', () {
      final password = 'a' * PasswordPolicy.minLength;
      expect(isPasswordValid(password), isTrue);
    });

    test('password of exactly maxLength (128) passes validation', () {
      final password = 'a' * PasswordPolicy.maxLength;
      expect(isPasswordValid(password), isTrue);
    });

    test('password one character below minLength (7) fails validation', () {
      final password = 'a' * (PasswordPolicy.minLength - 1);
      expect(isPasswordValid(password), isFalse);
    });

    test('password one character above maxLength (129) fails validation', () {
      final password = 'a' * (PasswordPolicy.maxLength + 1);
      expect(isPasswordValid(password), isFalse);
    });

    test('empty password fails validation', () {
      expect(isPasswordValid(''), isFalse);
    });
  });
}
