/// Security utilities for input sanitization and validation.
///
/// Provides methods to sanitize user input and prevent XSS attacks
/// when displaying external data in the UI.
///
/// Note: Flutter's Text widget does not parse HTML by default, but we
/// escape HTML entities as defense-in-depth in case:
/// - Content is logged and viewed in browser developer tools
/// - Content is exported to HTML/email formats
/// - Future code uses HTML rendering widgets
class SecurityUtils {
  /// Maximum length for error messages to prevent DoS
  static const int maxErrorLength = 200;

  /// Maximum length for error codes
  static const int maxErrorCodeLength = 100;

  /// Maximum length for OAuth codes/tokens
  static const int maxOAuthCodeLength = 2048;

  /// Sanitizes user input to prevent XSS attacks.
  ///
  /// Uses a single-pass approach with StringBuffer for efficiency.
  /// Escapes HTML special characters and truncates to [maxLength].
  /// Returns empty string if input is null.
  ///
  /// The escaping order prevents double-encoding bypass attacks by
  /// processing & last, after other special characters are escaped.
  ///
  /// Example:
  /// ```dart
  /// final safe = SecurityUtils.sanitizeUserInput('<script>alert("xss")</script>');
  /// // Returns: '&lt;script&gt;alert(&quot;xss&quot;)&lt;&#x2F;script&gt;'
  /// ```
  static String sanitizeUserInput(String? input, {int? maxLength}) {
    if (input == null || input.isEmpty) return '';

    final limit = maxLength ?? maxErrorLength;
    final buffer = StringBuffer();
    var inputWasTruncated = false;

    // Single-pass sanitization for efficiency
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final codeUnit = char.codeUnitAt(0);

      // Skip NULL bytes and control characters (except newline/tab)
      if (codeUnit == 0 ||
          (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13)) {
        continue;
      }

      // Escape HTML special characters
      // Process < > " ' / first, then & last to prevent double-encoding
      String toAdd;
      switch (char) {
        case '<':
          toAdd = '&lt;';
        case '>':
          toAdd = '&gt;';
        case '"':
          toAdd = '&quot;';
        case "'":
          toAdd = '&#x27;';
        case '/':
          toAdd = '&#x2F;';
        case '&':
          toAdd = '&amp;';
        default:
          // Handle Unicode lookalikes for < and > (homograph attack prevention)
          if (_isUnicodeAngleBracket(codeUnit)) {
            toAdd = '&lt;'; // Treat as <
          } else {
            toAdd = char;
          }
      }

      // Check if adding this would exceed the limit
      if (buffer.length + toAdd.length > limit) {
        inputWasTruncated = true;
        break;
      }
      buffer.write(toAdd);
    }

    // Mark as truncated if we didn't process all input
    if (!inputWasTruncated && input.length > buffer.toString().length) {
      // Some chars were stripped (control chars), check if we processed all
      inputWasTruncated = false;
    }

    final result = buffer.toString();

