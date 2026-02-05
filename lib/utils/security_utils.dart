/// Security utilities for input sanitization and validation.
///
/// Provides methods to sanitize user input and prevent XSS attacks
/// when displaying external data in the UI.
class SecurityUtils {
  /// Maximum length for error messages to prevent DoS
  static const int maxErrorLength = 200;

  /// Maximum length for error codes
  static const int maxErrorCodeLength = 100;

  /// Sanitizes user input to prevent XSS attacks.
  ///
  /// Escapes HTML special characters and truncates to [maxLength].
  /// Returns empty string if input is null.
  ///
  /// Example:
  /// ```dart
  /// final safe = SecurityUtils.sanitizeUserInput('<script>alert("xss")</script>');
  /// // Returns: '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;'
  /// ```
  static String sanitizeUserInput(String? input, {int? maxLength}) {
    if (input == null || input.isEmpty) return '';

    // Escape HTML special characters
    final sanitized = input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    final limit = maxLength ?? maxErrorLength;
    if (sanitized.length > limit) {
      return '${sanitized.substring(0, limit)}...';
    }
    return sanitized;
  }

  /// Validates that a string contains only safe characters for display.
  ///
  /// Returns true if input is null, empty, or contains no HTML special chars.
  static bool isSafeForDisplay(String? input) {
    if (input == null || input.isEmpty) return true;
    return !RegExp(r'[<>"' "'" r'/]').hasMatch(input);
  }

  /// Sanitizes an error code for display.
  ///
  /// Error codes should be alphanumeric with underscores only.
  /// Returns null if input doesn't match expected pattern.
  static String? sanitizeErrorCode(String? input) {
    if (input == null || input.isEmpty) return null;

    // Allow only alphanumeric, underscores, and hyphens
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input)) {
      // Input contains unexpected characters, sanitize it
      return sanitizeUserInput(input, maxLength: maxErrorCodeLength);
    }

    // Truncate if too long
    if (input.length > maxErrorCodeLength) {
      return '${input.substring(0, maxErrorCodeLength)}...';
    }
    return input;
  }
}