    // Add truncation indicator if needed
    if (inputWasTruncated) {
      return '${_truncateWithCleanBoundary(result, limit)}...';
    }
    return result;
  }

  /// Check for Unicode characters that look like < or >
  static bool _isUnicodeAngleBracket(int codeUnit) {
    // U+FF1C (Fullwidth Less-Than Sign)
    // U+FF1E (Fullwidth Greater-Than Sign)
    // U+02C2 (Modifier Letter Left Arrowhead)
    // U+02C3 (Modifier Letter Right Arrowhead)
    // U+3008 (Left Angle Bracket)
    // U+3009 (Right Angle Bracket)
    // U+2039 (Single Left-Pointing Angle Quotation Mark)
    // U+203A (Single Right-Pointing Angle Quotation Mark)
    return codeUnit == 0xFF1C ||
        codeUnit == 0xFF1E ||
        codeUnit == 0x02C2 ||
        codeUnit == 0x02C3 ||
        codeUnit == 0x3008 ||
        codeUnit == 0x3009 ||
        codeUnit == 0x2039 ||
        codeUnit == 0x203A;
  }

  /// Truncate string ensuring we don't split HTML entities
  static String _truncateWithCleanBoundary(String input, int maxLength) {
    if (input.length <= maxLength) return input;

    var truncated = input.substring(0, maxLength);

    // If we're in the middle of an entity, back up
    final lastAmp = truncated.lastIndexOf('&');
    if (lastAmp != -1) {
      final afterAmp = truncated.substring(lastAmp);
      // Check if this looks like an incomplete entity
      if (!afterAmp.contains(';') && afterAmp.length < 7) {
        truncated = truncated.substring(0, lastAmp);
      }
    }

    return truncated;
  }

  /// Validates that a string contains only safe characters for display.
  ///
  /// Returns true if input is null, empty, or contains no HTML special chars.
  /// Use this as a quick check before deciding whether to sanitize.
  static bool isSafeForDisplay(String? input) {
    if (input == null || input.isEmpty) return true;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final codeUnit = char.codeUnitAt(0);

      // Check for HTML special characters
      if (char == '<' ||
          char == '>' ||
          char == '"' ||
          char == "'" ||
          char == '/' ||
          char == '&') {
        return false;
      }

      // Check for Unicode lookalikes
      if (_isUnicodeAngleBracket(codeUnit)) {
        return false;
      }

      // Check for control characters
      if (codeUnit == 0 ||
          (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13)) {
        return false;
      }
    }

    return true;
  }

  /// Sanitizes an error code for display.
  ///
  /// Error codes should be alphanumeric with underscores/hyphens only.
  /// Returns null if input is null/empty.
  /// Returns sanitized version if input contains unexpected characters.
  static String? sanitizeErrorCode(String? input) {
    if (input == null || input.isEmpty) return null;

    // Allow only alphanumeric, underscores, and hyphens (standard OAuth error codes)
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input)) {
      // Input contains unexpected characters - potential attack
      // Log would go here in production: debugPrint('[SECURITY] Suspicious error code')
      return sanitizeUserInput(input, maxLength: maxErrorCodeLength);
    }

    // Truncate if too long
    if (input.length > maxErrorCodeLength) {
      return '${input.substring(0, maxErrorCodeLength)}...';
    }
    return input;
  }

  /// Default message for verbose or unrecognized server errors.
  static const String genericErrorMessage =
      'Something went wrong. Please try again.';

  /// Maximum length for a user-displayable server error message.
  static const int maxServerErrorLength = 120;

  /// Sanitizes a raw server error string for display in the UI.
  ///
  /// Passes through short, single-line messages that are likely user-friendly.
  /// Falls back to [genericErrorMessage] for verbose, multi-line, or
  /// stack-trace-containing strings to prevent internal detail leakage.
  static String sanitizeServerError(String raw) {
    if (raw.length > maxServerErrorLength ||
        raw.contains('\n') ||
        raw.contains(' at ')) {
      return genericErrorMessage;
    }
    return raw;
  }

  /// Sanitizes an OAuth authorization code.
  ///
  /// OAuth codes are typically base64-encoded, so we allow alphanumeric
  /// plus standard base64 characters (+, /, =, -). Any other characters
  /// are sanitized for safe display/logging.
  static String? sanitizeOAuthCode(String? input) {
    if (input == null || input.isEmpty) return null;

    // OAuth codes are typically base64 or hex encoded
    // Allow: alphanumeric, +, /, =, -, _ (for base64url)
    if (!RegExp(r'^[a-zA-Z0-9+/=_-]+$').hasMatch(input)) {
      // Unexpected format - sanitize for safe display
      return sanitizeUserInput(input, maxLength: maxOAuthCodeLength);
    }

    // Truncate if too long
    if (input.length > maxOAuthCodeLength) {
      return '${input.substring(0, maxOAuthCodeLength)}...';
    }
    return input;
  }

  /// Sanitizes an OAuth state parameter.
  ///
  /// State parameters are typically base64-encoded or random hex strings.
  /// Returns sanitized version if unexpected characters are found.
  static String? sanitizeOAuthState(String? input) {
    if (input == null || input.isEmpty) return null;

    // State params are typically base64url or hex
    // Allow: alphanumeric, -, _, . (for base64url)
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(input)) {
      // Unexpected format - sanitize for safe display
      return sanitizeUserInput(input, maxLength: maxErrorCodeLength);
    }

    // Truncate if too long
    if (input.length > maxErrorCodeLength) {
      return '${input.substring(0, maxErrorCodeLength)}...';
    }
    return input;
  }
}
